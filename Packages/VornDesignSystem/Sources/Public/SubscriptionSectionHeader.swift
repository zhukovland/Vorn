import SwiftUI

/// Заголовок секции подписки над сеткой её серверов: имя подписки слева,
/// метаданные (трафик/срок) и меню действий (⋯) справа — обновить/удалить.
/// Само подтверждение удаления показывает вызывающий (алерт). Домен не знает.
///
/// Если передан onToggleCollapse, заголовок становится тумблером сворачивания:
/// тап по имени сворачивает/разворачивает секцию, состояние показывает
/// шеврон. Прячет ли контент — решает вызывающий; здесь только управление.
public struct SubscriptionSectionHeader: View {
    private let title: String
    private let meta: String?
    private let refreshing: Bool
    private let collapsed: Bool
    private let onToggleCollapse: (() -> Void)?
    private let onRefresh: (() -> Void)?
    private let onPing: (() -> Void)?
    private let onDelete: (() -> Void)?

    @Environment(\.vornTheme) private var theme

    public init(
        title: String,
        meta: String? = nil,
        refreshing: Bool = false,
        collapsed: Bool = false,
        onToggleCollapse: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onPing: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.title = title
        self.meta = meta
        self.refreshing = refreshing
        self.collapsed = collapsed
        self.onToggleCollapse = onToggleCollapse
        self.onRefresh = onRefresh
        self.onPing = onPing
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: VornSpacing.s) {
            if let onToggleCollapse {
                Button(action: onToggleCollapse) {
                    HStack(spacing: VornSpacing.s) {
                        titleAndMeta
                        chevron
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                titleAndMeta
            }
            Spacer(minLength: VornSpacing.s)
            trailing
        }
        .padding(.horizontal, VornSpacing.xs)
    }

    @ViewBuilder
    private var titleAndMeta: some View {
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
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.colors.inkTertiary)
            .rotationEffect(.degrees(collapsed ? -90 : 0))
    }

    @ViewBuilder
    private var trailing: some View {
        if refreshing {
            ProgressView().controlSize(.small)
        } else if onRefresh != nil || onPing != nil || onDelete != nil {
            Menu {
                if let onRefresh {
                    Button(action: onRefresh) {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                }
                if let onPing {
                    Button(action: onPing) {
                        Label("Измерить пинг", systemImage: "gauge.medium")
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
