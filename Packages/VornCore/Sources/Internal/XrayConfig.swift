import Foundation

/// Encodable-модель той части конфига Xray, которую генерирует приложение.
/// TUN-inbound сюда не входит — его добавляет ядро (SwiftyXrayKit) на своей
/// стороне; наш JSON описывает только log, outbounds и routing.
struct XrayConfig: Encodable {
    let log: Log
    let outbounds: [Outbound]
    let routing: Routing

    struct Log: Encodable {
        let loglevel: String
    }

    struct Outbound: Encodable {
        let tag: String
        let `protocol`: String
        let settings: Settings?
        let streamSettings: StreamSettings?

        struct Settings: Encodable {
            let vnext: [VNext]
        }

        struct VNext: Encodable {
            let address: String
            let port: Int
            let users: [User]
        }

        struct User: Encodable {
            let id: String
            let encryption: String
            let flow: String?
        }

        struct StreamSettings: Encodable {
            let network: String
            let security: String
            let realitySettings: Reality
        }

        struct Reality: Encodable {
            let publicKey: String
            let shortId: String
            let serverName: String
            let fingerprint: String
            let spiderX: String?
        }
    }

    struct Routing: Encodable {
        let domainStrategy: String
    }
}
