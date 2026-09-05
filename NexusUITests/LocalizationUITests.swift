import CardDetail
import Entities
import XCTest

/// Localization canaries: launch the app under a forced non-English system
/// language and assert that *translated* copy renders on real views.
///
/// These tests are the end-to-end guard for the String Catalog wiring: a
/// key missing from the catalog, a drift between the code literal and the
/// catalog key, or a broken `-AppleLanguages` plumbing each fail here —
/// and they fail with English on screen, not with a missing string.
///
/// The asserted copy is intentionally minimal and stable chrome (the
/// freeze control and the card-detail status line); when a translation is
/// edited in `Nexus/Localizable.xcstrings`, update the matching literal in
/// the test that pins it.
///
/// Accessibility identifiers come from the shared `CardDetailAccessibility`
/// namespace and entity ids from the domain mocks, never from literals.
final class LocalizationUITests: XCTestCase {
    /// The demo deep link used by the other suites (`-demoOpenCard`),
    /// mirroring `AppContainer`'s `LaunchArguments`.
    private static let openCardArgument = "-demoOpenCard=\(Card.mockCreditCard.id)"

    /// `XCUIApplication` is main-actor-isolated, so the helper must be too.
    @MainActor
    private func launchApp(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-demoMode",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            Self.openCardArgument,
        ]
        app.launch()
        return app
    }

    @MainActor
    func testRussianCopyRendersOnCardDetail() {
        let app = launchApp(language: "ru", locale: "ru_RU")

        // The deep link lands on the card detail with the card title.
        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 20),
        )
        XCTAssertTrue(app.navigationBars["Карта ••4821"].waitForExistence(timeout: 10))

        // The freeze control and the status line read Russian.
        XCTAssertEqual(app.buttons[CardDetailAccessibility.freeze].label, "Заморозить карту")
        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertEqual(status.label, "Статус: Активна")
    }

    @MainActor
    func testEstonianCopyRendersOnCardDetail() {
        let app = launchApp(language: "et", locale: "et_EE")

        XCTAssertTrue(
            app.descendants(matching: .any)[CardDetailAccessibility.screen]
                .waitForExistence(timeout: 20),
        )
        XCTAssertTrue(app.navigationBars["Kaart ••4821"].waitForExistence(timeout: 10))

        XCTAssertEqual(app.buttons[CardDetailAccessibility.freeze].label, "Külmuta kaart")
        let status = app.descendants(matching: .any)[CardDetailAccessibility.status]
        XCTAssertEqual(status.label, "Staatus: Aktiivne")
    }
}
