import CoreGraphics

/// The spacing scale shared by every Nexus screen (architecture.md §9.4,
/// tasks.md Day 9).
///
/// Small values (`xs…xl`) pad content inside a block; the `section` values
/// separate distinct content blocks (carousel → offers → limits, etc.).
/// Components never hardcode padding — they compose these constants so the
/// rhythm of the UI stays consistent app-wide.
public enum Spacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24

    public static let section1: CGFloat = 40
    public static let section2: CGFloat = 64
    public static let section3: CGFloat = 96
}
