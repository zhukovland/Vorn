import SwiftUI

/// Типографика. Дисплей — SF Pro с плотным трекингом (читается как сильный
/// гротеск), данные — моноширинные цифры. Кастомную дисплейную гарнитуру
/// можно подключить сюда позже как ресурс пакета, не трогая места вызова.
public enum VornFont {
    /// Крупное слово-состояние («Защищено»).
    public static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Заголовки секций и карточек.
    public static func title(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Основной текст.
    public static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Подписи, метки.
    public static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Числа и технические значения (адрес, задержка, трафик).
    public static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

/// Трекинг для дисплейного слова-состояния: лёгкое разрежение придаёт
/// «гротескную» осанку.
public extension Text {
    func vornDisplayTracking() -> Text {
        tracking(1.5)
    }
}
