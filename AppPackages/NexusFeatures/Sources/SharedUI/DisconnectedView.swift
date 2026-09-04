import Design
import SwiftUI

/// Full-area "session dropped" state.
///
/// Shown when the live session disconnects — e.g. `AppContainer` swaps the
/// content for this view on `.disconnected` instead of letting screens
/// silently serve stale state. Offers an optional reconnect action.
public struct DisconnectedView: View {
    private let reconnect: (() -> Void)?

    public init(reconnect: (() -> Void)? = nil) {
        self.reconnect = reconnect
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: Icons.offline)
                .font(.system(size: 52))
                .foregroundStyle(ColorPalette.secondaryLabel)
                .accessibilityHidden(true)
            Text(Strings.Connection.title)
                .font(.headline)
            Text(Strings.Connection.message)
                .font(.subheadline)
                .foregroundStyle(ColorPalette.secondaryLabel)
                .multilineTextAlignment(.center)
            if let reconnect {
                Button(Strings.Connection.reconnect, action: reconnect)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("With reconnect") {
    DisconnectedView(reconnect: {})
}

#Preview("Passive") {
    DisconnectedView()
}
