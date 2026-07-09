import Foundation

/// Сервер из vless:// ссылки подписки.
public struct VLESSServer: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    /// Имя из fragment-части ссылки (#name).
    public var name: String
    public var address: String
    public var port: Int
    /// UUID пользователя из userinfo-части ссылки.
    public var userID: String

    public init(id: UUID = UUID(), name: String, address: String, port: Int, userID: String) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.userID = userID
    }
}
