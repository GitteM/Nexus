import Entities
import Foundation
import Testing

@Suite("CardState")
struct CardStateTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let state = CardState(cardId: "card-1", status: .frozen)
        #expect(state.cardId == "card-1")
        #expect(state.status == .frozen)
        #expect(state.id == "card-1")
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        #expect(CardState(cardId: "card-1", status: .frozen) == CardState(cardId: "card-1", status: .frozen))
        #expect(CardState(cardId: "card-1", status: .frozen) != CardState(cardId: "card-1", status: .active))
        #expect(CardState(cardId: "card-1", status: .frozen) != CardState(cardId: "card-2", status: .frozen))
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let state = CardState(cardId: "card-rt", status: .lost)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CardState.self, from: data)
        #expect(decoded == state)
    }

    @Test func `decodes from wire json`() throws {
        let json = Data(#"{"cardId":"c1","status":"active"}"#.utf8)
        let decoded = try JSONDecoder().decode(CardState.self, from: json)
        #expect(decoded.cardId == "c1")
        #expect(decoded.status == .active)
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique`() {
        #expect(!CardState.mockDefaults.isEmpty)
        #expect(Set(CardState.mockDefaults.map(\.id)).count == CardState.mockDefaults.count)
    }

    @Test func `mock card ids match card mocks`() {
        #expect(CardState.mockActiveState.cardId == Card.mockCreditCard.id)
        #expect(CardState.mockFrozenState.cardId == Card.mockFrozenCard.id)
        #expect(CardState.mockLostState.cardId == Card.mockLostCard.id)
    }

    @Test func `mock statuses match their card statuses`() {
        #expect(CardState.mockActiveState.status == Card.mockCreditCard.status)
        #expect(CardState.mockFrozenState.status == Card.mockFrozenCard.status)
        #expect(CardState.mockLostState.status == Card.mockLostCard.status)
    }
}
