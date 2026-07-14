import Foundation

/// Разбор одиночной vless:// ссылки в VLESSServer по стандарту share-ссылок
/// (XTLS/Xray-core discussion #716). Собирает query-параметры и отдаёт их
/// общей фабрике VLESSServerFactory; наружу не торчит.
enum VLESSLinkParser {
    /// Возвращает nil для ссылок, из которых нельзя собрать рабочий
    /// Reality/Vision-сервер: битый URL, чужая схема, невалидные параметры.
    static func parse(_ link: String) -> VLESSServer? {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = components(from: trimmed),
            components.scheme?.lowercased() == "vless",
            let host = components.host, !host.isEmpty,
            let port = components.port,
            let userID = components.user, !userID.isEmpty
        else { return nil }

        // URLComponents может вернуть IPv6 в скобках; в модели адрес — без них.
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

        // Для IPv6 скобки в отображаемом имени ставим осознанно — иначе
        // host и port сливаются в одну двоеточечную кашу.
        let defaultName = address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"

        return VLESSServerFactory.make(
            name: components.fragment.flatMap(\.nonEmpty) ?? defaultName,
            userID: userID,
            address: address,
            port: port,
            security: params["security"],
            encryption: params["encryption"],
            flow: params["flow"],
            network: params["type"],
            publicKey: params["pbk"],
            serverName: params["sni"],
            shortID: params["sid"],
            fingerprint: params["fp"],
            spiderX: params["spx"],
            xhttpPath: params["path"],
            xhttpHost: params["host"],
            xhttpMode: params["mode"]
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
