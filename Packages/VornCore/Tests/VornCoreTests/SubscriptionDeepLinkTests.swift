import Foundation
import Testing
@testable import VornCore

struct SubscriptionDeepLinkTests {
    private func parse(_ link: String) -> URL? {
        URL(string: link).flatMap(SubscriptionDeepLink.parse)
    }

    @Test func parsesPlainLink() {
        let url = parse("vorn://add/https://cdn.xrayconnect.xyz/abc123")
        #expect(url?.absoluteString == "https://cdn.xrayconnect.xyz/abc123")
    }

    @Test func keepsQueryOfNestedLink() {
        // query принадлежит вложенной ссылке, а не самому диплинку.
        let url = parse("vorn://add/https://cdn.example/sub?token=x&f=1")
        #expect(url?.absoluteString == "https://cdn.example/sub?token=x&f=1")
    }

    @Test func decodesPercentEncodedNestedLink() {
        let url = parse("vorn://add/https%3A%2F%2Fcdn.example%2Fsub%3Ftoken%3Dx")
        #expect(url?.absoluteString == "https://cdn.example/sub?token=x")
    }

    @Test func schemePrefixIsCaseInsensitive() {
        #expect(parse("VORN://ADD/https://cdn.example/sub") != nil)
    }

    @Test func rejectsInsecureNestedLink() {
        #expect(parse("vorn://add/http://cdn.example/sub") == nil)
    }

    @Test func rejectsForeignActions() {
        #expect(parse("vorn://toggle") == nil)
        #expect(parse("vorn://add/") == nil)
        #expect(parse("happ://add/https://cdn.example/sub") == nil)
        #expect(parse("vorn://add/not a url") == nil)
    }
}
