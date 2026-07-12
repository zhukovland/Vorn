import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Абстракция HTTP-выборки, чтобы загрузчик тестировался без сети:
/// прод берёт URLSession, тесты — стаб с готовыми (Data, ответ).
public protocol HTTPFetching: Sendable {
    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Продовая реализация поверх URLSession.
public struct URLSessionHTTPClient: HTTPFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SubscriptionFetchError.network
        }
        return (data, http)
    }
}
