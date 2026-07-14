import CryptoKit
import Foundation
import VornCore

/// Одна подписка: источник и список серверов, полученных из него.
public struct Subscription: Codable, Identifiable, Equatable, Sendable {
    /// Стабильный идентификатор источника: подписка — это её URL, поэтому
    /// повторный импорт того же URL обновляет запись, а не плодит копии.
    /// SHA-256-префикс, а не сам URL: подписочный URL — capability-ссылка
    /// с секретным токеном, id же обязан быть безопасным для логов —
    /// та же конвенция, что у VLESSServer.id. Сравнение побайтовое, без
    /// нормализации: URL копируют из панели как есть.
    public var id: String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    public let url: URL
    /// Отображаемое имя. Пользователь может переименовать, на id не влияет.
    public var name: String
    /// Серверы этой подписки в порядке, в котором их отдал сервер.
    public var servers: [VLESSServer]
    /// Момент последнего успешного обновления.
    public var updatedAt: Date
    /// Сообщение панели (заголовок announce): акции, техработы и т.п.
    /// Относится к этой подписке, не глобально.
    public var announce: String?

    public init(
        url: URL,
        name: String,
        servers: [VLESSServer],
        updatedAt: Date,
        announce: String? = nil
    ) {
        self.url = url
        self.name = name
        self.servers = servers
        self.updatedAt = updatedAt
        self.announce = announce
    }
}

/// Ссылка на выбранный сервер. Указывает источник, а не только сервер:
/// один и тот же сервер может присутствовать в двух подписках и среди
/// ручных ключей — VLESSServer.id (хэш параметров подключения) сам по
/// себе источник не различает.
public enum ServerSelection: Codable, Equatable, Hashable, Sendable {
    /// Сервер из подписки.
    case subscription(subscriptionID: String, serverID: String)
    /// Сервер, добавленный голой vless://-ссылкой.
    case manual(serverID: String)
}
