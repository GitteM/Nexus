import Foundation

/// Live per-card state, decoded from the event stream (architecture.md §4.1).
///
/// `CardState` is what `CardStatusRepository` subscribes to: the current
/// lifecycle status of one card. Balances and spending limits travel as
/// their own entities (`Balance`, `SpendingLimit`) on separate channels.
public struct CardState: Codable, Sendable, Equatable, Identifiable {
    public let cardId: String
    public let status: CardStatus

    public var id: String {
        cardId
    }

    public init(cardId: String, status: CardStatus) {
        self.cardId = cardId
        self.status = status
    }
}

public extension CardState {
    static let mockActiveState = CardState(cardId: "card-credit-001", status: .active)

    static let mockFrozenState = CardState(cardId: "card-credit-002", status: .frozen)

    static let mockLostState = CardState(cardId: "card-credit-004", status: .lost)

    /// Demo/default state set covering the statuses a live card can move
    /// through (expired is terminal and never arrives as an update).
    static var mockDefaults: [CardState] {
        [.mockActiveState, .mockFrozenState, .mockLostState]
    }
}
