@testable import Entities
import Foundation
import Testing

@Suite("CardOffer")
struct CardOfferTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let offer = CardOffer(
            id: "offer-1",
            title: "Cashback Card",
            subtitle: "2% back",
            type: .credit,
            currency: "EUR",
            annualFee: nil,
            benefits: ["2% cashback"],
        )
        #expect(offer.id == "offer-1")
        #expect(offer.title == "Cashback Card")
        #expect(offer.subtitle == "2% back")
        #expect(offer.type == .credit)
        #expect(offer.currency == "EUR")
        #expect(offer.annualFee == nil)
        #expect(offer.benefits == ["2% cashback"])
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = CardOffer(
            id: "offer-1",
            title: "Cashback Card",
            subtitle: "2% back",
            type: .credit,
            currency: "EUR",
            annualFee: nil,
            benefits: ["2% cashback"],
        )
        let same = CardOffer(
            id: "offer-1",
            title: "Cashback Card",
            subtitle: "2% back",
            type: .credit,
            currency: "EUR",
            annualFee: nil,
            benefits: ["2% cashback"],
        )
        let different = CardOffer(
            id: "offer-2",
            title: "Cashback Card",
            subtitle: "2% back",
            type: .credit,
            currency: "EUR",
            annualFee: nil,
            benefits: ["2% cashback"],
        )
        #expect(a == same)
        #expect(a != different)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let offer = CardOffer(
            id: "offer-rt",
            title: "Travel Rewards Card",
            subtitle: "3x points on travel",
            type: .credit,
            currency: "EUR",
            annualFee: 95,
            benefits: ["3x points", "Lounge access"],
        )
        let data = try JSONEncoder().encode(offer)
        let decoded = try JSONDecoder().decode(CardOffer.self, from: data)
        #expect(decoded == offer)
        #expect(decoded.annualFee == 95)
    }

    @Test func `codable round trip with nil annual fee`() throws {
        let offer = CardOffer(
            id: "offer-rt-nil",
            title: "Everyday Prepaid Card",
            subtitle: "No credit check",
            type: .prepaid,
            currency: "EUR",
            annualFee: nil,
            benefits: [],
        )
        let data = try JSONEncoder().encode(offer)
        let decoded = try JSONDecoder().decode(CardOffer.self, from: data)
        #expect(decoded == offer)
        #expect(decoded.annualFee == nil)
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique`() {
        #expect(!CardOffer.mockDefaults.isEmpty)
        #expect(Set(CardOffer.mockDefaults.map(\.id)).count == CardOffer.mockDefaults.count)
    }

    @Test func `mock defaults have titles and subtitles`() {
        for offer in CardOffer.mockDefaults {
            #expect(!offer.title.isEmpty)
            #expect(!offer.subtitle.isEmpty)
        }
    }

    @Test func `mock defaults cover multiple card types`() {
        #expect(Set(CardOffer.mockDefaults.map(\.type)).count >= 2)
    }
}
