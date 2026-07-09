import Foundation
import Testing
@testable import VornCore

struct XrayConfigBuilderTests {
    static func makeServer(flow: String? = "xtls-rprx-vision", spiderX: String? = nil) -> VLESSServer {
        VLESSServer(
            name: "Test",
            address: "1.2.3.4",
            port: 443,
            userID: "b831381d-6324-4d53-ad4f-8cda48b30811",
            flow: flow,
            reality: RealitySettings(
                publicKey: "pbk-value",
                shortID: "6ba85179",
                serverName: "yahoo.com",
                fingerprint: "chrome",
                spiderX: spiderX
            )
        )
    }

    static func json(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func buildsVLESSRealityOutbound() throws {
        let config = try Self.json(try XrayConfigBuilder.makeConfig(for: Self.makeServer()))

        let log = try #require(config["log"] as? [String: Any])
        #expect(log["loglevel"] as? String == "warning")

        let outbounds = try #require(config["outbounds"] as? [[String: Any]])
        #expect(outbounds.count == 2)
        #expect(outbounds[0]["protocol"] as? String == "vless")
        #expect(outbounds[0]["tag"] as? String == "proxy")
        #expect(outbounds[1]["protocol"] as? String == "freedom")

        let settings = try #require(outbounds[0]["settings"] as? [String: Any])
        let vnext = try #require(settings["vnext"] as? [[String: Any]])
        #expect(vnext[0]["address"] as? String == "1.2.3.4")
        #expect(vnext[0]["port"] as? Int == 443)
        let user = try #require((vnext[0]["users"] as? [[String: Any]])?.first)
        #expect(user["id"] as? String == "b831381d-6324-4d53-ad4f-8cda48b30811")
        #expect(user["encryption"] as? String == "none")
        #expect(user["flow"] as? String == "xtls-rprx-vision")

        let stream = try #require(outbounds[0]["streamSettings"] as? [String: Any])
        #expect(stream["network"] as? String == "tcp")
        #expect(stream["security"] as? String == "reality")
        let reality = try #require(stream["realitySettings"] as? [String: Any])
        #expect(reality["publicKey"] as? String == "pbk-value")
        #expect(reality["shortId"] as? String == "6ba85179")
        #expect(reality["serverName"] as? String == "yahoo.com")
        #expect(reality["fingerprint"] as? String == "chrome")
        #expect(reality["spiderX"] == nil)
    }

    @Test func omitsAbsentOptionals() throws {
        let config = try Self.json(try XrayConfigBuilder.makeConfig(for: Self.makeServer(flow: nil)))
        let outbounds = try #require(config["outbounds"] as? [[String: Any]])
        let settings = try #require(outbounds[0]["settings"] as? [String: Any])
        let user = try #require(((settings["vnext"] as? [[String: Any]])?.first?["users"] as? [[String: Any]])?.first)
        #expect(user["flow"] == nil)
    }

    @Test func neverEmitsForbiddenBlocks() throws {
        let config = try Self.json(try XrayConfigBuilder.makeConfig(for: Self.makeServer()))
        #expect(config["api"] == nil)
        #expect(config["metrics"] == nil)
        #expect(config["stats"] == nil)
        // TUN-inbound добавляет ядро; наш конфиг inbounds не описывает.
        #expect(config["inbounds"] == nil)
    }

    @Test func outputIsDeterministic() throws {
        let first = try XrayConfigBuilder.makeConfig(for: Self.makeServer())
        let second = try XrayConfigBuilder.makeConfig(for: Self.makeServer())
        #expect(first == second)
    }
}
