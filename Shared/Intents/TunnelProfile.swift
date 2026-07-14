import Foundation
@preconcurrency import NetworkExtension
import VornStorage

/// Метка «наш» на VPN-профиле. Переустановки приложения оставляют в системе
/// профили-сироты с тем же именем и bundle id; их extension указывает на
/// удалённую копию, и start/stopVPNTunnel по ним молча уходит в пустоту.
/// Отличить живой профиль от сироты по полям NE нельзя — поэтому приложение
/// кладёт UUID в providerConfiguration профиля и его копию в общие
/// UserDefaults App Group. Профиль с совпадающей меткой — действующий;
/// остальные приложение удаляет при запуске (см. TunnelModel.doPrepare).
///
/// Меткой пользуются и приложение, и интент виджета (на macOS он выполняется
/// в процессе виджета и выбирает профиль сам). UUID — не секрет, это ярлык.
enum TunnelProfile {
    nonisolated private static let defaultsKey = "tunnel.profile.id"
    nonisolated private static let configKey = "vornProfileID"

    nonisolated private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    /// Метка действующего профиля; nil — профиль ещё не создавался.
    nonisolated static var currentID: String? {
        defaults?.string(forKey: defaultsKey)
    }

    /// Выпускает новую метку и запоминает её как действующую.
    nonisolated static func registerNewID() -> String {
        let id = UUID().uuidString
        defaults?.set(id, forKey: defaultsKey)
        return id
    }

    /// Проставляет метку в конфигурацию создаваемого профиля.
    nonisolated static func stamp(_ proto: NETunnelProviderProtocol, id: String) {
        var config = proto.providerConfiguration ?? [:]
        config[configKey] = id
        proto.providerConfiguration = config
    }

    nonisolated static func isCurrent(_ manager: NETunnelProviderManager) -> Bool {
        guard let currentID else { return false }
        let proto = manager.protocolConfiguration as? NETunnelProviderProtocol
        return proto?.providerConfiguration?[configKey] as? String == currentID
    }
}
