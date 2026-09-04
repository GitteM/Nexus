import Entities

/// Tracks one card's live balance.
///
/// Balance frames arrive on the `card.events.{cardId}` channel and decode
/// into `Balance`; `nil` from the one-shot means no balance is known for the
/// card yet. The balance is a per-card latest value — like
/// `CardStatusRepositoryProtocol`, the stream yields the current value
/// first, then updates.
public protocol BalanceRepositoryProtocol: Sendable {
    /// Returns the latest known balance for one card, or `nil` when none is
    /// known.
    func getBalance(cardId: String) async throws -> Balance?

    /// Subscribes to one card's balance; the stream yields the current
    /// value first, then updates as new frames arrive.
    ///
    /// Throws `AppError` when the subscription cannot be set up.
    func subscribeToBalance(cardId: String) async throws -> AsyncStream<Balance>
}
