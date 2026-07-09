import Foundation
import Testing
@testable import VornCore

struct XrayConfigSanitizerTests {
    /// Враждебный конфиг «из подписки»: управляющий API со слушающим сокетом,
    /// телеметрия, файловые логи и правила, ссылающиеся на всё это.
    /// Функция, а не static let: словарь [String: Any] не Sendable.
    static func hostileConfig() -> [String: Any] { [
        "log": ["loglevel": "debug", "access": "/tmp/access.log", "dnsLog": true],
        "api": ["tag": "api", "services": ["HandlerService", "StatsService"]],
        "stats": [:],
        "metrics": ["tag": "metrics"],
        "observatory": ["subjectSelector": ["proxy"]],
        "burstObservatory": ["subjectSelector": ["proxy"]],
        "reverse": ["bridges": [["tag": "bridge", "domain": "evil.example"]]],
        "policy": ["system": ["statsInboundUplink": true, "statsUserUplink": true]],
        "inbounds": [
            ["tag": "tun", "protocol": "tun"],
            ["tag": "api", "protocol": "dokodemo-door", "listen": "127.0.0.1", "port": 10085],
        ],
        "outbounds": [["tag": "proxy", "protocol": "vless"]],
        "routing": [
            "domainStrategy": "AsIs",
            "rules": [
                ["type": "field", "inboundTag": ["api"], "outboundTag": "api"],
                ["type": "field", "outboundTag": "proxy", "network": "tcp,udp"],
            ],
        ],
    ] }

    @Test func keepsOnlyAllowedTopLevelBlocks() {
        let config = XrayConfigSanitizer.sanitize(Self.hostileConfig())
        for forbidden in ["api", "stats", "metrics", "observatory", "burstObservatory", "reverse", "policy"] {
            #expect(config[forbidden] == nil, "block \(forbidden) survived sanitization")
        }
        #expect(Set(config.keys).isSubset(of: XrayPolicy.allowedTopLevelKeys))
        #expect(config["outbounds"] != nil)
    }

    @Test func dropsListeningInbounds() throws {
        let config = XrayConfigSanitizer.sanitize(Self.hostileConfig())
        let inbounds = try #require(config["inbounds"] as? [[String: Any]])
        // dokodemo-door на 127.0.0.1:10085 — это и есть управляющий порт.
        #expect(inbounds.count == 1)
        #expect(inbounds[0]["tag"] as? String == "tun")
    }

    @Test func rebuildsLogBlockWithoutFileSinks() throws {
        let config = XrayConfigSanitizer.sanitize(Self.hostileConfig())
        let log = try #require(config["log"] as? [String: Any])
        #expect(log["loglevel"] as? String == "warning")
        #expect(log["access"] == nil)
        #expect(log["dnsLog"] == nil)
    }

    @Test func createsLogBlockWhenMissing() throws {
        let config = XrayConfigSanitizer.sanitize(["outbounds": []])
        let log = try #require(config["log"] as? [String: Any])
        #expect(log["loglevel"] as? String == "warning")
    }

    @Test func dropsRulesReferencingRemovedTags() throws {
        let config = XrayConfigSanitizer.sanitize(Self.hostileConfig())
        let routing = try #require(config["routing"] as? [String: Any])
        let rules = try #require(routing["rules"] as? [[String: Any]])
        #expect(rules.count == 1)
        #expect(rules[0]["outboundTag"] as? String == "proxy")
    }

    /// Тег api-блока конфигурируем — очистка не должна опираться на литерал "api".
    @Test func dropsRulesReferencingRenamedAPITag() throws {
        var hostile = Self.hostileConfig()
        hostile["api"] = ["tag": "myapi", "services": ["HandlerService"]]
        hostile["routing"] = ["rules": [["type": "field", "outboundTag": "myapi"]]]
        hostile["outbounds"] = [["tag": "proxy", "protocol": "vless"]]

        let routing = try #require(XrayConfigSanitizer.sanitize(hostile)["routing"] as? [String: Any])
        #expect((routing["rules"] as? [[String: Any]])?.isEmpty == true)
    }

    /// inboundTag в Xray — StringList: и массив, и голая строка.
    @Test func dropsRuleWithStringInboundTag() throws {
        var hostile = Self.hostileConfig()
        hostile["routing"] = ["rules": [["type": "field", "inboundTag": "api", "outboundTag": "proxy"]]]

        let routing = try #require(XrayConfigSanitizer.sanitize(hostile)["routing"] as? [String: Any])
        #expect((routing["rules"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test func keepsRuleWithSurvivingInboundTag() throws {
        var hostile = Self.hostileConfig()
        hostile["routing"] = ["rules": [["type": "field", "inboundTag": ["tun", "api"], "outboundTag": "proxy"]]]

        let routing = try #require(XrayConfigSanitizer.sanitize(hostile)["routing"] as? [String: Any])
        let rules = try #require(routing["rules"] as? [[String: Any]])
        #expect(rules.count == 1)
        // Исчезнувший тег вычищен из списка, живой остался.
        #expect(rules[0]["inboundTag"] as? [String] == ["tun"])
    }

    @Test func dropsRuleReferencingUnknownBalancer() throws {
        let config = XrayConfigSanitizer.sanitize([
            "outbounds": [["tag": "proxy"]],
            "routing": ["rules": [["type": "field", "balancerTag": "ghost"]]],
        ])
        let routing = try #require(config["routing"] as? [String: Any])
        #expect((routing["rules"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test func isIdempotent() {
        let once = XrayConfigSanitizer.sanitize(Self.hostileConfig())
        let twice = XrayConfigSanitizer.sanitize(once)
        #expect(NSDictionary(dictionary: once) == NSDictionary(dictionary: twice))
    }

    @Test func passesBuilderOutputUnchanged() throws {
        // Сравниваем разобранный JSON, а не байты: билдер печатает "/" как есть
        // (withoutEscapingSlashes), JSONSerialization экранирует его в "\/".
        let built = try #require(Fixtures.object(try XrayConfigBuilder.makeConfig(for: Fixtures.server(spiderX: "/index.html"))))
        let sanitized = XrayConfigSanitizer.sanitize(built)
        #expect(NSDictionary(dictionary: sanitized) == NSDictionary(dictionary: built))
    }

    @Test func dataVariantRoundTrips() throws {
        let built = try XrayConfigBuilder.makeConfig(for: Fixtures.server())
        let sanitized = try XrayConfigSanitizer.sanitize(built)
        let config = try #require(Fixtures.object(sanitized))
        #expect((config["log"] as? [String: Any])?["loglevel"] as? String == "warning")
        #expect((config["outbounds"] as? [[String: Any]])?.count == 2)
    }

    @Test(arguments: ["not json at all", "[1, 2, 3]", ""])
    func dataVariantThrowsOnInvalidInput(_ input: String) {
        #expect(throws: XrayConfigSanitizer.SanitizeError.invalidJSON) {
            try XrayConfigSanitizer.sanitize(Data(input.utf8))
        }
    }
}
