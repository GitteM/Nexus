import Entities
import ServiceProtocols
import Testing

@Suite("SessionManagerProtocol")
@MainActor
struct SessionManagerProtocolTests {
    // MARK: - Shape

    /// Pins the protocol surface: sync status read, one-shot throws, and a
    /// stream-based event channel — no completion handlers, no `Result`.
    @Test func `protocol surface holds`() {
        let session: SessionManagerProtocol = TestSessionManager()
        let _: SessionStatus = session.sessionStatus
        let _: (String) -> AsyncStream<BankingEvent> = session.events(for:)
    }

    // MARK: - sessionStatus

    @Test func `starts disconnected`() {
        #expect(TestSessionManager().sessionStatus == .disconnected)
    }

    @Test func `connect transitions to connected`() async throws {
        let session = TestSessionManager()
        try await session.connect()
        #expect(session.sessionStatus == .connected)
    }

    @Test func `connect surfaces the configured AppError and stays disconnected`() async {
        let session = TestSessionManager()
        session.connectError = .apiConnectionFailed(details: "handshake rejected")

        do {
            try await session.connect()
            Issue.record("Expected connect to throw")
        } catch {
            #expect(error as? AppError == .apiConnectionFailed(details: "handshake rejected"))
        }
        #expect(session.sessionStatus == .disconnected)
    }

    @Test func `disconnect returns to disconnected and ends active streams`() async throws {
        let session = TestSessionManager()
        try await session.connect()
        let stream = session.events(for: "card.status")

        session.disconnect()

        #expect(session.sessionStatus == .disconnected)
        var received: [BankingEvent] = []
        for await event in stream {
            received.append(event)
        }
        #expect(received.isEmpty)
    }

    // MARK: - events(for:)

    @Test func `events delivers events for the subscribed channel`() async {
        let session = TestSessionManager()
        let stream = session.events(for: "card.status")

        session.emit(BankingEvent.mockCardStatusEvent)

        var received: [BankingEvent] = []
        for await event in stream {
            received.append(event)
            if received.count == 1 {
                break
            }
        }
        #expect(received == [.mockCardStatusEvent])
    }

    @Test func `events for one channel do not leak into another`() async {
        let session = TestSessionManager()
        let statusStream = session.events(for: "card.status")
        let balanceStream = session.events(for: "card.balance")

        session.emit(BankingEvent.mockCardStatusEvent)
        session.finishAllStreams()

        var statusEvents: [BankingEvent] = []
        for await event in statusStream {
            statusEvents.append(event)
        }
        var balanceEvents: [BankingEvent] = []
        for await event in balanceStream {
            balanceEvents.append(event)
        }
        #expect(statusEvents == [.mockCardStatusEvent])
        #expect(balanceEvents.isEmpty)
    }

    @Test func `every subscriber receives its own independent stream`() async {
        let session = TestSessionManager()
        let first = session.events(for: "card.status")
        let second = session.events(for: "card.status")

        session.emit(BankingEvent.mockCardStatusEvent)
        session.finishAllStreams()

        var firstEvents: [BankingEvent] = []
        for await event in first {
            firstEvents.append(event)
        }
        var secondEvents: [BankingEvent] = []
        for await event in second {
            secondEvents.append(event)
        }
        #expect(firstEvents == [.mockCardStatusEvent])
        #expect(secondEvents == [.mockCardStatusEvent])
    }

    // MARK: - send(to:payload:)

    @Test func `send records the channel and payload`() async throws {
        let session = TestSessionManager()
        let payload = #"{"type":"freeze"}"#

        try await session.send(to: "card.command", payload: payload)

        #expect(session.sent.count == 1)
        #expect(session.sent[0].channel == "card.command")
        #expect(session.sent[0].payload == payload)
    }

    @Test func `send surfaces the configured AppError and records nothing`() async {
        let session = TestSessionManager()
        session.sendError = .requestTimedOut

        do {
            try await session.send(to: "card.command", payload: #"{"type":"freeze"}"#)
            Issue.record("Expected send to throw")
        } catch {
            #expect(error as? AppError == .requestTimedOut)
        }
        #expect(session.sent.isEmpty)
    }
}
