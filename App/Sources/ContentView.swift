import SwiftUI
import VornCore
import VornDesignSystem

struct ContentView: View {
    @State private var vault = VaultModel()
    @State private var tunnel = TunnelModel()
    @State private var ping = PingModel()
    // Подписка из диплинка, ждущая подтверждения пользователя.
    @State private var pendingSubscription: URL?

    var body: some View {
        HomeView(vault: vault, tunnel: tunnel, ping: ping)
            // Тему потом вынесем в настройки (system/dark/light); пока по системе.
            .vornThemed(.system)
            .onOpenURL { url in
                pendingSubscription = SubscriptionDeepLink.parse(url)
            }
            // Импорт только с подтверждением: диплинк может прислать любой
            // сайт, а молчаливая подмена серверов — перехват трафика.
            .alert(
                "Добавить подписку?",
                isPresented: Binding(
                    get: { pendingSubscription != nil },
                    set: { if !$0 { pendingSubscription = nil } }
                ),
                presenting: pendingSubscription
            ) { url in
                Button("Добавить") {
                    Task { await vault.importSubscription(urlString: url.absoluteString) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { url in
                Text("Источник: \(url.host() ?? url.absoluteString)")
            }
    }
}

#Preview {
    ContentView()
}
