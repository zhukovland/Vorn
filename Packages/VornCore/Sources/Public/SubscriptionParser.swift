import Foundation

/// Разбор подписки Remnawave: base64-текст со списком vless:// ссылок.
public enum SubscriptionParser {
    public enum ParseError: Error, Equatable {
        case invalidBase64
        case noServers
    }

    /// Декодирует base64-ответ сервера подписки в список серверов.
    public static func parse(base64Payload: String) throws -> [VLESSServer] {
        // TODO: реализовать вместе с экраном импорта подписки.
        throw ParseError.noServers
    }
}
