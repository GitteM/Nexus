@testable import Entities
import Foundation
import Testing

@Suite("CardType and CardStatus")
struct CardTypeStatusTests {
    // MARK: - Codable

    @Test func `card type round trips through raw values`() throws {
        for type in CardType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(CardType.self, from: data)
            #expect(decoded == type)
            #expect(type.rawValue == type.rawValue.lowercased())
        }
    }

    @Test func `card status round trips through raw values`() throws {
        for status in CardStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(CardStatus.self, from: data)
            #expect(decoded == status)
            #expect(status.rawValue == status.rawValue.lowercased())
        }
    }

    @Test func `card type decodes from wire name`() throws {
        let decoded = try JSONDecoder().decode(CardType.self, from: Data(#""credit""#.utf8))
        #expect(decoded == .credit)
    }

    @Test func `card status decodes from wire name`() throws {
        let decoded = try JSONDecoder().decode(CardStatus.self, from: Data(#""frozen""#.utf8))
        #expect(decoded == .frozen)
    }

    // MARK: - Conveniences

    @Test func `display name is non empty for all cases`() {
        for type in CardType.allCases {
            #expect(!type.displayName.isEmpty)
        }
        for status in CardStatus.allCases {
            #expect(!status.displayName.isEmpty)
        }
    }

    @Test func `icon is non empty for all cases`() {
        for type in CardType.allCases {
            #expect(!type.icon.isEmpty)
        }
        for status in CardStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    // MARK: - Case coverage

    @Test func `card type covers expected kinds`() {
        #expect(CardType.allCases == [.credit, .debit, .prepaid])
    }

    @Test func `card status covers expected kinds`() {
        #expect(CardStatus.allCases == [.active, .frozen, .expired, .lost])
    }
}
