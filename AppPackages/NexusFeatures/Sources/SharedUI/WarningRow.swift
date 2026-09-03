import Design
import SwiftUI

/// Attention row for non-blocking warnings (architecture.md §9.4, tasks.md
/// Day 9) — e.g. a card approaching its spending limit.
///
/// The icon and amber tint are fixed; screens pass the copy.
public struct WarningRow: View {
    private let title: String
    private let message: String?

    public init(title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: Icons.warning)
                .foregroundStyle(ColorPalette.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ColorPalette.label)
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(ColorPalette.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        WarningRow(
            title: "Spending limit reached",
            message: "Your daily limit is 90% used. It resets at midnight.",
        )
        WarningRow(title: "Card expiring soon")
    }
    .padding(Spacing.lg)
}
