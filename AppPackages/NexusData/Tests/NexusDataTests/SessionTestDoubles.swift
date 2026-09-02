import Entities
import Foundation
@testable import Session

/// Fake "SDK client" for the session manager tests (tasks.md Day 5):
/// connect/disconnect, event bridging, and reconnect behavior.
///
/// Test hooks drive the manager from the outside: `inject(_:)` feeds inbound
/// frames, `closeFromServer()` models a server-side socket drop, and
/// `holdsConnect` lets a test park `connect()` mid-handshake so the
/// `.connecting` transition is observable.
///
/// Threading model: the whole fake — including every continuation it parks
/// and resumes — is confined to the main actor, mirroring the production
/// transport and the manager (architecture.md §6.2 accepts main-actor hops at
/// banking-feed rates). `inject`, `closeFromServer`, `allowConnect`, and
/// `disconnect` are test hooks and must be called from a `@MainActor` test;
/// continuations are only ever resumed on the main actor, so no
/// `@unchecked Sendable` is needed.
@MainActor
final class FakeWebSocketClient: WebSocketClientProtocol {
    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var sentTexts: [String] = []
    var connectError: Error?
    var sendError: Error?

    /// When true, `connect()` parks until `allowConnect()` resumes it.
    var holdsConnect = false
    private var connectGate: CheckedContinuation<Void, Never>?

    private var isClosed = false
    private var queuedTexts: [String] = []
    private var pendingReceives: [CheckedContinuation<String?, Error>] = []
    private var receiveError: Error?

    // MARK: - WebSocketClientProtocol

    func connect() async throws {
        connectCallCount += 1
        if let connectError {
            throw connectError
        }
        // A reconnect opens a fresh socket: clear every per-connection state
        // left behind by the previous close (a real client builds a new
        // `URLSessionWebSocketTask` in `connect()`).
        isClosed = false
        queuedTexts = []
        receiveError = nil
        drainPendingReceives()
        if holdsConnect {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                connectGate = continuation
            }
        }
    }

    func send(_ text: String) async throws {
        if let sendError {
            throw sendError
        }
        sentTexts.append(text)
    }

    func receive() async throws -> String? {
        if let receiveError {
            self.receiveError = nil
            throw receiveError
        }
        if !queuedTexts.isEmpty {
            return queuedTexts.removeFirst()
        }
        if isClosed {
            return nil
        }
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<String?, Error>) in
            pendingReceives.append(continuation)
        }
    }

    func disconnect() {
        disconnectCallCount += 1
        isClosed = true
        drainPendingReceives()
    }

    // MARK: - Test hooks

    /// Resumes a parked `connect()` (see `holdsConnect`).
    func allowConnect() {
        holdsConnect = false
        connectGate?.resume()
        connectGate = nil
    }

    /// Waits until `connect()` has been entered.
    func waitUntilConnectStarted() async {
        while connectCallCount == 0 {
            await Task.yield()
        }
    }

    /// Feeds one inbound frame, delivering it to a parked `receive()` or
    /// queueing it for the next call.
    func inject(_ text: String) {
        if let receive = pendingReceives.first {
            pendingReceives.removeFirst()
            receive.resume(returning: text)
        } else {
            queuedTexts.append(text)
        }
    }

    /// Models a server-side close: pending `receive()` calls finish cleanly
    /// (`nil`) and future calls return `nil`.
    func closeFromServer() {
        isClosed = true
        drainPendingReceives()
    }

    /// Makes the next `receive()` call throw instead of returning a frame.
    func failNextReceive(with error: Error) {
        receiveError = error
    }

    private func drainPendingReceives() {
        for receive in pendingReceives {
            receive.resume(returning: nil)
        }
        pendingReceives = []
    }
}
