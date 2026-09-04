import Entities
import Foundation
import Observation
import RepositoryProtocols

/// Owns the transaction detail screen for one transaction (architecture.md
/// §9.1, tasks.md Day 13).
///
/// The screen is a static deep view: it fetches the card's feed once and
/// picks the transaction by id (there is no get-by-id on the boundary).
/// A stale deep link whose transaction left the feed lands in `.missing`
/// (an empty state, not an error); a failed fetch lands `.error` with the
/// standard retry path. Live updates are unnecessary on a snapshot detail
/// screen in v1.0 — the list screen above stays live.
@MainActor
@Observable
public final class TransactionDetailModel {
    public private(set) var viewState: TransactionDetailViewState = .loading

    private let cardID: String
    private let transactionID: String
    private let transactionRepository: TransactionRepositoryProtocol
    private var isLoadInFlight = false

    public init(
        cardID: String,
        transactionID: String,
        transactionRepository: TransactionRepositoryProtocol,
    ) {
        self.cardID = cardID
        self.transactionID = transactionID
        self.transactionRepository = transactionRepository
    }

    /// Idempotent initial load; refires on every appear and retries from
    /// `.error`. The feed is fetched once and the matching transaction
    /// picked out — a missing id maps to `.missing`.
    public func load() async {
        guard !isLoadInFlight, !isSettled else { return }
        isLoadInFlight = true
        defer { isLoadInFlight = false }
        viewState = .loading
        do {
            let transactions = try await transactionRepository.getTransactions(cardId: cardID)
            guard let transaction = transactions.first(where: { $0.id == transactionID }) else {
                viewState = .missing
                return
            }
            viewState = .loaded(transaction)
        } catch is CancellationError {
            // The triggering view task was cancelled mid-load; the next
            // appear refires load().
        } catch let error as AppError {
            viewState = .error(error)
        } catch {
            viewState = .error(.unknown(underlying: error))
        }
    }

    /// True once a transaction (or the missing state) is on screen.
    private var isSettled: Bool {
        switch viewState {
        case .loading, .error:
            false
        case .loaded, .missing:
            true
        }
    }
}
