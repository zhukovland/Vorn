import Foundation
import Testing
@testable import VornCore

struct VLESSServerTests {
    static func makeServer(
        name: String = "Test",
        address: String = "example.com",
        userID: String = "b831381d-6324-4d53-ad4f-8cda48b30811",
        publicKey: String = "pbk"
    ) -> VLESSServer {
        VLESSServer(
            name: name,
            address: address,
            port: 443,
            userID: userID,
            flow: "xtls-rprx-vision",
            reality: RealitySettings(publicKey: publicKey, shortID: "sid", serverName: "yahoo.com", fingerprint: "chrome")
        )
    }

    @Test func roundTripsThroughCodable() throws {
        let server = Self.makeServer()
        let data = try JSONEncoder().encode(server)
        let decoded = try JSONDecoder().decode(VLESSServer.self, from: data)
        #expect(decoded == server)
        #expect(decoded.id == server.id)
    }

    @Test func roundTripsXHTTPThroughCodable() throws {
        let server = VLESSServer(
            name: "X", address: "1.2.3.4", port: 443, userID: "uuid",
            network: "xhttp",
            reality: RealitySettings(publicKey: "pbk", shortID: "sid", serverName: "a.com", fingerprint: "chrome"),
            xhttp: XHTTPSettings(path: "/dl", host: "cdn.example", mode: "stream-up")
        )
        let decoded = try JSONDecoder().decode(VLESSServer.self, from: JSONEncoder().encode(server))
        #expect(decoded == server)
        #expect(decoded.xhttp == server.xhttp)
        #expect(decoded.id == server.id)
    }

    @Test func idIsStableAcrossRenames() {
        #expect(Self.makeServer(name: "A").id == Self.makeServer(name: "renamed in panel").id)
    }

    @Test func idDistinguishesConnectionParameters() {
        #expect(Self.makeServer(publicKey: "key1").id != Self.makeServer(publicKey: "key2").id)
    }

    @Test func parsesBareLink() throws {
        let pbk = "SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc"
        let link = "vless://aaa-uuid@10.0.0.1:443?security=reality&pbk=\(pbk)&sni=a.com&flow=xtls-rprx-vision#A"
        let server = try #require(VLESSServer(link: link))
        #expect(server.name == "A")
        #expect(server.address == "10.0.0.1")
        #expect(server.reality.publicKey == pbk)
        // Тот же контракт идентичности, что у серверов из подписки.
        #expect(server.id == VLESSLinkParser.parse(link)?.id)
    }

    @Test func rejectsNonRealityLink() {
        #expect(VLESSServer(link: "vless://uuid@1.2.3.4:443?security=tls&sni=a.com#X") == nil)
        #expect(VLESSServer(link: "не ссылка вовсе") == nil)
    }

    @Test func idLeaksNoSecrets() {
        let server = Self.makeServer()
        #expect(!server.id.localizedCaseInsensitiveContains(server.userID))
        #expect(!server.id.contains(server.address))
    }
}
