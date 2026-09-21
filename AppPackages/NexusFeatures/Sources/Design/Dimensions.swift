import CoreGraphics

/// Fixed component geometry that is not spacing.
///
/// `Spacing` owns the gaps *between* things; `Dimensions` owns the sizes *of*
/// things — an offer card's width, the page-indicator dots. Naming them here
/// keeps each size in one place instead of a literal at the call site.
public enum Dimensions {
    /// Width of one offer card in the dashboard's horizontal row.
    public static let offerCardWidth: CGFloat = 248

    /// Page-indicator dot: the inactive diameter and the active capsule width.
    public static let pageDotDiameter: CGFloat = 7
    public static let pageDotActiveWidth: CGFloat = 20
}
