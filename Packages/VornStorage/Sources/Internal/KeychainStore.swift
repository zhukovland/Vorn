import Foundation

/// Keychain-реализация SecureStore с access group на App Group.
/// Наружу отдаётся только как SecureStore через фабрику в Public.
struct KeychainStore: SecureStore {
    let accessGroup: String

    func save(_ data: Data, forKey key: String) throws {
        // TODO: SecItemAdd/SecItemUpdate с kSecAttrAccessGroup.
    }

    func load(forKey key: String) throws -> Data? {
        // TODO: SecItemCopyMatching.
        nil
    }

    func delete(forKey key: String) throws {
        // TODO: SecItemDelete.
    }
}
