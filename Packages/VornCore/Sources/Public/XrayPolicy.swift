import Foundation

/// Структурные константы генерируемого конфига. Вынесены сюда, потому что на
/// них ссылаются и билдер, и санитайзер, и (в будущем) routing-правила из
/// extension-таргета: компилятор не ловит расхождение магических строк через
/// границу App↔Extension, а Xray отвергает конфиг с висячим тегом на старте.
public enum XrayTag {
    /// VLESS/Reality outbound — весь проксируемый трафик.
    public static let proxy = "proxy"
    /// freedom outbound — задел под split-tunnel; сейчас правил на него нет.
    public static let direct = "direct"
}

public enum XrayPolicy {
    /// Единственный допустимый уровень логирования: в логах extension не должно
    /// быть UUID ключей и адресов серверов.
    public static let logLevel = "warning"

    /// Верхнеуровневые ключи, которые разрешено передавать ядру.
    ///
    /// Allowlist, а не blocklist: Xray добавляет управляющие и телеметрийные
    /// поверхности от релиза к релизу (api, metrics, stats, observatory,
    /// burstObservatory, reverse, fakedns, policy). Перечислять запрещённое
    /// — значит отставать на релиз; перечисляем разрешённое.
    public static let allowedTopLevelKeys: Set<String> = [
        "log", "dns", "inbounds", "outbounds", "routing", "transport",
    ]
}
