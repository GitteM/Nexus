import XCTest

/// Dashboard UI suite (tasks.md Day 11, architecture.md §10): launches the
/// app with `-demoMode` and asserts the ready, loading, and error states
/// render on the real view layer.
///
/// The demo root (`Nexus/DemoRootView.swift`) parses the `-demoState` knob
/// and builds the dashboard over the shared mock repositories, so these
/// tests exercise the same orchestration code previews and demo mode run —
/// only the transport/persistence edges are faked (§9.5). Replaces the
/// Day 1 launch smoke test, which only proved the runner installed.
final class DashboardUITests: XCTestCase {
    private func launchApp(state: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-demoMode", "-demoState=\(state)"]
        app.launch()
        return app
    }

    /// The ready state renders the carousel (with display-safe card fronts)
    /// and the offers row's add actions.
    @MainActor
    func testReadyStateRendersCarouselAndOffers() {
        let app = launchApp(state: "ready")

        XCTAssertTrue(app.navigationBars["Dashboard"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["dashboard.carousel"].waitForExistence(timeout: 10))

        // The first managed card (mock credit card, ending 4821, active)
        // is one combined accessibility element whose label names the tail
        // and the status — the data the carousel must expose to VoiceOver.
        let firstCard = app.descendants(matching: .any)["dashboard.card.card-credit-001"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.label.contains("4821"), "label was: \(firstCard.label)")
        XCTAssertTrue(firstCard.label.contains("Active"), "label was: \(firstCard.label)")
        XCTAssertEqual(firstCard.value as? String, "Card 1 of 6")

        // The offers row lists the demo offers with add actions.
        XCTAssertTrue(app.buttons["dashboard.offer.add.offer-cashback-001"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dashboard.offer.add.offer-travel-001"].exists)
    }

    /// Adding an offer turns it into a managed card: the repository accepts
    /// it and the offer leaves the catalog (the model drops it, and the row
    /// has nothing left to render).
    @MainActor
    func testAddingAnOfferRemovesItFromTheCatalog() {
        let app = launchApp(state: "ready")

        let addButton = app.buttons["dashboard.offer.add.offer-cashback-001"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        XCTAssertTrue(addButton.waitForNonExistence(timeout: 10))
        // The other offers are untouched.
        XCTAssertTrue(app.buttons["dashboard.offer.add.offer-travel-001"].waitForExistence(timeout: 5))
    }

    /// The `-demoState=loading` knob parks the card fetch, so the loading
    /// surface stays on screen.
    @MainActor
    func testLoadingStateRendersLoadingSurface() {
        let app = launchApp(state: "loading")

        XCTAssertTrue(app.staticTexts["Loading your cards"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["dashboard.carousel"].exists)
    }

    /// The `-demoState=error` knob makes the card fetch throw, so the error
    /// surface with the `AppError` headline and a retry action renders.
    @MainActor
    func testErrorStateRendersErrorSurfaceWithRetry() {
        let app = launchApp(state: "error")

        XCTAssertTrue(app.staticTexts["We couldn't reach the server."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["dashboard.carousel"].exists)
    }
}
