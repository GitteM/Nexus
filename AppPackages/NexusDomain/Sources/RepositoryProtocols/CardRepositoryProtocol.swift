import Entities

/// Manages the customer's managed cards.
///
/// One-shot calls are `async throws` and surface `AppError` — there is no
/// `Result` at this boundary. Live per-card updates do not flow through this
/// protocol: status changes arrive on the `card.events.{cardId}` channel via
/// `CardStatusRepositoryProtocol` subscriptions.
public protocol CardRepositoryProtocol: Sendable {
    /// Lists all managed cards.
    func getCards() async throws -> [Card]

    /// Turns an accepted `CardOffer` into a managed `Card`.
    ///
    /// Throws `AppError.cardAlreadyExists` when the offer is already managed.
    func addCard(_ offer: CardOffer) async throws -> Card

    /// Removes a managed card by id.
    func removeCard(cardId: String) async throws
}
