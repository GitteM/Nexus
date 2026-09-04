import Entities
import Foundation

/// The transaction detail screen's explicit UI state (architecture.md
/// §9.1–§9.2, tasks.md Day 13).
///
/// `.loaded` carries the transaction; `.missing` covers a stale deep link
/// whose transaction left the feed (rendered as an empty state, not an
/// error — the data is not wrong, it is gone); `.error` covers fetch
/// failures.
public enum TransactionDetailViewState: Equatable {
    case loading
    case loaded(Transaction)
    case missing
    case error(AppError)
}

public extension TransactionDetailViewState {
    var error: AppError? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}
