import Entities

/// Offers the dashboard promotes in its offers row.
///
/// An offer becomes a managed `Card` when the customer adds it through
/// `CardRepositoryProtocol.addCard`. Live offer changes arrive on the
/// `card.offers` channel.
public protocol CardOffersRepositoryProtocol: Sendable {
    /// Fetches the offers available right now.
    func getAvailableOffers() async throws -> [CardOffer]

    /// Subscribes to the offer list; the stream yields the current offers
    /// first, then updates as they change.
    ///
    /// Throws `AppError` when the subscription cannot be set up.
    func subscribeToOffers() async throws -> AsyncStream<[CardOffer]>
}
