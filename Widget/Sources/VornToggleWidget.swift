import AppIntents
import SwiftUI
import WidgetKit

/// Спайк-виджет: одна кнопка, поднимающая/гасящая выбранный сервер через
/// TunnelToggleIntent. Дизайн черновой — цель проверить, что тумблер реально
/// управляет туннелем из виджета.
struct VornToggleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "VornToggle", provider: Provider()) { entry in
            VornWidgetView(entry: entry)
        }
        .configurationDisplayName("Vorn")
        .description("Подключение к выбранному серверу одной кнопкой.")
        .supportedFamilies([.systemSmall])
    }
}

private struct Entry: TimelineEntry {
    let date: Date
    let phase: WidgetTunnelState.Phase
    let flag: String?
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), phase: .disconnected, flag: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), phase: WidgetTunnelState.phase, flag: WidgetTunnelState.serverFlag))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Перерисовку инициирует reloadAllTimelines() из интента, поэтому
        // сам таймлайн статичен — .never, без пустой траты бюджета обновлений.
        let entry = Entry(date: Date(), phase: WidgetTunnelState.phase, flag: WidgetTunnelState.serverFlag)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private struct VornWidgetView: View {
    let entry: Entry

    var body: some View {
        VStack(spacing: 10) {
            Button(intent: TunnelToggleIntent()) {
                Image(systemName: "power")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(entry.phase == .disconnected ? Color.secondary : .white)
                    .frame(width: 64, height: 64)
                    .background(fill, in: Circle())
            }
            .buttonStyle(.plain)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Системная отбивка нажатия: WidgetKit «мерцает» помеченным
                // контентом с момента тапа до перерисовки таймлайна. Темп
                // эффекта системный и не настраивается, поэтому смягчаем
                // иначе — метим только подпись, кнопку не трогаем.
                .invalidatableContent()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if let flag = entry.flag {
                Text(flag).font(.system(size: 16))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var fill: Color {
        switch entry.phase {
        case .connected: .green
        case .connecting, .disconnecting: .orange
        case .disconnected: Color.gray.opacity(0.25)
        }
    }

    private var caption: String {
        switch entry.phase {
        case .connected: "Подключено"
        case .connecting: "Подключение…"
        case .disconnecting: "Отключение…"
        case .disconnected: "Отключено"
        }
    }
}
