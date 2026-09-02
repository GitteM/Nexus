import Entities
import Foundation
import Observation
import ServiceProtocols

/// One live `events(for:)` subscription: a continuation plus a stable id so
/// `onTermination` can remove exactly the right subscriber from a channel
/// that several consumers share.
private struct Subscription {
    let id: UUID
    let continuation: AsyncStream<BankingEvent>.Continuation
}

/// Holds the receive-loop `Task` so `deinit` — which is nonisolated and
/// cannot touch `@MainActor` state — can still cancel a live loop. Actors
/// are this codebase's synchronization primitive (architecture.md §12.1);
/// `Task.cancel()` is idempotent and safe from any isolation domain.
private actor ReceiveTaskHandle {
    private var task: Task<Void, Never>?

    func set(_ task: Task<Void, Never>?) {
        self.task = task
    }

    func cancel() {
        task?.cancel()
    }
}

/// URLSession-backed implementation of `SessionManagerProtocol`
/// (architecture.md §6.2, tasks.md Day 5).
///
/// `APISessionManager` is the app's one SDK-touching object. It lives on the
/// main actor because `sessionStatus` is consumed directly by UI; actor
/// isolation is the synchronization — there are no `DispatchQueue` barriers
/// and no `@unchecked Sendable`. The `URLSessionWebSocketTask` plumbing is
/// hidden behind `WebSocketClientProtocol` so tests run against a fake SDK
/// client while production uses `URLSessionWebSocketClient`.
///
/// Event flow: one receive-loop `Task` per connection pulls inbound frames,
/// decodes each into a `BankingEvent`, and fans it out to the continuations
/// of the matching channel. Subscriptions are plain state:
///
/// - `events(for:)` registers the caller immediately, connected or not.
///   Channels registered while disconnected are the pending-subscription
///   queue — they start receiving once the next `connect()` reopens the
///   socket (no barrier queue; the registry *is* the queue).
/// - `disconnect()` and transport drops finish every active stream. Streams
///   created after that point queue until the next successful `connect()`;
///   models re-subscribe on reload (architecture.md §9.1), so streams are
///   never silently revived across a teardown.
///
/// Threading notes: every method here runs on the main actor, but consumer
/// stream termination (`onTermination`) can fire on any executor — the
/// cleanup closure hops back to the main actor before touching the registry.
/// The transport seam always surfaces `AppError`; a non-`AppError` thrown by
/// a client is mapped in `connect()` as a defensive fallback. `deinit` is
/// nonisolated and reaches the receive loop only through a Sendable task
/// handle, keeping the code free of `@unchecked Sendable`.
@MainActor
@Observable
public final class APISessionManager: @preconcurrency SessionManagerProtocol {
    public private(set) var sessionStatus: SessionStatus = .disconnected

    private let client: any WebSocketClientProtocol
    private let decoder = JSONDecoder()
    /// `nonisolated` (Sendable actor) so `deinit` can cancel a live receive
    /// loop without touching main-actor state; only main-actor code writes
    /// the handle.
    private nonisolated let receiveTaskHandle = ReceiveTaskHandle()
    private var subscriptions: [String: [Subscription]] = [:]
    /// Bumped on teardown so an in-flight `connect()` can detect that
    /// `disconnect()` cancelled it.
    private var connectionGeneration = 0

    /// Creates the manager over the default `URLSessionWebSocketTask`
    /// transport for the given WebSocket endpoint.
    public convenience init(url: URL) {
        self.init(client: URLSessionWebSocketClient(url: url))
    }

    /// Injection seam for tests and alternative transports: any
    /// `WebSocketClientProtocol` (the fake SDK client in tests).
    init(client: any WebSocketClientProtocol) {
        self.client = client
    }

    deinit {
        // Once the manager's last external reference is gone, the running
        // receive loop is the only thing that could outlive it; cancel so a
        // parked `receive()` ends and the transport is released. The handle
        // is a nonisolated `let`, so it is readable here without touching
        // main-actor state.
        let handle = receiveTaskHandle
        Task { await handle.cancel() }
    }

    // MARK: - SessionManagerProtocol

    public func connect() async throws {
        guard sessionStatus == .disconnected || sessionStatus == .error else {
            return // already connecting or connected
        }
        sessionStatus = .connecting
        let generation = connectionGeneration
        do {
            try await client.connect()
            guard generation == connectionGeneration else {
                return // disconnect() ran during the handshake; it already tore the session down
            }
            sessionStatus = .connected
            startReceivingEvents()
        } catch {
            guard generation == connectionGeneration else {
                return
            }
            sessionStatus = .error
            let mapped = (error as? AppError)
                ?? AppError.apiConnectionFailed(details: error.localizedDescription)
            throw mapped
        }
    }

    public func disconnect() {
        guard sessionStatus != .disconnected else {
            return
        }
        connectionGeneration += 1
        Task { await receiveTaskHandle.cancel() }
        client.disconnect()
        sessionStatus = .disconnected
        finishAllSubscriptions()
    }

