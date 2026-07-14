import SwiftUI

/// Контекстное меню карточки сервера (долгое нажатие). Вынесено отдельно —
/// сюда складываются действия над одиночным сервером; пока это «Измерить
/// пинг», позже добавятся другие (удалить ключ и т.п.).
struct ServerCardContextMenu: ViewModifier {
    let onPing: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        // Меню вешаем только когда есть действие — иначе долгое нажатие
        // открывало бы пустое меню. Новые пункты добавляются сюда же.
        if let onPing {
            content.contextMenu {
                Button(action: onPing) {
                    Label("Измерить пинг", systemImage: "gauge.medium")
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func serverCardContextMenu(onPing: (() -> Void)?) -> some View {
        modifier(ServerCardContextMenu(onPing: onPing))
    }
}
