import SwiftUI

/// Semantic color namespace for Nexus UI (architecture.md §9.4, tasks.md
/// Day 9).
///
/// System-backed members (`background`, `label`, …) resolve dynamically for
/// dark/light appearance. The brand and semantic accents are fixed values
/// tuned to read on both appearances. Views and components never hardcode a
/// color literal — they reference the palette so brand changes land in one
/// place.
public enum ColorPalette {
    // MARK: Brand

    public static let brand = Color(hex: 0x1B4DE4)
    public static let brandTint = Color(hex: 0xE8EDFB)

    // MARK: Neutral (system, appearance-aware)

    public static let background = Color(.systemBackground)
    public static let secondaryBackground = Color(.secondarySystemBackground)
    public static let label = Color(.label)
    public static let secondaryLabel = Color(.secondaryLabel)
    public static let separator = Color(.separator)

    // MARK: Semantic accents

    public static let success = Color(hex: 0x1F8A4C)
    public static let warning = Color(hex: 0xB26A00)
    public static let destructive = Color(hex: 0xD64541)
}

/// Private design-token helper: builds a `Color` from a `0xRRGGBB` value.
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}
