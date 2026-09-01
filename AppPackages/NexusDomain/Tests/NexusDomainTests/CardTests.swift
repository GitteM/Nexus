@testable import Entities
import Foundation
import Testing

@Suite("Card")
struct CardTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let card = Card(
            id: "card-1",
            cardholderName: "Avery Jordan",
            lastFourDigits: "1234",
            type: .debit,
            status: .active,
            currency: "EUR",
            spendingLimit: 500,
        )
        #expect(card.id == "card-1")
        #expect(card.cardholderName == "Avery Jordan")
        #expect(card.lastFourDigits == "1234")
        #expect(card.type == .debit)
        #expect(card.status == .active)
        #expect(card.currency == "EUR")
        #expect(card.spendingLimit == 500)
    }

    @Test func `spending limit is optional`() {
        let card = Card(
            id: "card-2",
            cardholderName: "Avery Jordan",
            lastFourDigits: "5678",
            type: .credit,
            status: .active,
            currency: "EUR",
            spendingLimit: nil,
        )
        #expect(card.spendingLimit == nil)
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = Card(
            id: "card-1",
            cardholderName: "Avery Jordan",
            lastFourDigits: "1234",
            type: .debit,
            status: .active,
            currency: "EUR",
            spendingLimit: 500,
        )
        let same = Card(
            id: "card-1",
            cardholderName: "Avery Jordan",
            lastFourDigits: "1234",
            type: .debit,
            status: .active,
            currency: "EUR",
            spendingLimit: 500,
        )
        let different = Card(
            id: "card-9",
            cardholderName: "Avery Jordan",
            lastFourDigits: "1234",
            type: .debit,
            status: .active,
            currency: "EUR",
            spendingLimit: 500,
        )
        #expect(a == same)
        #expect(a != different)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let card = Card(
            id: "card-rt",
            cardholderName: "Avery Jordan",
            lastFourDigits: "8888",
            type: .prepaid,
            status: .frozen,
            currency: "EUR",
            spendingLimit: 1250.50,
        )
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(Card.self, from: data)
        #expect(decoded == card)
        #expect(decoded.spendingLimit == 1250.50)
    }

    @Test func `codable round trip with nil spending limit`() throws {
        let card = Card(
            id: "card-rt-nil",
            cardholderName: "Avery Jordan",
            lastFourDigits: "0001",
            type: .debit,
            status: .active,
            currency: "EUR",
            spendingLimit: nil,
        )
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(Card.self, from: data)
        #expect(decoded == card)
        #expect(decoded.spendingLimit == nil)
    }

    @Test func `decoding missing optional spending limit succeeds`() throws {
        let json = Data(
            #"""
            {"id":"c1","cardholderName":"Avery Jordan","lastFourDigits":"4242",
             "type":"credit","status":"active","currency":"EUR"}
            """#.utf8,
        )
        let decoded = try JSONDecoder().decode(Card.self, from: json)
        #expect(decoded.spendingLimit == nil)
        #expect(decoded.status == .active)
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique`() {
        #expect(!Card.mockDefaults.isEmpty)
        #expect(Set(Card.mockDefaults.map(\.id)).count == Card.mockDefaults.count)
    }

    @Test func `mock defaults cover every card type`() {
        #expect(Set(Card.mockDefaults.map(\.type)) == Set(CardType.allCases))
    }

    @Test func `mock defaults cover every card status`() {
        #expect(Set(Card.mockDefaults.map(\.status)) == Set(CardStatus.allCases))
    }

    @Test func `mock last four digits are four digits`() {
        for card in Card.mockDefaults {
            #expect(card.lastFourDigits.count == 4)
            // Key-path form (allSatisfy(\.isNumber)) breaks Swift Testing's #expect
            // macro expansion on this toolchain, so keep the closure.
            // swiftformat:disable:next preferKeyPath
            #expect(card.lastFourDigits.allSatisfy { $0.isNumber })
        }
    }

    @Test func `mock cardholder name is consistent`() {
        let names = Set(Card.mockDefaults.map(\.cardholderName))
        #expect(names.count == 1)
    }
}
