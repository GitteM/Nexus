import Entities
import Foundation
@testable import Session
import Testing

@Suite("EventSubscriptionManager")
@MainActor
struct EventSubscriptionManagerTests {
    private func frame(_ event: BankingEvent) -> String {
        let data = try! JSONEncoder().encode(event)
        return String(data: data, encoding: .utf8)!
    }

    private func nextEvent(_ stream: AsyncStream<BankingEvent>) async -> BankingEvent? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test func `facade forwards the session lifecycle`() async throws {
        let client = FakeWebSocketClient()
        let manager = APISessionManager(client: client)
        let facade = EventSubscriptionManager(session: manager)

        try await facade.connect()
        #expect(manager.sessionStatus == .connected)
        #expect(client.connectCallCount == 1)

        facade.disconnect()
        #expect(manager.sessionStatus == .disconnected)
        #expect(client.disconnectCallCount == 1)
    }

    @Test func `facade streams events and sends payloads through the session`() async throws {
        let client = FakeWebSocketClient()
        let manager = APISessionManager(client: client)
        let facade = EventSubscriptionManager(session: manager)
        try await facade.connect()

        let stream = facade.events(for: "card.status")
        client.inject(frame(BankingEvent.mockCardStatusEvent))
        #expect(await nextEvent(stream) == .mockCardStatusEvent)

        try await facade.send(to: "card.command", payload: #"{"type":"freeze"}"#)
        #expect(client.sentTexts.count == 1)
    }
}
