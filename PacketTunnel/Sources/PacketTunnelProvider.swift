import NetworkExtension
import SwiftyXrayKit
import VornCore
import VornStorage

/// Единственное место в проекте, где живёт SwiftyXrayKit (план Б из CLAUDE.md:
/// замена ядра не должна трогать ничего, кроме этого таргета). Конфиг
/// сервера читается из общего Keychain, собирается билдером VornCore и
/// принудительно проходит санитайзер в configTransform-хуке.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    // bridge и stopped защищены замком: система может прислать stopTunnel,
    // пока startTunnel ещё поднимает мост (таргет nonisolated, ничто не
    // сериализует эти вызовы). stopped закрывает гонку «стоп во время старта».
    private let lock = NSLock()
    private var bridge: XrayBridge?
    private var stopped = false

    enum TunnelError: Error {
        case noServerSelected
        case configEncoding
    }

    override func startTunnel(options: [String: NSObject]?) async throws {
        let server: VLESSServer
        do {
            guard let selected = try ServerVault().load().selectedServer else {
                throw TunnelError.noServerSelected
            }
            server = selected
        } catch {
            // Провал старта не ведёт к вызову stopTunnel — фазу для виджета
            // сбрасываем сами, иначе он застрянет на «Подключение…».
            WidgetTunnelState.set(.disconnected)
            throw Self.describe(error)
        }

        do {
            try await setTunnelNetworkSettings(Self.networkSettings(remoteAddress: server.address))
            try startXray(for: server)
        } catch {
            WidgetTunnelState.set(.disconnected)
            throw Self.describe(error)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        // Синхронный хелпер: замок не пересекает await (NSLock это запрещает).
        takeBridgeAndMarkStopped()?.stop()
        try? FileManager.default.removeItem(at: Self.finalConfigURL)
        WidgetTunnelState.set(.disconnected)
    }

    private func startXray(for server: VLESSServer) throws {
        let configData = try XrayConfigBuilder.makeConfig(for: server)
        guard let json = String(data: configData, encoding: .utf8) else {
            throw TunnelError.configEncoding
        }

        // Стоп мог прийти, пока собирался конфиг — не поднимаем ядро зря.
        if isStopped { return }

        let newBridge = XrayBridge(packetFlow: packetFlow)
        let configPath = Self.finalConfigURL
        try newBridge.start(
            config: .json(json),
            // Гео-файлы не нужны: routing без geoip/geosite-правил.
            dataDir: FileManager.default.temporaryDirectory,
            finalConfigPath: configPath,
            configTransform: { XrayConfigSanitizer.sanitize($0) }
            // traceHandle не задаём: жизненный цикл ядра может упоминать
            // адреса — в логах extension им не место (CLAUDE.md).
        )
        // Ядро уже прочитало конфиг в память при запуске — файл с UUID и
        // адресом сервера на диске больше не нужен (CLAUDE.md: ключи только
        // в Keychain). Удаляем сразу, сужая окно до времени старта ядра.
        try? FileManager.default.removeItem(at: configPath)

        // Стоп мог прийти, пока поднимался мост: тогда его уже никто не
        // заберёт — гасим ядро здесь, иначе оно осталось бы работать.
        if installBridge(newBridge) {
            // Extension — единственный процесс, живущий ровно столько,
            // сколько поднят туннель: его запись достоверна даже когда
            // приложение закрыто и наблюдателя NEVPNStatusDidChange нет.
            WidgetTunnelState.set(.connected)
        } else {
            newBridge.stop()
        }
    }

    // MARK: - Синхронный доступ к bridge/stopped под замком

    private var isStopped: Bool {
        lock.lock(); defer { lock.unlock() }
        return stopped
    }

    /// Устанавливает мост, если стоп ещё не пришёл. false — стоп опередил.
    private func installBridge(_ newBridge: XrayBridge) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !stopped else { return false }
        bridge = newBridge
        return true
    }

    /// Помечает провайдер остановленным и отдаёт текущий мост (для stop()).
    private func takeBridgeAndMarkStopped() -> XrayBridge? {
        lock.lock(); defer { lock.unlock() }
        stopped = true
        let running = bridge
        bridge = nil
        return running
    }

    /// Причина отказа уходит приложению через fetchLastDisconnectError, но
    /// NetworkExtension дублирует её в системный лог — поэтому наружу только
    /// обобщённый текст без адресов и UUID (CLAUDE.md). OSStatus безопасен:
    /// это число, не секрет.
    private static func describe(_ error: Error) -> NSError {
        let message: String
        switch error {
        case TunnelError.noServerSelected:
            message = "Сервер не выбран"
        case TunnelError.configEncoding:
            message = "Не удалось собрать конфигурацию"
        case SwiftyXRayError.invalidResponse:
            message = "Xray не запустился — проверьте параметры сервера"
        case SecureStoreError.keychain(let status):
            message = "Keychain недоступен в extension (OSStatus \(status))"
        case VaultError.corruptedState:
            message = "Состояние в Keychain не читается"
        default:
            message = "Не удалось запустить туннель"
        }
        return NSError(
            domain: "com.bigboys.Vorn.PacketTunnel",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static var finalConfigURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("xray-final.json")
    }

    private static func networkSettings(remoteAddress: String) -> NEPacketTunnelNetworkSettings {
        // tunnelRemoteAddress — диагностическая метка конечной точки;
        // трафик самого extension в туннель не заворачивается, маршрутизация
        // от неё не зависит. Система принимает только IP-литерал, поэтому
        // для доменного адреса ставим заглушку из TEST-NET-1 (RFC 5737):
        // резолвить домен здесь — лишняя точка отказа до подъёма туннеля,
        // а loopback читался бы как локальный прокси (которого у нас нет).
        let remote = isIPLiteral(remoteAddress) ? remoteAddress : "192.0.2.1"
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remote)

        let ipv4 = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // Без этого IPv6-трафик на dual-stack сети шёл бы мимо туннеля с
        // реальным IP. Дефолтный маршрут заводит его в TUN-inbound Xray
        // (ядро обрабатывает AF_INET6).
        let ipv6 = NEIPv6Settings(addresses: ["fd00:7::2"], networkPrefixLengths: [64])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        // Пустой matchDomain = все DNS-запросы системы идут в туннель.
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        // Согласован с TUN-inbound SwiftyXrayKit (XrayBridge задаёт MTU 1360).
        settings.mtu = 1360
        return settings
    }

    private static func isIPLiteral(_ address: String) -> Bool {
        var v4 = in_addr()
        var v6 = in6_addr()
        return inet_pton(AF_INET, address, &v4) == 1 || inet_pton(AF_INET6, address, &v6) == 1
    }
}
