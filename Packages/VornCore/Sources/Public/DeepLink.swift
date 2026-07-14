import Foundation

/// Диплинки vorn:// — разбор здесь, политика исполнения за приложением:
/// - `vorn://add/<https-ссылка>` — добавить подписку (формат как
///   `happ://add/...` у других клиентов); импорт только с подтверждением
///   пользователя — молчаливый позволил бы сайту подменить серверы своими;
/// - `vorn://on` — подключить туннель (безопасно выполнять молча);
/// - `vorn://off` — отключить; приложение обязано спросить подтверждение:
///   молчаливое отключение по ссылке — атака на деанонимизацию (страница
///   гасит VPN и видит реальный адрес);
/// - `vorn://toggle` — переключить (в сторону отключения — та же политика).
public enum DeepLink: Equatable, Sendable {
    case addSubscription(URL)
    case connect
    case disconnect
    case toggle

    public static func parse(_ url: URL) -> DeepLink? {
        if let subscription = subscriptionURL(from: url) {
            return .addSubscription(subscription)
        }
        guard url.scheme?.lowercased() == "vorn" else { return nil }
        // Не URL.host(): пакет держит пол iOS 15, а host() появился в 16.
        let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host
        switch host?.lowercased() {
        case "on": return .connect
        case "off": return .disconnect
        case "toggle": return .toggle
        default: return nil
        }
    }

    /// Ссылка подписки из `vorn://add/...`; nil — это не add-диплинк или
    /// вложенная ссылка не https. Хвост берём из сырой строки, а не из
    /// URLComponents: query вложенной ссылки (`?token=…`) иначе достался
    /// бы самому диплинку.
    private static func subscriptionURL(from url: URL) -> URL? {
        let raw = url.absoluteString
        let prefix = "vorn://add/"
        guard raw.count > prefix.count,
              raw.prefix(prefix.count).lowercased() == prefix
        else { return nil }

        var tail = String(raw.dropFirst(prefix.count))
        // Некоторые генераторы percent-кодируют вложенную ссылку целиком.
        if !tail.lowercased().hasPrefix("https://"),
           let decoded = tail.removingPercentEncoding {
            tail = decoded
        }
        guard let subscription = URL(string: tail),
              subscription.scheme?.lowercased() == "https"
        else { return nil }
        return subscription
    }
}
