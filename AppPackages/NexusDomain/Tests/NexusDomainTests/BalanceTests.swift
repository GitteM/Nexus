import Entities
import Foundation
import Testing

@Suite("Balance")
struct BalanceTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let balance = Balance(
            cardId: "card-1",
            current: 100,
            available: 90,
            creditLimit: 500,
            currency: "EUR",
        )
        #expect(balance.cardId == "card-1")
        #expect(balance.current == 100)
        #expect(balance.available == 90)
        #expect(balance.creditLimit == 500)
        #expect(balance.currency == "EUR")
        #expect(balance.id == "card-1")
    }

    @Test func `credit limit is optional`() {
        let balance = Balance(
            cardId: "card-2",
            current: 100,
            available: 100,
            creditLimit: nil,
            currency: "EUR",
        )
        #expect(balance.creditLimit == nil)
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = Balance(
            cardId: "card-1",
            current: 100,
            available: 90,
            creditLimit: 500,
            currency: "EUR",
        )
        let same = Balance(
            cardId: "card-1",
            current: 100,
            available: 90,
            creditLimit: 500,
            currency: "EUR",
        )
        let different = Balance(
            cardId: "card-9",
            current: 100,
            available: 90,
            creditLimit: 500,
            currency: "EUR",
        )
        #expect(a == same)
        #expect(a != different)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let balance = Balance(
            cardId: "card-rt",
            current: 1240.75,
            available: 1259.25,
            creditLimit: Decimal(string: "2500.00"),
            currency: "EUR",
        )
        let data = try JSONEncoder().encode(balance)
        let decoded = try JSONDecoder().decode(Balance.self, from: data)
        #expect(decoded == balance)
        #expect(decoded.creditLimit == Decimal(string: "2500.00"))
    }

    @Test func `codable round trip with nil credit limit`() throws {
        let balance = Balance(
            cardId: "card-rt-nil",
            current: 482.30,
            available: 482.30,
            creditLimit: nil,
            currency: "EUR",
        )
        let data = try JSONEncoder().encode(balance)
        let decoded = try JSONDecoder().decode(Balance.self, from: data)
        #expect(decoded == balance)
        #expect(decoded.creditLimit == nil)
    }

    @Test func `decoding missing optional credit limit succeeds`() throws {
        let json = Data(
            #"""
            {"cardId":"c1","current":100,"available":100,"currency":"EUR"}
            """#.utf8,
        )
        let decoded = try JSONDecoder().decode(Balance.self, from: json)
        #expect(decoded.creditLimit == nil)
        #expect(decoded.current == 100)
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique`() {
        #expect(!Balance.mockDefaults.isEmpty)
        #expect(Set(Balance.mockDefaults.map(\.id)).count == Balance.mockDefaults.count)
    }

    @Test func `mock amounts are non negative`() {
        for balance in Balance.mockDefaults {
            #expect(balance.current >= 0)
            #expect(balance.available >= 0)
        }
    }

    @Test func `mock currency is EUR`() {
        for balance in Balance.mockDefaults {
            #expect(balance.currency == "EUR")
        }
    }

    @Test func `mock credit limit is never below available`() {
        for balance in Balance.mockDefaults {
            if let creditLimit = balance.creditLimit {
                #expect(creditLimit >= balance.available)
            }
        }
    }

    @Test func `mock card ids match card mocks`() {
        #expect(Balance.mockCreditBalance.cardId == Card.mockCreditCard.id)
        #expect(Balance.mockDebitBalance.cardId == Card.mockDebitCard.id)
    }
}
