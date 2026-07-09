import Foundation

/// Разбор одиночной vless:// ссылки в VLESSServer.
/// Используется SubscriptionParser-ом, наружу не торчит.
enum VLESSLinkParser {
    /// Возвращает nil для ссылок, из которых нельзя собрать рабочий
    /// Reality-сервер: битый URL, чужая схема, security != reality,
    /// отсутствие pbk или sni. Браковать лучше здесь — отказ на этапе
    /// подключения всплывает слишком далеко от причины.
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

        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            params[item.name.lowercased()] = item.value
        }

        // VLESS не поддерживает шифрование на уровне протокола — допустимо только none.
        if let encryption = params["encryption"], !encryption.isEmpty, encryption != "none" {
            return nil
        }

        // Продукт поддерживает только VLESS Reality. SNI обязателен явно:
        // фоллбек на address дал бы голый IP в ClientHello (запрещено RFC 6066)
        // и Reality-хендшейк, падающий уже на подключении.
        guard params["security"]?.lowercased() == "reality",
              let publicKey = params["pbk"], !publicKey.isEmpty,
              let serverName = params["sni"], !serverName.isEmpty
        else { return nil }

        let reality = RealitySettings(
            publicKey: publicKey,
            shortID: params["sid"] ?? "",
            serverName: serverName,
            fingerprint: params["fp"].flatMap(\.nonEmpty) ?? "chrome",
            spiderX: params["spx"]
        )

        // Для IPv6 скобки в отображаемом имени ставим осознанно — иначе
        // host и port сливаются в одну двоеточечную кашу.
        let defaultName = address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"

        return VLESSServer(
            name: components.fragment.flatMap(\.nonEmpty) ?? defaultName,
            address: address,
            port: port,
            userID: userID,
            flow: params["flow"].flatMap(\.nonEmpty),
            network: params["type"].flatMap(\.nonEmpty)?.lowercased() ?? "tcp",
            reality: reality
        )
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
