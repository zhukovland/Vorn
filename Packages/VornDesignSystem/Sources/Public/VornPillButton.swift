import SwiftUI

/// Кнопка-пилюля. Filled — главное действие (Подключить), outline —
/// обратное (Отключить). На токенах темы.
public struct VornPillButton: View {
    public enum Kind: Sendable { case filled, outline }

    private let title: String
    private let kind: Kind
    private let busy: Bool
    private let action: () -> Void

    @Environment(\.vornTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, kind: Kind = .filled, busy: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.busy = busy
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(VornFont.title(16))
                    .opacity(busy ? 0 : 1)
                if busy {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: VornRadius.pill)
                    .strokeBorder(kind == .outline ? theme.colors.accent.opacity(0.5) : .clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: VornRadius.pill))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var foreground: Color {
        switch kind {
        case .filled: theme.isDark ? theme.colors.base : Color.white
        case .outline: theme.colors.accent
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .filled:
            LinearGradient(
                colors: [theme.colors.accent, theme.colors.accentDeep],
                startPoint: .top, endPoint: .bottom
            )
        case .outline:
            theme.colors.accent.opacity(0.08)
        }
    }
}
