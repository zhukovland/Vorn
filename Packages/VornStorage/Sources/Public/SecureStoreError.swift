import Foundation

/// Ошибки уровня хранилища; наружу модуля их бросают операции ServerVault.
public enum SecureStoreError: Error, Equatable {
    /// Не удалось прочитать/записать Keychain. Несёт только OSStatus:
    /// ни ключей, ни адресов серверов в описании ошибки быть не должно.
    case keychain(status: OSStatus)
    /// В хранилище лежит не Data ожидаемого вида.
    case corruptedData
}
