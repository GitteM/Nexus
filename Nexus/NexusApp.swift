import SwiftUI

@main
struct NexusApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
                // Debug root: `-demoMode` / `API_ENVIRONMENT = demo` show
                // the dashboard over the shared mocks (tasks.md Day 11).
                // Replaced by the AppContainer composition root on Day 14.
                DemoRootView()
            #else
                // Release placeholder until the composition root lands
                // (tasks.md Day 14). Never a demo: `-demoMode` is a debug
                // launch argument and the mock graph is compiled out.
                Text("Nexus")
            #endif
        }
    }
}
