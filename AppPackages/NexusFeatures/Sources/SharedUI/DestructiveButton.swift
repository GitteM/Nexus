import SwiftUI

/// Full-width destructive action button (architecture.md §9.4, tasks.md
/// Day 9) — e.g. "Report lost or stolen".
///
/// Uses the destructive button role so system behaviors (confirmation
/// dialogs, accessibility) treat it correctly, tinted with the palette's
/// destructive color.
public struct DestructiveButton: View {
    private let title: String
    private let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorPalette.destructive)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        DestructiveButton(title: "Report lost or stolen", action: {})
        DestructiveButton(title: "Delete card", action: {})
            .disabled(true)
    }
    .padding(Spacing.lg)
}
