import Entities
import Foundation
import Testing

@Suite("SpendingLimit")
struct SpendingLimitTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let limit = SpendingLimit(
            cardId: "card-1",
            period: .weekly,
            amount: 500,
            currency: "EUR",
        )
        #expect(limit.cardId == "card-1")
        #expect(limit.period == .weekly)
        #expect(limit.amount == 500)
        #expect(limit.currency == "EUR")
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = SpendingLimit(
            cardId: "card-1",
            period: .weekly,
            amount: 500,
            currency: "EUR",
        )
        let same = SpendingLimit(
            cardId: "card-1",
            period: .weekly,
            amount: 500,
            currency: "EUR",
        )
        let different = SpendingLimit(
            cardId: "card-1",
            period: .monthly,
            amount: 500,
            currency: "EUR",
        )
        #expect(a == same)
        #expect(a != different)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let limit = SpendingLimit(
            cardId: "card-rt",
            period: .daily,
            amount: 125.50,
            currency: "EUR",
        )
        let data = try JSONEncoder().encode(limit)
        let decoded = try JSONDecoder().decode(SpendingLimit.self, from: data)
        #expect(decoded == limit)
        #expect(decoded.amount == Decimal(string: "125.50"))
    }

    @Test func `decodes from wire json`() throws {
        let json = Data(#"{"cardId":"c1","period":"monthly","amount":2000,"currency":"EUR"}"#.utf8)
        let decoded = try JSONDecoder().decode(SpendingLimit.self, from: json)
        #expect(decoded.period == .monthly)
        #expect(decoded.amount == 2000)
    }

    // MARK: - Period enum

    @Test func `period round trips through raw values`() throws {
        for period in SpendingLimitPeriod.allCases {
            let data = try JSONEncoder().encode(period)
            let decoded = try JSONDecoder().decode(SpendingLimitPeriod.self, from: data)
            #expect(decoded == period)
        }
    }

    @Test func `period raw values match wire contract`() {
        #expect(SpendingLimitPeriod.allCases.map(\.rawValue) == ["daily", "weekly", "monthly"])
    }

    @Test func `period display names match wire contract`() {
        #expect(SpendingLimitPeriod.allCases.map(\.displayName) == ["Daily", "Weekly", "Monthly"])
    }

    // MARK: - Mocks

    @Test func `mock defaults cover every period`() {
        #expect(Set(SpendingLimit.mockDefaults.map(\.period)) == Set(SpendingLimitPeriod.allCases))
    }

    @Test func `mock amounts are positive and EUR`() {
        for limit in SpendingLimit.mockDefaults {
            #expect(limit.amount > 0)
            #expect(limit.currency == "EUR")
        }
    }

    @Test func `mock card id matches card mock`() {
        for limit in SpendingLimit.mockDefaults {
            #expect(limit.cardId == Card.mockCreditCard.id)
        }
    }
}
