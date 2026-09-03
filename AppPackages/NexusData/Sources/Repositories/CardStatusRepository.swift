import DataSources
import Entities
import RepositoryProtocols

/// Domain-facing implementation of `CardStatusRepositoryProtocol`
/// (architecture.md §6.3, tasks.md Day 7): a thin wrapper over the
/// `CardStateDataSource` actor that adds boundary validation and owns the
/// error contract models rely on.
///
/// The data source keeps the per-id cache, parses `card.events.{cardId}`
/// frames, and owns the live stream (architecture.md §6.1); this repository
/// adds no business rules — it validates the `cardId` every method takes
/// (so an empty id fails fast with `AppError.validationError` instead of
/// reading an empty channel) and rethrows the source's `AppError`s
/// untouched. A non-`AppError` escaping the source would be a Data-layer
/// bug; it is mapped defensively to `AppError.unknown` so the boundary
/// still speaks one error type (architecture.md §5).
public struct CardStatusRepository: CardStatusRepositoryProtocol, Sendable {
    private let source: CardStateDataSource

    public init(source: CardStateDataSource) {
        self.source = source
    }

    /// The latest known status for one card, or `nil` when no status has
    /// arrived on the wire yet (cache read — no network round-trip).
    public func getCardStatus(cardId: String) async throws -> CardState? {
        try Self.validate(cardId)
        return await source.getCardStatus(cardId: cardId)
    }

    /// Subscribes to one card's status updates; the stream yields the
    /// current cached state first, then live updates (architecture.md §4.2).
    public func subscribeToCardStatus(cardId: String) async throws -> AsyncStream<CardState> {
        try Self.validate(cardId)
        do {
            return try await source.subscribeToCardStatus(cardId: cardId)
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unknown(underlying: error)
        }
    }

    /// Rejects ids the app must never put on the wire or in a channel name.
    private static func validate(_ cardId: String) throws {
        guard !cardId.isEmpty else {
            throw AppError.validationError(
                field: "cardId",
                reason: "Card id must not be empty."
            )
        }
    }
}
