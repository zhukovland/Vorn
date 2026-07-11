import Foundation

/// Хранилище чувствительных данных (подписочные URL, ключи серверов).
/// Единственная реализация в проде — Keychain с access group на App Group;
/// UserDefaults не использовать. Наружу модуля протокол не торчит:
/// публичное API хранения — только ServerVault.
protocol SecureStore: Sendable {
    func save(_ data: Data, forKey key: String) throws
    func load(forKey key: String) throws -> Data?
    func delete(forKey key: String) throws
}
