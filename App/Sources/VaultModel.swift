import Foundation
import VornCore
import VornStorage
import VornSubscription

/// Строка списка серверов для UI: сервер плюс ссылка на выбор (какого
/// источника). id уникален между источниками — один и тот же VLESSServer.id
/// может быть и в подписке, и среди ручных ключей.
struct ServerEntry: Identifiable {
    let server: VLESSServer
    let selection: ServerSelection
    let subscriptionName: String?

    var id: String {
        switch selection {
        case .manual(let serverID): "manual:\(serverID)"
        case .subscription(let subscriptionID, let serverID): "sub:\(subscriptionID):\(serverID)"
        }
    }
}

/// Состояние vault для UI. Операции Keychain синхронные и короткие; загрузка
/// подписки — сетевая, поэтому async.
@Observable
@MainActor
final class VaultModel {
    private(set) var state = VaultState()
    var lastError: String?
    /// Сообщение панели из заголовка announce последней загрузки подписки.
    var announce: String?

    @ObservationIgnored private let vault = ServerVault()
    @ObservationIgnored private let loader = SubscriptionLoader(userAgent: "Vorn/1.0")

    /// Все серверы плоским списком: ручные, затем по подпискам.
    var entries: [ServerEntry] {
        let manual = state.manualServers.map {
            ServerEntry(server: $0, selection: .manual(serverID: $0.id), subscriptionName: nil)
        }
        let subscription = state.subscriptions.flatMap { sub in
            sub.servers.map {
                ServerEntry(
                    server: $0,
                    selection: .subscription(subscriptionID: sub.id, serverID: $0.id),
                    subscriptionName: sub.name
                )
            }
        }
        return manual + subscription
    }

    var selectedServer: VLESSServer? { state.selectedServer }

    func reload() {
        perform { state = try vault.load() }
    }

    /// Импорт голой vless://-ссылки; добавленный сервер сразу выбирается.
    func addServer(link: String) {
        guard let server = VLESSServer(link: link) else {
            lastError = "Не получилось разобрать ссылку: нужна vless:// с security=reality, pbk и Vision/tcp"
            return
        }
        perform {
            try vault.addManual(server)
            state = try vault.select(.manual(serverID: server.id))
        }
    }

    /// Загрузка подписки по URL и слияние в vault. Имя берём из panel-заголовка
    /// profile-title, иначе из хоста. Пустой список — не ошибка (см. загрузчик).
    func importSubscription(urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            lastError = "Неверный URL подписки"
            return
        }
        do {
            let result = try await loader.load(from: url)
            let name = result.title ?? url.host ?? "Подписка"
            let subscription = Subscription(
                url: url, name: name, servers: result.servers, updatedAt: Date()
            )
            state = try vault.merge(subscription)
            // Если после обновления выбор опустел (выбранный сервер исчез из
            // свежего списка) или его ещё не было — выбираем первый сервер
            // этой подписки, чтобы всегда было что подключать.
            if state.selectedServer == nil, let first = subscription.servers.first {
                state = try vault.select(.subscription(subscriptionID: subscription.id, serverID: first.id))
            }
            announce = result.announce
            lastError = result.servers.isEmpty ? "Подписка без серверов" : nil
        } catch {
            lastError = Self.describeFetch(error)
        }
    }

    func select(_ selection: ServerSelection) {
        perform { state = try vault.select(selection) }
    }

    func isSelected(_ selection: ServerSelection) -> Bool {
        state.selection == selection
    }

    func removeManual(serverID: String) {
        perform { state = try vault.removeManual(serverID: serverID) }
    }

    func removeSubscription(id: String) {
        perform { state = try vault.remove(subscriptionID: id) }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            lastError = nil
        } catch {
            lastError = Self.describe(error)
        }
    }

    /// Человекочитаемое описание ошибки. Ни ключей, ни адресов — только суть.
    private static func describe(_ error: Error) -> String {
        switch error {
        case SecureStoreError.keychain(let status):
            "Keychain недоступен (OSStatus \(status))"
        case VaultError.corruptedState:
            "Сохранённые данные повреждены"
        case VaultError.unknownSelection, VaultError.unknownSubscription:
            "Элемент уже удалён — обновите список"
        default:
            "Операция не удалась: \(error.localizedDescription)"
        }
    }

    private static func describeFetch(_ error: Error) -> String {
        switch error {
        case SubscriptionFetchError.insecureURL:
            "Подписка должна быть по https://"
        case SubscriptionFetchError.http(let status):
            "Сервер подписки ответил ошибкой (HTTP \(status))"
        case SubscriptionFetchError.network:
            "Не удалось связаться с сервером подписки"
        case SubscriptionFetchError.parse:
            "Ответ подписки не распознан"
        default:
            describe(error)
        }
    }
}
