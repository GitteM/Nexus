import Foundation

/// A transport-neutral event value: the wire channel plus the raw JSON
/// payload.
///
/// `BankingEvent` is what `SessionManagerProtocol` streams and what
/// `CardStateDataSource.parseEvent` decodes into typed entities —
/// `CardState`, `Balance`, `Transaction`, `SpendingLimit`. The payload stays
/// a string here so the Domain never touches the wire format.
public struct BankingEvent: Codable, Sendable, Equatable {
    public let channel: String
    public let payload: String

    public init(channel: String, payload: String) {
        self.channel = channel
        self.payload = payload
    }
}

public extension BankingEvent {
    /// A `card.status` event whose payload decodes to `CardState`.
    static let mockCardStatusEvent = BankingEvent(
        channel: "card.status",
        payload: #"{"cardId":"card-credit-001","status":"frozen"}"#,
    )

    /// A `card.balance` event whose payload decodes to `Balance`.
    static let mockBalanceEvent = BankingEvent(
        channel: "card.balance",
        payload: #"{"cardId":"card-credit-001","current":1240.75,"available":1259.25,"creditLimit":2500,"currency":"EUR"}"#,
    )

    /// A `card.transactions` event whose payload decodes to `Transaction`.
    static let mockTransactionEvent = BankingEvent(
        channel: "card.transactions",
        payload: #"{"id":"txn-event-001","cardId":"card-credit-001","date":800000000,"merchant":"Cafe Central","amount":-4.5,"currency":"EUR","category":"dining","status":"pending","location":"Berlin"}"#,
    )

    /// A `card.limits` event whose payload decodes to `SpendingLimit`.
    static let mockSpendingLimitEvent = BankingEvent(
        channel: "card.limits",
        payload: #"{"cardId":"card-credit-001","period":"weekly","amount":500,"currency":"EUR"}"#,
    )

    /// Demo/default event set covering one payload per typed entity.
    static var mockDefaults: [BankingEvent] {
        [.mockCardStatusEvent, .mockBalanceEvent, .mockTransactionEvent, .mockSpendingLimitEvent]
    }
}
