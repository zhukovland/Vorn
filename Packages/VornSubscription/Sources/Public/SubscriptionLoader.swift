import Foundation
import VornCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Загружает подписку по URL и разбирает ответ: тело — в серверы (через
/// VornCore.SubscriptionParser), заголовки — в метаданные для пользователя.
public struct SubscriptionLoader: Sendable {
    private let client: HTTPFetching
    private let userAgent: String

    /// - Parameter userAgent: честный `Vorn/<версия>`. Не маскируемся под
    ///   v2rayN/Happ: панель по чужому UA может отдать JSON вместо base64.
    public init(client: HTTPFetching = URLSessionHTTPClient(), userAgent: String = "Vorn") {
        self.client = client
        self.userAgent = userAgent
    }

    public func load(from url: URL) async throws -> SubscriptionFetchResult {
        guard url.scheme?.lowercased() == "https" else {
            throw SubscriptionFetchError.insecureURL
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.fetch(request)
        } catch let error as SubscriptionFetchError {
            throw error
        } catch {
            // Транспортную ошибку не пробрасываем как есть: её текст может
            // содержать хост подписки.
            throw SubscriptionFetchError.network
        }

        guard (200...299).contains(response.statusCode) else {
            throw SubscriptionFetchError.http(status: response.statusCode)
        }

        let servers = try parseServers(from: data)
        return SubscriptionFetchResult(
            servers: servers,
            title: SubscriptionHeaders.text(header(response, "profile-title")),
            userInfo: SubscriptionHeaders.userInfo(header(response, "subscription-userinfo")),
            updateInterval: SubscriptionHeaders.updateInterval(header(response, "profile-update-interval")),
            announce: SubscriptionHeaders.text(header(response, "announce")),
            supportURL: SubscriptionHeaders.url(header(response, "support-url")),
            webPageURL: SubscriptionHeaders.url(header(response, "profile-web-page-url"))
        )
    }

    /// Пустое тело — легитимный ответ (например, лимит устройств): 0 серверов,
    /// но заголовки (announce) могут объяснить причину. Непустое, но
    /// неразобранное — ошибка разбора.
    private func parseServers(from data: Data) throws -> [VLESSServer] {
        let payload = String(decoding: data, as: UTF8.self)
        guard !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        do {
            return try SubscriptionParser.parse(payload: payload)
        } catch let error as SubscriptionParser.ParseError {
            throw SubscriptionFetchError.parse(error)
        }
    }

    private func header(_ response: HTTPURLResponse, _ name: String) -> String? {
        response.value(forHTTPHeaderField: name)
    }
}
