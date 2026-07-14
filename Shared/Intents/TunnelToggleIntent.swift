import AppIntents
// @preconcurrency: API NetworkExtension старше строгой конкурентности — тот
// же приём, что в TunnelModel: снимаем Sendable-диагностику с типов фреймворка.
@preconcurrency import NetworkExtension
import VornStorage

/// Тумблер туннеля для виджета: подключить/отключить выбранный сервер.
///
/// LiveActivityIntent-конформанс заставляет систему выполнять `perform()`
/// в процессе приложения (при необходимости подняв его в фоне), а не в
/// процессе виджета. Это принципиально: NE-энтайтлмент есть только у
/// app-таргета — виджет туннелем управлять не вправе (и не должен, см.
/// правило изоляции ядра в CLAUDE.md).
///
/// Конфиг сервера через NE не передаём: extension читает выбранный сервер
/// из общего Keychain, как и при запуске из приложения.
///
/// LiveActivityIntent недоступен на macOS (там нет Live Activities), поэтому
/// база подставляется платформенно. Спайк проверяем на iOS; macOS-путь пока
/// только компилируется — форс app-процесса там решается отдельно.
#if os(iOS)
private typealias TunnelIntentBase = LiveActivityIntent
#else
private typealias TunnelIntentBase = AppIntent
#endif

struct TunnelToggleIntent: TunnelIntentBase {
    static let title: LocalizedStringResource = "Переключить Vorn"
    static let description = IntentDescription("Подключить или отключить выбранный сервер.")

    func perform() async throws -> some IntentResult {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        // Профиля ещё нет — приложение не настраивали. Виджету тут делать
        // нечего: разрешение на VPN и выбор сервера возможны только в app.
        guard let manager = managers.first else { return .result() }

        let connection = manager.connection
        switch connection.status {
        case .connected, .connecting, .reasserting:
            connection.stopVPNTunnel()
            // Переходная фаза сразу: виджет показывает «Отключение…»,
            // не дожидаясь исхода — это и есть отклик на нажатие.
            WidgetTunnelState.set(.disconnecting)
        default:
            if !manager.isEnabled {
                manager.isEnabled = true
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            try connection.startVPNTunnel()
            WidgetTunnelState.set(.connecting)
        }

        // Возвращаемся сразу, не дожидаясь исхода: WidgetKit откладывает
        // перерисовку виджета до завершения интента, поэтому любое ожидание
        // здесь прятало бы переходную фазу (оранжевый не показывался бы при
        // запуске из виджета). Финальную фазу пишет PacketTunnel-extension:
        // .connected при фактическом подъёме ядра, .disconnected при
        // остановке и при ошибке старта.
        return .result()
    }
}
