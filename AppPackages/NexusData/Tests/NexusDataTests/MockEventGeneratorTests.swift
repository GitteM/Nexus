@testable import DataSources
import Entities
import Mocks
import Testing

/// Tests for `MockEventGenerator`: the demo's synthetic events must decode
/// through the same `parseEvent` / `JSONDecoder` AppError path live frames
/// use, and the plan must be a deterministic cycle.
@Suite("MockEventGenerator")
@MainActor
struct MockEventGeneratorTests {
    // MARK: - Decode through the real path

    /// Every `card.offers` snapshot event decodes via the real
    /// `OffersDataSource.parseEvent` into exactly the seeded offers.
    @Test
    func `the demo offers snapshot decodes through the real source`() async {
        let event = MockEventGenerator.offersSnapshotEvent
        #expect(event.channel == EventChannels.offers)

        let source = OffersDataSource(
            eventSubscriptionManager: FakeEventSubscriptionManager(),
            logger: RecordingLogger(),
        )
        let offers = await source.parseEvent(event)
        #expect(offers == CardOffer.mockDefaults)
    }

    /// Every demo card-status frame decodes via the real
    /// `CardStateDataSource.parseEvent` into exactly the state it was
    /// generated from, on the card's own channel.
    @Test
    func `demo card status events decode through the real source`() async {
        let source = CardStateDataSource(
            eventSubscriptionManager: FakeEventSubscriptionManager(),
            logger: RecordingLogger(),
        )
        let expectedByCardId = Dictionary(
            CardState.mockDefaults.map { ($0.cardId, $0) },
            uniquingKeysWith: { _, last in last },
        )

        for state in CardState.mockDefaults {
            let event = MockEventGenerator.cardStateEvent(for: state)
            #expect(event.channel == EventChannels.cardEvents(cardId: state.cardId))
            let decoded = await source.parseEvent(event)
            #expect(decoded == expectedByCardId[state.cardId])
        }
    }

    /// The full demo cycle: an offers snapshot first, then one status frame
    /// per default card — every frame on a documented channel.
    @Test
    func `demoEvents opens with the offers snapshot then each card state`() {
        let events = MockEventGenerator.demoEvents()
        #expect(events.first == MockEventGenerator.offersSnapshotEvent)

        let statusFrames = events.dropFirst()
        #expect(statusFrames.count == CardState.mockDefaults.count)
        for (index, state) in CardState.mockDefaults.enumerated() {
            let event = statusFrames[statusFrames.startIndex + index]
            #expect(event.channel == EventChannels.cardEvents(cardId: state.cardId))
        }
    }

    // MARK: - Cycle mechanics

    @Test
    func `nextEvent walks the plan and wraps around`() {
        let first = MockEventGenerator.cardStateEvent(for: .mockActiveState)
        let second = MockEventGenerator.cardStateEvent(for: .mockFrozenState)
        let generator = MockEventGenerator(events: [first, second])

        #expect(generator.nextEvent() == first)
        #expect(generator.nextEvent() == second)
        #expect(generator.nextEvent() == first) // wraps around
        #expect(generator.emittedCount == 3)
    }

    @Test
    func `an empty plan emits nothing`() {
        let generator = MockEventGenerator(events: [])
        #expect(generator.nextEvent() == nil)
        #expect(generator.nextEvent() == nil)
        #expect(generator.emittedCount == 0)
    }

    @Test
    func `demoDefaults seeds the standard plan and interval`() {
        let generator = MockEventGenerator.demoDefaults(interval: .seconds(2))
        #expect(generator.events == MockEventGenerator.demoEvents())
        #expect(generator.interval == .seconds(2))
        #expect(MockEventGenerator.demoDefaults().interval == .seconds(5))
    }
}
