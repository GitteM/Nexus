import DataSources
import Entities
import Foundation
import ServiceProtocols
import Testing

@Suite("CardActionDataSource")
@MainActor
struct CardActionDataSourceTests {
    /// Records whether `execute` threw, and which `AppError` it threw.
    private struct Outcome {
        let error: AppError?
    }

    private func execute(
        _ command: CardCommand,
        session: FakeEventSubscriptionManager,
        logger: RecordingLogger = RecordingLogger(),
    ) async -> Outcome {
        let source = CardActionDataSource(eventSubscriptionManager: session, logger: logger)
        do {
            try await source.execute(command)
            return Outcome(error: nil)
        } catch let error as AppError {
            return Outcome(error: error)
        } catch {
            Issue.record("execute threw \(error), not an AppError")
            return Outcome(error: nil)
        }
    }

    private func decodeCommand(payload: String) throws -> CardCommand {
        try JSONDecoder().decode(CardCommand.self, from: Data(payload.utf8))
    }

    @Test func `freeze sends a serialized command on the commands channel`() async throws {
        let session = FakeEventSubscriptionManager()
        let outcome = await execute(.freeze(cardId: "card-credit-001"), session: session)

        #expect(outcome.error == nil)
        #expect(session.sent.count == 1)
        #expect(session.sent.first?.channel == EventChannels.commands)
        let sent = try decodeCommand(payload: #require(session.sent.first?.payload))
        #expect(sent == .freeze(cardId: "card-credit-001"))
    }

    @Test func `setSpendingLimit round-trips its amount and period`() async throws {
        let session = FakeEventSubscriptionManager()
        let command = CardCommand.setSpendingLimit(
            cardId: "card-credit-001",
            period: .weekly,
            amount: 500,
        )
        let outcome = await execute(command, session: session)

        #expect(outcome.error == nil)
        let sent = try decodeCommand(payload: #require(session.sent.first?.payload))
        #expect(sent == command)
    }

    @Test func `empty card id is rejected`() async {
        let session = FakeEventSubscriptionManager()
        let outcome = await execute(.freeze(cardId: ""), session: session)
        guard case .validationError = outcome.error else {
            Issue.record("expected validationError, got \(String(describing: outcome.error))")
            return
        }
        #expect(session.sent.isEmpty)
    }

    @Test func `unknown command types are rejected`() async {
        let session = FakeEventSubscriptionManager()
        let outcome = await execute(
            CardCommand(cardId: "card-credit-001", type: .unknown),
            session: session,
        )
        guard case .validationError = outcome.error else {
            Issue.record("expected validationError, got \(String(describing: outcome.error))")
            return
        }
        #expect(session.sent.isEmpty)
    }

    @Test func `setSpendingLimit requires amount and period`() async {
        let session = FakeEventSubscriptionManager()

        let missingPeriod = await execute(
            CardCommand(cardId: "card-credit-001", type: .setSpendingLimit, amount: 500, period: nil),
            session: session,
        )
        guard case .validationError = missingPeriod.error else {
            Issue.record("expected validationError, got \(String(describing: missingPeriod.error))")
            return
        }

        let missingAmount = await execute(
            CardCommand(cardId: "card-credit-001", type: .setSpendingLimit, amount: nil, period: .weekly),
            session: session,
        )
        guard case .validationError = missingAmount.error else {
            Issue.record("expected validationError, got \(String(describing: missingAmount.error))")
            return
        }
        #expect(session.sent.isEmpty)
    }

    @Test func `payload on a payload-free action is rejected`() async {
        let session = FakeEventSubscriptionManager()
        let outcome = await execute(
            CardCommand(cardId: "card-credit-001", type: .freeze, amount: 500, period: nil),
            session: session,
        )
        guard case .validationError = outcome.error else {
            Issue.record("expected validationError, got \(String(describing: outcome.error))")
            return
        }
        #expect(session.sent.isEmpty)
    }

    @Test func `a session AppError propagates and is logged`() async {
        let session = FakeEventSubscriptionManager()
        let logger = RecordingLogger()
        let transportError = AppError.cardActionFailed(action: "freeze", details: "rejected by backend")
        session.sendError = transportError

        let outcome = await execute(.freeze(cardId: "card-credit-001"), session: session, logger: logger)
        #expect(outcome.error == transportError)
        #expect(logger.errorRecords.count == 1)
    }

    @Test func `a non-AppError from the transport maps defensively`() async {
        struct TransportMisbehavior: LocalizedError {
            var errorDescription: String? {
                "transport said no"
            }
        }

        let session = FakeEventSubscriptionManager()
        session.sendError = TransportMisbehavior()

        let outcome = await execute(.freeze(cardId: "card-credit-001"), session: session)
        guard case let .apiConnectionFailed(details)? = outcome.error else {
            Issue.record("expected apiConnectionFailed, got \(String(describing: outcome.error))")
            return
        }
        #expect(details?.contains("transport said no") == true)
    }
}
