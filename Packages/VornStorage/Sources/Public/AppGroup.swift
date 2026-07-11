import Foundation

/// Общие идентификаторы App + PacketTunnel extension.
/// Значения обязаны совпадать с entitlements обоих таргетов (Project.swift).
public enum AppGroup {
    /// Контейнер, общий для приложения и extension.
    public static let identifier = "group.com.bigboys.Vorn"

    /// Keychain access group: приложение кладёт конфиг, extension читает.
    /// Совпадает с App Group: group.*-идентификаторы попадают в entitlements
    /// как есть, без Team-ID префикса. На macOS доступность group.*-группы
    /// как keychain access group зависит от подписи и провижининга —
    /// проверить при добавлении entitlements вместе с таргетом PacketTunnel.
    public static let keychainAccessGroup = identifier

    /// kSecAttrService, общий для приложения и extension. Совпадает с
    /// bundle id приложения (Project.swift) — при смене менять синхронно.
    public static let keychainService = "com.bigboys.Vorn"

    /// Bundle id extension-таргета — им NETunnelProviderManager находит провайдер.
    public static let tunnelBundleIdentifier = "com.bigboys.Vorn.PacketTunnel"
}
