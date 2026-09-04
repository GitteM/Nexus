import Design
import Entities
import SwiftUI

/// Compact badge showing the current session state.
///
/// Renders `SessionStatus.displayName` / `.icon` (domain-owned copy)
/// tinted by status: connected → green, connecting → amber, error → red,
/// disconnected → neutral. `AppContainer` places it when the session status
/// changes.
public struct SessionStatusIndicator: View {
    private let status: SessionStatus

    public init(status: SessionStatus) {
        self.status = status
    }

    public var body: some View {
        Label {
            Text(status.displayName)
        } icon: {
            Image(systemName: status.icon)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Capsule().fill(ColorPalette.secondaryBackground))
    }

    private var tint: Color {
        switch status {
        case .connecting: ColorPalette.warning
        case .connected: ColorPalette.success
        case .disconnected: ColorPalette.secondaryLabel
        case .error: ColorPalette.destructive
        }
    }
}

#Preview("All statuses") {
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ForEach(SessionStatus.allCases, id: \.rawValue) { status in
            SessionStatusIndicator(status: status)
        }
    }
    .padding(Spacing.lg)
}
