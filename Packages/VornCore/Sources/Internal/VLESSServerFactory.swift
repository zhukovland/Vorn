import Foundation

/// Общая сборка валидного Reality/Vision-сервера из сырых полей. Используется
/// и парсером ссылок (VLESSLinkParser), и XRAY_JSON-парсером — валидация одна.
/// nil = невалидно или неподдерживаемо (не Reality, чужой транспорт, битый pbk).
enum VLESSServerFactory {
    /// serverName: nil — поля не было (переиспользуем адрес как SNI);
    /// "" — поле есть и пустое (отказ, как требует спека).
    static func make(
        name: String,
        userID: String,
        address: String,
        port: Int,
        security: String?,
        encryption: String?,
        flow rawFlow: String?,
        network rawNetwork: String?,
        publicKey: String?,
        serverName: String?,
        shortID: String?,
        fingerprint: String?,
        spiderX: String?,
        xhttpPath: String? = nil,
        xhttpHost: String? = nil,
        xhttpMode: String? = nil
    ) -> VLESSServer? {
        guard !userID.isEmpty, !address.isEmpty, (1...65535).contains(port) else { return nil }

        // VLESS не шифрует на уровне протокола: допустимо "none" или отсутствие.
        if let encryption, encryption != "none" { return nil }

        guard security?.lowercased() == "reality",
              let pbk = publicKey, isRealityPublicKey(pbk)
        else { return nil }

        // sni: отсутствие → адрес; явная пустая строка → отказ.
        let sni: String
        if let serverName {
            guard !serverName.isEmpty else { return nil }
            sni = serverName
        } else {
            sni = address
        }

        let sid = shortID ?? ""
        guard isRealityShortID(sid) else { return nil }

        // Транспорт: tcp/raw (Vision) и xhttp; grpc/ws не поддерживаем.
        let network: String
        let xhttp: XHTTPSettings?
        switch rawNetwork?.nonEmpty?.lowercased() ?? "tcp" {
        case "tcp", "raw":
            network = "tcp"
            xhttp = nil
        case "xhttp":
            network = "xhttp"
            xhttp = XHTTPSettings(
                path: xhttpPath?.nonEmpty ?? "/",
                host: xhttpHost?.nonEmpty,
                mode: xhttpMode?.nonEmpty ?? "auto"
            )
        default:
            return nil
        }

        // flow: Vision только поверх RAW/TCP; для xhttp очищаем.
        let flow: String?
        if network == "tcp" {
            let raw = rawFlow?.nonEmpty
            if let raw, raw != "xtls-rprx-vision", raw != "xtls-rprx-vision-udp443" {
                return nil
            }
            flow = raw
        } else {
            flow = nil
        }

        // spx: ядро требует ведущий "/"; невалидное значение отбрасываем.
        let spx = spiderX?.nonEmpty.flatMap { $0.hasPrefix("/") ? $0 : nil }

        let reality = RealitySettings(
            publicKey: pbk,
            shortID: sid,
            serverName: sni,
            fingerprint: normalizedFingerprint(fingerprint),
            spiderX: spx
        )
        return VLESSServer(
            name: name, address: address, port: port, userID: userID,
            flow: flow, network: network, reality: reality, xhttp: xhttp
        )
    }

    /// pbk — x25519-ключ в base64url без паддинга, ровно 32 байта: так его
    /// валидирует Xray-core (base64.RawURLEncoding). Паддинг и стандартный
    /// алфавит (+, /) ядро отвергает — отвергаем и мы.
    static func isRealityPublicKey(_ value: String) -> Bool {
        guard value.count == 43,
              !value.contains("="), !value.contains("+"), !value.contains("/"),
              let data = Data(relaxedBase64: value)
        else { return false }
        return data.count == 32
    }

    /// sid — hex до 16 символов чётной длины; пустой допустим.
    static func isRealityShortID(_ value: String) -> Bool {
        value.isEmpty || (
            value.count <= 16 && value.count % 2 == 0
                && value.allSatisfy { $0.isASCII && $0.isHexDigit }
        )
    }

    /// Известные uTLS-пресеты Xray. Всё остальное сводим к chrome — дефолту
    /// спеки: неизвестный fp уронил бы конфиг на старте ядра.
    private static let knownFingerprints: Set<String> = [
        "chrome", "firefox", "safari", "ios", "android", "edge",
        "360", "qq", "random", "randomized", "randomizednoalpn",
    ]

    static func normalizedFingerprint(_ value: String?) -> String {
        guard let value = value?.lowercased(), knownFingerprints.contains(value) else {
            return "chrome"
        }
        return value
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
