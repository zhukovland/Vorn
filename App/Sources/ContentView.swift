import SwiftUI
import VornCore

struct ContentView: View {
    @State private var vaultModel = VaultModel()
    @State private var tunnel = TunnelModel()
    @State private var linkInput = ""
    @State private var subscriptionInput = ""
    @State private var importing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            connectionSection
            addSection
            announceBanner
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
        VStack(spacing: 8) {
            HStack {
                TextField("Ссылка подписки https://…", text: $subscriptionInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit(importSubscription)
                Button("Импорт", action: importSubscription)
                    .disabled(importing || subscriptionInput.trimmed.isEmpty)
            }
            HStack {
                TextField("Или vless://-ключ", text: $linkInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit(addLink)
                Button("Добавить", action: addLink)
                    .disabled(linkInput.trimmed.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var announceBanner: some View {
        if let announce = vaultModel.announce {
            Text(announce)
                .font(.callout)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
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
        List(vaultModel.entries) { entry in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.server.name)
                    Text(subtitle(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if vaultModel.isSelected(entry.selection) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { vaultModel.select(entry.selection) }
            .contextMenu { removeButton(for: entry) }
        }
        .listStyle(.inset)
        .overlay {
            if vaultModel.entries.isEmpty {
                ContentUnavailableView(
                    "Нет серверов",
                    systemImage: "network.badge.shield.half.filled",
                    description: Text("Импортируйте подписку или вставьте vless://-ключ")
                )
            }
        }
    }

    private func subtitle(for entry: ServerEntry) -> String {
        let endpoint = "\(entry.server.address):\(String(entry.server.port))"
        if let name = entry.subscriptionName {
            return "\(name) · \(endpoint)"
        }
        return "ключ · \(endpoint)"
    }

    @ViewBuilder
    private func removeButton(for entry: ServerEntry) -> some View {
        switch entry.selection {
        case .manual(let serverID):
            Button("Удалить ключ", role: .destructive) {
                vaultModel.removeManual(serverID: serverID)
            }
        case .subscription(let subscriptionID, _):
            Button("Удалить подписку", role: .destructive) {
                vaultModel.removeSubscription(id: subscriptionID)
            }
        }
    }

    private func importSubscription() {
        let url = subscriptionInput.trimmed
        guard !url.isEmpty else { return }
        importing = true
        Task {
            await vaultModel.importSubscription(urlString: url)
            importing = false
            if vaultModel.lastError == nil { subscriptionInput = "" }
        }
    }

    private func addLink() {
        let link = linkInput.trimmed
        guard !link.isEmpty else { return }
        vaultModel.addServer(link: link)
        if vaultModel.lastError == nil { linkInput = "" }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    ContentView()
}
