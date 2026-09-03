import DataSources
import Entities
import RepositoryProtocols

/// Domain-facing implementation of `CardActionRepositoryProtocol`
/// (architecture.md §6.3, tasks.md Day 7): a thin wrapper over the
/// `CardActionDataSource` struct.
///
/// Validation of a `CardCommand` lives in the data source (architecture.md
/// §6.1 — it rejects empty card ids, `.unknown` types, and malformed
/// payloads before anything reaches the wire) and its errors are already
/// contextual `AppError`s: `.validationError` for commands that cannot be
/// sent, `.serializationError` when encoding fails, and the session's
/// `AppError` when the send fails. This repository rethrows them untouched,
/// adding no duplicate rules — it is the protocol boundary models receive,
/// so no model ever sees a `CardActionDataSource`.
public struct CardActionRepository: CardActionRepositoryProtocol, Sendable {
    private let source: CardActionDataSource

    public init(source: CardActionDataSource) {
        self.source = source
    }

    /// Sends one `CardCommand` (freeze, unfreeze, report lost/stolen,
    /// request replacement, set spending limit). The resulting state
    /// arrives back on the live `card.events.{cardId}` channel through
    /// `CardStatusRepositoryProtocol` (architecture.md §11.4).
    public func execute(_ command: CardCommand) async throws {
        try await source.execute(command)
    }
}
