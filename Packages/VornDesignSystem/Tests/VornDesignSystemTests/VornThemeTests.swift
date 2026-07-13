import SwiftUI
import Testing
@testable import VornDesignSystem

struct VornThemeTests {
    @Test func themesAreDistinct() {
        // Тёмная и светлая обязаны отличаться фоном — иначе «две темы» фикция.
        #expect(VornTheme.dark.base != VornTheme.light.base)
        #expect(VornTheme.dark.isDark)
        #expect(!VornTheme.light.isDark)
    }

    @Test func everyPhaseHasTitle() {
        for phase in [ConnectionPhase.idle, .connecting, .protected, .failed] {
            #expect(!phase.title.isEmpty)
        }
    }

    @Test func onlyActivePhasesAnimate() {
        #expect(ConnectionPhase.protected.isAnimated)
        #expect(ConnectionPhase.connecting.isAnimated)
        #expect(!ConnectionPhase.idle.isAnimated)
        #expect(!ConnectionPhase.failed.isAnimated)
    }
}

private extension VornTheme {
    var base: Color { colors.base }
}
