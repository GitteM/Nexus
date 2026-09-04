import Entities
import Foundation
import Persistence
import Repositories
import Testing

/// Integration tests for `CardRepository` over the real SwiftData store:
/// repository validation and error wrapping over the real store. Every test
/// builds a real in-memory `ModelContainer`/`SwiftDataCardRepository` —
/// no mocks.
@Suite("CardRepository")
struct CardRepositoryTests {
    private func makeRepository() throws -> CardRepository {
        let container = try SwiftDataCardRepository.makeContainer(storedInMemoryOnly: true)
        let store = SwiftDataCardRepository(container: container)
        return CardRepository(store: store)
    }

    private var sampleOffer: CardOffer {
        CardOffer(
            id: "offer-cashback-001",
            title: "Cashback Card",
            subtitle: "2% back on every purchase, no annual fee",
            type: .credit,
            currency: "EUR",
            annualFee: nil,
            benefits: ["2% cashback on everything"],
        )
    }

    // MARK: - addCard

    @Test
    func `addCard provisions the offer as a managed card`() async throws {
        let repository = try makeRepository()

        let card = try await repository.addCard(sampleOffer)

        #expect(card.id == sampleOffer.id)
        #expect(card.type == sampleOffer.type)
        #expect(card.currency == sampleOffer.currency)
        #expect(card.status == .active)
        #expect(card.spendingLimit == nil)
        // Provisional mapping: issuance-only fields are empty until the
        // REST contract lands (see CardRepository documentation).
        #expect(card.lastFourDigits.isEmpty)
        #expect(card.cardholderName.isEmpty)
        #expect(try await repository.getCards() == [card])
    }

    @Test
    func `duplicate offer throws cardAlreadyExists and persists once`() async throws {
        let repository = try makeRepository()
        _ = try await repository.addCard(sampleOffer)

        do {
            _ = try await repository.addCard(sampleOffer)
            Issue.record("Expected cardAlreadyExists for a duplicate offer.")
        } catch let error as AppError {
            #expect(error == .cardAlreadyExists(cardId: sampleOffer.id))
        } catch {
            Issue.record("Expected AppError, got \(error).")
        }
        #expect(try await repository.getCards().count == 1)
    }

    @Test
    func `empty offer id throws validationError`() async throws {
        let repository = try makeRepository()
        let offer = CardOffer(
            id: "", title: "Broken", subtitle: "", type: .credit,
            currency: "EUR", annualFee: nil, benefits: [],
        )
        await #expect(throws: AppError.self) {
            _ = try await repository.addCard(offer)
        }
    }

    @Test
    func `empty offer currency throws validationError`() async throws {
        let repository = try makeRepository()
        let offer = CardOffer(
            id: "offer-x", title: "Broken", subtitle: "", type: .credit,
            currency: "", annualFee: nil, benefits: [],
        )
        await #expect(throws: AppError.self) {
            _ = try await repository.addCard(offer)
        }
    }

    @Test
    func `two distinct offers produce two cards`() async throws {
        let repository = try makeRepository()
        let other = CardOffer(
            id: "offer-travel-001", title: "Travel Rewards Card", subtitle: "",
            type: .credit, currency: "EUR", annualFee: 95, benefits: [],
        )
        _ = try await repository.addCard(sampleOffer)
        _ = try await repository.addCard(other)
        #expect(try await repository.getCards().count == 2)
    }

    @Test
    func `concurrent duplicate adds persist once and throw once`() async throws {
        let repository = try makeRepository()
        let offer = sampleOffer
        let attempts = 20

        // Fire many addCard calls for the same offer at once. The duplicate
        // check runs inside the store's single ModelActor turn, so exactly
        // one call inserts and every other call reports cardAlreadyExists
        // (the check-then-act guard in CardRepository is no longer racy).
        let outcomes = await withTaskGroup(of: Result<Card, Error>.self) { group in
            for _ in 0 ..< attempts {
                group.addTask {
                    do {
                        return try await .success(repository.addCard(offer))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var results: [Result<Card, Error>] = []
            for await outcome in group {
                results.append(outcome)
            }
            return results
        }

        let inserted = outcomes.filter {
            if case .success = $0 {
                return true
            }
            return false
        }
        let alreadyExists = outcomes.filter {
            if case let .failure(error) = $0,
               let appError = error as? AppError,
               appError == .cardAlreadyExists(cardId: offer.id)
            {
                return true
            }
            return false
        }
        #expect(inserted.count == 1)
        #expect(alreadyExists.count == attempts - 1)

        let cards = try await repository.getCards()
        #expect(cards.count == 1)
        #expect(cards.first?.id == offer.id)
    }

    // MARK: - removeCard

    @Test
    func `removeCard deletes a managed card`() async throws {
        let repository = try makeRepository()
        _ = try await repository.addCard(sampleOffer)

        try await repository.removeCard(cardId: sampleOffer.id)
        #expect(try await repository.getCards().isEmpty)
    }

    @Test
    func `removeCard with unknown id is a no-op`() async throws {
        let repository = try makeRepository()
        _ = try await repository.addCard(sampleOffer)

        try await repository.removeCard(cardId: "card-that-never-existed")
        #expect(try await repository.getCards().count == 1)
    }

    @Test
    func `removeCard with empty id throws validationError`() async throws {
        let repository = try makeRepository()
        await #expect(throws: AppError.self) {
            try await repository.removeCard(cardId: "")
        }
    }

    // MARK: - Durability across repository instances

    @Test
    func `cards survive a new repository over the same container`() async throws {
        let container = try SwiftDataCardRepository.makeContainer(storedInMemoryOnly: true)
        let first = CardRepository(store: SwiftDataCardRepository(container: container))
        let card = try await first.addCard(sampleOffer)

        // A second repository over the same container reads the same store —
        // persistence lives in the container, not in a repository instance.
        let second = CardRepository(store: SwiftDataCardRepository(container: container))
        #expect(try await second.getCards() == [card])
    }
}
