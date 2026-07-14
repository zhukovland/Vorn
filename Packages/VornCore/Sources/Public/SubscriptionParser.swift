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
    /// Поддерживаются три формата: список vless:// ссылок в base64 (канонический
    /// Remnawave), тот же список плейн-текстом и XRAY_JSON (массив/объект полных
    /// Xray-конфигов — панель отдаёт его некоторым клиентам). JSON пробуем и в
    /// самом теле, и после base64-декодирования. Невалидные строки и чужие
    /// протоколы молча пропускаются; дубликаты (по id) схлопываются.
    public static func parse(payload: String) throws -> [VLESSServer] {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ParseError.invalidBase64 }

        var candidates: [String] = []
        if let data = Data(relaxedBase64: trimmed),
           let decoded = String(data: data, encoding: .utf8) {
            candidates.append(decoded)
        }
        candidates.append(trimmed)

        // 1) XRAY_JSON: тело (или декодированное) — JSON-массив/объект конфигов.
        var sawJSON = false
        for text in candidates {
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard body.hasPrefix("[") || body.hasPrefix("{") else { continue }
            sawJSON = true
            if let servers = XrayJSONSubscriptionParser.parse(Data(body.utf8)), !servers.isEmpty {
                return servers
            }
        }

        // 2) Список vless:// ссылок (в base64 или плейн-тексте).
        for text in candidates {
            let found = servers(in: text)
            if !found.isEmpty { return found }
        }

        // JSON распознан, но серверов не извлекли — это noServers, не «не base64».
        if !sawJSON, candidates.count == 1,
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
