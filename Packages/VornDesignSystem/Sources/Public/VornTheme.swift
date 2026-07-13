import SwiftUI

/// Полный набор токенов одной темы. Компоненты читают только это —
/// сырых цветов и величин по месту быть не должно.
public struct VornTheme: Sendable {
    public let colors: Colors
    public let isDark: Bool
    /// Амплитуда фонового зерна. На светлом слабее — шум заметнее на белом.
    public let grain: Double

    /// Семантические цвета. Именуем по роли, не по оттенку: смена палитры
    /// не должна ломать смысл в местах использования.
    public struct Colors: Sendable {
        /// Дальний фон экрана.
        public let base: Color
        /// Приподнятая поверхность (карточки, секции).
        public let raised: Color
        /// Утопленная поверхность (поля ввода, желоба).
        public let sunken: Color
        /// Основной текст.
        public let inkPrimary: Color
        /// Второстепенный текст.
        public let inkSecondary: Color
        /// Третичный текст, подписи.
        public let inkTertiary: Color
        /// Единственный акцент бренда — медь. Состояние «под защитой».
        public let accent: Color
        /// Тёмная медь для нажатий/градиентов.
        public let accentDeep: Color
        /// Свечение ореола дыхания (медь с прозрачностью кладём по месту).
        public let glow: Color
        /// Промежуточное состояние (подключаюсь).
        public let pending: Color
        /// Ошибка/разрыв.
        public let danger: Color
        /// Тонкая разделительная линия.
        public let hairline: Color
    }

    /// Тёмная тема: чернильный индиго, медь как единственный акцент.
    public static let dark = VornTheme(
        colors: Colors(
            base: Color(hex: 0x101120),
            raised: Color(hex: 0x1A1B30),
            sunken: Color(hex: 0x0A0B16),
            inkPrimary: Color(hex: 0xECEDF5),
            inkSecondary: Color(hex: 0x9A9CB5),
            inkTertiary: Color(hex: 0x5E6080),
            accent: Color(hex: 0xA78BFA),
            accentDeep: Color(hex: 0x7C5CE0),
            glow: Color(hex: 0xA78BFA),
            pending: Color(hex: 0xC4B5FD),
            danger: Color(hex: 0xD9736A),
            hairline: Color.white.opacity(0.08)
        ),
        isDark: true,
        grain: 0.055
    )

    /// Светлая тема: туман/бумага; медь темнее ради контраста на светлом.
    public static let light = VornTheme(
        colors: Colors(
            base: Color(hex: 0xEFF1F7),
            raised: Color(hex: 0xFFFFFF),
            sunken: Color(hex: 0xE4E7F0),
            inkPrimary: Color(hex: 0x1A1B2E),
            inkSecondary: Color(hex: 0x565877),
            inkTertiary: Color(hex: 0x8A8CA6),
            accent: Color(hex: 0x6D3CD4),
            accentDeep: Color(hex: 0x522BA6),
            glow: Color(hex: 0x8B5CF6),
            pending: Color(hex: 0x8B6FD0),
            danger: Color(hex: 0xC0483E),
            hairline: Color.black.opacity(0.08)
        ),
        isDark: false,
        grain: 0.03
    )
}

// MARK: - Environment

private struct VornThemeKey: EnvironmentKey {
    static let defaultValue = VornTheme.dark
}

public extension EnvironmentValues {
    var vornTheme: VornTheme {
        get { self[VornThemeKey.self] }
        set { self[VornThemeKey.self] = newValue }
    }
}

/// Как выбирается тема: следовать системе или зафиксировать одну.
public enum VornThemePreference: String, Sendable, CaseIterable {
    case system, dark, light
}

public extension View {
    /// Кладёт тему в окружение по предпочтению пользователя и системной
    /// схеме. Ставится на корневой view приложения.
    func vornThemed(_ preference: VornThemePreference) -> some View {
        modifier(VornThemeProvider(preference: preference))
    }
}

private struct VornThemeProvider: ViewModifier {
    let preference: VornThemePreference
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let theme: VornTheme = switch preference {
        case .system: colorScheme == .dark ? .dark : .light
        case .dark: .dark
        case .light: .light
        }
        content
            .environment(\.vornTheme, theme)
            .tint(theme.colors.accent)
    }
}
