#if DEBUG
    import Entities
    import Observation
    import ServiceProtocols

    /// In-memory `SessionManagerProtocol` double shared by previews, tests,
    /// and demo mode.
    ///
    /// Demo mode substitutes this session for the real transport at the
    /// composition root: it connects instantly, fans out the events
    /// `MockEventGenerator` produces on the documented channels, and records
    /// outgoing sends — no network, no Keychain, no disk.
    ///
    /// Lifecycle mirrors the live manager closely enough for the demo and
    /// for tests:
    /// - `connect()` moves `.disconnected`/`.error → .connecting → .connected`
    ///   and throws `connectError` (status `.error`) when the knob is set.
    /// - `disconnect()` stops emission and finishes every active stream —
    ///   teardown semantics identical to a transport drop; models
    ///   re-subscribe on their next reload.
    /// - `events(for:)` registers the caller immediately, connected or not.
    ///   Events published while a stream is registered reach it; the mock has
    ///   no socket to gate delivery on, so publish order is whatever the
    ///   test/demo drives.
    /// - `send(to:payload:)` records the outbound payload and throws
    ///   `sendError` when the knob is set.
    ///
    /// `@MainActor` + `@Observable` mirror `APISessionManager` so the demo's
    /// `sessionStatus` reaches views through the same pass-through as live;
    /// the conformance is `@preconcurrency` because the protocol inherits
    /// `Sendable`.
    @MainActor
    @Observable
    public final class MockSessionManager: @preconcurrency SessionManagerProtocol {
        public private(set) var sessionStatus: SessionStatus
        /// The demo's synthetic event source; `nil` keeps the session inert
        /// (plain connect/disconnect/send behavior for focused tests).
        public let eventGenerator: MockEventGenerator?

        /// When set, `connect()` throws it and lands on `.error`.
        public var connectError: AppError?
        /// When set, `send` throws it.
        public var sendError: AppError?

        public private(set) var connectCallCount = 0
        public private(set) var disconnectCallCount = 0
        /// Outbound `(channel, payload)` pairs, oldest first.
        public private(set) var sent: [(channel: String, payload: String)] = []
        /// Events fanned out via `publish`, oldest first.
        public private(set) var publishedEvents: [BankingEvent] = []

        private var nextSubscriberID = 0
        private var subscribers: [String: [Int: AsyncStream<BankingEvent>.Continuation]] = [:]
        private var emissionTask: Task<Void, Never>?

        /// - Parameters:
        ///   - initialStatus: The state the session starts in (default
        ///     `.disconnected`, so previews/tests opt into a status).
        ///   - eventGenerator: The demo event source; when present,
        ///     `startDemoEvents()` emits its plan on a timer.
        public init(
            initialStatus: SessionStatus = .disconnected,
            eventGenerator: MockEventGenerator? = nil,
        ) {
            sessionStatus = initialStatus
            self.eventGenerator = eventGenerator
        }

        // MARK: - SessionManagerProtocol

        /// Connects instantly: `.disconnected`/`.error → .connecting →
        /// `.connected`. Attempts while already connecting/connected are
        /// no-ops (mirroring `APISessionManager`).
        public func connect() async throws {
            guard sessionStatus == .disconnected || sessionStatus == .error else {
                return
            }
            sessionStatus = .connecting
            connectCallCount += 1
            if let connectError {
                sessionStatus = .error
                throw connectError
            }
            sessionStatus = .connected
        }

        /// Tears the session down: stops emission, returns to
        /// `.disconnected`, and finishes every active event stream.
        public func disconnect() {
            disconnectCallCount += 1
            stopDemoEvents()
            sessionStatus = .disconnected
            for channel in subscribers.values {
                for continuation in channel.values {
                    continuation.finish()
                }
            }
            subscribers.removeAll()
        }

        /// Subscribes to one channel. Each call returns an independent
        /// stream; ending it (consumer cancellation or deinit) unregisters
        /// exactly that subscriber.
        public func events(for channel: String) -> AsyncStream<BankingEvent> {
            assert(!channel.isEmpty, "events(for:) requires a non-empty channel")
            let (stream, continuation) = AsyncStream<BankingEvent>.makeStream()
            let id = nextSubscriberID
            nextSubscriberID += 1
            subscribers[channel, default: [:]][id] = continuation
            continuation.onTermination = { [weak self] _ in
                // Termination can fire away from the main actor; hop back
                // before touching the registry (APISessionManager pattern).
                Task { @MainActor [weak self] in
                    self?.removeSubscriber(id: id, channel: channel)
                }
            }
            return stream
        }

        /// Records the outbound payload. Mirrors `APISessionManager`'s
        /// boundary rules: sending while disconnected fails, and empty
        /// channels are rejected — demo mode must exercise the same
        /// contract, not a looser one. Throws `sendError` when the knob is
        /// set (checked before the connection guard so error-path tests can
        /// drive it from any status).
        public func send(to channel: String, payload: String) async throws {
            if let sendError {
                throw sendError
            }
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
            sent.append((channel, payload))
        }

        // MARK: - Demo/test hooks

        /// Fans one inbound event out to every live subscriber of its
        /// channel — what the transport would deliver from the server.
        public func publish(_ event: BankingEvent) {
            publishedEvents.append(event)
            let listeners = subscribers[event.channel].map { Array($0.values) } ?? []
            for continuation in listeners {
                continuation.yield(event)
            }
        }

        /// Starts the demo emit loop: `eventGenerator.nextEvent()` published
        /// every `eventGenerator.interval`, until `stopDemoEvents()` (or a
        /// `disconnect()`). No-op when there is no generator or the loop is
        /// already running.
        ///
        /// Lifecycle: the loop holds the session weakly and exits when the
        /// session (or its generator) is gone, so a deallocated session never
        /// keeps emitting — at most one in-flight `Task.sleep` ends unused.
        /// Demo mode keeps the session alive for the app's lifetime
        /// (composition root); tests stop the loop explicitly before letting
        /// the session go.
        public func startDemoEvents() {
            guard eventGenerator != nil, emissionTask == nil else {
                return
            }
            emissionTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self, let generator = eventGenerator else {
                        return
                    }
                    guard let event = generator.nextEvent() else {
                        return
                    }
                    publish(event)
                    try? await Task.sleep(for: generator.interval)
                }
            }
        }

        /// Stops the demo emit loop; already-published state is retained.
        public func stopDemoEvents() {
            emissionTask?.cancel()
            emissionTask = nil
        }

        private func removeSubscriber(id: Int, channel: String) {
            subscribers[channel]?[id] = nil
            if subscribers[channel]?.isEmpty == true {
                subscribers[channel] = nil
            }
        }
    }
#endif
