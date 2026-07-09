import Foundation
import Testing
@testable import VornCore

struct VLESSLinkParserTests {
    let realityLink = "vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443"
        + "?security=reality&encryption=none&pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc"
        + "&sid=6ba85179&sni=yahoo.com&fp=chrome&flow=xtls-rprx-vision&type=tcp#My%20Server"

    @Test func parsesRealityVisionLink() throws {
        let server = try #require(VLESSLinkParser.parse(realityLink))
        #expect(server.name == "My Server")
        #expect(server.address == "1.2.3.4")
        #expect(server.port == 443)
        #expect(server.userID == "b831381d-6324-4d53-ad4f-8cda48b30811")
        #expect(server.flow == "xtls-rprx-vision")
        #expect(server.network == "tcp")
        #expect(server.reality.publicKey == "SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc")
        #expect(server.reality.shortID == "6ba85179")
        #expect(server.reality.serverName == "yahoo.com")
        #expect(server.reality.fingerprint == "chrome")
    }

    @Test func parsesIPv6Host() throws {
        let link = "vless://uuid@[2001:db8::1]:8443?security=reality&pbk=key&sni=mask.example#v6"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.address == "2001:db8::1")
        #expect(server.port == 8443)
    }

    @Test func bracketsIPv6InDefaultName() throws {
        let link = "vless://uuid@[2001:db8::1]:8443?security=reality&pbk=key&sni=mask.example"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.name == "[2001:db8::1]:8443")
    }

    @Test func parsesRawUnicodeName() throws {
        let link = "vless://uuid@host.example:443?security=reality&pbk=key&sni=mask.example#🇳🇱 Netherlands NL-1"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.name == "🇳🇱 Netherlands NL-1")
    }

    @Test func fallsBackToDefaults() throws {
        let link = "vless://uuid@example.com:443?security=reality&pbk=key&sni=mask.example"
        let server = try #require(VLESSLinkParser.parse(link))
        // Без имени — host:port; без fp — chrome; sid/flow опциональны.
        #expect(server.name == "example.com:443")
        #expect(server.reality.fingerprint == "chrome")
        #expect(server.reality.shortID == "")
        #expect(server.flow == nil)
        #expect(server.network == "tcp")
    }

    @Test(arguments: [
        "trojan://uuid@host:443?security=reality&pbk=key&sni=a.com#wrong-scheme",
        "vless://uuid@host?security=reality&pbk=key&sni=a.com#no-port",
        "vless://@host:443?security=reality&pbk=key&sni=a.com#no-uuid",
        "vless://uuid@host:443?security=reality&sni=a.com#reality-without-pbk",
        "vless://uuid@host:443?security=reality&pbk=key#reality-without-sni",
        "vless://uuid@host:443?security=none#unsupported-security-none",
        "vless://uuid@host:443?security=tls&sni=a.com#unsupported-security-tls",
        "vless://uuid@host:443?security=reality&pbk=key&sni=a.com&encryption=aes-128-gcm#bad-encryption",
        "vless://uuid@host:99999?security=reality&pbk=key&sni=a.com#port-out-of-range",
        "not a link at all",
    ])
    func rejectsInvalidLinks(_ link: String) {
        #expect(VLESSLinkParser.parse(link) == nil)
    }
}
