import Entities
import Foundation
@testable import Session
import Testing

@Suite("APISessionManager")
@MainActor
struct APISessionManagerTests {
    private func makeManager(client: FakeWebSocketClient = FakeWebSocketClient()) -> APISessionManager {
        APISessionManager(client: client)
    }

    /// Serializes an event into the raw frame the transport would receive.
    private func frame(_ event: BankingEvent) throws -> String {
        try String(decoding: JSONEncoder().encode(event), as: UTF8.self)
    }

    /// Awaits the next event on a stream (parks until one arrives or the
    /// stream finishes).
    private func nextEvent(_ stream: AsyncStream<BankingEvent>) async -> BankingEvent? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    /// Yields the main actor a few times so queued `Task`s (receive loop,
    /// `onTermination` cleanup) can run.
    private func flushMainActor() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    // MARK: - Session status

    @Test func `starts disconnected`() {
        let manager = makeManager()
        #expect(manager.sessionStatus == .disconnected)
    }

    @Test func `connect moves through connecting to connected`() async throws {
        let client = FakeWebSocketClient()
        client.holdsConnect = true
        let manager = makeManager(client: client)

        let connectTask = Task { try await manager.connect() }
        await client.waitUntilConnectStarted()
        #expect(manager.sessionStatus == .connecting)

        client.allowConnect()
        try await connectTask.value
        #expect(manager.sessionStatus == .connected)
        #expect(client.connectCallCount == 1)
    }

