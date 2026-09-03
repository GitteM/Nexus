import Foundation

/// A card a customer manages: the dashboard unit of work for the card carousel,
/// card controls, and spending limits.
///
/// `Card` is the static identity of a managed card (a `CardOffer` becomes a
/// `Card` when the customer adds it). Live state — balances, transactions,
/// status changes — arrives separately as `CardState` / `BankingEvent`.
public struct Card: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let cardholderName: String
    public let lastFourDigits: String
    public let type: CardType
    public let status: CardStatus
    public let currency: String
    public let spendingLimit: Decimal?

    public init(
        id: String,
        cardholderName: String,
        lastFourDigits: String,
        type: CardType,
        status: CardStatus,
        currency: String,
        spendingLimit: Decimal?,
    ) {
        self.id = id
        self.cardholderName = cardholderName
        self.lastFourDigits = lastFourDigits
        self.type = type
        self.status = status
        self.currency = currency
        self.spendingLimit = spendingLimit
    }
}

public extension Card {
    /// A copy of this card with a new lifecycle status — the model's way to
    /// fold live `CardState` updates back into the managed-card list
    /// (architecture.md §9.1: subscriptions "also update card.status")
    /// without reconstructing the whole entity at the call site.
    func withStatus(_ status: CardStatus) -> Card {
        Card(
            id: id,
            cardholderName: cardholderName,
            lastFourDigits: lastFourDigits,
            type: type,
            status: status,
            currency: currency,
            spendingLimit: spendingLimit,
        )
    }
}

public extension Card {
    static let mockCreditCard = Card(
        id: "card-credit-001",
        cardholderName: "Jordan Avery",
        lastFourDigits: "4821",
        type: .credit,
        status: .active,
        currency: "EUR",
        spendingLimit: 2500,
    )

    static let mockDebitCard = Card(
        id: "card-debit-001",
        cardholderName: "Jordan Avery",
        lastFourDigits: "9034",
        type: .debit,
        status: .active,
        currency: "EUR",
        spendingLimit: nil,
    )

    static let mockFrozenCard = Card(
        id: "card-credit-002",
        cardholderName: "Jordan Avery",
        lastFourDigits: "1147",
        type: .credit,
        status: .frozen,
        currency: "EUR",
        spendingLimit: 1000,
    )

    static let mockExpiredCard = Card(
        id: "card-credit-003",
        cardholderName: "Jordan Avery",
        lastFourDigits: "7720",
        type: .credit,
        status: .expired,
        currency: "EUR",
        spendingLimit: nil,
    )

    static let mockLostCard = Card(
        id: "card-credit-004",
        cardholderName: "Jordan Avery",
        lastFourDigits: "3381",
        type: .credit,
        status: .lost,
        currency: "EUR",
        spendingLimit: 1500,
    )

    static let mockPrepaidCard = Card(
        id: "card-prepaid-001",
        cardholderName: "Jordan Avery",
        lastFourDigits: "6059",
        type: .prepaid,
        status: .active,
        currency: "EUR",
        spendingLimit: 200,
    )

    /// Demo/default card set covering every `CardType` and `CardStatus` for
    /// previews and tests.
    static var mockDefaults: [Card] {
        [.mockCreditCard, .mockDebitCard, .mockFrozenCard, .mockExpiredCard, .mockLostCard, .mockPrepaidCard]
    }
}
