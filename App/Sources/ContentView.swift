import SwiftUI
import VornDesignSystem

struct ContentView: View {
    @State private var vault = VaultModel()
    @State private var tunnel = TunnelModel()

    var body: some View {
        HomeView(vault: vault, tunnel: tunnel)
            // Тему потом вынесем в настройки (system/dark/light); пока по системе.
            .vornThemed(.system)
    }
}

#Preview {
    ContentView()
}
