import SwiftUI

/// Разбор ведущего флаг-эмодзи в имени сервера. Флаг — пара regional-indicator
/// символов (U+1F1E6…U+1F1FF); из неё же выводится ISO-код страны.
public enum ServerName {
    /// Отделяет ведущий флаг от остального имени. Флаг убираем из текста —
    /// показываем его отдельным чипом.
    public static func split(_ name: String) -> (flag: String?, title: String) {
        let scalars = Array(name.unicodeScalars)
        guard scalars.count >= 2, isRegionalIndicator(scalars[0]), isRegionalIndicator(scalars[1]) else {
            return (nil, name)
        }
        let flag = String(String.UnicodeScalarView(scalars[0...1]))
        let rest = String(String.UnicodeScalarView(scalars[2...]))
            .trimmingCharacters(in: .whitespaces)
        return (flag, rest.isEmpty ? name : rest)
    }

    /// ISO-код страны из флага ("🇳🇱" → "NL"); nil, если это не флаг.
    public static func countryCode(_ flag: String) -> String? {
        let scalars = Array(flag.unicodeScalars)
        guard scalars.count == 2, isRegionalIndicator(scalars[0]), isRegionalIndicator(scalars[1]) else {
            return nil
        }
        let letters = scalars.map { Character(Unicode.Scalar($0.value - 0x1F1E6 + 0x41)!) }
        return String(letters)
    }

    private static func isRegionalIndicator(_ s: Unicode.Scalar) -> Bool {
        (0x1F1E6...0x1F1FF).contains(s.value)
    }
}

/// Флаг сервера — просто нативный эмодзи-флаг, без рамки и подложки.
/// На Apple-платформах он рендерится настоящим флагом, картинки не нужны.
/// Показывается только при наличии флага.
public struct FlagChip: View {
    private let flag: String
    private let size: CGFloat

    public init(flag: String, size: CGFloat = 22) {
        self.flag = flag
        self.size = size
    }

    public var body: some View {
        Text(flag).font(.system(size: size))
    }
}
