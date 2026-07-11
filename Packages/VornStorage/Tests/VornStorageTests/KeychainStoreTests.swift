import Foundation
import Security
import Testing
@testable import VornStorage

struct KeychainStoreTests {
    /// Запросы к Keychain можно проверить, не трогая сам Keychain: именно
    /// атрибуты запроса определяют, увидит ли extension запись приложения.
    @Test func queryPinsServiceAccountAndAccessGroup() {
        let store = KeychainStore(service: "com.bigboys.Vorn", accessGroup: AppGroup.keychainAccessGroup)
        let query = store.query(forKey: "vault.state")

        #expect(query[kSecClass as String] as? String == kSecClassGenericPassword as String)
        #expect(query[kSecAttrService as String] as? String == "com.bigboys.Vorn")
        #expect(query[kSecAttrAccount as String] as? String == "vault.state")
        #expect(query[kSecAttrAccessGroup as String] as? String == "group.com.bigboys.Vorn")
    }

    @Test func queryOmitsAccessGroupWhenAbsent() {
        let query = KeychainStore(service: "s", accessGroup: nil).query(forKey: "k")
        #expect(query[kSecAttrAccessGroup as String] == nil)
    }

    /// Без него на macOS элемент уходит в legacy-keychain, где access group
    /// игнорируется, и extension не увидит запись приложения.
    @Test func queryUsesDataProtectionKeychain() {
        let query = KeychainStore(service: "s", accessGroup: nil).query(forKey: "k")
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
    }

    /// Data protection keychain доступен только подписанному процессу с
    /// entitlements: `swift test` получает errSecMissingEntitlement (-34018).
    /// Проверяем, что статус доходит до вызывающего и в ошибке нет ничего,
    /// кроме OSStatus — ни ключа, ни данных. Живой Keychain проверяется
    /// на устройстве, когда появятся entitlements у таргетов.
    @Test func keychainFailureSurfacesStatusOnly() {
        let store = KeychainStore(service: "com.bigboys.Vorn.tests", accessGroup: AppGroup.keychainAccessGroup)
        // Если окружение всё же позволит запись (подписанный тест-хост),
        // не оставляем след в реальном Keychain.
        defer { try? store.delete(forKey: "probe") }
        #expect(throws: SecureStoreError.keychain(status: errSecMissingEntitlement)) {
            try store.save(Data("secret".utf8), forKey: "probe")
        }
    }
}
