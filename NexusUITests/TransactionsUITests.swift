import CardDetail
import Dashboard
import Entities
import Transactions
import XCTest

/// Transactions UI suite (tasks.md Day 13, architecture.md §10): launches
/// with `-demoMode`, opens the credit card's detail, and drives the
/// account-activity screen — balance header, filtered history, and the
/// transaction detail deep view.
///
/// The demo graph (`Nexus/DemoRootView.swift`) seeds the shared mock
/// balance/transaction repositories, so the screens exercise the real
/// model/view orchestration over the mocks (§9.5). Accessibility
/// identifiers come from the shared `…Accessibility` namespaces and domain
/// mock ids, never from literals (§9.4); system search fields are matched
/// by type because they expose no identifier contract.
final class TransactionsUITests: XCTestCase {
    /// `XCUIApplication` is main-actor-isolated, so the helpers must be too.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-demoMode", "-demoState=ready"]
        app.launch()
        return app
    }

    /// Opens the credit card's account-activity screen: dashboard → card
    /// detail → the Transactions row.
    @MainActor
    private func openHistory(in app: XCUIApplication) {
        let carousel = app.descendants(matching: .any)[DashboardAccessibility.carousel]
        XCTAssertTrue(carousel.waitForExistence(timeout: UITestTimeout.seconds(20)))

        let firstCard = app.descendants(matching: .any)[DashboardAccessibility.card(Card.mockCreditCard.id)]
        XCTAssertTrue(firstCard.waitForExistence(timeout: UITestTimeout.seconds(10)))
        firstCard.tap()

        let transactionsRow = app.buttons[CardDetailAccessibility.transactions]
        XCTAssertTrue(transactionsRow.waitForExistence(timeout: UITestTimeout.seconds(20)))
        if !transactionsRow.isHittable {
            app.swipeUp()
        }
        transactionsRow.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)[TransactionsAccessibility.historyScreen]
                .waitForExistence(timeout: UITestTimeout.seconds(20)),
        )
    }

    /// The history screen shows the card's balance header and the seeded
    /// transaction feed, and a row opens the transaction detail.
    @MainActor
    func testHistoryShowsBalanceAndOpensTransactionDetail() {
        let app = launchApp()
        openHistory(in: app)

        // Balance header for the mock credit card (locale formats vary:
        // 1,240.75 / 1.240,75 / 1 240,75 €).
        let balance = app.descendants(matching: .any)[TransactionsAccessibility.balanceSummary]
        XCTAssertTrue(balance.waitForExistence(timeout: UITestTimeout.seconds(10)))
        let compactLabel = balance.label.replacingOccurrences(of: " ", with: "")
        XCTAssertTrue(
            compactLabel.contains("240,75") || compactLabel.contains("240.75"),
            "label was: \(balance.label)",
        )

        // A seeded transaction row exists (pending coffee purchase).
        let row = app.descendants(matching: .any)[TransactionsAccessibility.transactionRow(Transaction.mockCoffeePurchase.id)]
        XCTAssertTrue(row.waitForExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(row.label.contains("Cafe Central"), "label was: \(row.label)")

        // Tapping the row opens the detail screen with the transaction id.
        row.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)[TransactionsAccessibility.detailScreen]
                .waitForExistence(timeout: UITestTimeout.seconds(20)),
        )
        // The id row can surface as several accessibility elements; the
        // first match carries the id text.
        let detailID = app.descendants(matching: .any)
            .matching(identifier: TransactionsAccessibility.detailTransactionID).firstMatch
        XCTAssertTrue(detailID.waitForExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(detailID.label.contains(Transaction.mockCoffeePurchase.id),
                      "label was: \(detailID.label)")
    }

    /// The search field filters the feed: matching rows stay, non-matching
    /// rows leave the list.
    @MainActor
    func testSearchFiltersTransactionHistory() {
        let app = launchApp()
        openHistory(in: app)

        let coffeeRow = app.descendants(matching: .any)[TransactionsAccessibility.transactionRow(Transaction.mockCoffeePurchase.id)]
        let groceriesRow = app.descendants(matching: .any)[TransactionsAccessibility.transactionRow(Transaction.mockGroceriesPurchase.id)]
        XCTAssertTrue(coffeeRow.waitForExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(groceriesRow.waitForExistence(timeout: UITestTimeout.seconds(10)))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: UITestTimeout.seconds(10)))
        searchField.tap()
        searchField.typeText("Cafe")

        XCTAssertTrue(coffeeRow.waitForExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(groceriesRow.waitForNonExistence(timeout: UITestTimeout.seconds(10)))

        // The filtered state is announced in-list: a banner with the result
        // count and the active filter (copy matched literally — Design is
        // not linked into the UI test target). The banner container exposes
        // its text as child elements, so assert on those.
        let banner = app.descendants(matching: .any)[TransactionsAccessibility.filteredBanner]
        XCTAssertTrue(banner.waitForExistence(timeout: UITestTimeout.seconds(10)))
        let filtersActive = app.staticTexts["Filters active"]
        XCTAssertTrue(filtersActive.waitForExistence(timeout: UITestTimeout.seconds(10)))
        let showingCount = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Showing 1 of \(Transaction.mockDefaults.count)"),
        ).firstMatch
        XCTAssertTrue(showingCount.exists, "count line was missing")

        // Reset restores the whole feed and removes the banner.
        let reset = app.buttons[TransactionsAccessibility.filteredBannerReset]
        XCTAssertTrue(reset.waitForExistence(timeout: UITestTimeout.seconds(10)))
        reset.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(groceriesRow.waitForExistence(timeout: UITestTimeout.seconds(10)))
        XCTAssertTrue(coffeeRow.exists)
    }
}
