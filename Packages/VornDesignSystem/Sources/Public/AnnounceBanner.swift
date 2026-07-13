import SwiftUI

/// Баннер объявления панели (заголовок announce): сообщение пользователю —
/// акции, техработы, причина пустого списка.
public struct AnnounceBanner: View {
    private let text: String

    @Environment(\.vornTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: VornSpacing.s) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 12))
                .foregroundStyle(theme.colors.accent)
                .padding(.top, 1)
            Text(text)
                .font(VornFont.body(13))
                .foregroundStyle(theme.colors.inkSecondary)
            Spacer(minLength: 0)
        }
        .padding(VornSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: VornRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: VornRadius.small)
                .strokeBorder(theme.colors.accent.opacity(0.2), lineWidth: 1)
        )
    }
}
