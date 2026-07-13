import SwiftUI

/// Заголовок секции подписки над сеткой её серверов: имя подписки слева,
/// метаданные (трафик/срок) и меню действий (⋯) справа — обновить/удалить.
/// Само подтверждение удаления показывает вызывающий (алерт). Домен не знает.
public struct SubscriptionSectionHeader: View {
    private let title: String
    private let meta: String?
    private let refreshing: Bool
    private let onRefresh: (() -> Void)?
    private let onDelete: (() -> Void)?

    @Environment(\.vornTheme) private var theme

    public init(
        title: String,
        meta: String? = nil,
        refreshing: Bool = false,
        onRefresh: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.meta = meta
        self.refreshing = refreshing
        self.onRefresh = onRefresh
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: VornSpacing.s) {
            Text(title)
                .font(VornFont.title(15))
                .foregroundStyle(theme.colors.inkPrimary)
                .lineLimit(1)
            if let meta {
                Text(meta)
                    .font(VornFont.mono(11))
                    .foregroundStyle(theme.colors.inkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: VornSpacing.s)
            trailing
        }
        .padding(.horizontal, VornSpacing.xs)
    }

    @ViewBuilder
    private var trailing: some View {
        if refreshing {
            ProgressView().controlSize(.small)
        } else if onRefresh != nil || onDelete != nil {
            Menu {
                if let onRefresh {
                    Button(action: onRefresh) {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                }
                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.inkSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
        }
    }
}
