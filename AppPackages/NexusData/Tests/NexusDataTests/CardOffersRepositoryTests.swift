import DataSources
import Entities
import Foundation
import Repositories
import Testing

/// Tests for the thin `CardOffersRepository` over the real `OffersDataSource`
/// driven by the fake session facade (tasks.md Day 7).
@Suite("CardOffersRepository")
@MainActor
struct CardOffersRepositoryTests {
    private func makeRepository() -> (CardOffersRepository, FakeEventSubscriptionManager) {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger()
        )
        return (CardOffersRepository(source: source), session)
    }

    /// A full-list snapshot frame on the real `card.offers` channel, encoded
    /// through the wire envelope (`OffersSnapshotDTO`).
    private func offersEvent(_ offers: [CardOffer]) throws -> BankingEvent {
        let payload = try String(
            decoding: JSONEncoder().encode(OffersSnapshotDTO(offers: offers)),
            as: UTF8.self
        )
        return BankingEvent(channel: EventChannels.offers, payload: payload)
    }

    private func nextList(_ stream: AsyncStream<[CardOffer]>) async -> [CardOffer]? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test
    func `offers read empty before any snapshot`() async throws {
        let (repository, _) = makeRepository()
        let offers = await repository.getAvailableOffers()
        #expect(offers.isEmpty)
    }

    @Test
    func `snapshot on subscription seeds the list and the one-shot`() async throws {
        let (repository, session) = makeRepository()
        let expected = CardOffer.mockDefaults

        let stream = await repository.subscribeToOffers()
        try session.inject(offersEvent(expected))

        #expect(await nextList(stream) == expected)

        // Delivery is the happens-before edge for the snapshot cache.
        let offers = await repository.getAvailableOffers()
        #expect(offers == expected)
    }

    @Test
    func `replacement snapshot streams through and refreshes the one-shot`() async throws {
        let (repository, session) = makeRepository()
        let first = [CardOffer.mockCashbackOffer]
        let replacement = [CardOffer.mockTravelOffer, CardOffer.mockPrepaidOffer]

        let stream = await repository.subscribeToOffers()
        try session.inject(offersEvent(first))
        #expect(await nextList(stream) == first)
        try session.inject(offersEvent(replacement))
        #expect(await nextList(stream) == replacement)

        #expect(await repository.getAvailableOffers() == replacement)
    }

    @Test
    func `malformed snapshot is skipped without clearing the cache`() async throws {
        let (repository, session) = makeRepository()
        let expected = CardOffer.mockDefaults

        let stream = await repository.subscribeToOffers()
        try session.inject(offersEvent(expected))
        #expect(await nextList(stream) == expected)

        // A malformed replacement must be dropped, not served or applied.
        session.inject(BankingEvent(channel: EventChannels.offers, payload: "{not json"))
        try await Task.sleep(for: .milliseconds(50))
        #expect(await repository.getAvailableOffers() == expected)
    }
}
