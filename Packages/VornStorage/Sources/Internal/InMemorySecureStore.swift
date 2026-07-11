import Foundation

/// Реализация SecureStore для тестов (доступна через @testable).
/// В проде не использовать: данные живут только в памяти процесса.
final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    // @unchecked Sendable: изменяемое состояние защищено замком.
    // Это единственное место в проекте, где мы обходим проверку компилятора,
    // и только потому, что SecureStore синхронный (как SecItem-API).
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    init() {}

    func save(_ data: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    func load(forKey key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func delete(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