    /// Returns a stream of events on `channel`.
    ///
    /// Channel names follow the app/backend contract (architecture.md §11.4:
    /// `card.events.{cardId}`, `card.offers`, ...). The manager does not
    /// validate names client-side — an unknown or empty channel simply
    /// receives nothing until the backend pushes on it. Subscriptions are
    /// registered regardless of connection state and start receiving once
    /// the next `connect()` reopens the socket (the pending-subscription
    /// queue). Each call returns an independent stream; ending it (consumer
    /// cancellation or deinit) unregisters exactly that subscriber.
    public func events(for channel: String) -> AsyncStream<BankingEvent> {
        let (stream, continuation) = AsyncStream<BankingEvent>.makeStream()
        register(continuation, for: channel)
        return stream
    }

    public func send(to channel: String, payload: String) async throws {
        guard sessionStatus == .connected else {
            throw AppError.apiConnectionFailed(
                details: "Cannot send while \(sessionStatus.displayName).",
            )
        }
        guard !channel.isEmpty else {
            throw AppError.validationError(
                field: "channel",
                reason: "Channel must not be empty.",
            )
        }
        let event = BankingEvent(channel: channel, payload: payload)
        let data: Data
        do {
            data = try JSONEncoder().encode(event)
        } catch {
            throw AppError.serializationError(
                type: "BankingEvent",
                details: error.localizedDescription,
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw AppError.serializationError(
                type: "BankingEvent",
                details: "Encoded payload is not valid UTF-8.",
            )
        }
        do {
            try await client.send(text)
        } catch {
            // Same defensive mapping as connect(): the seam documents
            // `AppError`, but a client that misbehaves must not leak a raw
            // error across the boundary.
            throw (error as? AppError)
                ?? AppError.apiConnectionFailed(details: error.localizedDescription)
        }
    }

    // MARK: - Subscription registry (the pending-subscription queue)

    private func register(_ continuation: AsyncStream<BankingEvent>.Continuation, for channel: String) {
        let id = UUID()
        subscriptions[channel, default: []].append(Subscription(id: id, continuation: continuation))
        continuation.onTermination = { [weak self] _ in
            // Termination can fire away from the main actor; hop back before
            // touching the registry.
            Task { @MainActor [weak self] in
                self?.removeSubscriber(id: id, from: channel)
            }
        }
    }

    private func removeSubscriber(id: UUID, from channel: String) {
        guard var list = subscriptions[channel] else {
            return
        }
        list.removeAll { $0.id == id }
        if list.isEmpty {
            subscriptions[channel] = nil
        } else {
            subscriptions[channel] = list
        }
    }

    private func finishAllSubscriptions() {
        for list in subscriptions.values {
            for subscription in list {
                subscription.continuation.finish()
            }
        }
        subscriptions = [:]
    }

    // MARK: - Receive loop

    private func startReceivingEvents() {
        // The loop owns the transport for its lifetime; `self` stays weak so a
        // receive parked on an idle socket cannot keep the manager alive
        // (self -> task handle -> Task -> closure -> self would be a cycle).
        // `deinit`/`disconnect()` cancel the task through the handle, which
        // unparks `receive()` and ends the loop.
        let client = client
        let task = Task { [weak self] in
            while let text = try? await client.receive() {
                self?.route(text)
            }
            self?.handleTransportClosed()
        }
        Task { await receiveTaskHandle.set(task) }
    }

    private func route(_ text: String) {
        guard let event = decodeEvent(text) else {
            return
        }
        for subscription in subscriptions[event.channel, default: []] {
            subscription.continuation.yield(event)
        }
    }

    private func decodeEvent(_ text: String) -> BankingEvent? {
        guard
            let data = text.data(using: .utf8),
            let event = try? decoder.decode(BankingEvent.self, from: data)
        else {
            // Malformed frames are dropped here. Contextualized
            // deserialization errors (with logging) land with the
            // `JSONDecoder` AppError extension (architecture.md §6.4,
            // tasks.md Day 6).
            return nil
        }
        return event
    }

    private func handleTransportClosed() {
        guard sessionStatus == .connected else {
            return
        }
        // Clean close or transport failure: the connection is gone. Active
        // streams finish; subscriptions registered after this point queue in
        // `subscriptions` until the next successful `connect()`.
        sessionStatus = .disconnected
        finishAllSubscriptions()
    }

    // MARK: - Test introspection

    /// Channels with at least one live subscriber. Internal so tests can
    /// assert termination cleanup, which has no wire-visible side effect.
    var subscribedChannelCount: Int {
        subscriptions.count
    }

    /// Live subscribers across all channels. Internal test introspection.
    var subscriberCount: Int {
        subscriptions.values.reduce(0) { $0 + $1.count }
    }
}
