
import SwiftUI

/// Данные героя — примитивы, без домена. Кнопка показывает только
/// состояние и пинг; какой сервер подключён — видно по выделению в списке.
public struct ConnectHeroModel: Sendable {
    public var phase: ConnectionPhase
    public var latencyMs: Int?

    public init(phase: ConnectionPhase, latencyMs: Int? = nil) {
        self.phase = phase
        self.latencyMs = latencyMs
    }
}

/// Герой-экран подключения: дышащий диск — сам по себе кнопка (тап
/// подключает/отключает). Подпись экрана — единственный дышащий элемент,
/// без генеричных прямоугольных кнопок.
public struct ConnectHero: View {
    private let model: ConnectHeroModel
    private let busy: Bool
    private let onToggle: () -> Void

    @Environment(\.vornTheme) private var theme

    public init(model: ConnectHeroModel, busy: Bool = false, onToggle: @escaping () -> Void) {
        self.model = model
        self.busy = busy
        self.onToggle = onToggle
    }

    public var body: some View {
        VStack(spacing: VornSpacing.l) {
            discButton
            if let ping = pingText {
                pingPill(ping)
            }
            hint
        }
    }

    private var discButton: some View {
        Button(action: onToggle) {
            ZStack {
                BreathingDisc(phase: model.phase, diameter: 130)
                Image(systemName: model.phase.symbolName)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(symbolColor)
                    //.symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.automatic))
            }
            .frame(height: 180)
            .contentShape(Circle())
        }
        .buttonStyle(DiscButtonStyle())
        .disabled(busy)
    }

    private var symbolColor: Color {
        // Выключено — серый; подключение и защищено — акцент (одинаковый, без
        // промежуточного оттенка, чтобы цвет не мельтешил); ошибка — красный.
        switch model.phase {
        case .idle: theme.colors.inkSecondary
        case .connecting, .protected: theme.colors.accent
        case .failed: theme.colors.danger
        }
    }

    private func pingPill(_ ping: String) -> some View {
        HStack(spacing: VornSpacing.xs) {
            Image(systemName: "bolt.fill").font(.system(size: 9))
            Text(ping).font(VornFont.mono(12))
        }
        .foregroundStyle(theme.colors.inkSecondary)
        .padding(.horizontal, VornSpacing.m)
        .padding(.vertical, VornSpacing.xs)
        .background(theme.colors.raised.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(theme.colors.hairline, lineWidth: 1))
    }

    private var hint: some View {
        Text(hintText)
            .font(VornFont.caption())
            .foregroundStyle(theme.colors.inkTertiary)
            .textCase(.uppercase)
            .tracking(1)
    }

    private var hintText: String {
        switch model.phase {
        case .idle: "Нажмите, чтобы подключиться"
        case .connecting: "Подключение…"
        case .protected: "Нажмите, чтобы отключить"
        case .failed: "Нажмите, чтобы повторить"
        }
    }

    private var pingText: String? {
        guard model.phase == .protected, let latency = model.latencyMs else { return nil }
        return "\(latency) мс"
    }
}

/// Нажатие на диск: мягкое проседание пружиной — тактильный отклик без
/// прямоугольной кнопки.
private struct DiscButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

/// Интерактивное превью: тап по диску гоняет цикл idle→подключение→защита→
/// idle, чтобы вживую видеть «печать» и запуск дыхания.
private struct HeroPlayground: View {
    @State private var phase: ConnectionPhase = .idle
    var body: some View {
        VornBackground {
            ConnectHero(
                model: ConnectHeroModel(phase: phase, latencyMs: 12),
                onToggle: advance
            )
        }
    }
    private func advance() {
        switch phase {
        case .idle, .failed: phase = .connecting
        case .connecting: phase = .protected
        case .protected: phase = .idle
        }
    }
}

#Preview("Интерактив · тёмная") {
    HeroPlayground().vornThemed(.dark).frame(width: 390, height: 760)
}

#Preview("Тёмная · защищено") {
    VornBackground {
        ConnectHero(
            model: ConnectHeroModel(phase: .protected, latencyMs: 12),
            onToggle: {}
        )
    }
    .vornThemed(.dark)
    .frame(width: 390, height: 760)
}

#Preview("Светлая · защищено") {
    VornBackground {
        ConnectHero(
            model: ConnectHeroModel(phase: .protected, latencyMs: 12),
            onToggle: {}
        )
    }
    .vornThemed(.light)
    .frame(width: 390, height: 760)
}

#Preview("Светлая · открыто") {
    VornBackground {
        ConnectHero(
            model: ConnectHeroModel(phase: .idle),
            onToggle: {}
        )
    }
    .vornThemed(.light)
    .frame(width: 390, height: 760)
}
