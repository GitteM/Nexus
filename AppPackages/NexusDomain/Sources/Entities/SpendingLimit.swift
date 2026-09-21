import Foundation

/// The period a spending limit applies to.
///
/// Encoded by its raw value on the wire, e.g. `"weekly"`.
public enum SpendingLimitPeriod: String, Codable, CaseIterable, Sendable, Equatable {
    case daily
    case weekly
    case monthly
}

extension SpendingLimitPeriod {
    /// Human-readable label for UI, e.g. "Weekly". Localized through the
    /// app's String Catalog at lookup time.
    public var displayName: String {
        switch self {
        case .daily: String(localized: "Daily")
        case .weekly: String(localized: "Weekly")
        case .monthly: String(localized: "Monthly")
        }
    }
}

/// A per-card spending limit for one period, decoded from the event stream
/// and set through `CardCommand.setSpendingLimit`.
public struct SpendingLimit: Codable, Sendable, Equatable {
    public let cardId: String
    public let period: SpendingLimitPeriod
    public let amount: Decimal
    public let currency: String

    public init(
        cardId: String,
        period: SpendingLimitPeriod,
        amount: Decimal,
        currency: String
    ) {
        self.cardId = cardId
        self.period = period
        self.amount = amount
        self.currency = currency
    }
}

extension SpendingLimit {
    public static let mockDailyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .daily,
        amount: 100,
        currency: "EUR"
    )

    public static let mockWeeklyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .weekly,
        amount: 500,
        currency: "EUR"
    )

    public static let mockMonthlyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .monthly,
        amount: 2000,
        currency: "EUR"
    )

    /// Demo/default limit set covering every `SpendingLimitPeriod`.
    public static var mockDefaults: [SpendingLimit] {
        [.mockDailyLimit, .mockWeeklyLimit, .mockMonthlyLimit]
    }
}
