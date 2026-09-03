import Design
import SwiftUI

/// Informational row for hints and neutral context (architecture.md §9.4,
/// tasks.md Day 9) — e.g. "replacement cards keep their number".
///
/// The icon and tint are fixed; screens pass the copy.
public struct InfoRow: View {
    private let title: String
    private let message: String?

    public init(title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: Icons.info)
                .foregroundStyle(ColorPalette.brand)
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
        InfoRow(
            title: "Replacement cards",
            message: "A replacement keeps your card number and PIN.",
        )
        InfoRow(title: "Statements arrive by email")
    }
    .padding(Spacing.lg)
}
