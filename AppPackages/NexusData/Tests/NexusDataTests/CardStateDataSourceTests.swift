@testable import DataSources
import Entities
import Foundation
import Testing

@Suite("CardStateDataSource")
@MainActor
struct CardStateDataSourceTests {
    /// Builds a status frame on the real per-card channel with a payload
    /// encoded through the same `JSONEncoder` the wire will use.
    private func statusEvent(cardId: String, status: CardStatus) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(
            CardState(cardId: cardId, status: status),
        ), as: UTF8.self)
        return BankingEvent(channel: EventChannels.cardEvents(cardId: cardId), payload: payload)
    }

    /// A non-status frame (a balance payload) on a card channel — must be
    /// skipped, not decoded as a status.
    private func balanceEvent(cardId: String) throws -> BankingEvent {
        let payload = try String(decoding: JSONEncoder().encode(
            Balance(cardId: cardId, current: 100, available: 100, creditLimit: nil, currency: "EUR"),
        ), as: UTF8.self)
        return BankingEvent(channel: EventChannels.cardEvents(cardId: cardId), payload: payload)
    }

    private func nextState(_ stream: AsyncStream<CardState>) async -> CardState? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test func `subscribe delivers live status updates`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")

        try session.inject(statusEvent(cardId: "card-credit-001", status: .active))
        #expect(await nextState(stream) == .mockActiveState)

        try session.inject(statusEvent(cardId: "card-credit-001", status: .frozen))
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .frozen))
    }

    @Test func `resubscribe seeds the cached state before going live`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let first = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001", status: .frozen))
        // Delivery is the happens-before edge: once the frame lands on the
        // stream, the per-id cache is warm.
        #expect(await nextState(first) == CardState(cardId: "card-credit-001", status: .frozen))

        // Second subscription on the same source: the per-id cache is warm.
        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .frozen))

        try session.inject(statusEvent(cardId: "card-credit-001", status: .lost))
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .lost))
    }

    @Test func `getCardStatus answers from the per-id cache`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        // Cache miss: nothing has arrived on the wire yet.
        #expect(await source.getCardStatus(cardId: "card-credit-001") == nil)

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(statusEvent(cardId: "card-credit-001", status: .active))
        // Delivery is the happens-before edge: the frame is cached before it
        // is yielded, so this observation proves the cache is warm.
        #expect(await nextState(stream) == .mockActiveState)

        // Cache hit: the one-shot answers immediately after the event landed.
        #expect(await source.getCardStatus(cardId: "card-credit-001") == .mockActiveState)
    }

    @Test func `malformed payloads are skipped and logged`() async throws {
        let logger = RecordingLogger()
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: logger)

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        session.inject(BankingEvent(
            channel: EventChannels.cardEvents(cardId: "card-credit-001"),
            payload: "not json at all",
        ))

        // The malformed frame must not surface; the next valid one must.
        try session.inject(statusEvent(cardId: "card-credit-001", status: .active))
        #expect(await nextState(stream) == .mockActiveState)
        #expect(logger.errorRecords.count == 1)
    }

    @Test func `non-status frames on a card channel are skipped`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        try session.inject(balanceEvent(cardId: "card-credit-001"))

        try session.inject(statusEvent(cardId: "card-credit-001", status: .active))
        #expect(await nextState(stream) == .mockActiveState)
    }

    @Test func `a frame for another card warms its cache but is not delivered`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-001")
        // Misrouted frame: the payload carries card-credit-002's state but the
        // frame arrives on card-credit-001's channel (a server-side mix-up).
        let misroutedPayload = try String(decoding: JSONEncoder().encode(
            CardState(cardId: "card-credit-002", status: .active),
        ), as: UTF8.self)
        session.inject(BankingEvent(
            channel: EventChannels.cardEvents(cardId: "card-credit-001"),
            payload: misroutedPayload,
        ))

        // A frame for the subscribed card proves the consumer ran through the
        // misrouted frame first (same task, wire order): the first element is
        // frozen, so the card-002 state was never delivered on this
        // subscription — and the cache read then observes the warm entry.
        try session.inject(statusEvent(cardId: "card-credit-001", status: .frozen))
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .frozen))

        // Cached under its own id (observable via the one-shot)…
        #expect(await source.getCardStatus(cardId: "card-credit-002")
            == CardState(cardId: "card-credit-002", status: .active))
        // …while card-credit-001's subscription is untouched by it.
        try session.inject(statusEvent(cardId: "card-credit-001", status: .lost))
        #expect(await nextState(stream) == CardState(cardId: "card-credit-001", status: .lost))
    }

    @Test func `subscribe throws on an empty card id`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        do {
            _ = try await source.subscribeToCardStatus(cardId: "")
            Issue.record("subscribeToCardStatus should throw for an empty card id")
        } catch let error as AppError {
            guard case .validationError = error else {
                Issue.record("Expected validationError, got \(error)")
                return
            }
        }
    }

    @Test func `parseEvent normalizes status payloads and rejects everything else`() async throws {
        let session = FakeEventSubscriptionManager()
        let source = CardStateDataSource(eventSubscriptionManager: session, logger: RecordingLogger())

        // A status frame parses to the typed entity.
        let status = try statusEvent(cardId: "card-credit-001", status: .frozen)
        #expect(await source.parseEvent(status) == CardState(cardId: "card-credit-001", status: .frozen))

        // A balance frame is not a status — parseEvent must answer nil.
        #expect(try await source.parseEvent(balanceEvent(cardId: "card-credit-001")) == nil)

        // Garbage is not a status either.
        #expect(await source.parseEvent(BankingEvent(
            channel: EventChannels.cardEvents(cardId: "card-credit-001"),
            payload: "{broken",
        )) == nil)
    }
}
