import Foundation
import Observation
import VornCore
import VornStorage

/// Состояние vault для UI. Операции Keychain синхронные, но короткие —
/// для действий по кнопке этого достаточно; при появлении фонового
/// обновления подписок перейдём на async-обёртку.
@Observable
final class VaultModel {
    private(set) var state = VaultState()
    var lastError: String?

    @ObservationIgnored private let vault = ServerVault()

    var manualServers: [VLESSServer] { state.manualServers }
    var selectedServer: VLESSServer? { state.selectedServer }

    func reload() {
        perform { state = try vault.load() }
    }

    /// Импорт голой vless://-ссылки; добавленный сервер сразу выбирается —
    /// в тестовом UI это всегда то, что пользователь хочет запустить.
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

    func select(_ server: VLESSServer) {
        perform {
            state = try vault.select(.manual(serverID: server.id))
        }
    }

    func remove(_ server: VLESSServer) {
        perform {
            state = try vault.removeManual(serverID: server.id)
        }
    }

    func isSelected(_ server: VLESSServer) -> Bool {
        state.selection == .manual(serverID: server.id)
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
}
