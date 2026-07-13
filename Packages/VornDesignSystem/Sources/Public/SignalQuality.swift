import SwiftUI

/// Качество связи вместо голого пинга: рядовому пользователю понятнее
/// «хорошая/слабая», чем «12 мс». Пороги RTT в одном месте.
public enum SignalQuality: Sendable, Equatable {
    case good
    case fair
    case poor
    /// Пинг ещё не измерен или сервер не ответил.
    case unknown

    /// Пороги под реальную сеть: даже лучшие серверы часто стартуют с ~500 мс
    /// (расстояние + оверхед обфускации). Меняются здесь одной строкой.
    public init(pingMs: Int?) {
        switch pingMs {
        case .none: self = .unknown
        case let ms? where ms <= 800: self = .good
        case let ms? where ms <= 1500: self = .fair
        default: self = .poor
        }
    }

    /// Сколько полосок зажечь (0…3).
    public var bars: Int {
        switch self {
        case .good: 3
        case .fair: 2
        case .poor: 1
        case .unknown: 0
        }
    }

    public var label: String {
        switch self {
        case .good: "Хорошая"
        case .fair: "Средняя"
        case .poor: "Слабая"
        case .unknown: "—"
        }
    }
}

/// Полоски сигнала: восходящие столбики, зажжено `quality.bars` в акценте,
/// остальные тусклые. На бренде, без светофора.
public struct SignalBars: View {
    private let quality: SignalQuality

    @Environment(\.vornTheme) private var theme

    public init(_ quality: SignalQuality) {
        self.quality = quality
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < quality.bars ? theme.colors.accent : theme.colors.hairline)
                    .frame(width: 3, height: 5 + CGFloat(index) * 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Качество связи: \(quality.label)")
    }
}
