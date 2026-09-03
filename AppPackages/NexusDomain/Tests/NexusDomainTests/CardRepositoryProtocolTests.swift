import Entities
import Foundation
import RepositoryProtocols
import Testing

@Suite("CardRepositoryProtocol")
@MainActor
struct CardRepositoryProtocolTests {
    // MARK: - Shape

    /// Pins the one-shot shape: `async throws` with no `Result` at the
    /// boundary (architecture.md §4.2, §12.1). If a signature regresses to
    /// `Result`, these assignments stop compiling.
    @Test func `methods are async throws and never return Result`() {
        let repository: CardRepositoryProtocol = TestCardRepository()
        let _: () async throws -> [Card] = repository.getCards
        let _: (CardOffer) async throws -> Card = repository.addCard
        let _: (String) async throws -> Void = repository.removeCard
    }

    // MARK: - Behavior

    @Test func `getCards returns the seeded cards`() async throws {
        let repository = TestCardRepository(cards: [.mockCreditCard, .mockDebitCard])
        let cards = try await repository.getCards()
        #expect(cards == [.mockCreditCard, .mockDebitCard])
    }

    @Test func `addCard appends the new card and returns it`() async throws {
        let repository = TestCardRepository()
        let added = try await repository.addCard(.mockCashbackOffer)
        #expect(added.type == CardOffer.mockCashbackOffer.type)
        #expect(repository.cards.contains { $0.id == added.id })
        #expect(repository.cards.count == Card.mockDefaults.count + 1)
    }

    @Test func `removeCard removes the card by id`() async throws {
        let repository = TestCardRepository(cards: [.mockCreditCard, .mockDebitCard])
        try await repository.removeCard(cardId: Card.mockCreditCard.id)
        #expect(repository.cards == [.mockDebitCard])
    }

    @Test func `methods surface the configured AppError`() async {
        let repository = TestCardRepository()
        repository.error = .persistenceError(operation: "getCards")
        do {
            _ = try await repository.getCards()
            Issue.record("Expected getCards to throw")
        } catch {
            #expect(error as? AppError == .persistenceError(operation: "getCards"))
        }
    }
}
