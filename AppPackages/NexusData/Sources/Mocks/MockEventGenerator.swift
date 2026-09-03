#if DEBUG
    import DataSources
    import Entities
    import Foundation

    /// Produces the synthetic `BankingEvent` stream for demo mode
    /// (architecture.md §11.2, §12.3 #6; tasks.md Day 8).
    ///
    /// The demo must feel alive, not static: events are emitted on a timer so
    /// the app exercises the real `AsyncStream → model → view` pipeline —
    /// offer lists update, `cardStates` tick. `MockSessionManager` pulls the
    /// next event from a generator and fans it out to the channel's
    /// subscribers.
    ///
    /// **Events decode through the same path as live data.** Every payload is
    /// produced by JSON-encoding the canonical Domain entity/DTO the wire
    /// shape belongs to (`CardState`, the `card.offers` `OffersSnapshotDTO`
    /// envelope), so the demo exercises the identical `parseEvent` /
    /// `JSONDecoder` AppError path live frames use — synthetic payloads can
    /// never drift from the SDK's shapes (architecture.md §12.3 #6).
    ///
    /// The generator is a deterministic cycle: `nextEvent()` walks `events`
    /// in order and wraps around at the end, so a demo plan repeats until the
    /// session stops emitting. An empty plan yields `nil` forever.
    @MainActor
    public final class MockEventGenerator {
        /// The plan of synthetic events, in emit order (cycled).
        public let events: [BankingEvent]
        /// Pause between emissions while the session's emit loop runs.
        public let interval: Duration

        /// How many events have been handed out since init.
        public private(set) var emittedCount = 0

        private var cursor = 0

        /// - Parameters:
        ///   - events: The event plan; `MockEventGenerator.demoDefaults()`
        ///     builds the standard demo cycle.
        ///   - interval: Pause between emissions (default 5 seconds — a calm
        ///     banking feed, not a ticker).
        public init(events: [BankingEvent], interval: Duration = .seconds(5)) {
            self.events = events
            self.interval = interval
        }

        /// The next event in the plan, wrapping around at the end; `nil`
        /// when the plan is empty (nothing to emit).
        public func nextEvent() -> BankingEvent? {
            guard !events.isEmpty else {
                return nil
            }
            let event = events[cursor % events.count]
            cursor += 1
            emittedCount += 1
            return event
        }
    }

    public extension MockEventGenerator {
        /// The standard demo plan (architecture.md §11.2): one full
        /// `card.offers` snapshot followed by one status frame per
        /// `CardState.mockDefaults` card, cycling at the given interval.
        static func demoDefaults(interval: Duration = .seconds(5)) -> MockEventGenerator {
            MockEventGenerator(events: demoEvents(), interval: interval)
        }

        /// The demo event cycle. Order is deliberate: the offers snapshot
        /// first, then each card's current status frame — a subscriber that
        /// joins mid-cycle still sees every channel's canonical first frame
        /// within one lap.
        static func demoEvents() -> [BankingEvent] {
            var events: [BankingEvent] = [offersSnapshotEvent]
            events += CardState.mockDefaults.map { cardStateEvent(for: $0) }
            return events
        }

        /// The `card.offers` snapshot the demo opens with, seeded from
        /// `CardOffer.mockDefaults` inside the real `OffersSnapshotDTO`
        /// envelope.
        static var offersSnapshotEvent: BankingEvent {
            BankingEvent(
                channel: EventChannels.offers,
                payload: payload(OffersSnapshotDTO(offers: CardOffer.mockDefaults)),
            )
        }

        /// A `card.events.{cardId}` frame carrying one `CardState`.
        static func cardStateEvent(for state: CardState) -> BankingEvent {
            BankingEvent(
                channel: EventChannels.cardEvents(cardId: state.cardId),
                payload: payload(state),
            )
        }

        /// JSON-encodes a wire-shaped value into a payload string. The
        /// encoding cannot fail for these in-memory Codable structs, so the
        /// forced `try` is safe; anything that would make it throw is a
        /// demo-plan bug that must surface loudly in DEBUG builds.
        private static func payload(_ value: some Encodable) -> String {
            // `.sortedKeys` keeps the wire shape canonical: JSONEncoder key
            // order is unspecified per encode, and deterministic payloads
            // keep demo events equal across encodes (tests compare whole
            // `BankingEvent`s) without affecting decoding.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try! encoder.encode(value)
            return String(decoding: data, as: UTF8.self)
        }
    }
#endif
