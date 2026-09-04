import Foundation

/// The period a spending limit applies to.
///
/// Encoded by its raw value on the wire, e.g. `"weekly"`.
public enum SpendingLimitPeriod: String, Codable, CaseIterable, Sendable, Equatable {
    case daily
    case weekly
    case monthly
}

public extension SpendingLimitPeriod {
    /// Human-readable label for UI, e.g. "Weekly".
    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
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
        currency: String,
    ) {
        self.cardId = cardId
        self.period = period
        self.amount = amount
        self.currency = currency
    }
}

public extension SpendingLimit {
    static let mockDailyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .daily,
        amount: 100,
        currency: "EUR",
    )

    static let mockWeeklyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .weekly,
        amount: 500,
        currency: "EUR",
    )

    static let mockMonthlyLimit = SpendingLimit(
        cardId: "card-credit-001",
        period: .monthly,
        amount: 2000,
        currency: "EUR",
    )

    /// Demo/default limit set covering every `SpendingLimitPeriod`.
    static var mockDefaults: [SpendingLimit] {
        [.mockDailyLimit, .mockWeeklyLimit, .mockMonthlyLimit]
    }
}
