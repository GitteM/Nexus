import Entities

/// Provides one card's transaction feed.
///
/// Transaction frames arrive on the `card.events.{cardId}` channel and
/// decode into single `Transaction` values; the
/// feed is the per-card, newest-first list built from them. The one-shot
/// returns the current list and the subscription yields the *updated list*
/// every time a frame lands (snapshot semantics, like
/// `CardOffersRepositoryProtocol`) so models can republish a flat list.
public protocol TransactionRepositoryProtocol: Sendable {
    /// Returns the current transaction list for one card, newest first.
    func getTransactions(cardId: String) async throws -> [Transaction]

    /// Subscribes to one card's transaction feed; the stream yields the
    /// current list first, then the updated list after every new frame.
    ///
    /// Throws `AppError` when the subscription cannot be set up.
    func subscribeToTransactions(cardId: String) async throws
        -> AsyncStream<[Transaction]>
}
