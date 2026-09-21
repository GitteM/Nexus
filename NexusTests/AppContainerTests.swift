import Entities
import Navigation
import Testing
@testable import Nexus

/// Composition-root integration tests: both modes construct, the demo
/// connects to `.ready`, reset
/// restores the demo, and the live mode reports the missing-backend
/// configuration gap instead of building a session to nowhere.
@Suite("AppContainer")
@MainActor
struct AppContainerTests {
    @Test func `demo container starts and lands on ready`() async {
        let container = AppContainer(mode: .demo)

        #expect(container.appState == .initializing)
        #expect(container.sessionStatus == .disconnected)

        await container.start()

        #expect(container.appState == .ready)
        #expect(container.sessionStatus == .connected)
        #expect(container.dashboardModel != nil)
    }

    @Test func `screen models are reused while their route stays on the stack`() throws {
        let container = AppContainer(mode: .demo)
        let cardID = Card.mockCreditCard.id

        container.prepareScreenModels(for: [.cardDetail(cardID: cardID)])
        let first = try #require(container.cardDetailModel(cardID: cardID))

        // Re-preparing the same stack must not replace the model (PR #26).
        container.prepareScreenModels(for: [.cardDetail(cardID: cardID)])
        let second = try #require(container.cardDetailModel(cardID: cardID))

        #expect(first === second)
    }

    @Test func `screen models are evicted once their route leaves the stack`() throws {
        let container = AppContainer(mode: .demo)
        let cardID = Card.mockCreditCard.id

        container.prepareScreenModels(for: [.cardDetail(cardID: cardID)])
        #expect(container.cardDetailModel(cardID: cardID) != nil)

        container.prepareScreenModels(for: [])

        #expect(container.cardDetailModel(cardID: cardID) == nil)
        #expect(container.cardDetailModels.isEmpty)
    }

    @Test func `reset demo rebuilds the graph and reconnects`() async {
        let container = AppContainer(mode: .demo)
        await container.start()
        #expect(container.appState == .ready)

        await container.resetDemo()

        // resetDemo rebuilds and reconnects before returning.
        #expect(container.appState == .ready)
        #expect(container.sessionStatus == .connected)
    }

    @Test func `reset demo drives the replacement dashboard to loaded content`() async throws {
        let container = AppContainer(mode: .demo)
        await container.start()

        // Mimic the view's initial load so the first model is settled.
        let originalModel = try #require(container.dashboardModel)
        await originalModel.load()
        #expect(originalModel.viewState == .loaded)

        await container.resetDemo()

        // resetDemo rebuilds the graph: a brand-new dashboard model…
        let replacement = try #require(container.dashboardModel)
        #expect(replacement !== originalModel)

        // …and that replacement must be settled, not stranded in `.loading`
        // waiting on a view `.task` that may never re-fire. Regression for
        // the reset that left the dashboard on "Loading your cards".
        #expect(replacement.viewState == .loaded)
    }

    @Test func `live container without a backend reports the configuration gap`() async {
        // baseURL nil means "read the (empty) config" — no backend exists
        // in current builds.
        let container = AppContainer(mode: .live, baseURL: nil)

        await container.start()

        guard case let .error(error) = container.appState else {
            Issue.record("expected an error state, got \(container.appState)")
            return
        }
        #expect(error.category == .initialization)
    }

    @Test func `session status changes map to app state transitions`() async {
        let container = AppContainer(mode: .demo)
        await container.start()
        #expect(container.appState == .ready)

        container.handleSessionStatusChange(.disconnected)
        #expect(container.appState == .disconnected)

        container.handleSessionStatusChange(.connecting)
        #expect(container.appState == .loading)

        container.handleSessionStatusChange(.connected)
        #expect(container.appState == .ready)
    }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<200 {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}
