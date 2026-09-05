import Dashboard
import Design
import Entities
import XCTest

/// Dashboard UI suite: launches the app with `-demoMode` and asserts the
/// ready, loading, and error states render on the real view layer.
///
/// The demo graph (`Nexus/AppContainer+Dependencies+Demo.swift`,
/// `LaunchArguments`) parses the `-demoState` knob and builds the dashboard
/// over the shared mock repositories, so these tests exercise the same
/// orchestration code previews and demo mode run — only the
/// transport/persistence edges are faked. Replaces the launch smoke test,
/// which only proved the runner installed.
///
/// Accessibility identifiers come from the shared `DashboardAccessibility`
/// namespace (and entity ids from the domain mocks), never from literals —
/// the views set exactly what these tests query.
final class DashboardUITests: XCTestCase {
    /// The `-demoState` values the demo graph understands — mirrors
    /// `LaunchArguments.DemoState` (Nexus/AppContainer+Dependencies+Demo.swift).
    ///
    /// UI tests launch the app as a black box and cannot import the app's
    /// type, so the raw values are the process-boundary contract and must
    /// stay in sync by hand. A mismatch fails loudly: the app's parser
    /// defaults an unknown state to `.ready`, so a loading/error test whose
    /// state drifted would assert against loaded content and fail — never
    /// silently pass.
    private enum DemoState: String, CaseIterable {
        case ready
        case loading
        case error

        /// The launch-argument element the demo graph parses,
        /// e.g. "-demoState=error".
        var launchArgument: String {
            "-demoState=\(rawValue)"
        }
    }

    /// `XCUIApplication` is main-actor-isolated, so the helper must be too.
    @MainActor
    private func launchApp(state: DemoState) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-demoMode", state.launchArgument]
        app.launch()
        return app
    }

    /// The ready state renders the carousel (with display-safe card fronts)
    /// and the offers row's add actions.
    @MainActor
    func testReadyStateRendersCarouselAndOffers() {
        let app = launchApp(state: .ready)

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[DashboardAccessibility.carousel].waitForExistence(timeout: 10))

        // The first managed card (mock credit card, ending 4821, active)
        // is one combined accessibility element whose label names the tail
        // and the status — the data the carousel must expose to VoiceOver.
        let firstCard = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.label.contains("4821"), "label was: \(firstCard.label)")
        XCTAssertTrue(firstCard.label.contains("Active"), "label was: \(firstCard.label)")
        XCTAssertEqual(firstCard.value as? String, "Card 1 of 6")

        // The offers row lists the demo offers with add actions.
        XCTAssertTrue(app.buttons[DashboardAccessibility.addOffer(CardOffer.mockCashbackOffer.id)].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[DashboardAccessibility.addOffer(CardOffer.mockTravelOffer.id)].exists)
    }

    /// Adding an offer turns it into a managed card: the repository accepts
    /// it and the offer leaves the catalog (the model drops it, and the row
    /// has nothing left to render).
    @MainActor
    func testAddingAnOfferRemovesItFromTheCatalog() {
        let app = launchApp(state: .ready)

        let addButton = app.buttons[DashboardAccessibility.addOffer(CardOffer.mockCashbackOffer.id)]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        XCTAssertTrue(UITestInteraction.tapWhenReady(addButton))

        XCTAssertTrue(addButton.waitForNonExistence(timeout: 10))
        // The other offers are untouched.
        XCTAssertTrue(app.buttons[DashboardAccessibility.addOffer(CardOffer.mockTravelOffer.id)].waitForExistence(timeout: 5))
    }

    /// The `-demoState=loading` knob parks the card fetch, so the loading
    /// surface stays on screen.
    @MainActor
    func testLoadingStateRendersLoadingSurface() {
        let app = launchApp(state: .loading)

        XCTAssertTrue(app.staticTexts["Loading your cards"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)[DashboardAccessibility.carousel].exists)
    }

    /// The `-demoState=error` knob makes the card fetch throw, so the error
    /// surface with the `AppError` headline and a retry action renders.
    @MainActor
    func testErrorStateRendersErrorSurfaceWithRetry() {
        let app = launchApp(state: .error)

        XCTAssertTrue(app.staticTexts["We couldn't reach the server."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)[DashboardAccessibility.carousel].exists)
    }

    /// Regression: tapping the demo "Reset demo" toolbar button replaces the
    /// dashboard model, and the replacement must settle back on loaded
    /// content. It used to strand the dashboard on "Loading your cards"
    /// with no way forward.
    @MainActor
    func testResetDemoReturnsDashboardToLoadedContent() {
        let app = launchApp(state: .ready)

        let card = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(card.waitForExistence(timeout: 10))

        let resetButton = app.buttons[Strings.App.resetDemo]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        XCTAssertTrue(UITestInteraction.tapWhenReady(resetButton))

        // The dashboard must come back to loaded content — not stay on the
        // loading surface after the model swap.
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Loading your cards"].exists)
    }
}
