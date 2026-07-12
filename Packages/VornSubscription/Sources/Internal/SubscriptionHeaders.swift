import Foundation

/// Разбор заголовков ответа подписки по конвенциям экосистемы v2ray
/// (Remnawave/Marzban/PasarGuard и черновик стандарта XTLS #4877).
enum SubscriptionHeaders {
    /// profile-title и announce приходят одинаково: сырой текст либо
    /// "base64:<base64 UTF-8>" (Remnawave кодирует, чтобы уместить не-ASCII
    /// и переносы в один HTTP-заголовок).
    static func text(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        let prefix = "base64:"
        guard raw.hasPrefix(prefix) else { return raw }
        let encoded = String(raw.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: encoded),
              let decoded = String(data: data, encoding: .utf8)
        else { return raw }
        return decoded
    }

    /// URL-заголовок (support-url, profile-web-page-url): принимаем только
    /// http/https, чтобы в UI не пролезла ссылка на произвольную схему.
    static func url(_ raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    /// profile-update-interval: целое число часов → секунды.
    static func updateInterval(_ raw: String?) -> TimeInterval? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), let hours = Double(raw), hours > 0
        else { return nil }
        return hours * 3600
    }

    /// subscription-userinfo: "upload=0; download=N; total=N; expire=unixsec".
    /// Пары через ";", значения целые; total=0 → безлимит, expire=0 → без срока.
    static func userInfo(_ raw: String?) -> SubscriptionUserInfo? {
        guard let raw, !raw.isEmpty else { return nil }
        var fields: [String: Int64] = [:]
        for pair in raw.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces)
            let value = Int64(kv[1].trimmingCharacters(in: .whitespaces))
            if let value { fields[key] = value }
        }
        guard !fields.isEmpty else { return nil }
        let expire = fields["expire"].flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
        return SubscriptionUserInfo(
            upload: fields["upload"],
            download: fields["download"],
            total: fields["total"].flatMap { $0 > 0 ? $0 : nil },
            expire: expire
        )
    }
}
