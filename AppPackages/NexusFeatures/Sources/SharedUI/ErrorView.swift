import Entities
import SwiftUI

/// Full-area error state for one screen (architecture.md §9.4, tasks.md
/// Day 9).
///
/// Renders an `AppError` through its user-facing surfaces —
/// `errorDescription` as the headline, `recoverySuggestion` as the
/// guidance — and offers an optional retry action. Screen views switch their
/// `.error` view state to this component (§9.3).
public struct ErrorView: View {
    private let error: AppError
    private let retry: (() -> Void)?

    public init(error: AppError, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: Icons.warning)
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ColorPalette.warning)
                .accessibilityHidden(true)
            Text(error.errorDescription ?? Strings.App.errorTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.subheadline)
                    .foregroundStyle(ColorPalette.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
            if let retry {
                Button(action: retry) {
                    Label(Strings.Common.retry, systemImage: Icons.retry)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Recoverable") {
    ErrorView(error: .apiConnectionFailed(), retry: {})
}

#Preview("No retry") {
    ErrorView(error: .cardActionFailed(action: "freeze", details: "timed out"))
}
