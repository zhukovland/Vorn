import SwiftUI

/// Состояние карточки сервера в списке.
public enum ServerCardState: Sendable, Equatable {
    /// Обычный сервер.
    case normal
    /// Выбран пользователем — статичный обвод.
    case selected
    /// Туннель поднят через него — по границе бежит огонёк.
    case connected
}

/// Карточка сервера в сетке. Домен не знает — принимает готовые строки.
public struct ServerCard: View {
    private let name: String
    private let quality: SignalQuality
    private let pingMs: Int?
    private let transport: String?
    private let state: ServerCardState
    private let onTap: () -> Void
    
    @Environment(\.vornTheme) private var theme
    
    public init(
        name: String,
        quality: SignalQuality = .unknown,
        pingMs: Int? = nil,
        transport: String? = nil,
        state: ServerCardState = .normal,
        onTap: @escaping () -> Void
    ) {
        self.name = name
        self.quality = quality
        self.pingMs = pingMs
        self.transport = transport
        self.state = state
        self.onTap = onTap
    }
    
    public var body: some View {
        let parsed = ServerName.split(name)
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: VornSpacing.xs) {
                HStack(spacing: VornSpacing.s) {
                    if let flag = parsed.flag {
                        FlagChip(flag: flag)
                    }
                    if let transport {
                        Text(transport)
                            .font(VornFont.caption(10))
                            .foregroundStyle(theme.colors.inkTertiary)
                            .padding(.horizontal, VornSpacing.s)
                            .padding(.vertical, 2)
                            .background(theme.colors.sunken, in: Capsule())
                    }
                    Spacer()
                    
                    SignalBars(quality)

                }
                Spacer(minLength: VornSpacing.xs)
                Text(parsed.title)
                    .font(VornFont.title(15))
                    .foregroundStyle(theme.colors.inkPrimary)
                // До 2 строк, затем обрезка. minimumScaleFactor не ставим:
                // на многострочном тексте он ломает перенос (схлопывает в
                // одну строку).
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(VornSpacing.l)
            // Фиксированная высота (min==max) — карточки в сетке одинаковые.
            // Хватает на 2 строки имени; Spacer выше прибивает имя к низу.
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100, alignment: .leading)
            .background(theme.colors.raised, in: RoundedRectangle(cornerRadius: VornRadius.card))
            .overlay { border }
            .contentShape(RoundedRectangle(cornerRadius: VornRadius.card))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: VornRadius.card)
        switch state {
        case .normal:
            shape.strokeBorder(theme.colors.hairline, lineWidth: 1)
        case .selected:
            shape.strokeBorder(theme.colors.accent, lineWidth: 1.5)
        case .connected:
            RunningBorder()
        }
    }
}

/// Бегущий по периметру огонёк — активный (подключённый) сервер. Ровный
/// свет ведёт вращающийся угловой градиент; под ним тусклый акцентный
/// контур, чтобы граница читалась всегда. reduce-motion оставляет контур.
private struct RunningBorder: View {
    @Environment(\.vornTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let period: Double = 2.6
    
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: VornRadius.card)
        ZStack {
            shape.strokeBorder(theme.colors.accent.opacity(0.3), lineWidth: 1.5)
            if reduceMotion {
                shape.strokeBorder(theme.colors.accent, lineWidth: 1.5)
            } else {
                TimelineView(.animation) { timeline in
                    let angle = rotation(at: timeline.date)
                    shape.strokeBorder(comet(angle: angle), lineWidth: 2)
                }
            }
        }
    }
    
    private func rotation(at date: Date) -> Double {
        (date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period) * 360
    }
    
    /// Короткая яркая «голова» с затухающим хвостом, крутится по контуру.
    private func comet(angle: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: theme.colors.accent.opacity(0), location: 0),
                .init(color: theme.colors.accent.opacity(0), location: 0.72),
                .init(color: theme.colors.glow, location: 0.94),
                .init(color: theme.colors.accent.opacity(0), location: 1),
            ]),
            center: .center,
            angle: .degrees(angle)
        )
    }
}

// MARK: - Preview

#Preview("Карточки · состояния") {
    VornBackground {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VornSpacing.m) {
            ServerCard(name: "🇳🇱 Нидерланды NL-01", quality: .good, pingMs: 540, transport: "Vision", state: .connected, onTap: {})
            ServerCard(name: "🇩🇪 Германия DE-02", quality: .fair, pingMs: 1120, transport: "XHTTP", state: .selected, onTap: {})
            ServerCard(name: "🇸🇪 Швеция Стокгольм Премиум Максимальная Скорость", quality: .good, pingMs: 760, transport: "Vision", onTap: {})
            ServerCard(name: "США US-03", quality: .poor, pingMs: 1840, transport: "XHTTP", onTap: {})
            
            ServerCard(name: "США US-03", quality: .unknown, pingMs: nil, transport: "XHTTP", onTap: {})
        }
        .padding(VornSpacing.l)
    }
    .vornThemed(.dark)
    .frame(width: 390, height: 420)
}
