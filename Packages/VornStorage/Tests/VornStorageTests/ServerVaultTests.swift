import Foundation
import Testing
import VornCore
@testable import VornStorage

struct ServerVaultTests {
    static func server(name: String = "A", address: String = "1.2.3.4", publicKey: String = "pbk") -> VLESSServer {
        VLESSServer(
            name: name,
            address: address,
            port: 443,
            userID: "b831381d-6324-4d53-ad4f-8cda48b30811",
            flow: "xtls-rprx-vision",
            reality: RealitySettings(publicKey: publicKey, shortID: "sid", serverName: "mask.example", fingerprint: "chrome")
        )
    }

    static func subscription(
        url: String = "https://panel.example/sub/token",
        name: String = "Panel",
        servers: [VLESSServer],
        updatedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> Subscription {
        Subscription(url: URL(string: url)!, name: name, servers: servers, updatedAt: updatedAt)
    }

    static func selection(_ subscription: Subscription, _ server: VLESSServer) -> ServerSelection {
        .subscription(subscriptionID: subscription.id, serverID: server.id)
    }

    @Test func emptyVaultLoadsDefaultState() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        #expect(try vault.load() == VaultState())
    }

    @Test func roundTripsState() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        let subscription = Self.subscription(servers: [server])
        try vault.save(VaultState(subscriptions: [subscription], selection: Self.selection(subscription, server)))

