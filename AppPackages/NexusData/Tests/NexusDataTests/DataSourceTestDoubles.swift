import Entities
import Foundation
import os
import ServiceProtocols
import Session

/// Lock-backed `LoggerProtocol` double that records every message.
///
/// `LoggerProtocol` is `Sendable` and data sources may log from any
/// concurrency domain, so the double must be callable off the main actor
/// without `@unchecked Sendable` — an `OSAllocatedUnfairLock` guards the
/// records (the same pattern `APISessionManager.ReceiveTaskHandle` uses).
final class RecordingLogger: LoggerProtocol {
    private struct Logs {
        var records: [(message: String, level: LogLevel)] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Logs())

    func log(_ message: String, level: LogLevel) {
        storage.withLock { $0.records.append((message, level)) }
    }

    /// All recorded messages, oldest first.
    var records: [(message: String, level: LogLevel)] {
        storage.withLock { $0.records }
    }

    /// Messages recorded at `.error`, oldest first. Filtering happens inside
    /// the lock so the read and the filter observe one consistent snapshot.
    var errorRecords: [(message: String, level: LogLevel)] {
        storage.withLock { $0.records.filter { $0.level == .error } }
    }
}

/// Fake session facade for data source tests (tasks.md Day 6): the data
/// sources receive `EventSubscriptionManagerProtocol` and never see the SDK,
/// so tests drive the source with a controllable stand-in.
///
/// Unlike the production facade (`@MainActor`), this double is
/// isolation-free: `EventSubscriptionManagerProtocol` is `Sendable`, and a
/// lock guards the subscriber registry, so actor-based data sources can
/// register streams and tests can inject frames from any context without
/// main-actor scheduling entanglement.
///
/// Test hooks:
/// - `inject(_:)` fans one inbound `BankingEvent` out to every subscriber on
///   its channel.
/// - `sendError` makes `send`/`connect` throw.
/// - `sent` records outbound `(channel, payload)` pairs for assertions.
final class FakeEventSubscriptionManager: EventSubscriptionManagerProtocol {
    private struct Registry {
        var nextSubscriberID = 0
        var subscribers: [String: [Int: AsyncStream<BankingEvent>.Continuation]] = [:]
        var connectCallCount = 0
        var disconnectCallCount = 0
        var sent: [(channel: String, payload: String)] = []
        var sendError: Error?
    }

    private let storage = OSAllocatedUnfairLock(initialState: Registry())

    var connectCallCount: Int {
        storage.withLock { $0.connectCallCount }
    }

    var disconnectCallCount: Int {
        storage.withLock { $0.disconnectCallCount }
    }

    /// Outbound `(channel, payload)` pairs, oldest first.
    var sent: [(channel: String, payload: String)] {
        storage.withLock { $0.sent }
    }

    var sendError: Error? {
        get { storage.withLock { $0.sendError } }
        set { storage.withLock { $0.sendError = newValue } }
    }

    /// Channels with at least one live subscriber. Test introspection.
    var subscribedChannelCount: Int {
        storage.withLock { $0.subscribers.count }
    }

    func connect() async throws {
        storage.withLock { $0.connectCallCount += 1 }
        if let sendError = storage.withLock({ $0.sendError }) {
            throw sendError
        }
    }

    func disconnect() {
        storage.withLock { $0.disconnectCallCount += 1 }
    }

    func events(for channel: String) -> AsyncStream<BankingEvent> {
        let (stream, continuation) = AsyncStream<BankingEvent>.makeStream()
        let id: Int = storage.withLock {
            let id = $0.nextSubscriberID
            $0.nextSubscriberID += 1
            $0.subscribers[channel, default: [:]][id] = continuation
            return id
        }
        continuation.onTermination = { [weak self] _ in
            self?.removeSubscriber(id: id, channel: channel)
        }
        return stream
    }

    private func removeSubscriber(id: Int, channel: String) {
        storage.withLock {
            $0.subscribers[channel]?[id] = nil
            if $0.subscribers[channel]?.isEmpty == true {
                $0.subscribers[channel] = nil
            }
        }
    }

    func send(to channel: String, payload: String) async throws {
        if let sendError = storage.withLock({ $0.sendError }) {
            throw sendError
        }
        storage.withLock { $0.sent.append((channel, payload)) }
    }

    /// Delivers one inbound frame to every live subscriber of its channel.
    func inject(_ event: BankingEvent) {
        let continuations = storage.withLock {
            Array($0.subscribers[event.channel, default: [:]].values)
        }
        for continuation in continuations {
            continuation.yield(event)
        }
    }
}
