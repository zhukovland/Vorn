import Foundation

/// Параметры Reality из query-части ссылки.
public struct RealitySettings: Codable, Hashable, Sendable {
    /// pbk — публичный ключ сервера (x25519).
    public let publicKey: String
    /// sid — short ID; может быть пустым.
    public let shortID: String
    /// sni — имя маскировочного сайта.
    public let serverName: String
    /// fp — TLS-фингерпринт (uTLS), например "chrome".
    public let fingerprint: String
    /// spx — spiderX, опционально.
    public let spiderX: String?

    public init(publicKey: String, shortID: String, serverName: String, fingerprint: String, spiderX: String? = nil) {
        self.publicKey = publicKey
        self.shortID = shortID
        self.serverName = serverName
        self.fingerprint = fingerprint
        self.spiderX = spiderX
    }
}
