import Entities
import SharedUI
import SwiftUI

/// The root view: a pure function of the container's `appState`
/// (architecture.md §11.3, tasks.md Day 14). Each state renders its own
/// surface and injects the environments that surface needs; the session is
/// observed through `container.sessionStatus` (`.onChange`, no polling).
struct ContentView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            switch container.appState {
            case .initializing, .loading:
                AppLoadingView()
            case .ready:
                MainNavigationView()
                    .environment(container.router)
                    .environment(container.dashboardModel)
            case .disconnected:
                DisconnectedView {
                    container.retry()
                }
            case let .error(error):
                AppErrorView(error: error) {
                    container.retry()
                }
            }
        }
        .task {
            await container.start()
        }
        .onChange(of: container.sessionStatus) { _, status in
            container.handleSessionStatusChange(status)
        }
    }
}
