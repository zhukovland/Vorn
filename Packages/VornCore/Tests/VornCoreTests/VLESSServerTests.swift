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

    @Test func idIsStableAcrossRenames() {
        #expect(Self.makeServer(name: "A").id == Self.makeServer(name: "renamed in panel").id)
    }

    @Test func idDistinguishesConnectionParameters() {
        #expect(Self.makeServer(publicKey: "key1").id != Self.makeServer(publicKey: "key2").id)
    }

    @Test func idLeaksNoSecrets() {
        let server = Self.makeServer()
        #expect(!server.id.localizedCaseInsensitiveContains(server.userID))
        #expect(!server.id.contains(server.address))
    }
}
