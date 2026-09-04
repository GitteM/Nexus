import Design
import SwiftUI

/// Centered, full-area loading state.
///
/// Screen and app views show this while a model is in `.loading`.
public struct LoadingView: View {
    private let message: String?

    /// - Parameter message: Optional caption under the spinner; `nil` shows
    ///   the spinner alone (accessibility label still reads "Loading").
    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.large)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? Strings.Common.loading)
    }
}

#Preview("Spinner only") {
    LoadingView()
}

#Preview("With message") {
    LoadingView(message: Strings.Common.loading)
}
