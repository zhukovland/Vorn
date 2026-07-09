import Foundation

/// Хранилище чувствительных данных (подписочные URL, ключи).
/// Реализация — Keychain с access group на App Group; UserDefaults не использовать.
public protocol SecureStore: Sendable {
    func save(_ data: Data, forKey key: String) throws
    func load(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
}
