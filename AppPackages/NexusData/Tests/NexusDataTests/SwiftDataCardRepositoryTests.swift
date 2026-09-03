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
            spendingLimit: 2500
        )
    }

    // MARK: - Round-trips

    @Test
    func emptyStoreFetchesNoCards() async throws {
        let repository = try makeRepository()
        let cards = try await repository.fetchCards()
        #expect(cards.isEmpty)
    }

    @Test
    func insertThenFetchRoundTripsCard() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)

        let cards = try await repository.fetchCards()
        #expect(cards == [card])
    }

    @Test
    func roundTripPreservesOptionalLimit() async throws {
        let repository = try makeRepository()
        var card = sampleCard
        card = Card(
            id: card.id,
            cardholderName: card.cardholderName,
            lastFourDigits: card.lastFourDigits,
            type: card.type,
            status: card.status,
            currency: card.currency,
            spendingLimit: nil
        )
        try await repository.insert(card)
        #expect(try await repository.fetchCards() == [card])
    }

    @Test
    func roundTripPreservesEnumRawValues() async throws {
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
                    spendingLimit: nil
                )
                try await repository.insert(card)
            }
        }
        let cards = try await repository.fetchCards()
        #expect(cards.count == CardType.allCases.count * CardStatus.allCases.count)
        #expect(cards.contains { $0.type == .prepaid && $0.status == .lost })
    }

    @Test
    func fetchIsStableOrderedById() async throws {
        let repository = try makeRepository()
        let cardB = Card(
            id: "b", cardholderName: "B", lastFourDigits: "0002",
            type: .debit, status: .active, currency: "EUR", spendingLimit: nil
        )
        let cardA = Card(
            id: "a", cardholderName: "A", lastFourDigits: "0001",
            type: .credit, status: .active, currency: "EUR", spendingLimit: nil
        )
        try await repository.insert(cardB)
        try await repository.insert(cardA)
        #expect(try await repository.fetchCards() == [cardA, cardB])
    }

    // MARK: - Writes

    @Test
    func insertWithSameIdUpdatesInPlace() async throws {
        let repository = try makeRepository()
        var card = sampleCard
        try await repository.insert(card)

        let updated = Card(
            id: card.id,
            cardholderName: card.cardholderName,
            lastFourDigits: card.lastFourDigits,
            type: card.type,
            status: .frozen,
            currency: card.currency,
            spendingLimit: 500
        )
        try await repository.insert(updated)

        let cards = try await repository.fetchCards()
        #expect(cards.count == 1)
        #expect(cards.first == updated)
    }

    @Test
    func deleteRemovesCard() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)
        try await repository.delete(cardId: card.id)
        #expect(try await repository.fetchCards().isEmpty)
    }

    @Test
    func deleteUnknownIdIsANoOp() async throws {
        let repository = try makeRepository()
        let card = sampleCard
        try await repository.insert(card)
        try await repository.delete(cardId: "card-that-never-existed")
        #expect(try await repository.fetchCards() == [card])
    }

    // MARK: - Mapping corruption

    @Test
    func corruptedTypeRawSurfacesPersistenceError() {
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
    func corruptedStatusRawSurfacesPersistenceError() throws {
        let stored = StoredCard(card: sampleCard)
        stored.statusRaw = "repossessed"
        #expect(throws: AppError.self) {
            try stored.toDomain()
        }
    }
}
