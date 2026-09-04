#if DEBUG
    import SwiftUI

    /// Preview factories for the composition root: every app-level state
    /// renders the real `ContentView` over a demo container.
    extension AppContainer {
        /// A demo-mode container whose shell is in the given state.
        static func preview(state: AppState) -> AppContainer {
            let container = AppContainer(mode: .demo)
            container.configurePreview(state: state)
            return container
        }

        /// The running demo (`.ready` after `start()`).
        static func previewReady() -> AppContainer {
            AppContainer(mode: .demo)
        }

        /// The initial loading shell.
        static func previewLoading() -> AppContainer {
            preview(state: .loading)
        }

        /// The offline shell.
        static func previewDisconnected() -> AppContainer {
            preview(state: .disconnected)
        }

        /// The error shell with a representative failure.
        static func previewError() -> AppContainer {
            preview(state: .error(.apiConnectionFailed()))
        }
    }

    #Preview("Ready — demo") {
        ContentView()
            .environment(AppContainer.previewReady())
    }

    #Preview("Loading") {
        ContentView()
            .environment(AppContainer.previewLoading())
    }

    #Preview("Disconnected") {
        ContentView()
            .environment(AppContainer.previewDisconnected())
    }

    #Preview("Error") {
        ContentView()
            .environment(AppContainer.previewError())
    }
#endif
