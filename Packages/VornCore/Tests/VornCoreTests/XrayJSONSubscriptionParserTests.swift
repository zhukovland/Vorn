import Foundation
import Testing
@testable import VornCore

/// Валидный pbk (base64url, 32 байта) из реального ответа панели.
private let pbk = "dY9SNEllJMW63xo-JdXufhmjAxB_4uFw_QMjgufjiD8"

struct XrayJSONSubscriptionParserTests {
    /// Реальный одиночный tcp-reality конфиг из connliberty.com.
    @Test func parsesRealSingleTCPRealityConfig() throws {
        let json = #"""
        [{"remarks":"🇬🇧⚡Англия","outbounds":[{"mux":{"enabled":false},"protocol":"vless","settings":{"vnext":[{"address":"45.206.52.204","port":443,"users":[{"encryption":"none","flow":"xtls-rprx-vision","id":"1d2a0639-f7f1-48a7-9517-1cec2712a782","level":8}]}]},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"allowInsecure":false,"fingerprint":"firefox","publicKey":"dY9SNEllJMW63xo-JdXufhmjAxB_4uFw_QMjgufjiD8","serverName":"storage.yandex.net","shortId":"ea10cd5686751ec5","show":false}}}]}]
        """#
        let servers = try SubscriptionParser.parse(payload: json)
        #expect(servers.count == 1)
        let server = try #require(servers.first)
        #expect(server.name == "🇬🇧⚡Англия")
        #expect(server.address == "45.206.52.204")
        #expect(server.port == 443)
        #expect(server.userID == "1d2a0639-f7f1-48a7-9517-1cec2712a782")
        #expect(server.network == "tcp")
        #expect(server.flow == "xtls-rprx-vision")
        #expect(server.reality.serverName == "storage.yandex.net")
        #expect(server.reality.fingerprint == "firefox")
        #expect(server.reality.shortID == "ea10cd5686751ec5")
    }

    /// Массив: валидный tcp остаётся; grpc/tls отбраковываются, балансировщик
    /// и пустой конфиг пропускаются.
    @Test func keepsSupportedSkipsAggregatesAndUnsupported() throws {
        let json = """
        [
          {"remarks":"OK","outbounds":[\(vlessOutbound(network: "tcp", security: "reality"))]},
          {"remarks":"GRPC","outbounds":[\(vlessOutbound(network: "grpc", security: "reality"))]},
          {"remarks":"TLS","outbounds":[\(vlessOutbound(network: "tcp", security: "tls"))]},
          {"remarks":"AUTO","routing":{"balancers":[{"tag":"b"}]},"outbounds":[\(vlessOutbound(network: "tcp", security: "reality"))]},
          {"remarks":"EMPTY","outbounds":[]}
        ]
        """
        let servers = try SubscriptionParser.parse(payload: json)
        #expect(servers.map(\.name) == ["OK"])
    }

    @Test func parsesXHTTPConfig() throws {
        let outbound = vlessOutbound(
            network: "xhttp", security: "reality",
            extraStream: #""xhttpSettings":{"path":"/dl","host":"cdn.example","mode":"stream-up"}"#
        )
        let json = #"[{"remarks":"XH","outbounds":[\#(outbound)]}]"#
        let server = try #require(try SubscriptionParser.parse(payload: json).first)
        #expect(server.network == "xhttp")
        #expect(server.xhttp?.path == "/dl")
        #expect(server.xhttp?.host == "cdn.example")
    }

    /// XRAY_JSON, завёрнутый в base64 (детект после декодирования).
    @Test func parsesBase64WrappedJSON() throws {
        let json = #"[{"remarks":"B64","outbounds":[\#(vlessOutbound(network: "tcp", security: "reality"))]}]"#
        let wrapped = Data(json.utf8).base64EncodedString()
        let servers = try SubscriptionParser.parse(payload: wrapped)
        #expect(servers.map(\.name) == ["B64"])
    }

    /// JSON распознан, но ни одного поддерживаемого сервера — noServers.
    @Test func jsonWithoutSupportedServersThrowsNoServers() {
        let json = #"[{"remarks":"G","outbounds":[\#(vlessOutbound(network: "grpc", security: "reality"))]}]"#
        #expect(throws: SubscriptionParser.ParseError.noServers) {
            try SubscriptionParser.parse(payload: json)
        }
    }

    // Фрагмент vless-outbound с валидным Reality; network/security варьируем.
    private func vlessOutbound(network: String, security: String, extraStream: String = "") -> String {
        let extra = extraStream.isEmpty ? "" : ",\(extraStream)"
        return #"""
        {"protocol":"vless","settings":{"vnext":[{"address":"1.2.3.4","port":443,"users":[{"encryption":"none","flow":"","id":"uuid-\#(network)-\#(security)"}]}]},"streamSettings":{"network":"\#(network)","security":"\#(security)","realitySettings":{"fingerprint":"chrome","publicKey":"\#(pbk)","serverName":"a.com","shortId":"6ba85179"}\#(extra)}}
        """#
    }
}
