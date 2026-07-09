import Foundation

/// Разбор подписки Remnawave: base64-текст со списком vless:// ссылок.
public enum SubscriptionParser {
    public enum ParseError: Error, Equatable {
        /// Формат не распознан: не base64 и не текст со vless:// ссылками.
        case invalidBase64
        /// Формат распознан, но ни одного валидного VLESS-сервера не осталось.
        case noServers
    }

    /// Декодирует ответ сервера подписки в список серверов.
    ///
    /// Канонический формат — base64 (включая base64url и вариант без паддинга)
    /// от списка ссылок. Сначала пробуем его; если декодирование не удалось или
    /// в декодированном нет ни одного сервера — разбираем payload как плейн-текст.
    /// Это покрывает панели, отдающие уже декодированный список (в том числе с
    /// заголовками-комментариями первой строкой), и плейн-текст, случайно
    /// являющийся валидным base64. Невалидные строки и чужие протоколы молча
    /// пропускаются; дубликаты (по id) схлопываются.
    public static func parse(payload: String) throws -> [VLESSServer] {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.invalidBase64 }

        var candidates: [String] = []
        if let data = Data(relaxedBase64: trimmed),
           let decoded = String(data: data, encoding: .utf8) {
            candidates.append(decoded)
        }
        candidates.append(trimmed)

        for text in candidates {
            let found = servers(in: text)
            if !found.isEmpty { return found }
        }

        if candidates.count == 1,
           trimmed.range(of: "vless://", options: .caseInsensitive) == nil {
            throw ParseError.invalidBase64
        }
        throw ParseError.noServers
    }

    private static func servers(in text: String) -> [VLESSServer] {
        var seen = Set<String>()
        var result: [VLESSServer] = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard let server = VLESSLinkParser.parse(String(line)) else { continue }
            if seen.insert(server.id).inserted {
                result.append(server)
            }
        }
        return result
    }
}
