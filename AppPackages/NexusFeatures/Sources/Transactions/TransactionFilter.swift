import Entities
import Foundation

/// The date window a transaction-history filter applies to. Presets
/// relative to "now" — the model passes an explicit `now` so the pure
/// filter stays testable.
public enum TransactionDateRange: String, CaseIterable, Sendable, Equatable {
    case all
    case last7Days
    case last30Days
    case last90Days
}

public extension TransactionDateRange {
    /// The inclusive lower bound of the window relative to `now`; `nil`
    /// for `.all` (UI copy lives in `Strings.Transactions`).
    func lowerBound(relativeTo now: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .all:
            return nil
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .last90Days:
            return calendar.date(byAdding: .day, value: -90, to: now)
        }
    }
}

/// The active search/filter state of the transaction history screen:
/// free-text search plus filters by category, status, date window, and
/// amount magnitude.
///
/// `TransactionHistoryModel` publishes one query; the pure filtering rule
/// lives here so it is unit-testable without the model (no business rules
/// in views).
public struct TransactionQuery: Equatable, Sendable {
    /// Free-text search across merchant name and transaction id.
    public var searchText: String
    /// Restrict to one category; `nil` means every category.
    public var category: TransactionCategory?
    /// Restrict to one status; `nil` means both.
    public var status: TransactionStatus?
    /// Restrict to a date window; `.all` means every date.
    public var dateRange: TransactionDateRange
    /// Inclusive lower bound on the transaction's amount *magnitude*
    /// (spending amount, independent of direction); `nil` means none.
    public var minimumAmount: Decimal?
    /// Inclusive upper bound on the transaction's amount magnitude.
    public var maximumAmount: Decimal?

    public init(
        searchText: String = "",
        category: TransactionCategory? = nil,
        status: TransactionStatus? = nil,
        dateRange: TransactionDateRange = .all,
        minimumAmount: Decimal? = nil,
        maximumAmount: Decimal? = nil,
    ) {
        self.searchText = searchText
        self.category = category
        self.status = status
        self.dateRange = dateRange
        self.minimumAmount = minimumAmount
        self.maximumAmount = maximumAmount
    }

    /// True when no active filter narrows the list (search empty, every
    /// filter nil/all).
    public var isDefault: Bool {
        searchText.isEmpty
            && category == nil
            && status == nil
            && dateRange == .all
            && minimumAmount == nil
            && maximumAmount == nil
    }

    /// Applies the query to a newest-first transaction list, preserving
    /// order. Amount filters use the magnitude (`abs`), so "between €50 and
    /// €150" matches a €129.99 purchase and a €45 refund does not cross
    /// into spend-filter ranges.
    public static func filter(
        _ transactions: [Transaction],
        by query: TransactionQuery,
        now: Date = .now,
    ) -> [Transaction] {
        transactions.filter { transaction in
            if !query.searchText.isEmpty {
                let needle = query.searchText
                let haystack = "\(transaction.merchant) \(transaction.id)"
                guard haystack.localizedCaseInsensitiveContains(needle) else {
                    return false
                }
            }
            if let category = query.category, transaction.category != category {
                return false
            }
            if let status = query.status, transaction.status != status {
                return false
            }
            if let lowerBound = query.dateRange.lowerBound(relativeTo: now), transaction.date < lowerBound {
                return false
            }
            let magnitude = abs(transaction.amount)
            if let minimumAmount = query.minimumAmount, magnitude < minimumAmount {
                return false
            }
            if let maximumAmount = query.maximumAmount, magnitude > maximumAmount {
                return false
            }
            return true
        }
    }
}
