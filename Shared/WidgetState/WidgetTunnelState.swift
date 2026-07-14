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

    // MARK: - Выбранный сервер

    /// Флаг-эмодзи и отображаемое имя выбранного сервера — всё, что виджет
    /// знает о сервере. Ни адреса, ни ключей в общие UserDefaults не
    /// попадает: ключи остаются в Keychain (виджету он недоступен), а имя
    /// проходит через VLESSServer.sharableName — раскрывающее адрес имя
    /// сюда не пишется. Пишет приложение при каждом изменении vault
    /// (см. VaultModel.state).
    nonisolated private static let flagKey = "widget.server.flag"
    nonisolated private static let titleKey = "widget.server.title"

    nonisolated static var serverFlag: String? {
        defaults?.string(forKey: flagKey)
    }

    nonisolated static var serverTitle: String? {
        defaults?.string(forKey: titleKey)
    }

    nonisolated static func set(serverFlag: String?, serverTitle: String?) {
        guard serverFlag != self.serverFlag || serverTitle != self.serverTitle else { return }
        defaults?.set(serverFlag, forKey: flagKey)
        defaults?.set(serverTitle, forKey: titleKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
