import Foundation

extension Data {
    /// Декодирует base64 в «подписочном» виде: допускает base64url-алфавит (-, _),
    /// переносы строк и пробелы внутри, отсутствие =-паддинга.
    init?(relaxedBase64 string: String) {
        var normalized = string
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: normalized)
    }
}