    @Test func `connect when already connected is a no-op`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)

        try await manager.connect()
        try await manager.connect()

        #expect(client.connectCallCount == 1)
        #expect(manager.sessionStatus == .connected)
    }

    @Test func `a second connect while one is in flight is a no-op`() async throws {
        let client = FakeWebSocketClient()
        client.holdsConnect = true
        let manager = makeManager(client: client)

        let first = Task { try await manager.connect() }
        await client.waitUntilConnectStarted()
        #expect(manager.sessionStatus == .connecting)

        // Second caller while `.connecting`: returns without touching the
        // client or disturbing the in-flight attempt.
        try await manager.connect()
        #expect(client.connectCallCount == 1)

        client.allowConnect()
        try await first.value
        #expect(manager.sessionStatus == .connected)
        #expect(client.connectCallCount == 1)
    }

    @Test func `manager deallocates while a receive loop is parked`() async throws {
        let client = FakeWebSocketClient()
        var manager: APISessionManager? = makeManager(client: client)
        weak let weakManager = manager
        try await manager?.connect() // the receive loop parks on the fake
        #expect(manager?.sessionStatus == .connected)

        // The parked loop must not keep the manager alive (no retain cycle
        // through the receive task).
        manager = nil
        await flushMainActor()
        #expect(weakManager == nil)
    }

    @Test func `connect surfaces the AppError and marks the session errored`() async {
        let client = FakeWebSocketClient()
        client.connectError = AppError.apiConnectionFailed(details: "handshake rejected")
        let manager = makeManager(client: client)

        await #expect(throws: AppError.apiConnectionFailed(details: "handshake rejected")) {
            try await manager.connect()
        }
        #expect(manager.sessionStatus == .error)
    }

    @Test func `connect wraps a raw transport error as apiConnectionFailed`() async {
        let client = FakeWebSocketClient()
        let rawError = URLError(.cannotConnectToHost)
        client.connectError = rawError
        let manager = makeManager(client: client)

        do {
            try await manager.connect()
            Issue.record("Expected connect to throw")
        } catch {
            #expect(error as? AppError == .apiConnectionFailed(details: rawError.localizedDescription))
        }
        #expect(manager.sessionStatus == .error)
    }

    @Test func `disconnect during an in-flight connect cancels the attempt`() async throws {
        let client = FakeWebSocketClient()
        client.holdsConnect = true
        let manager = makeManager(client: client)

        let connectTask = Task { try await manager.connect() }
        await client.waitUntilConnectStarted()
        #expect(manager.sessionStatus == .connecting)

        manager.disconnect()
        #expect(manager.sessionStatus == .disconnected)
        #expect(client.disconnectCallCount == 1)

        client.allowConnect()
        try await connectTask.value
        // The raced attempt must not flip the session back to connected.
        #expect(manager.sessionStatus == .disconnected)
    }

    // MARK: - disconnect()

    @Test func `disconnect returns to disconnected and ends active streams`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()
        let stream = manager.events(for: "card.status")

        manager.disconnect()

        #expect(manager.sessionStatus == .disconnected)
        #expect(client.disconnectCallCount == 1)
        var received: [BankingEvent] = []
        for await event in stream {
            received.append(event)
        }
        #expect(received.isEmpty)
    }

    @Test func `disconnect when already disconnected is a no-op`() {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)

        manager.disconnect()

        #expect(client.disconnectCallCount == 0)
        #expect(manager.sessionStatus == .disconnected)
    }

    // MARK: - Event bridging

    @Test func `inbound frames bridge to the matching channel subscribers`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        let statusEvents = manager.events(for: "card.status")
        let balanceEvents = manager.events(for: "card.balance")

        try client.inject(frame(BankingEvent.mockCardStatusEvent))
        try client.inject(frame(BankingEvent.mockBalanceEvent))

        #expect(await nextEvent(statusEvents) == .mockCardStatusEvent)
        #expect(await nextEvent(balanceEvents) == .mockBalanceEvent)
    }

    @Test func `each subscriber of a channel receives its own stream`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        let first = manager.events(for: "card.status")
        let second = manager.events(for: "card.status")
        #expect(manager.subscriberCount == 2)

        try client.inject(frame(BankingEvent.mockCardStatusEvent))

        #expect(await nextEvent(first) == .mockCardStatusEvent)
        #expect(await nextEvent(second) == .mockCardStatusEvent)
    }

    @Test func `malformed frames are dropped without killing the connection`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        let stream = manager.events(for: "card.status")
        client.inject("this is not json")
        try client.inject(frame(BankingEvent.mockCardStatusEvent))

        #expect(await nextEvent(stream) == .mockCardStatusEvent)
        #expect(manager.sessionStatus == .connected)
    }

    @Test func `cancelling a consumer unregisters it and other subscribers keep receiving`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        let first = manager.events(for: "card.status")
        let second = manager.events(for: "card.status")
        #expect(manager.subscriberCount == 2)

        // A model-like consumer: keeps pulling until its task is cancelled.
        let consumer = Task {
            var iterator = first.makeAsyncIterator()
            while await iterator.next() != nil {}
        }
        await flushMainActor()
        consumer.cancel()
        await consumer.value
        await flushMainActor()

        #expect(manager.subscriberCount == 1)

        // The remaining subscriber is untouched by the cleanup.
        let secondEvent = BankingEvent(
            channel: "card.status",
            payload: #"{"cardId":"card-credit-001","status":"active"}"#,
        )
        try client.inject(frame(secondEvent))
        #expect(await nextEvent(second) == secondEvent)
    }

    // MARK: - Pending subscriptions & reconnect

    @Test func `subscriptions made while disconnected queue and deliver after connect`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)

        // Disconnected — this is the pending-subscription queue entry.
        let stream = manager.events(for: "card.status")
        #expect(manager.subscriberCount == 1)
        #expect(manager.sessionStatus == .disconnected)

        try await manager.connect()
        try client.inject(frame(BankingEvent.mockCardStatusEvent))

        #expect(await nextEvent(stream) == .mockCardStatusEvent)
    }

    @Test func `queued subscriptions survive a failed connect and deliver on retry`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)

        let stream = manager.events(for: "card.status")

        client.connectError = AppError.requestTimedOut
        await #expect(throws: AppError.requestTimedOut) {
            try await manager.connect()
        }
        #expect(manager.sessionStatus == .error)
        #expect(manager.subscriberCount == 1) // the queue survived

        client.connectError = nil
        try await manager.connect()
        try client.inject(frame(BankingEvent.mockCardStatusEvent))

        #expect(await nextEvent(stream) == .mockCardStatusEvent)
    }

    @Test func `transport drop marks disconnected, ends streams, and reconnect delivers to new subscriptions`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        let first = manager.events(for: "card.status")
        try client.inject(frame(BankingEvent.mockCardStatusEvent))
        #expect(await nextEvent(first) == .mockCardStatusEvent)

        // Server drops the socket: the receive loop ends.
        client.closeFromServer()
        await flushMainActor()
        #expect(manager.sessionStatus == .disconnected)

        // Active streams were finished by the teardown.
        var ended: [BankingEvent] = []
        for await event in first {
            ended.append(event)
        }
        #expect(ended.isEmpty)

        // Reconnect: a fresh subscription made while disconnected is queued,
        // then delivers once the socket is back. The fake reopens on
        // `connect()`, so the session stays connected (regression guard for
        // per-connection state leaking across a reconnect).
        let second = manager.events(for: "card.status")
        try await manager.connect()
        #expect(client.connectCallCount == 2)
        await flushMainActor()
        #expect(manager.sessionStatus == .connected)

        try client.inject(frame(BankingEvent.mockCardStatusEvent))
        #expect(await nextEvent(second) == .mockCardStatusEvent)
        #expect(manager.sessionStatus == .connected)
    }

    @Test func `transport error also marks disconnected and finishes streams`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()
        let stream = manager.events(for: "card.status")

        client.failNextReceive(with: URLError(.networkConnectionLost))
        await flushMainActor()

        #expect(manager.sessionStatus == .disconnected)
        var received: [BankingEvent] = []
        for await event in stream {
            received.append(event)
        }
        #expect(received.isEmpty)
    }

    // MARK: - send(to:payload:)

    @Test func `send encodes the BankingEvent and delivers it to the client`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()
        let payload = #"{"type":"freeze"}"#

        try await manager.send(to: "card.command", payload: payload)

        #expect(client.sentTexts.count == 1)
        let sent = try JSONDecoder().decode(
            BankingEvent.self,
            from: Data(client.sentTexts[0].utf8),
        )
        #expect(sent.channel == "card.command")
        #expect(sent.payload == payload)
    }

    @Test func `send while disconnected throws apiConnectionFailed and sends nothing`() async {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)

        await #expect(throws: AppError.apiConnectionFailed(details: "Cannot send while Disconnected.")) {
            try await manager.send(to: "card.command", payload: #"{"type":"freeze"}"#)
        }
        #expect(client.sentTexts.isEmpty)
    }

    @Test func `send surfaces the transport AppError`() async throws {
        let client = FakeWebSocketClient()
        client.sendError = AppError.requestTimedOut
        let manager = makeManager(client: client)
        try await manager.connect()

        await #expect(throws: AppError.requestTimedOut) {
            try await manager.send(to: "card.command", payload: #"{"type":"freeze"}"#)
        }
        #expect(client.sentTexts.isEmpty)
    }

    @Test func `send wraps a raw transport error as apiConnectionFailed`() async throws {
        let client = FakeWebSocketClient()
        let rawError = URLError(.networkConnectionLost)
        client.sendError = rawError
        let manager = makeManager(client: client)
        try await manager.connect()

        do {
            try await manager.send(to: "card.command", payload: #"{"type":"freeze"}"#)
            Issue.record("Expected send to throw")
        } catch {
            #expect(error as? AppError == .apiConnectionFailed(details: rawError.localizedDescription))
        }
        #expect(client.sentTexts.isEmpty)
    }

    @Test func `send rejects an empty channel`() async throws {
        let client = FakeWebSocketClient()
        let manager = makeManager(client: client)
        try await manager.connect()

        await #expect(throws: AppError.validationError(field: "channel", reason: "Channel must not be empty.")) {
            try await manager.send(to: "", payload: #"{"type":"freeze"}"#)
        }
        #expect(client.sentTexts.isEmpty)
    }
}
