import SwiftUI

/// Демонстрация собранного главного экрана на образцах данных: герой,
/// баннер, секции подписок с сетками карточек. Реальные данные подключит
/// приложение; здесь — сверка композиции и ритма.
private struct HomeScreenDemo: View {
    @State private var phase: ConnectionPhase = .protected

    private let columns = [GridItem(.flexible(), spacing: VornSpacing.m),
                           GridItem(.flexible(), spacing: VornSpacing.m)]

    var body: some View {
        VornBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: VornSpacing.xl) {
                    ConnectHero(
                        model: ConnectHeroModel(phase: phase, latencyMs: 540),
                        onToggle: toggle
                    )
                    .frame(maxWidth: .infinity)

                    AnnounceBanner("Плановые техработы 14 июля с 03:00 до 04:00 МСК. Возможны кратковременные разрывы.")

                    section(
                        title: "Основная подписка",
                        meta: "12 / 50 ГБ · до 30.07",
                        refresh: true
                    ) {
                        ServerCard(name: "🇳🇱 Нидерланды NL-01", quality: .good, pingMs: 540, transport: "Vision", state: .connected, onTap: {})
                        ServerCard(name: "🇩🇪 Германия DE-02", quality: .fair, pingMs: 1120, transport: "XHTTP", state: .selected, onTap: {})
                        ServerCard(name: "🇸🇪 Швеция SE-01", quality: .good, pingMs: 760, transport: "Vision", onTap: {})
                        ServerCard(name: "🇫🇷 Франция Париж Премиум Скорость", quality: .poor, pingMs: 1840, transport: "XHTTP", onTap: {})
                    }

                    section(title: "Ручные ключи", meta: nil, refresh: false) {
                        ServerCard(name: "🇯🇵 Япония Токио", quality: .fair, pingMs: 980, transport: "Vision", onTap: {})
                    }
                }
                .padding(VornSpacing.l)
            }
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        meta: String?,
        refresh: Bool,
        @ViewBuilder cards: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: VornSpacing.m) {
            SubscriptionSectionHeader(
                title: title,
                meta: meta,
                onRefresh: refresh ? {} : nil
            )
            LazyVGrid(columns: columns, spacing: VornSpacing.m) {
                cards()
            }
        }
    }

    private func toggle() {
        phase = phase == .protected ? .idle : .protected
    }
}

#Preview("Главный экран · тёмная") {
    HomeScreenDemo().vornThemed(.dark).frame(width: 390, height: 844)
}

#Preview("Главный экран · светлая") {
    HomeScreenDemo().vornThemed(.light).frame(width: 390, height: 844)
}
