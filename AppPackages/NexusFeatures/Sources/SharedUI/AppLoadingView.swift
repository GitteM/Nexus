import Design
import SwiftUI

/// App-level launch/bootstrapping state.
///
/// `AppContainer` shows this while `createDependencies()` runs and
/// while the app is in `.loading`.
public struct AppLoadingView: View {
    public init() {}

    public var body: some View {
        ZStack {
            ColorPalette.background
                .ignoresSafeArea()
            VStack(spacing: Spacing.md) {
                ProgressView()
                    .controlSize(.large)
                Text(Strings.App.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
        }
    }
}

#Preview {
    AppLoadingView()
}
