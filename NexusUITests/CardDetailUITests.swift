import CardDetail
import Dashboard
import Entities
import XCTest

/// Card detail + controls UI suite (tasks.md Day 12, architecture.md §10):
/// launches the app with `-demoMode` and drives the freeze round trip and
/// its failure knob through the real view layer.
///
/// The demo root (`Nexus/DemoRootView.swift`) shares one mock store graph
/// for the session and installs the `MockCommandCoordinator` backend echo,
/// so a freeze in detail persists to the status store and the dashboard
/// reflects it on return — the acceptance path appspec §2.2 pins. The
/// `-demoActionState=error` knob makes the action repository throw, so the
/// failure path leaves the card unchanged.
///
/// Accessibility identifiers come from the shared `DashboardAccessibility`
/// / `CardDetailAccessibility` namespaces and entity ids from the domain
/// mocks, never from literals (architecture.md §9.4); dialog buttons are
/// matched by copy because system alerts expose no identifier contract.
final class CardDetailUITests: XCTestCase {
    /// The `-demoState` values the demo root understands — mirrors
    /// `DemoRootView.DemoState` (Nexus/DemoRootView.swift).
    private enum DemoState: String {
        case ready
    }

    /// The `-demoActionState` values the demo root understands — mirrors
    /// `DemoRootView.DemoActionState`.
    private enum DemoActionState: String {
        case ready
        case error
    }

    /// `XCUIApplication` is main-actor-isolated, so the helper must be too.
    @MainActor
    private func launchApp(actionState: DemoActionState = .ready) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-demoMode",
            "-demoState=\(DemoState.ready.rawValue)",
            "-demoActionState=\(actionState.rawValue)",
        ]
        app.launch()
        return app
    }

    /// Opens the first managed card (mock credit card, ending 4821) from
    /// the dashboard carousel.
    @MainActor
    private func openFirstCard(in app: XCUIApplication) {
        let carousel = app.descendants(matching: .any)[DashboardAccessibility.carousel]
        XCTAssertTrue(carousel.waitForExistence(timeout: 10))

        let firstCard = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 10),
        )
    }

    /// Freeze/unfreeze round trip (appspec §2.2): the control reflects the
    /// stream-confirmed status; navigating away and back keeps the state
    /// (the shared repository store persists it), and the dashboard chip
    /// reconciles through its own live subscription.
    @MainActor
    func testFreezeRoundTripReflectsOnDetailAndDashboard() {
        let app = launchApp()
        openFirstCard(in: app)

        // Active card offers the freeze control.
        let freezeButton = app.buttons[CardDetailAccessibility.freeze]
        XCTAssertTrue(freezeButton.waitForExistence(timeout: 5))
        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")

        // Freeze → confirm → the status line announces Frozen.
        freezeButton.tap()
        let confirm = app.alerts.buttons[freezeLabel]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(waitForLabel(containing: "Frozen", on: status))
        XCTAssertTrue(freezeButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons[CardDetailAccessibility.unfreeze].exists)

        // Back on the dashboard, the carousel chip shows the frozen state
        // (the detail and dashboard share the status store + subscription).
        backToDashboard(from: app)
        let firstCard = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.label.contains("Frozen"), "label was: \(firstCard.label)")

        // Re-opening the detail keeps the frozen state — no reload resets it.
        firstCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 10),
        )
        let statusAfterReload = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(statusAfterReload.waitForExistence(timeout: 5))
        XCTAssertTrue(statusAfterReload.label.contains("Frozen"), "label was: \(statusAfterReload.label)")
    }

    /// Failure knob (appspec §2.2): the `-demoActionState=error` launch
    /// argument makes the action repository throw, so the freeze surfaces
    /// the error alert and the card stays active.
    @MainActor
    func testFreezeFailureLeavesTheCardActive() {
        let app = launchApp(actionState: .error)
        openFirstCard(in: app)

        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")

        let freezeButton = app.buttons[CardDetailAccessibility.freeze]
        XCTAssertTrue(freezeButton.waitForExistence(timeout: 5))
        freezeButton.tap()
        let confirm = app.alerts.buttons[freezeLabel]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // The AppError headline surfaces (the demo's thrown error copy; the
        // alert body is one multiline element, so match by CONTAINS).
        let alertHeadline = app.alerts.staticTexts.element(
            matching: NSPredicate(format: "label CONTAINS %@", "The 'Freeze' action failed.")
        )
        XCTAssertTrue(alertHeadline.waitForExistence(timeout: 10))
        // …dismissing keeps the card active and the controls usable.
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")
        XCTAssertTrue(app.buttons[CardDetailAccessibility.freeze].waitForExistence(timeout: 5))
    }

    /// System alert buttons expose no identifier contract, so their copy is
    /// the query boundary (DashboardUITests convention).
    private var freezeLabel: String {
        "Freeze card"
    }

    // MARK: - Helpers

    @MainActor
    private func backToDashboard(from app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
    }

    /// Polls until an element's accessibility label contains `text`.
    @MainActor
    private func waitForLabel(containing text: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }
}
