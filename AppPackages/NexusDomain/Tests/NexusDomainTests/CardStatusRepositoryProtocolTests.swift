import Entities
import Foundation
import RepositoryProtocols
import Testing

@Suite("CardStatusRepositoryProtocol")
struct CardStatusRepositoryProtocolTests {
    // MARK: - Shape

    /// Pins the shapes: one-shot `async throws`, per-card subscription
    /// `async throws -> AsyncStream`, no `Result` at the boundary
    /// (architecture.md §4.2).
    @Test func `one shot and subscription shapes hold`() {
        let repository: CardStatusRepositoryProtocol = TestCardStatusRepository()
        let _: (String) async throws -> CardState? = repository.getCardStatus
        let _: (String) async throws -> AsyncStream<CardState> = repository.subscribeToCardStatus
    }

    // MARK: - Behavior

    @Test func `getCardStatus returns the known state and nil for unknown cards`() async throws {
        let repository = TestCardStatusRepository(states: [.mockFrozenState])
        #expect(try await repository.getCardStatus(cardId: CardState.mockFrozenState.cardId) == .mockFrozenState)
        #expect(try await repository.getCardStatus(cardId: "card-unknown") == nil)
    }

    @Test func `getCardStatus surfaces the configured AppError`() async {
        let repository = TestCardStatusRepository()
        repository.error = .cardNotFound(cardId: "card-1")
        do {
            _ = try await repository.getCardStatus(cardId: "card-1")
            Issue.record("Expected getCardStatus to throw")
        } catch {
            #expect(error as? AppError == .cardNotFound(cardId: "card-1"))
        }
    }

    @Test func `subscription yields the current state then live updates`() async throws {
        let repository = TestCardStatusRepository(states: [.mockActiveState])
        let cardId = CardState.mockActiveState.cardId
        let stream = try await repository.subscribeToCardStatus(cardId: cardId)
        repository.emit(CardState(cardId: cardId, status: .frozen))

        var received: [CardState] = []
        for await state in stream {
            received.append(state)
            if received.count == 2 {
                break
            }
        }
        #expect(received == [.mockActiveState, CardState(cardId: cardId, status: .frozen)])
    }

    @Test func `subscription only delivers updates for its own card`() async throws {
        let repository = TestCardStatusRepository(states: [.mockActiveState])
        let cardId = CardState.mockActiveState.cardId
        let stream = try await repository.subscribeToCardStatus(cardId: cardId)

        // An update for another card must not leak into this stream.
        repository.emit(.mockLostState)
        let expectedUpdate = CardState(cardId: cardId, status: .frozen)
        repository.emit(expectedUpdate)

        var received: [CardState] = []
        for await state in stream {
            received.append(state)
            if received.count == 2 {
                break
            }
        }
        #expect(received == [.mockActiveState, expectedUpdate])
    }

    @Test func `subscription for an unknown card is silent until it ends`() async throws {
        let repository = TestCardStatusRepository()
        let stream = try await repository.subscribeToCardStatus(cardId: "card-unknown")
        repository.finishAllSubscriptions()

        var received: [CardState] = []
        for await state in stream {
            received.append(state)
        }
        #expect(received.isEmpty)
    }

    @Test func `subscription setup failure throws before returning a stream`() async {
        let repository = TestCardStatusRepository()
        repository.subscribeError = .apiConnectionFailed(details: "status channel down")
        do {
            _ = try await repository.subscribeToCardStatus(cardId: "card-1")
            Issue.record("Expected subscribeToCardStatus to throw")
        } catch {
            #expect(error as? AppError == .apiConnectionFailed(details: "status channel down"))
        }
    }
}
