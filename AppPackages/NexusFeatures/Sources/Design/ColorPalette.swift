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

    // MARK: Card art (physical card front; fixed values, not

    // appearance-aware — a card is the same object in dark and light)

    /// The card-front look per `CardType`. The artwork is a product-design
    /// decision, so it ships in the token layer (`ColorPalette`); the
    /// per-type composition lives in `CardArtwork` (SharedUI) where the
    /// domain `CardType` is visible.
    public enum CardArt {
        public static let creditStart = Color(hex: 0x14318F)
        public static let creditEnd = Color(hex: 0x3D7BFF)

        public static let debitStart = Color(hex: 0x0E5A3A)
        public static let debitEnd = Color(hex: 0x23A06B)

        public static let prepaidStart = Color(hex: 0x4C1D95)
        public static let prepaidEnd = Color(hex: 0x8B5CF6)

        /// Fixed white for content drawn on the art; tuned to hold
        /// contrast on every gradient in both appearances.
        public static let onArt = Color(hex: 0xFFFFFF)
    }
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
