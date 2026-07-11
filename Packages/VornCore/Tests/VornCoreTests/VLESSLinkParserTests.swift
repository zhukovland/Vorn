import Foundation
import Testing
@testable import VornCore

/// Валидный pbk: base64url без паддинга, ровно 32 байта после декодирования.
private let validPBK = "SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc"

struct VLESSLinkParserTests {
    let realityLink = "vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443"
        + "?security=reality&encryption=none&pbk=\(validPBK)"
        + "&sid=6ba85179&sni=yahoo.com&fp=chrome&flow=xtls-rprx-vision&type=tcp#My%20Server"

    @Test func parsesRealityVisionLink() throws {
        let server = try #require(VLESSLinkParser.parse(realityLink))
        #expect(server.name == "My Server")
        #expect(server.address == "1.2.3.4")
        #expect(server.port == 443)
        #expect(server.userID == "b831381d-6324-4d53-ad4f-8cda48b30811")
        #expect(server.flow == "xtls-rprx-vision")
        #expect(server.network == "tcp")
        #expect(server.reality.publicKey == validPBK)
        #expect(server.reality.shortID == "6ba85179")
        #expect(server.reality.serverName == "yahoo.com")
        #expect(server.reality.fingerprint == "chrome")
    }

    @Test func parsesIPv6Host() throws {
        let link = "vless://uuid@[2001:db8::1]:8443?security=reality&pbk=\(validPBK)&sni=mask.example#v6"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.address == "2001:db8::1")
        #expect(server.port == 8443)
    }

    @Test func bracketsIPv6InDefaultName() throws {
        let link = "vless://uuid@[2001:db8::1]:8443?security=reality&pbk=\(validPBK)&sni=mask.example"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.name == "[2001:db8::1]:8443")
    }

    @Test func parsesRawUnicodeName() throws {
        let link = "vless://uuid@host.example:443?security=reality&pbk=\(validPBK)&sni=mask.example#🇳🇱 Netherlands NL-1"
        let server = try #require(VLESSLinkParser.parse(link))
        #expect(server.name == "🇳🇱 Netherlands NL-1")
    }

    @Test func fallsBackToDefaults() throws {
        let link = "vless://uuid@example.com:443?security=reality&pbk=\(validPBK)&sni=mask.example"
        let server = try #require(VLESSLinkParser.parse(link))
        // Без имени — host:port; без fp — chrome; sid/flow опциональны.
        #expect(server.name == "example.com:443")
        #expect(server.reality.fingerprint == "chrome")
        #expect(server.reality.shortID == "")
        #expect(server.flow == nil)
        #expect(server.network == "tcp")
    }

    /// Спека #716: отсутствующий sni переиспользует host (для IP это даст
    /// ClientHello без SNI — валидно, если сервер допускает пустой serverName).
    @Test func reusesHostWhenSNIAbsent() throws {
        let domain = try #require(VLESSLinkParser.parse(
            "vless://uuid@host.example:443?security=reality&pbk=\(validPBK)#no-sni"
        ))
        #expect(domain.reality.serverName == "host.example")

        let ip = try #require(VLESSLinkParser.parse(
            "vless://uuid@1.2.3.4:443?security=reality&pbk=\(validPBK)#no-sni-ip"
        ))
        #expect(ip.reality.serverName == "1.2.3.4")
    }

    /// "raw" — новое имя tcp в Xray; после нормализации id не зависит от написания.
    @Test func normalizesRawNetworkToTCP() throws {
        let raw = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&type=raw#raw"
        ))
        let tcp = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&type=tcp#tcp"
        ))
        #expect(raw.network == "tcp")
        #expect(raw.id == tcp.id)
    }

    @Test func acceptsUDP443VisionFlow() throws {
        let server = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&flow=xtls-rprx-vision-udp443#quic"
        ))
        #expect(server.flow == "xtls-rprx-vision-udp443")
    }

    /// Неизвестный fp уронил бы конфиг на старте ядра; "unsafe" для Reality
    /// запрещён — всё вне списка пресетов сводится к chrome.
    @Test func normalizesUnknownFingerprintToChrome() throws {
        for fp in ["hellochrome_133", "unsafe", "garbage"] {
            let server = try #require(VLESSLinkParser.parse(
                "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&fp=\(fp)#fp"
            ))
            #expect(server.reality.fingerprint == "chrome")
        }
        let firefox = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&fp=firefox#fp"
        ))
        #expect(firefox.reality.fingerprint == "firefox")
    }

    /// spx без ведущего "/" ядро отвергло бы целиком; параметр косметический,
    /// поэтому невалидное значение выбрасываем, а не бракуем ссылку.
    @Test func dropsSpiderXWithoutLeadingSlash() throws {
        let bad = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&spx=nopath#spx"
        ))
        #expect(bad.reality.spiderX == nil)

        let good = try #require(VLESSLinkParser.parse(
            "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&spx=%2Fcrawl#spx"
        ))
        #expect(good.reality.spiderX == "/crawl")
    }

    @Test(arguments: [
        "trojan://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com#wrong-scheme",
        "vless://uuid@host?security=reality&pbk=\(validPBK)&sni=a.com#no-port",
        "vless://@host:443?security=reality&pbk=\(validPBK)&sni=a.com#no-uuid",
        "vless://uuid@host:443?security=reality&sni=a.com#reality-without-pbk",
        "vless://uuid@host:443?security=none#unsupported-security-none",
        "vless://uuid@host:443?security=tls&sni=a.com#unsupported-security-tls",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&encryption=aes-128-gcm#bad-encryption",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&encryption=#empty-encryption",
        "vless://uuid@host:99999?security=reality&pbk=\(validPBK)&sni=a.com#port-out-of-range",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=#empty-sni",
        "vless://uuid@host:443?security=reality&pbk=short-key&sni=a.com#pbk-not-32-bytes",
        "vless://uuid@host:443?security=reality&pbk=AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=&sni=a.com#pbk-padded",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&sid=6ba8517#odd-sid",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&sid=xyzw#non-hex-sid",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&sid=0123456789abcdef01#sid-too-long",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&type=ws#reality-over-ws",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&type=grpc#unsupported-transport",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&sni=a.com&flow=xtls-rprx-direct#legacy-flow",
        "vless://uuid@host:443?security=reality&pbk=\(validPBK)&pbk=\(validPBK)&sni=a.com#duplicate-param",
        "not a link at all",
    ])
    func rejectsInvalidLinks(_ link: String) {
        #expect(VLESSLinkParser.parse(link) == nil)
    }
}
