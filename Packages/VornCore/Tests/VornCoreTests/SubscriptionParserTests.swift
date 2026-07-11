import Foundation
import Testing
@testable import VornCore

struct SubscriptionParserTests {
    // pbk — валидные base64url-ключи (32 байта): парсер их проверяет.
    static let linkA = "vless://aaa-uuid@10.0.0.1:443?security=reality"
        + "&pbk=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE&sni=a.com&flow=xtls-rprx-vision#A"
    static let linkB = "vless://bbb-uuid@10.0.0.2:8443?security=reality"
        + "&pbk=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI&sni=b.com#B"
    /// Тот же endpoint, что linkA, но другой публичный ключ — другой сервер.
    static let linkA2 = "vless://aaa-uuid@10.0.0.1:443?security=reality"
        + "&pbk=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8&sni=a.com#A2"

    static func base64Payload(_ lines: [String]) -> String {
        Data(lines.joined(separator: "\n").utf8).base64EncodedString()
    }

    @Test func parsesBase64ListOfServers() throws {
        let servers = try SubscriptionParser.parse(payload: Self.base64Payload([Self.linkA, Self.linkB]))
        #expect(servers.map(\.name) == ["A", "B"])
    }

    @Test func skipsJunkAndForeignProtocolLines() throws {
        let servers = try SubscriptionParser.parse(payload: Self.base64Payload([
            "// remnawave header",
            Self.linkA,
            "ss://something@10.0.0.9:443#shadowsocks",
            "",
            Self.linkB,
        ]))
        #expect(servers.map(\.name) == ["A", "B"])
    }

    @Test func collapsesExactDuplicates() throws {
        let servers = try SubscriptionParser.parse(payload: Self.base64Payload([Self.linkA, Self.linkA, Self.linkB]))
        #expect(servers.count == 2)
    }

    @Test func keepsDistinctConfigsOfSameEndpoint() throws {
        let servers = try SubscriptionParser.parse(payload: Self.base64Payload([Self.linkA, Self.linkA2]))
        #expect(servers.count == 2)
    }

    @Test func acceptsBase64URLWithoutPadding() throws {
        let canonical = Self.base64Payload([Self.linkA, Self.linkB])
        let urlSafe = canonical
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let servers = try SubscriptionParser.parse(payload: urlSafe)
        #expect(servers.count == 2)
    }

    @Test func acceptsPlainTextPayload() throws {
        let servers = try SubscriptionParser.parse(payload: [Self.linkA, Self.linkB].joined(separator: "\n"))
        #expect(servers.count == 2)
    }

    @Test func acceptsPlainTextWithLeadingHeader() throws {
        let payload = ["//profile-title: My Sub", Self.linkA, Self.linkB].joined(separator: "\n")
        let servers = try SubscriptionParser.parse(payload: payload)
        #expect(servers.count == 2)
    }

    @Test func throwsOnGarbagePayload() {
        #expect(throws: SubscriptionParser.ParseError.invalidBase64) {
            try SubscriptionParser.parse(payload: "@@@ definitely not base64 @@@")
        }
        #expect(throws: SubscriptionParser.ParseError.invalidBase64) {
            try SubscriptionParser.parse(payload: "   ")
        }
    }

    @Test func throwsWhenNoValidServers() {
        #expect(throws: SubscriptionParser.ParseError.noServers) {
            try SubscriptionParser.parse(payload: Self.base64Payload(["ss://foreign@1.2.3.4:443#x"]))
        }
    }
}
