import Entities
import Foundation
import SwiftData

/// Hand-written `ModelActor` for `StoredCard` background writes.
///
/// The iOS 17 floor has no `@ModelActor` macro (that lands with iOS 18), so
/// the actor is written by hand: it owns one `ModelContext` on the
/// container and confines every touch of the non-`Sendable` `StoredCard`
/// model to that single isolation domain — no `@unchecked Sendable`, no
/// `DispatchQueue` barriers.
///
/// **Why one context for reads *and* writes.** SwiftData's main context
/// merges saves from sibling contexts asynchronously; an
/// insert-then-immediately-fetch across contexts is therefore not
/// deterministic on the iOS 17 floor. The store facade routes every
/// operation through this actor's single context, so a write is visible to
/// the next read by construction — the same read-your-writes guarantee a
/// repository contract needs — while the write itself still happens on a
/// background executor, never the main actor. (`ModelContainer.mainContext`
/// remains available for any future `@Query`-style UI access; repository
/// code never uses it.)
///
/// Every method wraps thrown SwiftData errors as
/// `AppError.persistenceError(operation:details:)` — no raw `Error` crosses
/// this boundary.
actor StoredCardModelActor {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    // MARK: - Operations

    /// Every stored card, in stable `id` order.
    func fetchAll() throws -> [Card] {
        try wrap("read_cards") {
            let descriptor = FetchDescriptor<StoredCard>(
                sortBy: [SortDescriptor(\StoredCard.id)],
            )
            return try context.fetch(descriptor).map { try $0.toDomain() }
        }
    }

    /// Inserts `card`, or updates the stored record with the same id in
    /// place when one exists (idempotent write; the id is the natural key on
    /// the iOS 17 floor, where `#Unique` is unavailable).
    func upsert(_ card: Card) throws {
        try wrap("write_card") {
            if let existing = try existingRecord(id: card.id) {
                existing.apply(card)
            } else {
                context.insert(StoredCard(card: card))
            }
            try context.save()
        }
    }

    /// Inserts `card` only when no record with the same id exists. The
    /// existence check and the insert run in a single actor turn, so they
    /// cannot interleave with any other operation on this actor — concurrent
    /// `insertIfAbsent` calls for the same id yield exactly one insert
    /// (atomic duplicate rejection on the iOS 17 floor, where `#Unique` is
    /// unavailable).
    ///
    /// - Returns: `true` when `card` was inserted; `false` when a record
    ///   with the same id already exists (nothing changes).
    func insertIfAbsent(_ card: Card) throws -> Bool {
        try wrap("write_card") {
            guard try existingRecord(id: card.id) == nil else {
                return false
            }
            context.insert(StoredCard(card: card))
            try context.save()
            return true
        }
    }

    /// Deletes the stored record for `cardId` when one exists. Deleting an
    /// unknown id is a no-op (idempotent removal).
    func delete(cardId: String) throws {
        try wrap("delete_card") {
            let matches = try context.fetch(existingDescriptor(id: cardId))
            for match in matches {
                context.delete(match)
            }
            try context.save()
        }
    }

    // MARK: - Lookup

    /// The stored record for `cardId`, if any.
    private func existingRecord(id cardId: String) throws -> StoredCard? {
        try context.fetch(existingDescriptor(id: cardId)).first
    }

    /// A predicate descriptor matching the record for `cardId` (the id is
    /// the natural key — the schema has no `#Unique` on the iOS 17 floor).
    private func existingDescriptor(id cardId: String) -> FetchDescriptor<StoredCard> {
        FetchDescriptor<StoredCard>(
            predicate: #Predicate<StoredCard> { $0.id == cardId },
        )
    }

    // MARK: - Error wrapping

    /// Runs `body`, rethrowing `AppError` untouched and mapping anything
    /// else to `AppError.persistenceError` with the operation context.
    private func wrap<T>(_ operation: String, _ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.persistenceError(
                operation: operation,
                details: error.localizedDescription,
            )
        }
    }
}
