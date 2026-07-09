import Foundation

/// Принудительная зачистка Xray-конфига перед запуском ядра.
///
/// Требование безопасности проекта: даже если конфиг пришёл извне или был
/// дополнен ядром, в нём не должно быть блоков "api", "metrics", "stats"
/// (известные уязвимости VLESS-клиентов — торчащие наружу управляющие API),
/// а loglevel всегда принудительно "warning". Вызывается из configTransform-хука
/// SwiftyXrayKit в extension; наш собственный XrayConfigBuilder эти блоки и так
/// не генерирует — санитайзер работает вторым эшелоном.
public enum XrayConfigSanitizer {
    public enum SanitizeError: Error, Equatable {
        case invalidJSON
    }

    public static func sanitize(_ configJSON: String) throws -> String {
        let sanitized = try sanitize(Data(configJSON.utf8))
        guard let result = String(data: sanitized, encoding: .utf8) else {
            throw SanitizeError.invalidJSON
        }
        return result
    }

    public static func sanitize(_ configData: Data) throws -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: configData),
              var config = object as? [String: Any]
        else { throw SanitizeError.invalidJSON }

        config.removeValue(forKey: "api")
        config.removeValue(forKey: "metrics")
        config.removeValue(forKey: "stats")

        var log = config["log"] as? [String: Any] ?? [:]
        log["loglevel"] = "warning"
        config["log"] = log

        // Вырезанный api-блок не должен оставить висячих ссылок: конфиг с
        // routing-правилом на несуществующий tag Xray не примет.
        if var routing = config["routing"] as? [String: Any],
           var rules = routing["rules"] as? [[String: Any]] {
            rules.removeAll { rule in
                if let outboundTag = rule["outboundTag"] as? String, outboundTag == "api" { return true }
                if let inboundTags = rule["inboundTag"] as? [String], inboundTags.contains("api") { return true }
                return false
            }
            routing["rules"] = rules
            config["routing"] = routing
        }

        do {
            return try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        } catch {
            throw SanitizeError.invalidJSON
        }
    }
}
