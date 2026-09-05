import CardDetail
import Dashboard
import Entities
import XCTest

/// Card detail + controls UI suite: launches the app with `-demoMode` and
/// drives the freeze round trip and its failure knob through the real view
/// layer.
///
/// The demo graph (`Nexus/AppContainer+Dependencies+Demo.swift`) shares one
/// mock store graph for the session and installs the
/// `MockCommandCoordinator` backend echo, so a freeze in detail persists to
/// the status store and the dashboard reflects it on return. The
/// `-demoActionState=error` knob makes the action repository throw, so the
/// failure path leaves the card unchanged.
///
/// Accessibility identifiers come from the shared `DashboardAccessibility`
/// / `CardDetailAccessibility` namespaces and entity ids from the domain
/// mocks, never from literals; dialog buttons are matched by copy because
/// system alerts expose no identifier contract.
final class CardDetailUITests: XCTestCase {
    /// The `-demoState` values the demo graph understands — mirrors
    /// `LaunchArguments.DemoState` (Nexus/AppContainer+Dependencies+Demo.swift).
    private enum DemoState: String {
        case ready
    }

    /// The `-demoActionState` values the demo graph understands — mirrors
    /// `LaunchArguments.DemoActionState`.
    private enum DemoActionState: String {
        case ready
        case error
    }

    /// `XCUIApplication` is main-actor-isolated, so the helper must be too.
    @MainActor
    private func launchApp(
        actionState: DemoActionState = .ready,
        openCardID: String? = nil,
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-demoMode",
            "-demoState=\(DemoState.ready.rawValue)",
            "-demoActionState=\(actionState.rawValue)",
        ]
        if let openCardID {
            // Deep-link: the demo graph starts with the card's detail pushed,
            // so these tests never tap through the cold dashboard (fresh CI
            // simulators can drop the very first tap — the app is rendered
            // but hit-testing is not settled).
            app.launchArguments += ["-demoOpenCard=\(openCardID)"]
        }
        app.launch()
        return app
    }

    /// Freeze/unfreeze round trip: the control reflects the
    /// stream-confirmed status; navigating away and back keeps the state
    /// (the shared repository store persists it), and the dashboard chip
    /// reconciles through its own live subscription. The detail screen is
    /// opened via the demo deep link; only the *warm* back-navigation tap
    /// comes from the test.
    @MainActor
    func testFreezeRoundTripReflectsOnDetailAndDashboard() {
        let app = launchApp(openCardID: Card.mockCreditCard.id)

        // The deep link lands on the card detail.
        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 20),
        )

        // Active card offers the freeze control.
        let freezeButton = app.buttons[CardDetailAccessibility.freeze]
        XCTAssertTrue(freezeButton.waitForExistence(timeout: 10))
        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")

        // Freeze → confirm → the status line announces Frozen.
        XCTAssertTrue(UITestInteraction.tapWhenReady(freezeButton))
        let confirm = app.alerts.buttons[freezeLabel]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(UITestInteraction.tapWhenReady(confirm))

        XCTAssertTrue(waitForLabel(containing: "Frozen", on: status))
        XCTAssertTrue(freezeButton.waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons[CardDetailAccessibility.unfreeze].exists)

        // Back on the dashboard, the carousel chip shows the frozen state
        // (the detail and dashboard share the status store + subscription).
        backToDashboard(from: app)
        let firstCard = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(firstCard.label.contains("Frozen"), "label was: \(firstCard.label)")

        // Re-opening the detail keeps the frozen state — no reload resets it.
        XCTAssertTrue(UITestInteraction.tapWhenReady(firstCard))
        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 20),
        )
        let statusAfterReload = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(statusAfterReload.waitForExistence(timeout: 10))
        XCTAssertTrue(statusAfterReload.label.contains("Frozen"), "label was: \(statusAfterReload.label)")
    }

    /// Failure knob: the `-demoActionState=error` launch argument makes the
    /// action repository throw, so the freeze surfaces the error alert and
    /// the card stays active.
    @MainActor
    func testFreezeFailureLeavesTheCardActive() {
        let app = launchApp(actionState: .error, openCardID: Card.mockCreditCard.id)

        // The deep link lands on the card detail.
        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 20),
        )

        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")

        let freezeButton = app.buttons[CardDetailAccessibility.freeze]
        XCTAssertTrue(freezeButton.waitForExistence(timeout: 10))
        XCTAssertTrue(UITestInteraction.tapWhenReady(freezeButton))
        let confirm = app.alerts.buttons[freezeLabel]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(UITestInteraction.tapWhenReady(confirm))

        // The AppError headline surfaces (the demo's thrown error copy; the
        // alert body is one multiline element, so match by CONTAINS).
        let alertHeadline = app.alerts.staticTexts.element(
            matching: NSPredicate(format: "label CONTAINS %@", "The 'Freeze' action failed."),
        )
        XCTAssertTrue(alertHeadline.waitForExistence(timeout: 20))
        // …dismissing keeps the card active and the controls usable.
        XCTAssertTrue(UITestInteraction.tapWhenReady(app.alerts.buttons["OK"]))
        XCTAssertTrue(status.label.contains("Active"), "label was: \(status.label)")
        XCTAssertTrue(app.buttons[CardDetailAccessibility.freeze].waitForExistence(timeout: 10))
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
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        XCTAssertTrue(UITestInteraction.tapWhenReady(backButton))
    }

    /// Polls until an element's accessibility label contains `text`.
    @MainActor
    private func waitForLabel(containing text: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 20) == .completed
    }
}
