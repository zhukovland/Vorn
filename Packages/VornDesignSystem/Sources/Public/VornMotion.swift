import SwiftUI

/// Тайминги и кривые движения. «Дыхание» — сердце интерфейса, поэтому
/// его параметры живут в одном месте и переиспользуются.
public enum VornMotion {
    /// Полный цикл спокойного дыхания (вдох+выдох), с. Ритм расслабленного
    /// дыхания человека.
    public static let breathPeriod: Double = 5.5
    /// Период рождения сонар-колец, с.
    public static let sonarPeriod: Double = 3.0
    /// Учащённый неглубокий пульс состояния «подключаюсь», с.
    public static let pendingPeriod: Double = 1.2

    /// Пружина для смены состояний (появление/переключение).
    public static let transition: Animation = .spring(response: 0.5, dampingFraction: 0.82)
    /// Мягкое проявление.
    public static let ease: Animation = .easeInOut(duration: 0.35)
}
