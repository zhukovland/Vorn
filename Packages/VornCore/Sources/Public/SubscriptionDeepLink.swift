import Foundation

/// Диплинк добавления подписки: `vorn://add/<https-ссылка подписки>`,
/// по образцу `happ://add/...` у других клиентов. Разбор — здесь, решение
/// об импорте — за приложением (и только с подтверждением пользователя:
/// молчаливый импорт позволил бы сайту подменить серверы своими).
public enum SubscriptionDeepLink {
    /// Ссылка подписки из диплинка; nil — это не наш диплинк или вложенная
    /// ссылка не https. Хвост берём из сырой строки, а не из URLComponents:
    /// query вложенной ссылки (`?token=…`) иначе достался бы самому диплинку.
    public static func parse(_ url: URL) -> URL? {
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
