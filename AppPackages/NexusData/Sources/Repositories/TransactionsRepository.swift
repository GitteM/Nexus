import DataSources
import Entities
import RepositoryProtocols

/// Domain-facing implementation of `TransactionRepositoryProtocol`
/// (architecture.md §6.3, tasks.md Day 13): a thin wrapper over the
/// `CardTransactionsDataSource` actor that adds boundary validation and
/// owns the error contract models rely on.
///
/// The data source keeps the per-card, newest-first transaction lists,
/// parses `card.events.{cardId}` frames, and owns the live streams (§6.1);
/// this repository adds no business rules — it validates the `cardId` every
/// method takes (so an empty id fails fast with
/// `AppError.validationError`) and rethrows the source's `AppError`s
/// untouched. A non-`AppError` escaping the source would be a Data-layer
/// bug; it is mapped defensively to `AppError.unknown` (architecture.md §5).
public struct TransactionsRepository: TransactionRepositoryProtocol, Sendable {
    private let source: CardTransactionsDataSource

    public init(source: CardTransactionsDataSource) {
        self.source = source
    }

    /// The current transaction list for one card, newest first.
    public func getTransactions(cardId: String) async throws -> [Transaction] {
        try Self.validate(cardId)
        return await source.getTransactions(cardId: cardId)
    }

    /// Subscribes to one card's transaction feed; the stream yields the
    /// current list first, then the updated list after every new frame.
    public func subscribeToTransactions(cardId: String) async throws -> AsyncStream<[Transaction]> {
        try Self.validate(cardId)
        do {
            return try await source.subscribeToTransactions(cardId: cardId)
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
