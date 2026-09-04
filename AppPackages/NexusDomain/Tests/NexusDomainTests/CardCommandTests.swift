import Entities
import Foundation
import Testing

@Suite("CardCommand and CardCommandType")
struct CardCommandTests {
    // MARK: - Factories

    @Test func `freeze factory`() {
        let command = CardCommand.freeze(cardId: "card-1")
        #expect(command.cardId == "card-1")
        #expect(command.type == .freeze)
        #expect(command.amount == nil)
        #expect(command.period == nil)
    }

    @Test func `unfreeze factory`() {
        let command = CardCommand.unfreeze(cardId: "card-1")
        #expect(command.cardId == "card-1")
        #expect(command.type == .unfreeze)
        #expect(command.amount == nil)
        #expect(command.period == nil)
    }

    @Test func `set spending limit factory carries amount and period`() {
        let command = CardCommand.setSpendingLimit(
            cardId: "card-1",
            period: .weekly,
            amount: 500,
        )
        #expect(command.cardId == "card-1")
        #expect(command.type == .setSpendingLimit)
        #expect(command.amount == 500)
        #expect(command.period == .weekly)
    }

    @Test func `memberwise init defaults payload to nil`() {
        let command = CardCommand(cardId: "card-1", type: .reportLost)
        #expect(command.amount == nil)
        #expect(command.period == nil)
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = CardCommand.freeze(cardId: "card-1")
        let same = CardCommand.freeze(cardId: "card-1")
        let different = CardCommand.unfreeze(cardId: "card-1")
        let differentLimit = CardCommand.setSpendingLimit(cardId: "card-1", period: .weekly, amount: 500)
        let otherLimit = CardCommand.setSpendingLimit(cardId: "card-1", period: .weekly, amount: 600)
        #expect(a == same)
        #expect(a != different)
        #expect(differentLimit != otherLimit)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let command = CardCommand.setSpendingLimit(
            cardId: "card-rt",
            period: .monthly,
            amount: 1500.00,
        )
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(CardCommand.self, from: data)
        #expect(decoded == command)
        #expect(decoded.amount == Decimal(string: "1500.00"))
    }

    @Test func `codable round trip without payload`() throws {
        let command = CardCommand(cardId: "card-rt", type: .requestReplacement)
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(CardCommand.self, from: data)
        #expect(decoded == command)
    }

    // MARK: - CardCommandType

    @Test func `type round trips through raw values`() throws {
        for type in CardCommandType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(CardCommandType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test func `type raw values match wire contract`() {
        #expect(
            CardCommandType.allCases.map(\.rawValue)
                == ["freeze", "unfreeze", "reportLost", "reportStolen", "requestReplacement", "setSpendingLimit", "unknown"],
        )
    }

    @Test func `unknown type raw value decodes to unknown instead of throwing`() throws {
        // Deliberate deviation from CardType/CardStatus: a new backend action
        // must not break decoding.
        let decoded = try JSONDecoder().decode(CardCommandType.self, from: Data(#""block""#.utf8))
        #expect(decoded == .unknown)
    }

    @Test func `display names are non empty for all cases`() {
        for type in CardCommandType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }
}
