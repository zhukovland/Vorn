import Foundation

/// Разбор одиночной vless:// ссылки в VLESSServer по стандарту share-ссылок
/// (XTLS/Xray-core discussion #716). Используется SubscriptionParser-ом,
/// наружу не торчит.
enum VLESSLinkParser {
    /// Возвращает nil для ссылок, из которых нельзя собрать рабочий
    /// Reality/Vision-сервер: битый URL, чужая схема, security != reality,
    /// невалидные pbk/sid/flow/транспорт. Браковать лучше здесь — отказ
    /// ядра на старте туннеля всплывает слишком далеко от причины.
    static func parse(_ link: String) -> VLESSServer? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = components(from: trimmed),
            components.scheme?.lowercased() == "vless",
            let host = components.host, !host.isEmpty,
            let port = components.port, (1...65535).contains(port),
            let userID = components.user, !userID.isEmpty
        else { return nil }

        // URLComponents может вернуть IPv6 в скобках; в модели и Xray-конфиге адрес — без них.
        let address = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))

        // Спека запрещает дублировать query-ключи: молча брать последнее
        // значение — значит позволить перебить security= или pbk= вторым
        // экземпляром параметра.
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let name = item.name.lowercased()
            guard !params.keys.contains(name) else { return nil }
            params[name] = item.value ?? ""
        }

        // VLESS не поддерживает шифрование на уровне протокола: допустимо
        // отсутствие параметра или явное "none"; пустое значение спека
        // запрещает, PQ-варианты (mlkem768x25519…) продукт не поддерживает.
        if let encryption = params["encryption"], encryption != "none" { return nil }

        // Продукт поддерживает только VLESS Reality.
        guard params["security"]?.lowercased() == "reality",
              let publicKey = params["pbk"], isRealityPublicKey(publicKey)
        else { return nil }

        // sni: отсутствие = переиспользовать host (спека); явная пустая
        // строка запрещена. Для IP-хоста это даст ClientHello без SNI —
        // легально, если сервер допускает пустой serverName.
        let serverName: String
        if let sni = params["sni"] {
            guard !sni.isEmpty else { return nil }
            serverName = sni
        } else {
            serverName = address
        }

        let shortID = params["sid"] ?? ""
        guard isRealityShortID(shortID) else { return nil }

        // flow: пусто (Reality без Vision) или Vision-варианты; -udp443 —
        // клиентская опция «не резать QUIC», принимаем как есть. Легаси
        // xtls-rprx-direct/origin/splice ядро убрало в 1.8.0.
        let flow = params["flow"].flatMap(\.nonEmpty)
        if let flow, flow != "xtls-rprx-vision", flow != "xtls-rprx-vision-udp443" {
            return nil
        }

        // Транспорт: Vision работает только поверх RAW/TCP, а grpc/xhttp
        // требуют транспортных параметров, которые мы в конфиг не переносим —
        // честнее отказать при импорте. "raw" — новое имя tcp в Xray;
        // нормализуем, чтобы id сервера не зависел от написания.
        let network: String
        switch params["type"].flatMap(\.nonEmpty)?.lowercased() ?? "tcp" {
        case "tcp", "raw": network = "tcp"
        default: return nil
        }

        // spx: ядро требует ведущий "/" и подставляет "/" вместо пустого;
        // невалидное значение выбрасываем, а не роняем весь линк — параметр
        // косметический (путь «паука» маскировки).
        let spiderX = params["spx"].flatMap(\.nonEmpty).flatMap { $0.hasPrefix("/") ? $0 : nil }

        let reality = RealitySettings(
            publicKey: publicKey,
            shortID: shortID,
            serverName: serverName,
            fingerprint: normalizedFingerprint(params["fp"]),
            spiderX: spiderX
        )

        // Для IPv6 скобки в отображаемом имени ставим осознанно — иначе
        // host и port сливаются в одну двоеточечную кашу.
        let defaultName = address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"

        return VLESSServer(
            name: components.fragment.flatMap(\.nonEmpty) ?? defaultName,
            address: address,
            port: port,
            userID: userID,
            flow: flow,
            network: network,
            reality: reality
        )
    }

    /// pbk — x25519-ключ в base64url без паддинга, ровно 32 байта: так его
    /// валидирует Xray-core (base64.RawURLEncoding). Паддинг и стандартный
    /// алфавит (+, /) ядро отвергает — отвергаем и мы.
    private static func isRealityPublicKey(_ value: String) -> Bool {
        guard value.count == 43,
              !value.contains("="), !value.contains("+"), !value.contains("/"),
              let data = Data(relaxedBase64: value)
        else { return false }
        return data.count == 32
    }

    /// sid — hex до 16 символов чётной длины (hex.DecodeString в ядре);
    /// пустой допустим, если сервер разрешает пустой short ID.
    private static func isRealityShortID(_ value: String) -> Bool {
        value.isEmpty || (
            value.count <= 16 && value.count % 2 == 0
                && value.allSatisfy { $0.isASCII && $0.isHexDigit }
        )
    }

    /// Известные uTLS-пресеты Xray. Всё остальное сводим к chrome — дефолту
    /// спеки: неизвестный fp уронил бы весь конфиг на старте ядра, а
    /// "unsafe"/"hellogolang" для Reality запрещены и не должны пролезать
    /// из недоверенной подписки.
    private static let knownFingerprints: Set<String> = [
        "chrome", "firefox", "safari", "ios", "android", "edge",
        "360", "qq", "random", "randomized", "randomizednoalpn",
    ]

    private static func normalizedFingerprint(_ value: String?) -> String {
        guard let value = value?.lowercased(), knownFingerprints.contains(value) else {
            return "chrome"
        }
        return value
    }

    /// Foundation до iOS 17 / macOS 14 строго следует RFC 3986 и возвращает nil
    /// для ссылок с сырыми не-ASCII символами или пробелами — в подписках это
    /// почти всегда имя сервера (#🇳🇱 Netherlands). При неудаче кодируем fragment
    /// и пробуем ещё раз; на современных системах первая ветка срабатывает всегда.
    private static func components(from link: String) -> URLComponents? {
        if let components = URLComponents(string: link) { return components }
        guard let hashIndex = link.firstIndex(of: "#") else { return nil }
        let base = String(link[..<hashIndex])
        let rawFragment = String(link[link.index(after: hashIndex)...])
        guard let fragment = (rawFragment.removingPercentEncoding ?? rawFragment)
            .addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
        else { return nil }
        return URLComponents(string: base + "#" + fragment)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
