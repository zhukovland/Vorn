import SwiftUI
import VornCore
import VornDesignSystem

struct ContentView: View {
    @State private var vault = VaultModel()
    @State private var tunnel = TunnelModel()
    @State private var ping = PingModel()
    // Подписка из диплинка, ждущая подтверждения пользователя.
    @State private var pendingSubscription: URL?
    // Отключение по диплинку тоже требует подтверждения: молчаливое
    // vorn://off с любого сайта — атака на деанонимизацию (страница гасит
    // VPN и видит реальный адрес). Включение безопасно — выполняем молча.
    @State private var confirmingDisconnect = false

    var body: some View {
        HomeView(vault: vault, tunnel: tunnel, ping: ping)
            // Тему потом вынесем в настройки (system/dark/light); пока по системе.
            .vornThemed(.system)
            .onOpenURL { url in
                switch DeepLink.parse(url) {
                case .addSubscription(let subscription):
                    pendingSubscription = subscription
                case .connect:
                    connectFromDeepLink()
                case .disconnect:
                    if tunnel.isActive { confirmingDisconnect = true }
                case .toggle:
                    if tunnel.isActive {
                        confirmingDisconnect = true
                    } else {
                        connectFromDeepLink()
                    }
                case nil:
                    break
                }
            }
            .alert("Отключить VPN?", isPresented: $confirmingDisconnect) {
                Button("Отключить", role: .destructive) { tunnel.disconnect() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Запрос на отключение пришёл по внешней ссылке.")
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

    /// Ошибка «сервер не выбран» дойдёт из extension через lastError —
    /// отдельного алерта здесь не нужно.
    private func connectFromDeepLink() {
        guard !tunnel.isActive else { return }
        Task { await tunnel.connect() }
    }
}

#Preview {
    ContentView()
}
