import CoreGraphics
import SwiftUI

/// Фон экрана: базовый цвет темы плюс тонкое плёночное зерно. Зерно —
/// тайловая шумовая текстура, сгенерированная в коде один раз (без Metal,
/// без ресурсов и тулчейнов). Ставится корнем экрана; контент кладётся поверх.
public struct VornBackground<Content: View>: View {
    private let content: Content

    @Environment(\.vornTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        // Фон (цвет + зерно) заполняет весь экран, игнорируя safe area;
        // контент — НЕ игнорирует, иначе он лез бы под навбар/за край.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    theme.colors.base
                    grain
                }
                .ignoresSafeArea()
            }
    }

    private var grain: some View {
        Image(decorative: VornNoise.tile, scale: 1)
            .resizable(resizingMode: .tile)
            // overlay: серое зерно (~128) почти не трогает середину, а
            // выше/ниже даёт лёгкую зернистость — плёночный эффект.
            .blendMode(.overlay)
            .opacity(theme.grain)
            .allowsHitTesting(false)
    }
}

/// Одноразовая генерация шумового тайла. Детерминированный xorshift —
/// зерно стабильно между запусками и не зависит от Date/Random.
enum VornNoise {
    static let tile: CGImage = makeTile(size: 128)

    private static func makeTile(size: Int) -> CGImage {
        var pixels = [UInt8](repeating: 0, count: size * size)
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        for i in pixels.indices {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            pixels[i] = UInt8(state & 0xFF)
        }
        let context = CGContext(
            data: &pixels,
            width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        // Размер и параметры фиксированы — создание не может провалиться;
        // на всякий случай отдаём пустой 1×1, а не падаем.
        return context?.makeImage() ?? fallbackPixel()
    }

    private static func fallbackPixel() -> CGImage {
        var byte: UInt8 = 128
        let context = CGContext(
            data: &byte, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        return context!.makeImage()!
    }
}
