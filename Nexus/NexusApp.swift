import SwiftUI

@main
struct NexusApp: App {
    /// One container for the app's whole life (architecture.md §11.1).
    @State private var appContainer = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appContainer)
        }
    }
}
