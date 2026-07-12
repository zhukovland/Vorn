import Foundation
@testable import VornCore

/// Общая фикстура: единственное место, которое надо править при добавлении
/// обязательного поля в VLESSServer или RealitySettings.
enum Fixtures {
    static func server(
        name: String = "Test",
        address: String = "1.2.3.4",
        port: Int = 443,
        userID: String = "b831381d-6324-4d53-ad4f-8cda48b30811",
        flow: String? = "xtls-rprx-vision",
        network: String = "tcp",
        publicKey: String = "pbk-value",
        shortID: String = "6ba85179",
        serverName: String = "yahoo.com",
        fingerprint: String = "chrome",
        spiderX: String? = nil,
        xhttp: XHTTPSettings? = nil
    ) -> VLESSServer {
        VLESSServer(
            name: name,
            address: address,
            port: port,
            userID: userID,
            flow: flow,
            network: network,
            reality: RealitySettings(
                publicKey: publicKey,
                shortID: shortID,
                serverName: serverName,
                fingerprint: fingerprint,
                spiderX: spiderX
            ),
            xhttp: xhttp
        )
    }

    static func object(_ data: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
