import SwiftUI

/// Герой-элемент: дышащий диск состояния. Непрерывное движение — через
/// TimelineView (не дёргаем @State), поведение — от фазы. Сонар-кольца
/// «сигнал уходит наружу», ореол и масштаб «дышат» в ритме спокойного
/// дыхания. reduce-motion замораживает всё в статичном кадре.
public struct BreathingDisc: View {
    private let phase: ConnectionPhase
    private let diameter: CGFloat

    @Environment(\.vornTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// «Печать»: доля обода, обведённая акцентом. Анимируется при смене фазы —
    /// на подключении дуга обегает круг (замок защёлкивается), на отключении
    /// сматывается. Canvas интерполирует её покадрово.
    @State private var seal: Double = 0

    public init(phase: ConnectionPhase, diameter: CGFloat = 240) {
        self.phase = phase
        self.diameter = diameter
    }

    public var body: some View {
        // Layout-размер диска — его видимый диаметр. Канвас с кольцами/ореолом
        // (шире в 1.9×) рисуется overlay-ем поверх и выходит за границы, не
        // растягивая раскладку экрана.
        Color.clear
            .frame(width: diameter, height: diameter)
            .overlay {
                TimelineView(.animation(paused: reduceMotion || !phase.isAnimated)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let breath = breathValue(at: t)
                    Canvas { context, size in
                        draw(in: &context, size: size, breath: breath, time: t)
                    }
                    .frame(width: diameter * 1.9, height: diameter * 1.9)
                }
            }
            .onAppear { seal = sealTarget }
            .onChange(of: phase) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.9)) { seal = sealTarget }
            }
            .accessibilityElement()
            .accessibilityLabel(phase.title)
    }

    /// Обод обведён, когда идёт защита или подключение.
    private var sealTarget: Double {
        phase == .protected || phase == .connecting ? 1 : 0
    }

    // MARK: - Значения

    /// 0…1 в ритме дыхания; для idle/failed — статичная середина.
    private func breathValue(at t: TimeInterval) -> Double {
        guard phase.isAnimated, !reduceMotion else { return 0.5 }
        let period = phase == .connecting ? VornMotion.pendingPeriod : VornMotion.breathPeriod
        return (sin(2 * .pi * t / period) + 1) / 2
    }

    private var tint: Color {
        switch phase {
        case .protected: theme.colors.accent
        case .connecting: theme.colors.accent
        case .failed: theme.colors.danger
        case .idle: theme.colors.inkTertiary
        }
    }

    // MARK: - Отрисовка

    private func draw(in context: inout GraphicsContext, size: CGSize, breath: Double, time t: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = diameter / 2
        let amplitude = phase == .connecting ? 0.018 : 0.04
        let scale = 1 + amplitude * breath
        let discRadius = radius * scale

        drawSonar(in: &context, center: center, radius: radius, time: t)
        drawGlow(in: &context, center: center, radius: discRadius, breath: breath)
        drawDisc(in: &context, center: center, radius: discRadius, breath: breath)
    }

    /// Расходящиеся кольца: несколько внахлёст, сдвинуты по фазе.
    private func drawSonar(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, time t: TimeInterval) {
        guard phase.isAnimated, !reduceMotion else { return }
        let count = 3
        for i in 0..<count {
            let p = (t / VornMotion.sonarPeriod + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
            let ringRadius = radius * (1 + 0.8 * p)
            let opacity = (1 - p) * 0.35
            let rect = CGRect(
                x: center.x - ringRadius, y: center.y - ringRadius,
                width: ringRadius * 2, height: ringRadius * 2
            )
            context.stroke(
                Circle().path(in: rect),
                with: .color(tint.opacity(opacity)),
                lineWidth: 1.5
            )
        }
    }

    /// Мягкий медный ореол, дышит вместе с диском.
    private func drawGlow(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, breath: Double) {
        let glowRadius = radius * 1.55
        let intensity = phase == .idle ? 0.14 : 0.35 + 0.4 * breath
        let rect = CGRect(
            x: center.x - glowRadius, y: center.y - glowRadius,
            width: glowRadius * 2, height: glowRadius * 2
        )
        let gradient = Gradient(colors: [
            theme.colors.glow.opacity(intensity),
            theme.colors.glow.opacity(0),
        ])
        context.fill(
            Circle().path(in: rect),
            with: .radialGradient(
                gradient, center: center,
                startRadius: radius * 0.6, endRadius: glowRadius
            )
        )
    }

    /// Тело диска: приподнятая поверхность с тонким ободом и дышащей тенью.
    /// Тень нужна прежде всего светлой теме: белый диск на тумане иначе без
    /// края, и дыхание не читается — тень «поднимает» и «опускает» его.
    private func drawDisc(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, breath: Double) {
        let rect = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        let body = Gradient(colors: [
            theme.colors.raised,
            theme.colors.raised.opacity(theme.isDark ? 0.7 : 0.94),
        ])
        // Тень дышит: радиус и смещение растут на вдохе. В тёмной — мягкое
        // свечение акцентом, в светлой — тёмный подъём.
        let shadowColor = theme.isDark
            ? theme.colors.glow.opacity(phase.isAnimated ? 0.18 + 0.14 * breath : 0.1)
            : theme.colors.inkPrimary.opacity(phase.isAnimated ? 0.1 + 0.08 * breath : 0.08)
        let shadowRadius = 16 + 12 * breath
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 6))
            layer.fill(
                Circle().path(in: rect),
                with: .radialGradient(body, center: center, startRadius: 0, endRadius: radius)
            )
        }
        // Базовый обод всегда тусклый; поверх него акцентом обегает «печать».
        context.stroke(Circle().path(in: rect.insetBy(dx: 1, dy: 1)), with: .color(theme.colors.hairline), lineWidth: 1.5)

        guard seal > 0.001 else { return }
        var arc = Path()
        arc.addArc(
            center: center, radius: radius - 1,
            startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * seal),
            clockwise: false
        )
        context.stroke(
            arc,
            with: .color(tint.opacity(theme.isDark ? 0.9 : 0.7)),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
    }
}
