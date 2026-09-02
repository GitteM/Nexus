import Entities

/// Executes outgoing card actions (architecture.md §4.2).
///
/// Covers freeze/unfreeze, report lost/stolen, replacement requests, and
/// spending-limit changes — all expressed as `CardCommand` values. The
/// resulting state arrives through the live event streams
/// (`CardStatusRepositoryProtocol.subscribeToCardStatus` for status,
/// `BankingEvent` channels for limits); implementations also apply the change
/// to their store so later reads reflect it.
public protocol CardActionRepositoryProtocol {
    /// Sends one card command to the backend.
    ///
    /// Throws `AppError.cardActionFailed` (or a more specific error) when the
    /// action is rejected.
    func execute(_ command: CardCommand) async throws
}
