import CoreGraphics

/// Отступы и радиусы. Шкала кратна 4 — ритм остаётся согласованным.
public enum VornSpacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

public enum VornRadius {
    public static let small: CGFloat = 12
    public static let card: CGFloat = 20
    public static let pill: CGFloat = 999
}
