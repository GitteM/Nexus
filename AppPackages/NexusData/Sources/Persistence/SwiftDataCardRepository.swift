import Entities
import Foundation
import SwiftData

/// SwiftData-backed durable store for the managed card list
/// (architecture.md §6.4, tasks.md Day 7).
///
/// This is the **store**, not the model-facing adapter: it maps `StoredCard`
/// records to and from domain `Card` structs and owns the `ModelContainer`.
/// Business rules on top (offer validation, duplicate rejection, operation
/// context) live in `Repositories.CardRepository`, which holds this store
/// (architecture.md §6.3: repositories are thin and hold a store).
///
/// `@Model` types never leave NexusData and never cross the repository
/// boundary (architecture.md §6.4): `StoredCard` is `internal`, the
/// container can only be created through `makeContainer` (which keeps the
/// schema under NexusData's control), and every public method speaks domain
/// structs.
///
/// The store is `Sendable`: it holds nothing but the `StoredCardModelActor`,
/// whose single background context performs every read and write (see the
/// actor's documentation for why reads share the write context).
public struct SwiftDataCardRepository: Sendable {
    private let store: StoredCardModelActor

    /// Builds the app's `ModelContainer` for the card schema.
    ///
    /// This is the composition root's entry point (architecture.md §11.2);
    /// tests and previews pass `storedInMemoryOnly: true`. The schema is
    /// private to NexusData — no caller outside `Persistence` can construct
    /// a container that references `StoredCard`.
    ///
    /// - Parameter storedInMemoryOnly: `true` backs the store in memory only
    ///   (tests, previews); `false` (the default) persists on disk. Demo mode
    ///   never constructs this store at all — demo state is in-memory mocks
    ///   (ROADMAP.md §5: persistence is a live-mode concern).
    public static func makeContainer(
        storedInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema([StoredCard.self])
        let configuration = ModelConfiguration(
            "Nexus",
            schema: schema,
            isStoredInMemoryOnly: storedInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public init(container: ModelContainer) {
        store = StoredCardModelActor(container: container)
    }

    // MARK: - Store operations

    /// Every managed card, in stable id order.
    public func fetchCards() async throws -> [Card] {
        try await store.fetchAll()
    }

    /// Persists `card`, replacing any stored record with the same id.
    public func insert(_ card: Card) async throws {
        try await store.upsert(card)
    }

    /// Removes the stored record for `cardId`; unknown ids are a no-op.
    public func delete(cardId: String) async throws {
        try await store.delete(cardId: cardId)
    }
}
