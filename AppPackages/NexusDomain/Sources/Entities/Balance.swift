import Foundation

/// Live balance for a card, decoded from the event stream (architecture.md
/// §4.1).
///
/// `current` is the posted balance; `available` is what the cardholder can
/// spend right now (posted plus pending activity, or the remaining credit).
/// `creditLimit` is present for credit cards only.
public struct Balance: Codable, Sendable, Equatable, Identifiable {
    public let cardId: String
    public let current: Decimal
    public let available: Decimal
    public let creditLimit: Decimal?
    public let currency: String

    public var id: String {
        cardId
    }

    public init(
        cardId: String,
        current: Decimal,
        available: Decimal,
        creditLimit: Decimal?,
        currency: String,
    ) {
        self.cardId = cardId
        self.current = current
        self.available = available
        self.creditLimit = creditLimit
        self.currency = currency
    }
}

public extension Balance {
    /// Credit card balance: posted balance, available credit, and limit.
    static let mockCreditBalance = Balance(
        cardId: "card-credit-001",
        current: 1240.75,
        available: 1259.25,
        creditLimit: 2500,
        currency: "EUR",
    )

    /// Debit card balance: no credit limit — available equals current.
    static let mockDebitBalance = Balance(
        cardId: "card-debit-001",
        current: 482.30,
        available: 482.30,
        creditLimit: nil,
        currency: "EUR",
    )

    /// Demo/default balance set for previews and tests.
    static var mockDefaults: [Balance] {
        [.mockCreditBalance, .mockDebitBalance]
    }
}
