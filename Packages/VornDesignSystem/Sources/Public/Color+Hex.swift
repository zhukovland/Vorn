import SwiftUI

extension Color {
    /// Цвет из 0xRRGGBB. Единственный вход для сырых хексов — дальше только
    /// семантические токены темы.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
