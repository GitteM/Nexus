import Entities
import Foundation

/// The stable accessibility-identifier contract for the transaction
/// history and detail screens (architecture.md §9.4, tasks.md Day 13).
///
/// Views set `.accessibilityIdentifier` from this namespace and the UI
/// tests (`NexusUITests`) reference the same helpers — never literal
/// strings in either place. Identifiers are a UI contract and do not
/// follow copy.
public enum TransactionsAccessibility {
    /// The transaction history screen container.
    public static let historyScreen = "transactions.history"

    /// The balance summary header on the history screen.
    public static let balanceSummary = "transactions.balance"

    /// One transaction row in the history list.
    public static func transactionRow(_ transactionID: String) -> String {
        "transactions.row.\(transactionID)"
    }

    /// The transaction detail screen container.
    public static let detailScreen = "transactions.detail"

    /// The transaction amount on the detail screen.
    public static let detailAmount = "transactions.detail.amount"

    /// The transaction id row on the detail screen.
    public static let detailTransactionID = "transactions.detail.id"
}
