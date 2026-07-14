import AppIntents
// @preconcurrency: API NetworkExtension старше строгой конкурентности — тот
// же приём, что в TunnelModel: снимаем Sendable-диагностику с типов фреймворка.
@preconcurrency import NetworkExtension
import VornStorage

/// Тумблер туннеля для виджета: подключить/отключить выбранный сервер.
///
/// iOS: LiveActivityIntent-конформанс заставляет систему выполнять
/// `perform()` в процессе приложения (при необходимости подняв его в фоне),
/// а не в процессе виджета — NE-энтайтлмент на iOS есть только у app.
///
/// macOS: LiveActivityIntent недоступен, интент выполняется в процессе
/// виджета, у которого есть собственный NE-энтайтлмент (см.
/// Vorn-Widget-macOS.entitlements) — так же устроен виджет Happ.
///
/// Конфиг сервера через NE не передаём: extension читает выбранный сервер
/// из общего Keychain, как и при запуске из приложения.
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
        // Среди найденных могут быть сироты прежних установок — действующий
        // профиль опознаём по метке (см. TunnelProfile); запасной признак —
        // активный статус: он бывает только у живого.
        let live = managers.first(where: TunnelProfile.isCurrent)
        let active = managers.first { candidate in
            switch candidate.connection.status {
            case .connected, .connecting, .reasserting, .disconnecting: true
            default: false
            }
        }
        guard let manager = live ?? active ?? managers.first else {
            return .result()
        }

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
