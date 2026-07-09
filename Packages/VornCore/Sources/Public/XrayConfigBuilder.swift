import Foundation

/// Генерация Xray-конфига из модели сервера.
public enum XrayConfigBuilder {
    public enum BuildError: Error, Equatable {
        /// Кодирование не удалось. Деталей намеренно нет — в описание ошибки
        /// не должны попадать адрес сервера и UUID пользователя.
        case encodingFailed
    }

    /// Собирает JSON-конфиг с VLESS/Reality outbound для сервера.
    /// Ключи отсортированы, поэтому вывод детерминирован и пригоден
    /// для сравнения в тестах и дедупликации.
    public static func makeConfig(for server: VLESSServer) throws -> Data {
        let config = XrayConfig(
            log: .init(loglevel: "warning"),
            outbounds: [
                .init(
                    tag: "proxy",
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
                        )
                    )
                ),
                .init(tag: "direct", protocol: "freedom"),
            ],
            routing: .init(domainStrategy: "AsIs")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(config)
        } catch {
            throw BuildError.encodingFailed
        }
    }
}
