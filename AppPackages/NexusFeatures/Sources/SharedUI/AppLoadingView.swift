import SwiftUI

/// App-level launch/bootstrapping state (architecture.md §9.4, tasks.md
/// Day 9).
///
/// `AppContainer` shows this while `createDependencies()` runs (§11.2) and
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
