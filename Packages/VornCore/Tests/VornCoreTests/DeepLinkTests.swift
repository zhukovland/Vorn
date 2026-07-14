import Foundation
import Testing
@testable import VornCore

struct DeepLinkTests {
    private func parse(_ link: String) -> DeepLink? {
        URL(string: link).flatMap(DeepLink.parse)
    }

    // MARK: - Подписка

    @Test func parsesPlainSubscriptionLink() {
        let expected = URL(string: "https://cdn.xrayconnect.xyz/abc123")!
        #expect(parse("vorn://add/https://cdn.xrayconnect.xyz/abc123") == .addSubscription(expected))
    }

    @Test func keepsQueryOfNestedLink() {
        // query принадлежит вложенной ссылке, а не самому диплинку.
        let expected = URL(string: "https://cdn.example/sub?token=x&f=1")!
        #expect(parse("vorn://add/https://cdn.example/sub?token=x&f=1") == .addSubscription(expected))
    }

    @Test func decodesPercentEncodedNestedLink() {
        let expected = URL(string: "https://cdn.example/sub?token=x")!
        #expect(parse("vorn://add/https%3A%2F%2Fcdn.example%2Fsub%3Ftoken%3Dx") == .addSubscription(expected))
    }

    @Test func rejectsInsecureNestedLink() {
        #expect(parse("vorn://add/http://cdn.example/sub") == nil)
        #expect(parse("vorn://add/") == nil)
        #expect(parse("vorn://add/not a url") == nil)
    }

    // MARK: - Туннель

    @Test func parsesTunnelCommands() {
        #expect(parse("vorn://on") == .connect)
        #expect(parse("vorn://off") == .disconnect)
        #expect(parse("vorn://toggle") == .toggle)
    }

    @Test func schemeAndCommandAreCaseInsensitive() {
        #expect(parse("VORN://ADD/https://cdn.example/sub") != nil)
        #expect(parse("Vorn://On") == .connect)
        #expect(parse("vorn://OFF") == .disconnect)
    }

    @Test func rejectsForeignLinks() {
        #expect(parse("vorn://unknown") == nil)
        #expect(parse("happ://add/https://cdn.example/sub") == nil)
        #expect(parse("https://example.com/on") == nil)
    }
}
