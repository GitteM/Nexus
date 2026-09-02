import Foundation

/// The lifecycle status of a transaction.
///
/// Encoded by its raw value on the wire, e.g. `"pending"`.
public enum TransactionStatus: String, Codable, CaseIterable, Sendable, Equatable {
    case pending
    case cleared
}

public extension TransactionStatus {
    /// Human-readable label for UI, e.g. "Pending".
    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .cleared: "Cleared"
        }
    }

    /// SF Symbol name used by the UI for this status.
    var icon: String {
        switch self {
        case .pending: "clock"
        case .cleared: "checkmark.circle"
        }
    }
}

/// The spending category of a transaction, used for search, filter, and
/// insights.
///
/// Encoded by its raw value on the wire, e.g. `"dining"`.
public enum TransactionCategory: String, Codable, CaseIterable, Sendable, Equatable {
    case dining
    case groceries
    case shopping
    case travel
    case entertainment
    case bills
    case transfer
    case other
}

public extension TransactionCategory {
    /// Human-readable label for UI, e.g. "Groceries".
    var displayName: String {
        switch self {
        case .dining: "Dining"
        case .groceries: "Groceries"
        case .shopping: "Shopping"
        case .travel: "Travel"
        case .entertainment: "Entertainment"
        case .bills: "Bills"
        case .transfer: "Transfer"
        case .other: "Other"
        }
    }

    /// SF Symbol name used by the UI for this category.
    var icon: String {
        switch self {
        case .dining: "fork.knife"
        case .groceries: "cart"
        case .shopping: "bag"
        case .travel: "airplane"
        case .entertainment: "film"
        case .bills: "doc.text"
        case .transfer: "arrow.left.arrow.right"
        case .other: "ellipsis"
        }
    }
}

/// A card transaction, decoded from the event stream (architecture.md §4.1).
///
/// `amount` is signed: negative for purchases and debits, positive for
/// refunds and credits. `location` is optional — present only when the
/// merchant shared it.
public struct Transaction: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let cardId: String
    public let date: Date
    public let merchant: String
    public let amount: Decimal
    public let currency: String
    public let category: TransactionCategory
    public let status: TransactionStatus
    public let location: String?

    public init(
        id: String,
        cardId: String,
        date: Date,
        merchant: String,
        amount: Decimal,
        currency: String,
        category: TransactionCategory,
        status: TransactionStatus,
        location: String?,
    ) {
        self.id = id
        self.cardId = cardId
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.currency = currency
        self.category = category
        self.status = status
        self.location = location
    }
}

public extension Transaction {
    static let mockCoffeePurchase = Transaction(
        id: "txn-001",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 799_200_000),
        merchant: "Cafe Central",
        amount: -4.50,
        currency: "EUR",
        category: .dining,
        status: .pending,
        location: "Berlin",
    )

    static let mockGroceriesPurchase = Transaction(
        id: "txn-002",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 798_900_000),
        merchant: "Fresh Market",
        amount: -86.20,
        currency: "EUR",
        category: .groceries,
        status: .cleared,
        location: "Berlin",
    )

    static let mockOnlineShoppingPurchase = Transaction(
        id: "txn-003",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 798_300_000),
        merchant: "Shoply",
        amount: -129.99,
        currency: "EUR",
        category: .shopping,
        status: .cleared,
        location: nil,
    )

    static let mockFlightPurchase = Transaction(
        id: "txn-004",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 797_500_000),
        merchant: "SkyWays",
        amount: -342.00,
        currency: "EUR",
        category: .travel,
        status: .cleared,
        location: "Berlin",
    )

    static let mockStreamingSubscription = Transaction(
        id: "txn-005",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 797_100_000),
        merchant: "StreamFlix",
        amount: -12.99,
        currency: "EUR",
        category: .entertainment,
        status: .pending,
        location: nil,
    )

    static let mockUtilityBill = Transaction(
        id: "txn-006",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 796_400_000),
        merchant: "CityPower",
        amount: -78.40,
        currency: "EUR",
        category: .bills,
        status: .cleared,
        location: "Berlin",
    )

    static let mockPeerTransfer = Transaction(
        id: "txn-007",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 795_800_000),
        merchant: "To Avery Jordan",
        amount: -200.00,
        currency: "EUR",
        category: .transfer,
        status: .cleared,
        location: nil,
    )

    static let mockRefund = Transaction(
        id: "txn-008",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 795_200_000),
        merchant: "Fresh Market",
        amount: 45.00,
        currency: "EUR",
        category: .groceries,
        status: .cleared,
        location: "Berlin",
    )

    static let mockParkingCharge = Transaction(
        id: "txn-009",
        cardId: "card-credit-001",
        date: Date(timeIntervalSinceReferenceDate: 794_600_000),
        merchant: "City Parking",
        amount: -15.00,
        currency: "EUR",
        category: .other,
        status: .cleared,
        location: "Berlin",
    )

    /// Demo/default transaction set for previews and tests: covers every
    /// `TransactionCategory`, both statuses, a pending purchase, a refund,
    /// and one transaction without a location.
    static var mockDefaults: [Transaction] {
        [
            .mockCoffeePurchase,
            .mockGroceriesPurchase,
            .mockOnlineShoppingPurchase,
            .mockFlightPurchase,
            .mockStreamingSubscription,
            .mockUtilityBill,
            .mockPeerTransfer,
            .mockRefund,
            .mockParkingCharge,
        ]
    }
}
