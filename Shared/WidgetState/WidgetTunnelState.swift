import Foundation
import VornStorage
import WidgetKit

/// Фаза туннеля в общих UserDefaults App Group — единственный канал
/// статуса, который виджет может прочитать синхронно из своего таймлайна
/// (loadAllFromPreferences в процессе виджета недоступен без NE-энтайтлмента).
/// Пишут все, кто узнаёт о смене статуса первым: приложение (наблюдатель
/// NEVPNStatusDidChange), интент виджета (переходная фаза сразу после
/// команды, финальная — по фактическому исходу) и PacketTunnel-extension —
/// источник истины, он жив ровно тогда, когда туннель поднят. Читает
/// провайдер таймлайна виджета.
///
/// nonisolated: доступ к UserDefaults потокобезопасен, а вызывающие живут
/// в разных изоляциях (MainActor в app/виджете, nonisolated в extension).
enum WidgetTunnelState {
    /// Упрощённые фазы NEVPNStatus — ровно столько, сколько виджет может
    /// показать: reasserting сведён к connecting, invalid — к disconnected.
    nonisolated enum Phase: String {
        case disconnected, connecting, disconnecting, connected

        var isTransitioning: Bool { self == .connecting || self == .disconnecting }
    }

    nonisolated private static let key = "widget.tunnel.phase"

    nonisolated private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    nonisolated static var phase: Phase {
        defaults?.string(forKey: key).flatMap(Phase.init) ?? .disconnected
    }

    /// Записывает фазу и сразу просит виджет перерисоваться: порознь
    /// эти шаги не нужны ни одному из процессов-писателей.
    ///
    /// Повторная запись той же фазы глотается: одну смену статуса видят
    /// сразу несколько писателей (интент, приложение, extension), и без
    /// дедупликации каждый дёргал бы перерисовку — виджет заметно мигает.
    nonisolated static func set(_ phase: Phase) {
        guard phase != self.phase else { return }
        defaults?.set(phase.rawValue, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Флаг выбранного сервера

    /// Флаг-эмодзи выбранного сервера — единственное, что виджет знает о
    /// сервере. Ни имени, ни адреса, ни ключей в общие UserDefaults не
    /// попадает (они остаются в Keychain, куда виджету доступа нет).
    /// Пишет приложение при каждом изменении vault (см. VaultModel.state).
    nonisolated private static let flagKey = "widget.server.flag"

    nonisolated static var serverFlag: String? {
        defaults?.string(forKey: flagKey)
    }

    nonisolated static func set(serverFlag: String?) {
        guard serverFlag != self.serverFlag else { return }
        defaults?.set(serverFlag, forKey: flagKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
