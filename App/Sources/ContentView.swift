import SwiftUI
import VornCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 48))
            Text("Vorn")
                .font(.largeTitle)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
