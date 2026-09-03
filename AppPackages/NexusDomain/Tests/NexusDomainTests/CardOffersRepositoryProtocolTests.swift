import Entities
import Foundation
import RepositoryProtocols
import Testing

@Suite("CardOffersRepositoryProtocol")
@MainActor
struct CardOffersRepositoryProtocolTests {
    // MARK: - Shape

    /// Pins the shapes: one-shot `async throws`, subscription
    /// `async throws -> AsyncStream`, no `Result` at the boundary
    /// (architecture.md §4.2).
    @Test func `one shot and subscription shapes hold`() {
        let repository: CardOffersRepositoryProtocol = TestCardOffersRepository()
        let _: () async throws -> [CardOffer] = repository.getAvailableOffers
        let _: () async throws -> AsyncStream<[CardOffer]> = repository.subscribeToOffers
    }

    // MARK: - Behavior

    @Test func `getAvailableOffers returns the seeded offers`() async throws {
        let repository = TestCardOffersRepository(offers: [.mockTravelOffer])
        let offers = try await repository.getAvailableOffers()
        #expect(offers == [.mockTravelOffer])
    }

    @Test func `getAvailableOffers surfaces the configured AppError`() async {
        let repository = TestCardOffersRepository()
        repository.error = .apiConnectionFailed()
        do {
            _ = try await repository.getAvailableOffers()
            Issue.record("Expected getAvailableOffers to throw")
        } catch {
            #expect(error as? AppError == .apiConnectionFailed())
        }
    }

    @Test func `subscription yields the current offers then updates`() async throws {
        let repository = TestCardOffersRepository(offers: [.mockCashbackOffer])
        let stream = try await repository.subscribeToOffers()
        repository.emit([.mockCashbackOffer, .mockTravelOffer])

        var received: [[CardOffer]] = []
        for await offers in stream {
            received.append(offers)
            if received.count == 2 {
                break
            }
        }
        #expect(received.first == [.mockCashbackOffer])
        #expect(received.last == [.mockCashbackOffer, .mockTravelOffer])
    }

    @Test func `subscription setup failure throws before returning a stream`() async {
        let repository = TestCardOffersRepository()
        repository.subscribeError = .systemUnavailable(details: "offers channel down")
        do {
            _ = try await repository.subscribeToOffers()
            Issue.record("Expected subscribeToOffers to throw")
        } catch {
            #expect(error as? AppError == .systemUnavailable(details: "offers channel down"))
        }
    }
}
