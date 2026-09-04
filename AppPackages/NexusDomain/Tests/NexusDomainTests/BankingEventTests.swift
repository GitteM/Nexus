import Entities
import Foundation
import Testing

@Suite("BankingEvent")
struct BankingEventTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let event = BankingEvent(channel: "card.status", payload: #"{"cardId":"c1"}"#)
        #expect(event.channel == "card.status")
        #expect(event.payload == #"{"cardId":"c1"}"#)
    }

    // MARK: - Equality & Codable

    @Test func `equality compares all properties`() {
        let a = BankingEvent(channel: "card.status", payload: #"{"cardId":"c1"}"#)
        let same = BankingEvent(channel: "card.status", payload: #"{"cardId":"c1"}"#)
        let different = BankingEvent(channel: "card.balance", payload: #"{"cardId":"c1"}"#)
        #expect(a == same)
        #expect(a != different)
    }

    @Test func `codable round trip preserves all fields`() throws {
        let event = BankingEvent(channel: "card.status", payload: #"{"cardId":"c1","status":"frozen"}"#)
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(BankingEvent.self, from: data)
        #expect(decoded == event)
    }

    // MARK: - Mock payloads decode into typed entities

    /// The demo wire shapes must decode through the same path live events
    /// will: `parseEvent` feeds these payloads into the entity `JSONDecoder`s.
    @Test func `card status event payload decodes to CardState`() throws {
        let state = try JSONDecoder().decode(
            CardState.self,
            from: Data(BankingEvent.mockCardStatusEvent.payload.utf8),
        )
        #expect(state == CardState(cardId: "card-credit-001", status: .frozen))
    }

    @Test func `balance event payload decodes to Balance`() throws {
        let balance = try JSONDecoder().decode(
            Balance.self,
            from: Data(BankingEvent.mockBalanceEvent.payload.utf8),
        )
        #expect(balance == Balance.mockCreditBalance)
    }

    @Test func `transaction event payload decodes to Transaction`() throws {
        let transaction = try JSONDecoder().decode(
            Transaction.self,
            from: Data(BankingEvent.mockTransactionEvent.payload.utf8),
        )
        #expect(transaction.id == "txn-event-001")
        #expect(transaction.cardId == "card-credit-001")
        #expect(transaction.date == Date(timeIntervalSinceReferenceDate: 800_000_000))
        #expect(transaction.merchant == "Cafe Central")
        #expect(transaction.amount == -4.5)
        #expect(transaction.currency == "EUR")
        #expect(transaction.category == .dining)
        #expect(transaction.status == .pending)
        #expect(transaction.location == "Berlin")
    }

    @Test func `spending limit event payload decodes to SpendingLimit`() throws {
        let limit = try JSONDecoder().decode(
            SpendingLimit.self,
            from: Data(BankingEvent.mockSpendingLimitEvent.payload.utf8),
        )
        #expect(limit == SpendingLimit.mockWeeklyLimit)
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique by channel`() {
        #expect(!BankingEvent.mockDefaults.isEmpty)
        #expect(Set(BankingEvent.mockDefaults.map(\.channel)).count == BankingEvent.mockDefaults.count)
    }

    @Test func `mock payloads are valid json`() throws {
        for event in BankingEvent.mockDefaults {
            let object = try JSONSerialization.jsonObject(with: Data(event.payload.utf8))
            #expect(JSONSerialization.isValidJSONObject(object))
        }
    }
}
