import SwiftUI
import VornCore

struct ContentView: View {
    @State private var vaultModel = VaultModel()
    @State private var tunnel = TunnelModel()
    @State private var linkInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionSection
            addSection
            errorSection
            serverList
        }
        .padding()
        #if os(macOS)
        // Минимальный размер окна — только для macOS; на узких iPhone
        // это резало бы края.
        .frame(minWidth: 440, minHeight: 480)
        #endif
        .onAppear { vaultModel.reload() }
        .task { await tunnel.prepare() }
    }

    private var connectionSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(tunnel.statusText)
            Spacer()
            if tunnel.isActive {
                Button("Отключить") { tunnel.disconnect() }
            } else {
                Button("Подключить") {
                    Task { await tunnel.connect() }
                }
                .disabled(vaultModel.selectedServer == nil)
            }
        }
    }

    private var statusColor: Color {
        switch tunnel.status {
        case .connected: .green
        case .connecting, .reasserting, .disconnecting: .yellow
        default: .secondary.opacity(0.4)
        }
    }

    private var addSection: some View {
        HStack {
            TextField("vless://…", text: $linkInput)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .onSubmit(addLink)
            Button("Добавить", action: addLink)
                .disabled(linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = vaultModel.lastError ?? tunnel.lastError {
            Text(error)
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    private var serverList: some View {
        List(vaultModel.manualServers) { server in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                    Text("\(server.address):\(String(server.port))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if vaultModel.isSelected(server) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { vaultModel.select(server) }
            .contextMenu {
                Button("Удалить", role: .destructive) { vaultModel.remove(server) }
            }
        }
        .listStyle(.inset)
        .overlay {
            if vaultModel.manualServers.isEmpty {
                ContentUnavailableView(
                    "Нет серверов",
                    systemImage: "network.badge.shield.half.filled",
                    description: Text("Вставьте vless://-ссылку, чтобы добавить сервер")
                )
            }
        }
    }

    private func addLink() {
        let link = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        vaultModel.addServer(link: link)
        if vaultModel.lastError == nil { linkInput = "" }
    }
}

#Preview {
    ContentView()
}
