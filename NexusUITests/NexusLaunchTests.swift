import XCTest

/// Day 1 (M0) smoke test: proves the NexusUITests runner installs, launches
/// the Nexus app, and sees its placeholder content. Replaced by real UI
/// suites from M4 (tasks.md Day 11) that launch with `-demoMode`.
final class NexusLaunchTests: XCTestCase {
    @MainActor
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Nexus"].waitForExistence(timeout: 10))
    }
}
