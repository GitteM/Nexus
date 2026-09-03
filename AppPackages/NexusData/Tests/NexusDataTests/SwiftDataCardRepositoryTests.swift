import Entities
import Foundation
@testable import Persistence
import SwiftData
import Testing

/// Integration tests over the real SwiftData stack (tasks.md Day 7):
/// `StoredCard` @Model records through a real in-memory `ModelContainer`,
/// the hand-written `StoredCardModelActor`, and `SwiftDataCardRepository`.
///
/// No mocks — every test builds the real container via
/// `SwiftDataCardRepository.makeContainer(storedInMemoryOnly: true)` and
/// drives the real store facade.
@Suite("SwiftDataCardRepository")
struct SwiftDataCardRepositoryTests {
    /// Fresh in-memory repository per test.
    private func makeRepository() throws -> SwiftDataCardRepository {
        let container = try SwiftDataCardRepository.makeContainer(storedInMemoryOnly: true)
        return SwiftDataCardRepository(container: container)
    }

    private var sampleCard: Card {
        Card(
            id: "card-credit-001",
            cardholderName: "Jordan Avery",
            lastFourDigits: "4821",
            type: .credit,
            status: .active,
            currency: "EUR",
            spendingLimit: 2500,
        )
    }

    // MARK: - Round-trips

    @Test
    func `empty store fetches no cards`() async throws {
        let repository = try makeRepository()
        let cards = try await repository.fetchCards()
        #expect(cards.isEmpty)
    }

    @Test
    func `insert then fetch round trips card`() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)

        let cards = try await repository.fetchCards()
        #expect(cards == [card])
    }

    @Test
    func `round trip preserves optional limit`() async throws {
        let repository = try makeRepository()
        var card = sampleCard
        card = Card(
            id: card.id,
            cardholderName: card.cardholderName,
            lastFourDigits: card.lastFourDigits,
            type: card.type,
            status: card.status,
            currency: card.currency,
            spendingLimit: nil,
        )
        try await repository.insert(card)
        #expect(try await repository.fetchCards() == [card])
    }

    @Test
    func `round trip preserves enum raw values`() async throws {
        let repository = try makeRepository()
        // Every CardType and CardStatus must survive a store round-trip.
        for type in CardType.allCases {
            for status in CardStatus.allCases {
                let card = Card(
                    id: "card-\(type.rawValue)-\(status.rawValue)",
                    cardholderName: "Jordan Avery",
                    lastFourDigits: "0001",
                    type: type,
                    status: status,
                    currency: "EUR",
                    spendingLimit: nil,
                )
                try await repository.insert(card)
            }
        }
        let cards = try await repository.fetchCards()
        #expect(cards.count == CardType.allCases.count * CardStatus.allCases.count)
        #expect(cards.contains { $0.type == .prepaid && $0.status == .lost })
    }

    @Test
    func `fetch is stable ordered by id`() async throws {
        let repository = try makeRepository()
        let cardB = Card(
            id: "b", cardholderName: "B", lastFourDigits: "0002",
            type: .debit, status: .active, currency: "EUR", spendingLimit: nil,
        )
        let cardA = Card(
            id: "a", cardholderName: "A", lastFourDigits: "0001",
            type: .credit, status: .active, currency: "EUR", spendingLimit: nil,
        )
        try await repository.insert(cardB)
        try await repository.insert(cardA)
        #expect(try await repository.fetchCards() == [cardA, cardB])
    }

    // MARK: - Writes

    @Test
    func `insert with same id updates in place`() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)

        let updated = Card(
            id: card.id,
            cardholderName: card.cardholderName,
            lastFourDigits: card.lastFourDigits,
            type: card.type,
            status: .frozen,
            currency: card.currency,
            spendingLimit: 500,
        )
        try await repository.insert(updated)

        let cards = try await repository.fetchCards()
        #expect(cards.count == 1)
        #expect(cards.first == updated)
    }

    @Test
    func `insertIfAbsent inserts once and reports existing id`() async throws {
        let repository = try makeRepository()
        #expect(try await repository.insertIfAbsent(sampleCard) == true)

        // A later insert with the same id reports the duplicate and leaves
        // the first record untouched (it is not an upsert).
        let changed = Card(
            id: sampleCard.id,
            cardholderName: "Someone Else",
            lastFourDigits: "0000",
            type: .prepaid,
            status: .frozen,
            currency: "USD",
            spendingLimit: 1,
        )
        #expect(try await repository.insertIfAbsent(changed) == false)
        #expect(try await repository.fetchCards() == [sampleCard])
    }

    @Test
    func `concurrent insertIfAbsent with the same id inserts once`() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        let attempts = 20

        let outcomes = await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< attempts {
                group.addTask {
                    await (try? repository.insertIfAbsent(card)) ?? false
                }
            }
            var inserted = 0
            for await outcome in group where outcome {
                inserted += 1
            }
            return inserted
        }

        // The actor serializes the check-then-insert, so exactly one
        // concurrent caller wins; the record is stored once.
        #expect(outcomes == 1)
        #expect(try await repository.fetchCards() == [card])
    }

    @Test
    func `delete removes card`() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)
        try await repository.delete(cardId: card.id)
        #expect(try await repository.fetchCards().isEmpty)
    }

    @Test
    func `delete unknown id is A no op`() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)
        try await repository.delete(cardId: "card-that-never-existed")
        #expect(try await repository.fetchCards() == [card])
    }

    // MARK: - Mapping corruption

    @Test
    func `corrupted type raw surfaces persistence error`() {
        // @Model records are internal; the corruption path (a stored raw
        // value that no longer maps to a domain enum) is tested directly on
        // the mapping so no SwiftData context is needed.
        let stored = StoredCard(card: sampleCard)
        stored.typeRaw = "banana"
        #expect(throws: AppError.self) {
            try stored.toDomain()
        }
        do {
            _ = try stored.toDomain()
            Issue.record("Expected a persistence error for corrupt type raw.")
        } catch let error as AppError {
            #expect(error.category == .data)
            guard case let .persistenceError(operation, _) = error else {
                Issue.record("Expected .persistenceError, got \(error).")
                return
            }
            #expect(operation == "read_card")
        } catch {
            Issue.record("Expected AppError, got \(error).")
        }
    }

    @Test
    func `corrupted status raw surfaces persistence error`() throws {
        let stored = StoredCard(card: sampleCard)
        stored.statusRaw = "repossessed"
        #expect(throws: AppError.self) {
            try stored.toDomain()
        }
    }
}
