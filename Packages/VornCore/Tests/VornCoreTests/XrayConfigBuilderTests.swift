import Foundation
import Testing
@testable import VornCore

struct XrayConfigBuilderTests {
    @Test func buildsVLESSRealityOutbound() throws {
        let config = try #require(Fixtures.object(try XrayConfigBuilder.makeConfig(for: Fixtures.server())))

        let log = try #require(config["log"] as? [String: Any])
        #expect(log["loglevel"] as? String == "warning")

        let outbounds = try #require(config["outbounds"] as? [[String: Any]])
        #expect(outbounds.count == 2)
        #expect(outbounds[0]["protocol"] as? String == "vless")
        #expect(outbounds[0]["tag"] as? String == XrayTag.proxy)
        #expect(outbounds[1]["protocol"] as? String == "freedom")
        #expect(outbounds[1]["tag"] as? String == XrayTag.direct)

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
        let config = try #require(Fixtures.object(try XrayConfigBuilder.makeConfig(for: Fixtures.server(flow: nil))))
        let outbounds = try #require(config["outbounds"] as? [[String: Any]])
        let settings = try #require(outbounds[0]["settings"] as? [String: Any])
        let user = try #require(((settings["vnext"] as? [[String: Any]])?.first?["users"] as? [[String: Any]])?.first)
        #expect(user["flow"] == nil)
    }

    @Test func emitsSpiderXPath() throws {
        let config = try #require(Fixtures.object(try XrayConfigBuilder.makeConfig(for: Fixtures.server(spiderX: "/index.html"))))
        let outbounds = try #require(config["outbounds"] as? [[String: Any]])
        let stream = try #require(outbounds[0]["streamSettings"] as? [String: Any])
        let reality = try #require(stream["realitySettings"] as? [String: Any])
        #expect(reality["spiderX"] as? String == "/index.html")
    }

    @Test func neverEmitsForbiddenBlocks() throws {
        let config = try #require(Fixtures.object(try XrayConfigBuilder.makeConfig(for: Fixtures.server())))
        #expect(config["api"] == nil)
        #expect(config["metrics"] == nil)
        #expect(config["stats"] == nil)
        // TUN-inbound добавляет ядро; наш конфиг inbounds не описывает.
        #expect(config["inbounds"] == nil)
    }

    @Test func outputIsDeterministic() throws {
        let first = try XrayConfigBuilder.makeConfig(for: Fixtures.server())
        let second = try XrayConfigBuilder.makeConfig(for: Fixtures.server())
        #expect(first == second)
    }
}
