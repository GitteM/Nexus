import Design
import Entities
import SwiftUI

/// The card-front artwork: a per-`CardType` gradient with a fixed on-art
/// foreground (architecture.md §9.4, tasks.md Day 11).
///
/// The card front is a *physical object*: its art and text colors are fixed
/// values tuned to hold contrast in both appearances (dark/light support
/// comes from the surrounding chrome using appearance-aware palette
/// members, not from changing the card). Color literals stay in the token
/// layer (`ColorPalette.CardArt`); this type is the one composition point
/// that knows how a `CardType` looks, so the dashboard carousel and any
/// later card screen (Card Detail, Day 12) render the same art without
/// duplicating the switch.
public enum CardArtwork {
    /// The art background for one card type.
    public static func gradient(for type: CardType) -> LinearGradient {
        let start: Color
        let end: Color
        switch type {
        case .credit:
            start = ColorPalette.CardArt.creditStart
            end = ColorPalette.CardArt.creditEnd
        case .debit:
            start = ColorPalette.CardArt.debitStart
            end = ColorPalette.CardArt.debitEnd
        case .prepaid:
            start = ColorPalette.CardArt.prepaidStart
            end = ColorPalette.CardArt.prepaidEnd
        }
        return LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    /// Text and symbols drawn on the art; fixed white for every type.
    public static let foreground = ColorPalette.CardArt.onArt
}

#if DEBUG
    #Preview("Artwork variants") {
        HStack(spacing: Spacing.md) {
            ForEach(CardType.allCases, id: \.self) { type in
                RoundedRectangle(cornerRadius: 12)
                    .fill(CardArtwork.gradient(for: type))
                    .frame(width: 120, height: 76)
                    .overlay {
                        Text(type.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CardArtwork.foreground)
                    }
            }
        }
        .padding(Spacing.lg)
    }
#endif
