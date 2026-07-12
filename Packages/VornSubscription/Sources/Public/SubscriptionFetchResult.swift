import Foundation
import VornCore

/// Разобранный ответ подписки: серверы плюс метаданные из заголовков.
/// updatedAt не входит — момент обновления ставит вызывающий (детерминизм
/// в тестах, единый источник времени в приложении).
public struct SubscriptionFetchResult: Sendable, Equatable {
    /// Серверы из тела; пусто — легитимный ответ (например, лимит устройств),
    /// а не ошибка: сохранённый список из-за этого сносить нельзя.
    public let servers: [VLESSServer]
    /// profile-title: отображаемое имя подписки от панели, если прислала.
    public let title: String?
    /// subscription-userinfo: трафик и срок действия, если прислано.
    public let userInfo: SubscriptionUserInfo?
    /// profile-update-interval, переведённый в секунды.
    public let updateInterval: TimeInterval?
    /// announce: свободное сообщение панели пользователю (акции, техработы,
    /// причина пустого списка). У Remnawave/Happ приходит как base64.
    public let announce: String?
    /// support-url: ссылка «поддержка», если панель прислала.
    public let supportURL: URL?
    /// profile-web-page-url: страница подписки для открытия в браузере.
    public let webPageURL: URL?

    public init(
        servers: [VLESSServer],
        title: String? = nil,
        userInfo: SubscriptionUserInfo? = nil,
        updateInterval: TimeInterval? = nil,
        announce: String? = nil,
        supportURL: URL? = nil,
        webPageURL: URL? = nil
    ) {
        self.servers = servers
        self.title = title
        self.userInfo = userInfo
        self.updateInterval = updateInterval
        self.announce = announce
        self.supportURL = supportURL
        self.webPageURL = webPageURL
    }
}

/// Трафик и срок из заголовка subscription-userinfo.
/// Семантика панелей (Remnawave/Marzban): total=0 — безлимит, expire=0/нет —
/// без срока; отсюда Optional вместо нулей-заглушек.
public struct SubscriptionUserInfo: Sendable, Equatable {
    public let upload: Int64?
    public let download: Int64?
    /// nil — безлимитный трафик (панель прислала total=0).
    public let total: Int64?
    /// nil — без срока действия (панель прислала expire=0 или не прислала).
    public let expire: Date?

    public init(upload: Int64?, download: Int64?, total: Int64?, expire: Date?) {
        self.upload = upload
        self.download = download
        self.total = total
        self.expire = expire
    }
}

public enum SubscriptionFetchError: Error, Equatable {
    /// URL не https — незашифрованные подписки не загружаем.
    case insecureURL
    /// HTTP-ответ с не-2xx статусом.
    case http(status: Int)
    /// Сбой транспорта. Без деталей: ни URL, ни токена в тексте быть не должно.
    case network
    /// Тело не разобралось как список vless://-серверов.
    case parse(SubscriptionParser.ParseError)
}
