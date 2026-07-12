import Foundation

/// Параметры транспорта XHTTP (бывший splithttp) из query-части ссылки.
/// REALITY поверх XHTTP — валидная комбинация Xray; Vision при этом не
/// применяется (flow пустой). Присутствует только у серверов с network=xhttp.
public struct XHTTPSettings: Codable, Hashable, Sendable {
    /// path — путь запроса; по умолчанию "/".
    public let path: String
    /// host — заголовок Host; опционален, по умолчанию берётся адрес сервера.
    public let host: String?
    /// mode — режим XHTTP (auto/packet-up/stream-up/stream-one); по умолчанию auto.
    public let mode: String

    public init(path: String = "/", host: String? = nil, mode: String = "auto") {
        self.path = path
        self.host = host
        self.mode = mode
    }
}
