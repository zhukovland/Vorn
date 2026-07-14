import Foundation

/// Разбор подписки в формате XRAY_JSON: массив (или один) полных Xray-конфигов
/// (панель Remnawave отдаёт такое некоторым клиентам). Из каждого конфига с
/// одним vless-outbound-ом берём сервер, имя — из remarks. Конфиги-агрегаты
/// (балансировщики/«Авто», 0 или >1 outbound) пропускаем: это не отдельный
/// сервер. Валидация Reality/транспорта — общая (VLESSServerFactory).
enum XrayJSONSubscriptionParser {
    static func parse(_ data: Data) -> [VLESSServer]? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        let configs: [[String: Any]]
        if let array = object as? [[String: Any]] {
            configs = array
        } else if let single = object as? [String: Any] {
            configs = [single]
        } else {
            return nil
        }

        var seen = Set<String>()
        var servers: [VLESSServer] = []
        for config in configs {
            // Балансировщик/«Авто» — не отдельный сервер.
            if let balancers = (config["routing"] as? [String: Any])?["balancers"] as? [[String: Any]],
               !balancers.isEmpty {
                continue
            }
            let proxies = (config["outbounds"] as? [[String: Any]] ?? [])
                .filter { ($0["protocol"] as? String) == "vless" }
            // Одиночный сервер: ровно один vless-outbound.
            guard proxies.count == 1 else { continue }

            let remarks = (config["remarks"] as? String)?.trimmingCharacters(in: .whitespaces)
            if let server = server(from: proxies[0], remarks: remarks),
               seen.insert(server.id).inserted {
                servers.append(server)
            }
        }
        return servers.isEmpty ? nil : servers
    }

    private static func server(from outbound: [String: Any], remarks: String?) -> VLESSServer? {
        guard let vnext = (outbound["settings"] as? [String: Any])?["vnext"] as? [[String: Any]],
              let node = vnext.first,
              let address = node["address"] as? String,
              let port = intValue(node["port"]),
              let user = (node["users"] as? [[String: Any]])?.first,
              let userID = user["id"] as? String
        else { return nil }

        let stream = outbound["streamSettings"] as? [String: Any] ?? [:]
        let reality = stream["realitySettings"] as? [String: Any] ?? [:]
        let xhttp = stream["xhttpSettings"] as? [String: Any]

        let name = remarks?.nonEmpty ?? "\(address):\(port)"
        return VLESSServerFactory.make(
            name: name,
            userID: userID,
            address: address,
            port: port,
            security: stream["security"] as? String,
            encryption: user["encryption"] as? String,
            flow: user["flow"] as? String,
            network: stream["network"] as? String,
            publicKey: reality["publicKey"] as? String,
            serverName: reality["serverName"] as? String,
            shortID: reality["shortId"] as? String,
            fingerprint: reality["fingerprint"] as? String,
            spiderX: reality["spiderX"] as? String,
            xhttpPath: xhttp?["path"] as? String,
            xhttpHost: xhttp?["host"] as? String,
            xhttpMode: xhttp?["mode"] as? String
        )
    }

    /// port в JSON бывает и числом, и строкой.
    private static func intValue(_ value: Any?) -> Int? {
        (value as? Int) ?? (value as? String).flatMap(Int.init)
    }
}
