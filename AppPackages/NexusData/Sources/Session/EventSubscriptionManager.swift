import Entities
import ServiceProtocols

/// The session surface data sources are given (architecture.md §6.1–6.2):
/// connect/disconnect/events/send, with no SDK types and no session-status
/// plumbing. `EventSubscriptionManager` is the production backing; the demo
/// mocks conform to the same protocol (tasks.md Day 8).
///
/// The protocol is `Sendable` so actor-based data sources can store it;
/// conformers are `@MainActor` classes and mark the conformance
/// `@preconcurrency` (the §12.3 #8 pattern — an isolated conformance cannot
/// carry `Sendable`). Callers therefore hop to the main actor.
public protocol EventSubscriptionManagerProtocol: Sendable {
    func connect() async throws
    func disconnect()
    func events(for channel: String) -> AsyncStream<BankingEvent>
    func send(to channel: String, payload: String) async throws
}

/// Thin facade over any `SessionManagerProtocol` (architecture.md §6.2,
/// tasks.md Day 5).
///
/// Data sources receive this facade — never the session manager or the SDK
/// behind it. It adds no behavior; it narrows the surface data sources can
/// reach and keeps the transport replaceable (real session in live mode,
/// mock session in demo mode).
@MainActor
public final class EventSubscriptionManager: @preconcurrency EventSubscriptionManagerProtocol {
    private let session: any SessionManagerProtocol

    public init(session: any SessionManagerProtocol) {
        self.session = session
    }

    public func connect() async throws {
        try await session.connect()
    }

    public func disconnect() {
        session.disconnect()
    }

    public func events(for channel: String) -> AsyncStream<BankingEvent> {
        session.events(for: channel)
    }

    public func send(to channel: String, payload: String) async throws {
        try await session.send(to: channel, payload: payload)
    }
}
