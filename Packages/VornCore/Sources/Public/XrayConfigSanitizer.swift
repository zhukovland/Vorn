import Foundation

/// Принудительная зачистка Xray-конфига перед запуском ядра.
///
/// Вызывается из configTransform-хука SwiftyXrayKit — хук небросающий и
/// работает со словарём, поэтому основной вход `sanitize(_:)` тоже небросающий:
/// на любом входе он возвращает конфиг, безопасный по инвариантам проекта.
/// Проваливаться наружу нечему, значит и fail-open на месте вызова невозможен.
///
/// Гарантии на выходе:
/// 1. Только разрешённые верхнеуровневые блоки (`XrayPolicy.allowedTopLevelKeys`).
///    api, metrics, stats, observatory, reverse и прочие управляющие и
///    телеметрийные поверхности вырезаны, даже если пришли из подписки.
/// 2. Ни одного inbound со слушающим сокетом: TUN-inbound ядро создаёт само,
///    а `dokodemo-door` на 127.0.0.1 — это и есть тот самый управляющий порт,
///    ради которого существует блок api.
/// 3. `log` пересобран с нуля: `loglevel: warning`, без access/error/dnsLog —
///    иначе Xray пишет посещённые домены и адреса серверов в файл.
/// 4. Никаких висячих ссылок: routing-правила, ссылающиеся на исчезнувшие теги,
///    удалены — Xray не примет конфиг с ссылкой на несуществующий тег.
/// 5. У outbound-ов нет полей перенаправления трафика и экфильтрации:
///    `proxySettings` и `sockopt.dialerProxy` (оба перецепляют трафик
///    outbound-а через другой outbound) и `masterKeyLog` в
///    reality/tlsSettings (пишет TLS-секреты в произвольный файл).
public enum XrayConfigSanitizer {
    public enum SanitizeError: Error, Equatable {
        case invalidJSON
    }

    public static func sanitize(_ config: [String: Any]) -> [String: Any] {
        // Тег api-блока конфигурируем ("api": {"tag": "myapi"}) — забираем его
        // до удаления, иначе правила, ссылающиеся на него, останутся висеть.
        var removedTags: Set<String> = []
        if let api = config["api"] as? [String: Any] {
            removedTags.insert(api["tag"] as? String ?? "api")
        }
        if let metrics = config["metrics"] as? [String: Any] {
            removedTags.insert(metrics["tag"] as? String ?? "metrics")
        }

        var sanitized = config.filter { XrayPolicy.allowedTopLevelKeys.contains($0.key) }
        sanitized["log"] = ["loglevel": XrayPolicy.logLevel]

        if let inbounds = sanitized["inbounds"] as? [[String: Any]] {
            let kept = inbounds.filter { !isListening($0) }
            for dropped in inbounds where isListening(dropped) {
                if let tag = dropped["tag"] as? String { removedTags.insert(tag) }
            }
            sanitized["inbounds"] = kept
        }

        if let outbounds = sanitized["outbounds"] as? [[String: Any]] {
            sanitized["outbounds"] = outbounds.map(scrubOutbound)
        }

        if var routing = sanitized["routing"] as? [String: Any] {
            sanitized["routing"] = sanitizeRouting(routing: &routing, in: sanitized, removedTags: removedTags)
        }

        return sanitized
    }

    /// Наш билдер этих полей не порождает — зачистка страхует от конфига,
    /// пришедшего любым другим путём (гарантия 5 в шапке).
    private static func scrubOutbound(_ outbound: [String: Any]) -> [String: Any] {
        var outbound = outbound
        // proxySettings.tag и sockopt.dialerProxy — один класс: перецепляют
        // трафик outbound-а через другой (потенциально чужой) outbound.
        outbound.removeValue(forKey: "proxySettings")

        guard var stream = outbound["streamSettings"] as? [String: Any] else { return outbound }
        for key in ["realitySettings", "tlsSettings"] {
            if var settings = stream[key] as? [String: Any] {
                settings.removeValue(forKey: "masterKeyLog")
                stream[key] = settings
            }
        }
        if var sockopt = stream["sockopt"] as? [String: Any] {
            sockopt.removeValue(forKey: "dialerProxy")
            stream["sockopt"] = sockopt
        }
        outbound["streamSettings"] = stream
        return outbound
    }

    /// Inbound со слушающим сокетом: у него есть порт или адрес прослушивания.
    /// TUN-inbound, который добавляет ядро, сокет не открывает.
    private static func isListening(_ inbound: [String: Any]) -> Bool {
        inbound["port"] != nil || inbound["listen"] != nil
    }

    private static func sanitizeRouting(
        routing: inout [String: Any],
        in config: [String: Any],
        removedTags: Set<String>
    ) -> [String: Any] {
        var knownTags = Set<String>()
        for inbound in config["inbounds"] as? [[String: Any]] ?? [] {
            if let tag = inbound["tag"] as? String { knownTags.insert(tag) }
        }
        for outbound in config["outbounds"] as? [[String: Any]] ?? [] {
            if let tag = outbound["tag"] as? String { knownTags.insert(tag) }
        }
        var knownBalancers = Set<String>()
        for balancer in routing["balancers"] as? [[String: Any]] ?? [] {
            if let tag = balancer["tag"] as? String, !removedTags.contains(tag) {
                knownBalancers.insert(tag)
            }
        }

        if let rules = routing["rules"] as? [[String: Any]] {
            routing["rules"] = rules.compactMap { rule in
                sanitizeRule(rule, knownTags: knownTags, knownBalancers: knownBalancers)
            }
        }
        return routing
    }

    /// Возвращает nil, если правило ссылается на тег, которого больше нет.
    private static func sanitizeRule(
        _ rule: [String: Any],
        knownTags: Set<String>,
        knownBalancers: Set<String>
    ) -> [String: Any]? {
        var rule = rule

        if let outboundTag = rule["outboundTag"] as? String, !knownTags.contains(outboundTag) {
            return nil
        }
        if let balancerTag = rule["balancerTag"] as? String, !knownBalancers.contains(balancerTag) {
            return nil
        }

        // inboundTag в Xray — StringList: принимается и массив, и голая строка.
        if let inboundTag = rule["inboundTag"] {
            let tags: [String]
            switch inboundTag {
            case let array as [String]: tags = array
            case let single as String: tags = [single]
            default: return nil
            }
            let surviving = tags.filter { knownTags.contains($0) }
            // Правило адресовалось только исчезнувшим inbound-ам — оно мертво.
            if surviving.isEmpty { return nil }
            rule["inboundTag"] = surviving
        }

        return rule
    }

    public static func sanitize(_ configData: Data) throws -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: configData),
              let config = object as? [String: Any]
        else { throw SanitizeError.invalidJSON }

        do {
            return try JSONSerialization.data(withJSONObject: sanitize(config), options: [.sortedKeys])
        } catch {
            throw SanitizeError.invalidJSON
        }
    }
}
