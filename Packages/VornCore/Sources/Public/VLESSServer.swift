import CryptoKit
import Foundation

/// Сервер из vless:// ссылки подписки (Reality/Vision).
///
/// Контракт идентичности: `id` — «тот же сервер» для UI и дедупликации,
/// `==` — полное равенство значения (включая имя). Переименование сервера
/// в панели не меняет `id`, но меняет значение.
public struct VLESSServer: Codable, Identifiable, Hashable, Sendable {
    /// Стабильный идентификатор: SHA-256 от полей, определяющих подключение
    /// (всё, кроме имени). Секретов не содержит — безопасен для логов и
    /// диагностики; изменение любого параметра подключения даёт новый id.
    public let id: String
    /// Имя из fragment-части ссылки (#name).
    public let name: String
    public let address: String
    public let port: Int
    /// UUID пользователя из userinfo-части ссылки. Секрет — не логировать.
    public let userID: String
    /// flow из query (для Vision — "xtls-rprx-vision"). Только с network=tcp.
    public let flow: String?
    /// Транспорт из query-параметра type; по умолчанию tcp. Поддерживаются
    /// "tcp" (RAW, для Vision) и "xhttp".
    public let network: String
    /// Параметры Reality. Продукт поддерживает только VLESS Reality,
    /// поэтому поле обязательное — сервер без Reality непредставим.
    public let reality: RealitySettings
    /// Параметры XHTTP; не-nil только при network=xhttp.
    public let xhttp: XHTTPSettings?

    public init(
        name: String,
        address: String,
        port: Int,
        userID: String,
        flow: String? = nil,
        network: String = "tcp",
        reality: RealitySettings,
        xhttp: XHTTPSettings? = nil
    ) {
        self.name = name
        self.address = address
        self.port = port
        self.userID = userID
        self.flow = flow
        self.network = network
        self.reality = reality
        self.xhttp = xhttp
        self.id = Self.connectionID(
            userID: userID, address: address, port: port,
            flow: flow, network: network, reality: reality, xhttp: xhttp
        )
    }

    /// Имя для поверхностей за пределами Keychain-периметра — виджет кладёт
    /// его в общие UserDefaults App Group и рисует на рабочем столе, откуда
    /// оно попадает в бэкапы и снапшоты WidgetKit. nil, когда имя раскрывает
    /// адрес сервера (CLAUDE.md: адреса наружу не выносим): это и заглушка
    /// «address:port» для ссылок без #fragment, и панельное имя, содержащее
    /// адрес, — заглушка содержит адрес по построению, правило одно.
    public var sharableName: String? {
        name.range(of: address, options: .caseInsensitive) == nil ? name : nil
    }

    /// Разбирает одиночную vless://-ссылку (импорт «голого ключа» без
    /// подписки). nil — из ссылки нельзя собрать рабочий Reality/Vision-сервер:
    /// битый URL, чужая схема, security != reality, невалидные pbk/sid,
    /// неподдерживаемый транспорт (не tcp/raw) или flow (не Vision).
    /// Полные правила валидации — во внутреннем VLESSLinkParser.
    public init?(link: String) {
        guard let server = VLESSLinkParser.parse(link) else { return nil }
        self = server
    }

    private static func connectionID(
        userID: String,
        address: String,
        port: Int,
        flow: String?,
        network: String,
        reality: RealitySettings,
        xhttp: XHTTPSettings?
    ) -> String {
        let material = [
            userID, address, String(port), flow ?? "", network,
            reality.publicKey, reality.shortID, reality.serverName,
            reality.fingerprint, reality.spiderX ?? "",
            xhttp?.path ?? "", xhttp?.host ?? "", xhttp?.mode ?? "",
        ].joined(separator: "\n")
        let digest = SHA256.hash(data: Data(material.utf8))
        // 64 бит хватает для дедупликации списка серверов с запасом.
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
