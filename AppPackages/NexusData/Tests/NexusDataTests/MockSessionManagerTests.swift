import DataSources
import Entities
import Mocks
import ServiceProtocols
import Session
import Testing

/// Day 8 tests for the in-memory `MockSessionManager` demo session
/// (architecture.md §6.2 semantics, §11.2 demo mode).
@Suite("MockSessionManager", .serialized)
@MainActor
struct MockSessionManagerTests {
    // MARK: - Lifecycle

    @Test
    func `connect moves disconnected → connected and counts attempts`() async throws {
        let session = MockSessionManager()
        #expect(session.sessionStatus == .disconnected)

        try await session.connect()
        #expect(session.sessionStatus == .connected)
        #expect(session.connectCallCount == 1)

        // Connecting while already connected is a no-op.
        try await session.connect()
        #expect(session.connectCallCount == 1)
    }

    @Test
    func `a failed connect lands on error and a later connect recovers`() async throws {
        let session = MockSessionManager()
        session.connectError = .apiConnectionFailed(details: "demo outage")

        await #expect(throws: AppError.apiConnectionFailed(details: "demo outage")) {
            try await session.connect()
        }
        #expect(session.sessionStatus == .error)

        session.connectError = nil
        try await session.connect()
        #expect(session.sessionStatus == .connected)
    }

    @Test
    func `disconnect returns to disconnected and finishes active streams`() async throws {
        let session = MockSessionManager()
        try await session.connect()
        let stream = session.events(for: "card.events.card-credit-001")

        session.disconnect()
        #expect(session.sessionStatus == .disconnected)
        #expect(session.disconnectCallCount == 1)

        // The stream ended rather than hanging forever.
        var ended = false
        for await _ in stream {
            ended = true
        }
        #expect(!ended)
    }

    // MARK: - Event fan-out

    @Test
    func `publish reaches only the matching channel's subscribers`() async throws {
        let session = MockSessionManager()
        try await session.connect()
        let cardStream = session.events(for: "card.events.card-credit-001")
        let offersStream = session.events(for: "card.offers")

        let stateEvent = MockEventGenerator.cardStateEvent(for: .mockActiveState)
        session.publish(stateEvent)

        #expect(session.publishedEvents == [stateEvent])
        #expect(await firstElement(of: cardStream) == stateEvent)
        #expect(await firstElement(of: offersStream, within: .milliseconds(100)) == nil)
    }

    @Test
    func `events(for:) hands out independent streams per call`() async throws {
        let session = MockSessionManager()
        try await session.connect()
        let first = session.events(for: "card.offers")
        let second = session.events(for: "card.offers")

        // The same snapshot twice: both streams must see both elements, in
        // order — the registry never steals an event for one subscriber.
        // (Each stream is drained by a single iterator: AsyncStream is
        // single-consumer, so per-stream sequential checks reuse one.)
        let snapshot = MockEventGenerator.offersSnapshotEvent
        session.publish(snapshot)
        session.publish(snapshot)

        #expect(await collect(first, upTo: 2) == [snapshot, snapshot])
        #expect(await collect(second, upTo: 2) == [snapshot, snapshot])
    }

    // MARK: - Send

    @Test
    func `send records outbound payloads and honors sendError`() async throws {
        let session = MockSessionManager()
        try await session.connect()

        try await session.send(to: "card.commands", payload: #"{"cardId":"card-credit-001"}"#)
        #expect(session.sent.count == 1)
        #expect(session.sent.first?.channel == "card.commands")

        session.sendError = .cardActionFailed(action: "freeze")
        await #expect(throws: AppError.cardActionFailed(action: "freeze")) {
            try await session.send(to: "card.commands", payload: #"{"cardId":"card-credit-001"}"#)
        }
        #expect(session.sent.count == 1) // failed sends are not recorded
    }

    // MARK: - Demo emission

    @Test
    func `startDemoEvents publishes the generator plan on its interval`() async {
        let generator = MockEventGenerator.demoDefaults(interval: .milliseconds(20))
        let session = MockSessionManager(
            initialStatus: .connected,
            eventGenerator: generator,
        )

        session.startDemoEvents()
        defer { session.stopDemoEvents() }

        // The first event of the demo plan is the offers snapshot.
        let emitted = await waitForFirstPublish(on: session, within: .seconds(2))
        #expect(emitted != nil)
        #expect(generator.emittedCount >= 1)
        #expect(session.publishedEvents.first == MockEventGenerator.offersSnapshotEvent)
    }

    @Test
    func `a second startDemoEvents does not double the emit loop`() async {
        let generator = MockEventGenerator.demoDefaults(interval: .milliseconds(20))
        let session = MockSessionManager(
            initialStatus: .connected,
            eventGenerator: generator,
        )

        session.startDemoEvents()
        session.startDemoEvents() // no-op: one loop only
        defer { session.stopDemoEvents() }

        _ = await waitForFirstPublish(on: session, within: .seconds(2))
        let countAfterFirst = session.publishedEvents.count
        session.stopDemoEvents()
        let countAtStop = session.publishedEvents.count
        // No events after stopping, and the loop had not raced ahead.
        try? await Task.sleep(for: .milliseconds(100))
        #expect(session.publishedEvents.count == countAtStop)
        #expect(countAfterFirst >= 1)
        session.publish(MockEventGenerator.offersSnapshotEvent)
        #expect(session.publishedEvents.count == countAtStop + 1)
    }

    // MARK: - Demo pipeline through the real data-source parse path

    /// The Day 8 verify: demo events decode through the same `parseEvent`
    /// path as live data. This test wires the real composition the container
    /// will use in demo mode — `MockSessionManager` behind the production
    /// `EventSubscriptionManager` facade feeding a real `CardStateDataSource`
    /// — and pushes one synthetic status frame through it.
    @Test
    func `a demo status event decodes through the real CardStateDataSource`() async throws {
        let session = MockSessionManager()
        try await session.connect()
        let facade = EventSubscriptionManager(session: session)
        let source = CardStateDataSource(
            eventSubscriptionManager: facade,
            logger: RecordingLogger(),
        )

        let stream = try await source.subscribeToCardStatus(cardId: "card-credit-002")
        let event = MockEventGenerator.cardStateEvent(for: .mockFrozenState)
        session.publish(event)

        let state = await firstElement(of: stream)
        #expect(state == CardState.mockFrozenState)
        // The frame also warmed the per-id cache (delivery is the edge).
        #expect(await source.getCardStatus(cardId: "card-credit-002") == CardState.mockFrozenState)
    }

    /// Offers flow through the same composition: the demo's `card.offers`
    /// snapshot decodes via the real `OffersDataSource`.
    @Test
    func `a demo offers snapshot decodes through the real OffersDataSource`() async throws {
        let session = MockSessionManager()
        try await session.connect()
        let facade = EventSubscriptionManager(session: session)
        let source = OffersDataSource(
            eventSubscriptionManager: facade,
            logger: RecordingLogger(),
        )

        let stream = await source.subscribeToOffers()
        session.publish(MockEventGenerator.offersSnapshotEvent)

        let offers = await firstElement(of: stream)
        #expect(offers == CardOffer.mockDefaults)
        #expect(await source.getAvailableOffers() == CardOffer.mockDefaults)
    }

    // MARK: - Helpers

    /// First element of a stream, or `nil` when it ends / times out first.
    private func firstElement<Element: Sendable>(
        of stream: AsyncStream<Element>,
        within timeout: Duration = .seconds(1),
    ) async -> Element? {
        await element(of: stream, at: 1, within: timeout)
    }

    /// Second element of a stream, or `nil` when it ends / times out first.
    private func secondElement<Element: Sendable>(
        of stream: AsyncStream<Element>,
        within timeout: Duration = .seconds(1),
    ) async -> Element? {
        await element(of: stream, at: 2, within: timeout)
    }

    private func element<Element: Sendable>(
        of stream: AsyncStream<Element>,
        at position: Int,
        within timeout: Duration,
    ) async -> Element? {
        await withTaskGroup(of: Element?.self) { group in
            group.addTask {
                var seen = 0
                for await element in stream {
                    seen += 1
                    if seen == position {
                        return element
                    }
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    /// Collects up to `limit` elements of a stream with one iterator
    /// (bounded: live mock streams stay open until terminated).
    private func collect<Element: Sendable>(
        _ stream: AsyncStream<Element>,
        upTo limit: Int,
    ) async -> [Element] {
        var collected: [Element] = []
        for await element in stream {
            collected.append(element)
            if collected.count == limit {
                break
            }
        }
        return collected
    }

    /// Polls until the session has published at least one event or the
    /// timeout elapses; returns the first published event, if any.
    private func waitForFirstPublish(
        on session: MockSessionManager,
        within timeout: Duration,
    ) async -> BankingEvent? {
        let step: Duration = .milliseconds(10)
        var waited: Duration = .zero
        while waited < timeout {
            if let first = session.publishedEvents.first {
                return first
            }
            try? await Task.sleep(for: step)
            waited += step
        }
        return session.publishedEvents.first
    }
}
