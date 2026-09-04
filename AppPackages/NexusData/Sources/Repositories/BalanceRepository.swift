import DataSources
import Entities
import RepositoryProtocols

/// Domain-facing implementation of `BalanceRepositoryProtocol`
/// (architecture.md §6.3, tasks.md Day 13): a thin wrapper over the
/// `CardBalanceDataSource` actor that adds boundary validation and owns the
/// error contract models rely on.
///
/// The data source keeps the per-card balance cache, parses
/// `card.events.{cardId}` frames, and owns the live stream (§6.1); this
/// repository adds no business rules — it validates the `cardId` every
/// method takes (so an empty id fails fast with
/// `AppError.validationError`) and rethrows the source's `AppError`s
/// untouched. A non-`AppError` escaping the source would be a Data-layer
/// bug; it is mapped defensively to `AppError.unknown` (architecture.md §5).
public struct BalanceRepository: BalanceRepositoryProtocol, Sendable {
    private let source: CardBalanceDataSource

    public init(source: CardBalanceDataSource) {
        self.source = source
    }

    /// The latest known balance for one card, or `nil` when none has
    /// arrived on the wire yet (cache read — no network round-trip).
    public func getBalance(cardId: String) async throws -> Balance? {
        try Self.validate(cardId)
        return await source.getBalance(cardId: cardId)
    }

    /// Subscribes to one card's balance updates; the stream yields the
    /// current cached value first, then live updates (§4.2).
    public func subscribeToBalance(cardId: String) async throws -> AsyncStream<Balance> {
        try Self.validate(cardId)
        do {
            return try await source.subscribeToBalance(cardId: cardId)
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
                reason: "Card id must not be empty.",
            )
        }
    }
}
