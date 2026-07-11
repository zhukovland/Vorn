import Foundation
import VornCore

/// Всё состояние приложения: подписки с их серверами и текущий выбор.
/// Целиком лежит в Keychain — серверы содержат UUID ключей.
public struct VaultState: Codable, Equatable, Sendable {
    /// Подписки в порядке добавления.
    public var subscriptions: [Subscription]
    /// Серверы, добавленные голыми vless://-ссылками, в порядке добавления.
    /// Источника-URL у них нет: не обновляются по refresh.
    public var manualServers: [VLESSServer]
    /// Выбранный сервер; nil — выбор не сделан. ServerVault поддерживает
    /// инвариант: selection всегда указывает на существующий сервер в своём
    /// источнике, «висячих» ссылок в сохранённом состоянии не бывает.
    public var selection: ServerSelection?

    public init(
        subscriptions: [Subscription] = [],
        manualServers: [VLESSServer] = [],
        selection: ServerSelection? = nil
    ) {
        self.subscriptions = subscriptions
        self.manualServers = manualServers
        self.selection = selection
    }

    public var selectedServer: VLESSServer? {
        switch selection {
        case nil:
            nil
        case .subscription(let subscriptionID, let serverID):
            subscriptions.first { $0.id == subscriptionID }?
                .servers.first { $0.id == serverID }
        case .manual(let serverID):
            manualServers.first { $0.id == serverID }
        }
    }
}

public enum VaultError: Error {
    /// Попытка выбрать сервер, которого нет в сохранённом состоянии
    /// (например, подписка обновилась в фоне между показом списка и тапом).
    case unknownSelection
    /// Операция над подпиской, которой нет в сохранённом состоянии.
    case unknownSubscription
    /// Данные в Keychain есть, но не декодируются как VaultState.
    /// Несёт исходную ошибку декодера: она содержит только coding path,
    /// не значения полей, поэтому безопасна для диагностики.
    case corruptedState(underlying: any Error)
}

extension VaultError: Equatable {
    // underlying намеренно не участвует в сравнении: это диагностика,
    // а не идентичность ошибки.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.unknownSelection, .unknownSelection),
             (.unknownSubscription, .unknownSubscription),
             (.corruptedState, .corruptedState):
            true
        default:
            false
        }
    }
}

/// Единственная точка чтения и записи состояния подписок.
///
/// Контракт конкурентности: **пишет только приложение**, extension только
/// читает через общую Keychain access group. Мутации — read-modify-write
/// без версионирования: два конкурентных писателя потеряют одно из
/// изменений. Если появится фоновое обновление подписок, добавить
/// версионирование состояния (generation-поле с проверкой при записи).
public struct ServerVault: Sendable {
    private static let stateKey = "vault.state"

    private let store: SecureStore

    /// Продовый vault: Keychain с access group, общей для app и extension.
    public init() {
        self.init(store: KeychainStore(
            service: AppGroup.keychainService,
            accessGroup: AppGroup.keychainAccessGroup
        ))
    }

    init(store: SecureStore) {
        self.store = store
    }

    public func load() throws -> VaultState {
        guard let data = try store.load(forKey: Self.stateKey) else { return VaultState() }
        do {
            return try JSONDecoder().decode(VaultState.self, from: data)
        } catch {
            throw VaultError.corruptedState(underlying: error)
        }
    }

    /// Прямая запись состояния — только для тестов; UI и extension ходят
    /// через семантические операции, которые поддерживают инвариант selection.
    func save(_ state: VaultState) throws {
        try store.save(try JSONEncoder().encode(state), forKey: Self.stateKey)
    }

    public func clear() throws {
        try store.delete(forKey: Self.stateKey)
    }

    /// Импорт или обновление подписки; подписки различаются по URL.
    ///
    /// У существующей подписки заменяются серверы и updatedAt, но не имя:
    /// переименование в приложении переживает обновление. Выбор пользователя
    /// сохраняется, пока выбранный сервер остаётся в подписке — серверы
    /// сопоставляются по id (хэш параметров подключения), поэтому
    /// переименование сервера в панели выбор не сбрасывает, а смена ключа
    /// или адреса — сбрасывает: это уже другой сервер.
    public func merge(_ subscription: Subscription) throws {
        try mutate { state in
            if let index = state.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                var updated = subscription
                updated.name = state.subscriptions[index].name
                state.subscriptions[index] = updated
            } else {
                state.subscriptions.append(subscription)
            }
        }
    }

    /// Удаляет подписку вместе с выбором, если он указывал в неё.
    /// Удалять несуществующую — не ошибка: операция идемпотентна.
    public func remove(subscriptionID: String) throws {
        try mutate { state in
            state.subscriptions.removeAll { $0.id == subscriptionID }
        }
    }

    /// Добавляет сервер из голой vless://-ссылки. Повторное добавление того
    /// же сервера (по id — хэшу параметров подключения) обновляет запись,
    /// а не плодит копии: вставить одну ссылку дважды безопасно.
    public func addManual(_ server: VLESSServer) throws {
        try mutate { state in
            if let index = state.manualServers.firstIndex(where: { $0.id == server.id }) {
                state.manualServers[index] = server
            } else {
                state.manualServers.append(server)
            }
        }
    }

    /// Удаляет ручной сервер вместе с выбором, если он указывал на него.
    /// Удалять несуществующий — не ошибка: операция идемпотентна.
    public func removeManual(serverID: String) throws {
        try mutate { state in
            state.manualServers.removeAll { $0.id == serverID }
        }
    }

    public func rename(subscriptionID: String, to name: String) throws {
        try mutate { state in
            guard let index = state.subscriptions.firstIndex(where: { $0.id == subscriptionID }) else {
                throw VaultError.unknownSubscription
            }
            state.subscriptions[index].name = name
        }
    }

    /// Устанавливает выбор; nil — снять выбор. Ссылка на несуществующий
    /// сервер — ошибка, а не молчаливая запись «висячего» выбора.
    public func select(_ selection: ServerSelection?) throws {
        try mutate { state in
            state.selection = selection
            if selection != nil, state.selectedServer == nil {
                throw VaultError.unknownSelection
            }
        }
    }

    /// Единственный путь записи: загрузить → изменить → снять «висячий»
    /// выбор → сохранить. Ошибка из transform прерывает до записи.
    private func mutate(_ transform: (inout VaultState) throws -> Void) throws {
        var state = try load()
        try transform(&state)
        if state.selectedServer == nil {
            state.selection = nil
        }
        try save(state)
    }
}
