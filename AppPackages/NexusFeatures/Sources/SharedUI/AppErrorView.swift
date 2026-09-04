import Design
import Entities
import SwiftUI

/// App-level fatal/startup error state.
///
/// Composes the shared `ErrorView` under an app-brand header. `AppContainer`
/// shows this when the container cannot be built or the session enters an
/// unrecoverable `.error` state.
public struct AppErrorView: View {
    private let error: AppError
    private let retry: (() -> Void)?

    public init(error: AppError, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(Strings.App.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(ColorPalette.label)
            ErrorView(error: error, retry: retry)
        }
        .padding(.top, Spacing.section1)
    }
}

#Preview("With retry") {
    AppErrorView(error: .initializationFailed(details: "Demo session failed to start"), retry: {})
}

#Preview("No retry") {
    AppErrorView(error: .systemUnavailable())
}
