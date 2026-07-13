import SwiftUI

/// Состояние подключения глазами дизайн-системы — без привязки к
/// NetworkExtension. Приложение маппит NEVPNStatus в эту фазу.
public enum ConnectionPhase: Sendable, Equatable {
    case idle
    case connecting
    case protected
    case failed

    /// Слово-состояние — для доступности (VoiceOver), не для показа текстом.
    public var title: String {
        switch self {
        case .idle: "Открыто"
        case .connecting: "Подключение"
        case .protected: "Защищено"
        case .failed: "Ошибка"
        }
    }

    /// SF Symbol в центре диска: power как кнопка питания, dotted — загрузка.
    public var symbolName: String {
        switch self {
        case .idle: "power"
        case .connecting: "power"
        case .protected: "power"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var isAnimated: Bool { self == .protected || self == .connecting }
}
