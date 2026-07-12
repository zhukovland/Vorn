import Foundation

/// Генерация Xray-конфига из модели сервера.
public enum XrayConfigBuilder {
    /// Собирает JSON-конфиг с VLESS/Reality outbound для сервера.
    /// Ключи отсортированы, поэтому вывод детерминирован и пригоден
    /// для сравнения в тестах и дедупликации.
    public static func makeConfig(for server: VLESSServer) throws -> Data {
        let config = XrayConfig(
            log: .init(loglevel: XrayPolicy.logLevel),
            outbounds: [
                .init(
                    tag: XrayTag.proxy,
                    protocol: "vless",
                    settings: .init(vnext: [
                        .init(
                            address: server.address,
                            port: server.port,
                            users: [
                                .init(id: server.userID, encryption: "none", flow: server.flow)
                            ]
                        )
                    ]),
                    streamSettings: .init(
                        network: server.network,
                        security: "reality",
                        realitySettings: .init(
                            publicKey: server.reality.publicKey,
                            shortId: server.reality.shortID,
                            serverName: server.reality.serverName,
                            fingerprint: server.reality.fingerprint,
                            spiderX: server.reality.spiderX
                        ),
                        xhttpSettings: server.xhttp.map {
                            .init(path: $0.path, host: $0.host, mode: $0.mode)
                        }
                    )
                ),
                .init(tag: XrayTag.direct, protocol: "freedom", settings: nil, streamSettings: nil),
            ],
            routing: .init(domainStrategy: "AsIs")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(config)
    }
}
