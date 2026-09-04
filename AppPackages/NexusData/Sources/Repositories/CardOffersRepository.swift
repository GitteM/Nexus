import DataSources
import Entities
import RepositoryProtocols

/// Domain-facing implementation of `CardOffersRepositoryProtocol`: a thin
/// wrapper over the `OffersDataSource` actor.
///
/// The data source owns the TTL-bounded `card.offers` snapshot cache and
/// the live stream; this repository is the protocol
/// boundary models receive. It adds no validation or business rules — the
/// offer list has no per-call input to validate, and an empty result is a
/// legitimate "no fresh offers known" state, not an error (a stale snapshot
/// is dropped by the source, never served).
///
/// Both protocol requirements are declared `async throws`, and both
/// witnesses are non-throwing: the source cannot fail offer setup (there is
/// no id to reject), so a returned stream always means "subscribed".
public struct CardOffersRepository: CardOffersRepositoryProtocol, Sendable {
    private let source: OffersDataSource

    public init(source: OffersDataSource) {
        self.source = source
    }

    /// The offers available right now: the current fresh snapshot, or `[]`
    /// when none is cached. `[]` means "no fresh offers known" — a valid
    /// empty state for the dashboard row.
    public func getAvailableOffers() async -> [CardOffer] {
        await source.getAvailableOffers()
    }

    /// Subscribes to the offer list; the stream yields the current fresh
    /// snapshot first, then every replacement the backend publishes.
    public func subscribeToOffers() async -> AsyncStream<[CardOffer]> {
        await source.subscribeToOffers()
    }
}
