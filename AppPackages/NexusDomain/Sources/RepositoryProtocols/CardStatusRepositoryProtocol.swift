import Entities

/// Tracks the live lifecycle status of managed cards (architecture.md §4.2).
///
/// Status updates arrive on the `card.events.{cardId}` channel
/// (architecture.md §11.4) and decode into `CardState`; `nil` from the
/// one-shot means no state is known for the card yet.
public protocol CardStatusRepositoryProtocol: Sendable {
    /// Returns the current status of one card, or `nil` when none is known.
    func getCardStatus(cardId: String) async throws -> CardState?

    /// Subscribes to one card's status; the stream yields the current state
    /// first, then updates as it changes.
    ///
    /// Throws `AppError` when the subscription cannot be set up.
    func subscribeToCardStatus(cardId: String) async throws -> AsyncStream<CardState>
}
