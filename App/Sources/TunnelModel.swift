import Foundation
// @preconcurrency: API NetworkExtension старше строгой конкурентности и
// не помечено Sendable; хэлпер снимает диагностику для типов фреймворка,
// наш собственный код остаётся под проверкой Swift 6.
@preconcurrency import NetworkExtension
import VornStorage

/// Управление packet-tunnel-профилем: создание NETunnelProviderManager,
/// старт/стоп туннеля и отслеживание статуса. Сам конфиг сервера через
/// NE не передаётся — extension читает его из общего Keychain.
@Observable
@MainActor
final class TunnelModel {
    private(set) var status: NEVPNStatus = .invalid
    var lastError: String?

    @ObservationIgnored private var manager: NETunnelProviderManager?
    // Один общий Task подготовки: prepare() из .task и connect() по кнопке
    // ждут его же, а не создают по второму профилю (гонка первого запуска).
    // Success = Void: NETunnelProviderManager не Sendable, поэтому результат
    // не пересекает границу — Task пишет self.manager как side effect.
    @ObservationIgnored private var prepareTask: Task<Void, Never>?
    // nonisolated(unsafe): токен трогают только init (main) и deinit;
    // NotificationCenter.removeObserver потокобезопасен.
    @ObservationIgnored nonisolated(unsafe) private var statusObserver: NSObjectProtocol?

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }
            // queue: .main гарантирует главный поток — изоляция реальна.
            MainActor.assumeIsolated {
                self?.handle(connection)
            }
        }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
    }

    private func handle(_ connection: NEVPNConnection) {
        status = connection.status
        guard status == .disconnected else { return }
        // Ошибка startTunnel не долетает до startVPNTunnel() — система
        // сообщает её постфактум, причиной последнего разрыва. Колбэк-форма
        // (не async): NEVPNConnection не Sendable, слать его в Task нельзя;
        // через границу уходит только готовая строка.
        connection.fetchLastDisconnectError { [weak self] error in
            guard let message = error?.localizedDescription else { return }
            Task { @MainActor in self?.lastError = message }
        }
    }

    /// Находит существующий профиль Vorn или создаёт и сохраняет новый.
    /// Первый вызов покажет системный запрос «разрешить добавление VPN».
    func prepare() async {
        _ = await preparedManager()
    }

    private func preparedManager() async -> NETunnelProviderManager? {
        if let manager { return manager }
        // Первый вошедший создаёт Task, остальные ждут его же (MainActor
        // делает проверку-и-создание атомарной между точками await).
        let task = prepareTask ?? {
            let created = Task { await self.doPrepare() }
            prepareTask = created
            return created
        }()
        await task.value
        return manager
    }

    private func doPrepare() async {
        defer { prepareTask = nil }
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                manager = existing
                status = existing.connection.status
                return
            }

            let created = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = AppGroup.tunnelBundleIdentifier
            // Отображается в системных настройках VPN; реальный адрес
            // сервера живёт в Keychain и сюда не попадает.
            proto.serverAddress = "Vorn"
            created.protocolConfiguration = proto
            created.localizedDescription = "Vorn"
            // Включаем сразу: иначе первый connect() платит ещё за одну
            // пару save/load, чтобы поднять isEnabled.
            created.isEnabled = true
            try await created.saveToPreferences()
            try await created.loadFromPreferences()
            manager = created
            status = created.connection.status
        } catch {
            lastError = "Не удалось подготовить VPN-профиль: \(error.localizedDescription)"
        }
    }

    func connect() async {
        guard let manager = await preparedManager() else { return }
        do {
            if !manager.isEnabled {
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            try manager.connection.startVPNTunnel()
            lastError = nil
        } catch {
            lastError = "Не удалось запустить туннель: \(error.localizedDescription)"
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    var isActive: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }

    var statusText: String {
        switch status {
        case .invalid: "профиль не установлен"
        case .disconnected: "отключено"
        case .connecting: "подключение…"
        case .connected: "подключено"
        case .reasserting: "переподключение…"
        case .disconnecting: "отключение…"
        @unknown default: "неизвестное состояние"
        }
    }
}