        let loaded = try vault.load()
        #expect(loaded.subscriptions == [subscription])
        #expect(loaded.selectedServer == server)
    }

    @Test func mergeAppendsNewSubscription() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let first = Self.subscription(url: "https://a.example/sub", servers: [Self.server()])
        let second = Self.subscription(url: "https://b.example/sub", servers: [Self.server(address: "5.6.7.8")])

        try vault.merge(first)
        try vault.merge(second)

        #expect(try vault.load().subscriptions == [first, second])
    }

    @Test func mergeUpdatesServersButKeepsUserRename() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let subscription = Self.subscription(name: "Panel", servers: [Self.server()])
        try vault.merge(subscription)
        try vault.rename(subscriptionID: subscription.id, to: "Моя")

        // Повторный импорт того же URL — обновление, а не копия;
        // имя, выбранное пользователем, не затирается именем из импорта.
        let refreshed = Self.subscription(
            name: "Panel",
            servers: [Self.server(address: "5.6.7.8")],
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        try vault.merge(refreshed)

        let loaded = try vault.load()
        #expect(loaded.subscriptions.count == 1)
        #expect(loaded.subscriptions[0].name == "Моя")
        #expect(loaded.subscriptions[0].servers == refreshed.servers)
        #expect(loaded.subscriptions[0].updatedAt == refreshed.updatedAt)
    }

    @Test func mergeKeepsSelectionWhenServerRenamed() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server(name: "Old name")
        let subscription = Self.subscription(servers: [server])
        try vault.merge(subscription)
        try vault.select(Self.selection(subscription, server))

        // Переименование в панели не меняет id сервера — выбор сохраняется.
        let renamed = Self.server(name: "New name")
        try vault.merge(Self.subscription(servers: [renamed]))

        let loaded = try vault.load()
        #expect(loaded.selection == .subscription(subscriptionID: subscription.id, serverID: renamed.id))
        #expect(loaded.selectedServer?.name == "New name")
    }

    @Test func mergeClearsSelectionWhenServerDisappears() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server(publicKey: "old-key")
        let subscription = Self.subscription(servers: [server])
        try vault.merge(subscription)
        try vault.select(Self.selection(subscription, server))

        // Смена ключа — это другой сервер: выбор сбрасывается, а не молча
        // указывает на несуществующую запись.
        try vault.merge(Self.subscription(servers: [Self.server(publicKey: "new-key")]))

        let loaded = try vault.load()
        #expect(loaded.selection == nil)
        #expect(loaded.selectedServer == nil)
    }

    @Test func removeClearsSelectionEvenIfSameServerExistsElsewhere() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        let first = Self.subscription(url: "https://a.example/sub", servers: [server])
        let second = Self.subscription(url: "https://b.example/sub", servers: [server])
        try vault.merge(first)
        try vault.merge(second)
        try vault.select(Self.selection(first, server))

        // Выбор составной: тот же сервер в другой подписке — другой выбор,
        // молча «переезжать» между подписками он не должен.
        try vault.remove(subscriptionID: first.id)

        let loaded = try vault.load()
        #expect(loaded.subscriptions == [second])
        #expect(loaded.selection == nil)
    }

    @Test func removeUnknownSubscriptionIsNoOp() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let subscription = Self.subscription(servers: [Self.server()])
        try vault.merge(subscription)

        try vault.remove(subscriptionID: "no-such-id")

        #expect(try vault.load().subscriptions == [subscription])
    }

    @Test func renameUnknownSubscriptionThrows() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        #expect(throws: VaultError.unknownSubscription) {
            try vault.rename(subscriptionID: "no-such-id", to: "Имя")
        }
    }

    @Test func selectUnknownServerThrows() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let subscription = Self.subscription(servers: [Self.server()])
        try vault.merge(subscription)

        #expect(throws: VaultError.unknownSelection) {
            try vault.select(.subscription(subscriptionID: subscription.id, serverID: "no-such-id"))
        }
        // Неудачный select ничего не записал.
        #expect(try vault.load().selection == nil)
    }

    @Test func selectNilClearsSelection() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        let subscription = Self.subscription(servers: [server])
        try vault.merge(subscription)
        try vault.select(Self.selection(subscription, server))

        try vault.select(nil)

        #expect(try vault.load().selection == nil)
    }

    @Test func addManualRoundTripsAndSelects() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        try vault.addManual(server)
        try vault.select(.manual(serverID: server.id))

        let loaded = try vault.load()
        #expect(loaded.manualServers == [server])
        #expect(loaded.selectedServer == server)
    }

    @Test func addManualTwiceUpdatesInsteadOfDuplicating() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        try vault.addManual(Self.server(name: "Old name"))
        // Та же ссылка (тот же id) с новым именем — обновление, не копия.
        try vault.addManual(Self.server(name: "New name"))

        let loaded = try vault.load()
        #expect(loaded.manualServers.count == 1)
        #expect(loaded.manualServers[0].name == "New name")
    }

    @Test func removeManualClearsSelection() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        try vault.addManual(server)
        try vault.select(.manual(serverID: server.id))

        try vault.removeManual(serverID: server.id)

        let loaded = try vault.load()
        #expect(loaded.manualServers.isEmpty)
        #expect(loaded.selection == nil)
    }

    @Test func manualSelectionSurvivesSubscriptionChanges() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        let server = Self.server()
        try vault.addManual(server)
        // Тот же сервер есть и в подписке — выбор указывает на ручную запись.
        try vault.merge(Self.subscription(servers: [server]))
        try vault.select(.manual(serverID: server.id))

        // Сервер пропал из подписки — ручной выбор это не задевает.
        try vault.merge(Self.subscription(servers: [Self.server(publicKey: "new-key")]))

        let loaded = try vault.load()
        #expect(loaded.selection == .manual(serverID: server.id))
        #expect(loaded.selectedServer == server)
    }

    @Test func selectUnknownManualServerThrows() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        try vault.addManual(Self.server())

        #expect(throws: VaultError.unknownSelection) {
            try vault.select(.manual(serverID: "no-such-id"))
        }
        #expect(try vault.load().selection == nil)
    }

    @Test func clearRemovesState() throws {
        let vault = ServerVault(store: InMemorySecureStore())
        try vault.merge(Self.subscription(servers: [Self.server()]))
        try vault.clear()
        #expect(try vault.load() == VaultState())
    }

    @Test func corruptedDataThrowsWithDecoderDiagnostics() throws {
        let store = InMemorySecureStore()
        try store.save(Data("not json".utf8), forKey: "vault.state")
        do {
            _ = try ServerVault(store: store).load()
            Issue.record("ожидали VaultError.corruptedState")
        } catch VaultError.corruptedState(let underlying) {
            #expect(underlying is DecodingError)
        }
    }
}
