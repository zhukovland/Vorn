import Foundation
import Security

/// Keychain-реализация SecureStore с access group на App Group.
/// Наружу отдаётся только как SecureStore через фабрику `SecureStore.keychain`.
struct KeychainStore: SecureStore {
    let service: String
    /// nil — дефолтная группа процесса. В тестах и превью access group
    /// недоступна (нет entitlements), в проде всегда AppGroup.keychainAccessGroup.
    let accessGroup: String?

    /// Базовый запрос, идентифицирующий один элемент.
    ///
    /// `kSecUseDataProtectionKeychain` обязателен: на macOS без него элемент
    /// уходит в legacy file-based keychain, который access group игнорирует —
    /// extension не увидел бы запись приложения. На iOS это поведение по умолчанию.
    ///
    /// `kSecAttrAccessibleAfterFirstUnlock` тоже обязателен: extension поднимается
    /// системой в фоне, в том числе когда устройство заблокировано, и с
    /// `WhenUnlocked` не смог бы прочитать конфиг.
    func query(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    func save(_ data: Data, forKey key: String) throws {
        let query = query(forKey: key)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
            switch addStatus {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                // Другой писатель создал элемент между update и add —
                // элемент уже есть, значит повторный update обязан пройти.
                let retryStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
                guard retryStatus == errSecSuccess else {
                    throw SecureStoreError.keychain(status: retryStatus)
                }
            default:
                throw SecureStoreError.keychain(status: addStatus)
            }
        default:
            throw SecureStoreError.keychain(status: updateStatus)
        }
    }

    func load(forKey key: String) throws -> Data? {
        var query = query(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw SecureStoreError.corruptedData }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw SecureStoreError.keychain(status: status)
        }
    }

    func delete(forKey key: String) throws {
        let status = SecItemDelete(query(forKey: key) as CFDictionary)
        // Удалять несуществующее — не ошибка: операция идемпотентна.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError.keychain(status: status)
        }
    }
}
