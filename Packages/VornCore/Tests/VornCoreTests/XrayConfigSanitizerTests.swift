import Foundation
import Testing
@testable import VornCore

struct XrayConfigSanitizerTests {
    /// Конфиг «из подписки» со всеми запрещёнными блоками и болтливым логом.
    static let hostileConfig = """
    {
      "log": {"loglevel": "debug", "access": "/tmp/access.log"},
      "api": {"tag": "api", "services": ["HandlerService", "StatsService"]},
      "stats": {},
      "metrics": {"tag": "metrics"},
      "inbounds": [{"tag": "tun", "protocol": "tun"}],
      "outbounds": [{"tag": "proxy", "protocol": "vless"}],
      "routing": {
        "domainStrategy": "AsIs",
        "rules": [
          {"type": "field", "inboundTag": ["api"], "outboundTag": "api"},
          {"type": "field", "outboundTag": "proxy", "network": "tcp,udp"}
        ]
      }
    }
    """

    @Test func removesForbiddenBlocksAndForcesLogLevel() throws {
        let sanitized = try XrayConfigSanitizer.sanitize(Self.hostileConfig)
        let config = try #require(try JSONSerialization.jsonObject(with: Data(sanitized.utf8)) as? [String: Any])

        #expect(config["api"] == nil)
        #expect(config["stats"] == nil)
        #expect(config["metrics"] == nil)

        let log = try #require(config["log"] as? [String: Any])
        #expect(log["loglevel"] as? String == "warning")

        // Правило, ссылавшееся на api, вырезано; обычное — сохранено.
        let routing = try #require(config["routing"] as? [String: Any])
        let rules = try #require(routing["rules"] as? [[String: Any]])
        #expect(rules.count == 1)
        #expect(rules[0]["outboundTag"] as? String == "proxy")

        // Остальные блоки не тронуты.
        #expect((config["inbounds"] as? [[String: Any]])?.count == 1)
        #expect((config["outbounds"] as? [[String: Any]])?.count == 1)
    }

    @Test func createsLogBlockWhenMissing() throws {
        let sanitized = try XrayConfigSanitizer.sanitize(#"{"outbounds": []}"#)
        let config = try #require(try JSONSerialization.jsonObject(with: Data(sanitized.utf8)) as? [String: Any])
        #expect((config["log"] as? [String: Any])?["loglevel"] as? String == "warning")
    }

    @Test func isIdempotent() throws {
        let once = try XrayConfigSanitizer.sanitize(Self.hostileConfig)
        let twice = try XrayConfigSanitizer.sanitize(once)
        #expect(once == twice)
    }

    @Test func passesBuilderOutputUnchanged() throws {
        let built = try XrayConfigBuilder.makeConfig(for: XrayConfigBuilderTests.makeServer())
        let sanitized = try XrayConfigSanitizer.sanitize(built)
        // Наш собственный конфиг уже чистый: санитайзер ничего не меняет.
        #expect(sanitized == built)
    }

    @Test(arguments: ["not json at all", "[1, 2, 3]", ""])
    func throwsOnInvalidInput(_ input: String) {
        #expect(throws: XrayConfigSanitizer.SanitizeError.invalidJSON) {
            try XrayConfigSanitizer.sanitize(input)
        }
    }
}
