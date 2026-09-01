import Foundation

/// A card a customer can add from the dashboard offers row.
///
/// An offer carries the marketing copy (`title`, `subtitle`, `benefits`) plus
/// the attributes needed to build a managed `Card` when the customer adds it.
public struct CardOffer: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let type: CardType
    public let currency: String
    public let annualFee: Decimal?
    public let benefits: [String]

    public init(
        id: String,
        title: String,
        subtitle: String,
        type: CardType,
        currency: String,
        annualFee: Decimal?,
        benefits: [String],
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.currency = currency
        self.annualFee = annualFee
        self.benefits = benefits
    }
}

public extension CardOffer {
    static let mockCashbackOffer = CardOffer(
        id: "offer-cashback-001",
        title: "Cashback Card",
        subtitle: "2% back on every purchase, no annual fee",
        type: .credit,
        currency: "EUR",
        annualFee: nil,
        benefits: ["2% cashback on everything", "No foreign transaction fees"],
    )

    static let mockTravelOffer = CardOffer(
        id: "offer-travel-001",
        title: "Travel Rewards Card",
        subtitle: "Earn 3x points on travel and dining",
        type: .credit,
        currency: "EUR",
        annualFee: 95,
        benefits: ["3x points on travel", "Airport lounge access"],
    )

    static let mockPrepaidOffer = CardOffer(
        id: "offer-prepaid-001",
        title: "Everyday Prepaid Card",
        subtitle: "Load and spend with no credit check",
        type: .prepaid,
        currency: "EUR",
        annualFee: nil,
        benefits: ["No credit check", "Instant top-up"],
    )

    /// Demo/default offer set for previews and tests.
    static var mockDefaults: [CardOffer] {
        [.mockCashbackOffer, .mockTravelOffer, .mockPrepaidOffer]
    }
}
