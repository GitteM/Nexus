import DataSources
import Entities
import Foundation
import Repositories
import Testing

/// Tests for the thin `CardStatusRepository` over the real
/// `CardStateDataSource` driven by the fake session facade (tasks.md Day 7:
/// repository validation and error wrapping).
@Suite("CardStatusRepository")
@MainActor
struct CardStatusRepositoryTests {
    private func makeRepository() -> (CardStatusRepository, FakeEventSubscriptionManager) {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger()
        )
        return (CardStatusRepository(source: source), session)
    }

    private func statusEvent(cardId: String, status: CardStatus) throws -> BankingEvent {
        let payload = try String(
            decoding: JSONEncoder().encode(CardState(cardId: cardId, status: status)),
            as: UTF8.self
        )
        return BankingEvent(channel: EventChannels.cardEvents(cardId: cardId), payload: payload)
    }

    private func nextState(_ stream: AsyncStream<CardState>) async -> CardState? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    // MARK: - Validation (repository boundary)

    @Test
    func `one-shot with empty card id throws validationError`() async throws {
        let (repository, _) = makeRepository()
        await #expect(throws: AppError.self) {
            _ = try await repository.getCardStatus(cardId: "")
        }
    }

    @Test
    func `subscribe with empty card id throws validationError`() async throws {
        let (repository, _) = makeRepository()
        await #expect(throws: AppError.self) {
            _ = try await repository.subscribeToCardStatus(cardId: "")
        }
    }

    @Test
    func `unknown card reads as nil`() async throws {
        let (repository, _) = makeRepository()
        let status = try await repository.getCardStatus(cardId: "card-not-seen-yet")
        #expect(status == nil)
    }

    // MARK: - Delegation to the source

    @Test
    func `subscription delivers live status updates`() async throws {
        let (repository, session) = makeRepository()

        let stream = try await repository.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001", status: .frozen))

        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .frozen))
    }

    @Test
    func `observed status warms the one-shot read`() async throws {
        let (repository, session) = makeRepository()

        let stream = try await repository.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001", status: .lost))
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .lost))

        // Delivery is the happens-before edge for the per-id cache: once the
        // frame arrived on the stream, the one-shot answers from the cache.
        let status = try await repository.getCardStatus(cardId: "card-credit-001")
        #expect(status == CardState(cardId: "card-credit-001", status: .lost))
    }

    @Test
    func `resubscribe seeds the cached state first`() async throws {
        let (repository, session) = makeRepository()

        let first = try await repository.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001", status: .frozen))
        #expect(await nextState(first) == CardState(cardId: "card-credit-001", status: .frozen))

        let second = try await repository.subscribeToCardStatus(cardId: "card-credit-001")
        #expect(await nextState(second) == CardState(cardId: "card-credit-001", status: .frozen))
    }
}
