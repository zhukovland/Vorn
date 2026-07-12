import Foundation
import Testing
import VornCore
@testable import VornSubscription

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Стаб HTTP: отдаёт заранее заданные тело/статус/заголовки или бросает.
private struct StubClient: HTTPFetching {
    var body: Data = .init()
    var status: Int = 200
    var headers: [String: String] = [:]
    var error: Error?

    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
        )!
        return (body, response)
    }
}

private let validPBK = "SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc"
private let linkA = "vless://a-uuid@10.0.0.1:443?security=reality&pbk=\(validPBK)&sni=a.com#A"
private let linkB = "vless://b-uuid@10.0.0.2:8443?security=reality&pbk=\(validPBK)&sni=b.com#B"
private let subURL = URL(string: "https://panel.example/sub/token")!

private func loader(_ stub: StubClient) -> SubscriptionLoader {
    SubscriptionLoader(client: stub, userAgent: "Vorn/1.0")
}

struct SubscriptionLoaderTests {
    @Test func parsesBase64Body() async throws {
        let payload = Data([linkA, linkB].joined(separator: "\n").utf8).base64EncodedString()
        let result = try await loader(StubClient(body: Data(payload.utf8))).load(from: subURL)
        #expect(result.servers.map(\.name) == ["A", "B"])
    }

    @Test func parsesPlainTextBody() async throws {
        let body = Data([linkA, linkB].joined(separator: "\n").utf8)
        let result = try await loader(StubClient(body: body)).load(from: subURL)
        #expect(result.servers.count == 2)
    }

    @Test func emptyBodyIsZeroServersNotError() async throws {
        let result = try await loader(StubClient(body: Data(), headers: ["announce": "base64:" + b64("Лимит устройств")])).load(from: subURL)
        #expect(result.servers.isEmpty)
        // Заголовки при пустом теле всё равно доносятся до пользователя.
        #expect(result.announce == "Лимит устройств")
    }

    @Test func rejectsNonHTTPS() async throws {
        await #expect(throws: SubscriptionFetchError.insecureURL) {
            try await loader(StubClient(body: Data(linkA.utf8)))
                .load(from: URL(string: "http://panel.example/sub")!)
        }
    }

    @Test func mapsHTTPStatusError() async throws {
        await #expect(throws: SubscriptionFetchError.http(status: 404)) {
            try await loader(StubClient(body: Data(), status: 404)).load(from: subURL)
        }
    }

    @Test func mapsTransportErrorWithoutLeakingDetails() async throws {
        let stub = StubClient(error: URLError(.cannotConnectToHost))
        await #expect(throws: SubscriptionFetchError.network) {
            try await loader(stub).load(from: subURL)
        }
    }

    @Test func propagatesParseErrorForJunkBody() async throws {
        let stub = StubClient(body: Data("@@@ not base64 @@@".utf8))
        await #expect(throws: SubscriptionFetchError.parse(.invalidBase64)) {
            try await loader(stub).load(from: subURL)
        }
    }

    @Test func decodesBase64ProfileTitle() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: ["profile-title": "base64:" + b64("Моя подписка")])
        let result = try await loader(stub).load(from: subURL)
        #expect(result.title == "Моя подписка")
    }

    @Test func acceptsRawProfileTitle() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: ["profile-title": "Panel"])
        #expect(try await loader(stub).load(from: subURL).title == "Panel")
    }

    @Test func parsesUserInfoTrafficAndExpiry() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: [
            "subscription-userinfo": "upload=0; download=1024; total=5120; expire=1893456000",
        ])
        let info = try #require(try await loader(stub).load(from: subURL).userInfo)
        #expect(info.download == 1024)
        #expect(info.total == 5120)
        #expect(info.expire == Date(timeIntervalSince1970: 1_893_456_000))
    }

    @Test func userInfoTreatsZeroTotalAndExpireAsUnlimited() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: [
            "subscription-userinfo": "upload=0; download=10; total=0; expire=0",
        ])
        let info = try #require(try await loader(stub).load(from: subURL).userInfo)
        #expect(info.total == nil)
        #expect(info.expire == nil)
    }

    @Test func convertsUpdateIntervalHoursToSeconds() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: ["profile-update-interval": "12"])
        #expect(try await loader(stub).load(from: subURL).updateInterval == 12 * 3600)
    }

    @Test func decodesAnnounceAndReadsSupportURLs() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: [
            "announce": "base64:" + b64("Плановые работы в 03:00"),
            "support-url": "https://t.me/support",
            "profile-web-page-url": "https://panel.example/app",
        ])
        let result = try await loader(stub).load(from: subURL)
        #expect(result.announce == "Плановые работы в 03:00")
        #expect(result.supportURL == URL(string: "https://t.me/support"))
        #expect(result.webPageURL == URL(string: "https://panel.example/app"))
    }

    @Test func rejectsNonWebSupportURLScheme() async throws {
        let stub = StubClient(body: Data(linkA.utf8), headers: ["support-url": "javascript:alert(1)"])
        #expect(try await loader(stub).load(from: subURL).supportURL == nil)
    }
}

private func b64(_ string: String) -> String {
    Data(string.utf8).base64EncodedString()
}
