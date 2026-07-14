import SwiftUI
import VornCore
import VornDesignSystem
import VornStorage

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Главный экран: герой подключения + сетка серверов, сгруппированных по
/// подпискам. Связывает дизайн-систему (VornDesignSystem) с данными vault
/// (VaultModel) и туннелем (TunnelModel).
struct HomeView: View {
    @Bindable var vault: VaultModel
    var tunnel: TunnelModel
    var ping: PingModel

    @State private var refreshingID: String?
    @State private var importing = false
    @State private var subscriptionToDelete: Subscription?
    @State private var showNoServerAlert = false
    @State private var addError: String?

    private let columns = [
        GridItem(.flexible(), spacing: VornSpacing.m),
        GridItem(.flexible(), spacing: VornSpacing.m),
    ]

    var body: some View {
        NavigationStack {
            VornBackground {
                ScrollView {
                    VStack(alignment: .leading, spacing: VornSpacing.xxl) {
                        hero
                        if let error = vault.lastError ?? tunnel.lastError {
                            errorText(error)
                        }
                        ForEach(vault.state.subscriptions) { subscription in
                            subscriptionSection(subscription)
                        }
                        if !vault.state.manualServers.isEmpty {
                            manualSection
                        }
                        if vault.entries.isEmpty {
                            emptyState
                        }
                    }
                    .padding(VornSpacing.l)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: addFromClipboard) {
                            Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .menuIndicator(.hidden)
                    .disabled(importing)
                }
            }
            .hiddenNavBarBackground()
        }
        .alert(
            "Удалить подписку?",
            isPresented: Binding(
                get: { subscriptionToDelete != nil },
                set: { if !$0 { subscriptionToDelete = nil } }
            ),
            presenting: subscriptionToDelete
        ) { subscription in
            Button("Удалить", role: .destructive) {
                vault.removeSubscription(id: subscription.id)
            }
            Button("Отмена", role: .cancel) {}
        } message: { subscription in
            Text("Все серверы подписки «\(subscription.name)» будут удалены.")
        }
        .alert("Выберите сервер", isPresented: $showNoServerAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Чтобы подключиться, выберите сервер из списка.")
        }
        .alert(
            "Не удалось добавить",
            isPresented: Binding(
                get: { addError != nil },
                set: { if !$0 { addError = nil } }
            ),
            presenting: addError
        ) { _ in
            Button("Понятно", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .task {
            await tunnel.prepare()
            vault.reload()
            measurePings()
        }
    }

    private var allServers: [VLESSServer] {
        vault.state.subscriptions.flatMap(\.servers) + vault.state.manualServers
    }

    /// Авто-замер: только при отключённом туннеле, чтобы не затирать хорошие
    /// значения мусорными. При поднятом VPN TCP-connect завершается локальным
    /// proxy-стеком мгновенно (~3 мс) и ничего не значит. Ручной замер (меню,
    /// долгое нажатие) работает всегда — это осознанное действие пользователя.
    private func measurePings() {
        guard !tunnel.isActive else { return }
        ping.measure(allServers)
    }

    // MARK: - Герой

    private var hero: some View {
        // Пинг на герое не показываем: при подключении честно померить его
        // нельзя (замер идёт через туннель), а «до подключения» вводит в
        // заблуждение. Качество сервера видно по полоскам в списке.
        ConnectHero(
            model: ConnectHeroModel(phase: tunnel.phase),
            busy: tunnel.status == .connecting || tunnel.status == .disconnecting,
            onToggle: toggle
        )
        .frame(maxWidth: .infinity)
    }

    private func toggle() {
        if tunnel.isActive {
            tunnel.disconnect()
        } else if vault.selectedServer != nil {
            Task { await tunnel.connect() }
        } else {
            showNoServerAlert = true
        }
    }

    // MARK: - Секции

    private func subscriptionSection(_ subscription: Subscription) -> some View {
        VStack(alignment: .leading, spacing: VornSpacing.m) {
            SubscriptionSectionHeader(
                title: subscription.name,
                meta: "\(subscription.servers.count) серв.",
                refreshing: refreshingID == subscription.id,
                onRefresh: { refresh(subscription) },
                onPing: { ping.measure(subscription.servers) },
                onDelete: { subscriptionToDelete = subscription }
            )
            if let announce = subscription.announce,
               !announce.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AnnounceBanner(announce)
            }
            grid(subscription.servers) { server in
                .subscription(subscriptionID: subscription.id, serverID: server.id)
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: VornSpacing.m) {
            SubscriptionSectionHeader(title: "Ручные ключи")
            grid(vault.state.manualServers) { server in
                .manual(serverID: server.id)
            }
        }
    }

    private func grid(
        _ servers: [VLESSServer],
        selection: @escaping (VLESSServer) -> ServerSelection
    ) -> some View {
        LazyVGrid(columns: columns, spacing: VornSpacing.m) {
            ForEach(servers) { server in
                let sel = selection(server)
                let ms = ping.pings[server.id]
                ServerCard(
                    name: server.name,
                    quality: SignalQuality(pingMs: ms),
                    measuring: ping.measuring.contains(server.id),
                    transport: transportLabel(server),
                    state: cardState(sel),
                    onPing: { ping.measure([server]) },
                    onTap: { selectServer(sel) }
                )
            }
        }
    }

    /// Выбор сервера. Если туннель активен и выбрали другой сервер —
    /// переподключаемся на него, а не просто переносим подсветку.
    private func selectServer(_ selection: ServerSelection) {
        let switching = tunnel.isActive && !vault.isSelected(selection)
        vault.select(selection)
        if switching, vault.selectedServer != nil {
            Task { await tunnel.reconnect() }
        }
    }

    private func cardState(_ selection: ServerSelection) -> ServerCardState {
        guard vault.isSelected(selection) else { return .normal }
        return tunnel.status == .connected ? .connected : .selected
    }

    private func transportLabel(_ server: VLESSServer) -> String {
        if server.network == "xhttp" { return "XHTTP" }
        if server.flow?.contains("vision") == true { return "Vision" }
        return "TCP"
    }

    @ViewBuilder
    private func errorText(_ error: String) -> some View {
        Text(error)
            .font(.callout)
            .foregroundStyle(.red)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Нет серверов",
            systemImage: "network.badge.shield.half.filled",
            description: Text("Нажмите + и вставьте ссылку подписки или vless://-ключ")
        )
        .padding(.top, VornSpacing.xxl)
    }

    // MARK: - Действия

    /// Добавление из буфера: vless:// — ручной ключ, иначе — подписка по URL.
    /// Любая ошибка добавления показывается алертом, не inline-текстом.
    private func addFromClipboard() {
        let clip = (Self.clipboardString() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clip.isEmpty else {
            addError = "Буфер обмена пуст"
            return
        }
        if clip.lowercased().hasPrefix("vless://") {
            vault.addServer(link: clip)
            surfaceAddError()
            measurePings()
        } else {
            importing = true
            Task {
                await vault.importSubscription(urlString: clip)
                importing = false
                surfaceAddError()
                measurePings()
            }
        }
    }

    /// Переносит ошибку из vault в алерт добавления, чтобы она не висела
    /// красным текстом на главном экране.
    private func surfaceAddError() {
        if let error = vault.lastError {
            addError = error
            vault.lastError = nil
        }
    }

    private func refresh(_ subscription: Subscription) {
        refreshingID = subscription.id
        Task {
            await vault.importSubscription(urlString: subscription.url.absoluteString)
            refreshingID = nil
            measurePings()
        }
    }

    private static func clipboardString() -> String? {
        #if canImport(UIKit)
        return UIPasteboard.general.string
        #elseif canImport(AppKit)
        return NSPasteboard.general.string(forType: .string)
        #else
        return nil
        #endif
    }
}

private extension View {
    /// Прозрачный фон навбара, чтобы грейн-фон просвечивал (iOS-only API).
    @ViewBuilder
    func hiddenNavBarBackground() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
