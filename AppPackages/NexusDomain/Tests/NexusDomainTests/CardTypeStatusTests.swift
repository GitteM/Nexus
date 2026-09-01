import Entities
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
        }
    }

    @Test func `card status round trips through raw values`() throws {
        for status in CardStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(CardStatus.self, from: data)
            #expect(decoded == status)
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

    @Test func `card type raw values match wire contract`() {
        #expect(CardType.allCases.map(\.rawValue) == ["credit", "debit", "prepaid"])
    }

    @Test func `card status raw values match wire contract`() {
        #expect(CardStatus.allCases.map(\.rawValue) == ["active", "frozen", "expired", "lost"])
    }

    @Test func `unknown card type raw value throws`() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(CardType.self, from: Data(#""gold""#.utf8))
        }
    }

    @Test func `unknown card status raw value throws`() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(CardStatus.self, from: Data(#""blocked""#.utf8))
        }
    }

    // MARK: - Conveniences

    @Test func `display name matches wire contract`() {
        #expect(CardType.allCases.map(\.displayName) == ["Credit", "Debit", "Prepaid"])
        #expect(CardStatus.allCases.map(\.displayName) == ["Active", "Frozen", "Expired", "Lost"])
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
