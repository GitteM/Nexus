import Design
import SwiftUI

/// Empty-state surface for a screen with no content (architecture.md §9.4,
/// tasks.md Day 9).
///
/// Wraps `ContentUnavailableView` (iOS 17+) so the empty state gets the
/// platform look for free. Screens pass their own copy and an optional
/// primary action — e.g. "no transactions yet" with an "Explore offers"
/// button.
public struct EmptyStateView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("With action") {
    EmptyStateView(
        systemImage: Icons.card,
        title: "No cards yet",
        message: "Add a card to start managing it here.",
        actionTitle: "Browse offers",
        action: {},
    )
}

#Preview("Minimal") {
    EmptyStateView(
        systemImage: "tray",
        title: "Nothing here",
    )
}
