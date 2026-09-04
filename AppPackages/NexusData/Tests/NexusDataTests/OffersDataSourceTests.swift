@testable import DataSources
import Entities
import Foundation
import Testing

@Suite("OffersDataSource")
@MainActor
struct OffersDataSourceTests {
    /// Builds a `card.offers` frame whose payload is an `OffersSnapshotDTO`
    /// envelope encoded through the same `JSONEncoder` the wire will use.
    private func snapshotEvent(_ offers: [CardOffer]) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(
            OffersSnapshotDTO(offers: offers),
        ), as: UTF8.self)
        return BankingEvent(channel: EventChannels.offers, payload: payload)
    }

    private func nextOffers(_ stream: AsyncStream<[CardOffer]>) async -> [CardOffer]? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test func `subscribe delivers live snapshots`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer]))
        #expect(await nextOffers(stream) == [.mockCashbackOffer])

        try session.inject(snapshotEvent([.mockCashbackOffer, .mockTravelOffer]))
        #expect(await nextOffers(stream) == [.mockCashbackOffer, .mockTravelOffer])
    }

    @Test func `resubscribe seeds the current fresh snapshot`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let first = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer, .mockTravelOffer]))
        // Delivery is the happens-before edge: the snapshot replaced the
        // cache before it was yielded.
        #expect(await nextOffers(first) == [.mockCashbackOffer, .mockTravelOffer])

        // A second subscription on the same source seeds the warm cache.
        let stream = await source.subscribeToOffers()
        #expect(await nextOffers(stream) == [.mockCashbackOffer, .mockTravelOffer])

        try session.inject(snapshotEvent([.mockPrepaidOffer]))
        #expect(await nextOffers(stream) == [.mockPrepaidOffer])
    }

    @Test func `getAvailableOffers misses then hits the cache`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        // Cache miss: no snapshot has arrived yet — an empty offer state.
        #expect(await source.getAvailableOffers() == [])

        let stream = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer, .mockTravelOffer]))
        // Delivery is the happens-before edge: the snapshot replaced the
        // cache before it was yielded.
        #expect(await nextOffers(stream) == [.mockCashbackOffer, .mockTravelOffer])

        // Cache hit: the one-shot answers immediately.
        #expect(await source.getAvailableOffers() == [.mockCashbackOffer, .mockTravelOffer])
    }

    @Test func `expired snapshots are dropped after the TTL`() async throws {
        let session = FakeEventSubscriptionManager()
        // A short TTL so the test does not wait five minutes.
        let source = OffersDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger(),
            ttl: 0.05,
        )

        let first = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer]))
        // Delivery marks the snapshot's arrival time (cache write precedes
        // the yield), so the TTL clock starts here.
        #expect(await nextOffers(first) == [.mockCashbackOffer])

        try await Task.sleep(for: .milliseconds(250))

        // Stale entries are dropped: the one-shot reports an empty state…
        #expect(await source.getAvailableOffers() == [])

        // …and a resubscribe does not seed the expired snapshot — the next
        // element is the next live snapshot, not the stale list.
        let stream = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockTravelOffer]))
        #expect(await nextOffers(stream) == [.mockTravelOffer])
    }

    @Test func `a fresh snapshot inside the TTL keeps serving`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger(),
            // Generous TTL: this test only asserts the fresh-snapshot path;
            // the 0.05 s TTL case above pins expiry. A short TTL here made
            // the assertion load-dependent on slow runners.
            ttl: 60,
        )

        let stream = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer]))
        #expect(await nextOffers(stream) == [.mockCashbackOffer])

        // Still inside the TTL: the one-shot serves the fresh snapshot.
        #expect(await source.getAvailableOffers() == [.mockCashbackOffer])
    }

    @Test func `malformed snapshots are skipped and logged`() async throws {
        let logger = RecordingLogger()
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: logger)

        let stream = await source.subscribeToOffers()
        session.inject(BankingEvent(
            channel: EventChannels.offers,
            payload: "not json at all",
        ))
        // A snapshot with the wrong shape (no `offers` key) is also skipped.
        session.inject(BankingEvent(
            channel: EventChannels.offers,
            payload: #"{"somethingElse":true}"#,
        ))

        try session.inject(snapshotEvent([.mockCashbackOffer]))
        #expect(await nextOffers(stream) == [.mockCashbackOffer])
        #expect(logger.errorRecords.count == 2)
    }

    @Test func `an empty snapshot replaces the cache`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = await source.subscribeToOffers()
        try session.inject(snapshotEvent([.mockCashbackOffer]))
        #expect(await nextOffers(stream) == [.mockCashbackOffer])

        // The backend clears its offer list: the next element is empty and
        // the cache holds the empty list (a real state, not a miss).
        try session.inject(snapshotEvent([]))
        #expect(await nextOffers(stream) == [])
        #expect(await source.getAvailableOffers() == [])
    }

    @Test func `parseEvent normalizes snapshots and rejects garbage`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = OffersDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let event = try snapshotEvent([.mockCashbackOffer, .mockTravelOffer])
        #expect(await source.parseEvent(event) == [.mockCashbackOffer, .mockTravelOffer])

        #expect(await source.parseEvent(BankingEvent(
            channel: EventChannels.offers,
            payload: "garbage",
        )) == nil)
        #expect(await source.parseEvent(BankingEvent(
            channel: EventChannels.offers,
            payload: #"{"missing":"offers"}"#,
        )) == nil)
    }
}
