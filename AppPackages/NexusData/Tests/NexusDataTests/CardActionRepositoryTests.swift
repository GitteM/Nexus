import DataSources
import Entities
import Foundation
import Repositories
import Testing

/// Tests for the thin `CardActionRepository` over the real
/// `CardActionDataSource` driven by the fake session facade (tasks.md Day 7).
@Suite("CardActionRepository")
@MainActor
struct CardActionRepositoryTests {
    private func makeRepository() -> (CardActionRepository, FakeEventSubscriptionManager) {
        let session = FakeEventSubscriptionManager()
        let source = CardActionDataSource(
            eventSubscriptionManager: session,
            logger: RecordingLogger()
        )
        return (CardActionRepository(source: source), session)
    }

    private func decodeCommand(payload: String) throws -> CardCommand {
        try JSONDecoder().decode(CardCommand.self, from: Data(payload.utf8))
    }

    @Test
    func `freeze sends a serialized command on the commands channel`() async throws {
        let (repository, session) = makeRepository()

        try await repository.execute(.freeze(cardId: "card-credit-001"))

        #expect(session.sent.count == 1)
        #expect(session.sent.first?.channel == EventChannels.commands)
        let sent = try decodeCommand(payload: #require(session.sent.first?.payload))
        #expect(sent == .freeze(cardId: "card-credit-001"))
    }

    @Test
    func `setSpendingLimit carries amount and period on the wire`() async throws {
        let (repository, session) = makeRepository()
        let command = CardCommand.setSpendingLimit(
            cardId: "card-credit-001",
            period: .daily,
            amount: 500
        )

        try await repository.execute(command)

        let sent = try decodeCommand(payload: #require(session.sent.first?.payload))
        #expect(sent == command)
        #expect(sent.amount == 500)
        #expect(sent.period == .daily)
    }

    @Test
    func `send failure surfaces as the same AppError`() async throws {
        let (repository, session) = makeRepository()
        session.sendError = AppError.apiConnectionFailed(details: "socket closed")

        do {
            try await repository.execute(.freeze(cardId: "card-credit-001"))
            Issue.record("Expected the send failure to propagate.")
        } catch let error as AppError {
            #expect(error == AppError.apiConnectionFailed(details: "socket closed"))
        } catch {
            Issue.record("Expected AppError, got \(error).")
        }
    }

    @Test
    func `empty card id is rejected before the wire`() async throws {
        let (repository, session) = makeRepository()

        do {
            try await repository.execute(.freeze(cardId: ""))
            Issue.record("Expected validationError for an empty card id.")
        } catch let error as AppError {
            guard case let .validationError(field, _) = error else {
                Issue.record("Expected .validationError, got \(error).")
                return
            }
            #expect(field == "cardId")
        } catch {
            Issue.record("Expected AppError, got \(error).")
        }
        #expect(session.sent.isEmpty)
    }

    @Test
    func `unknown command type is rejected before the wire`() async throws {
        let (repository, session) = makeRepository()
        let command = CardCommand(cardId: "card-credit-001", type: .unknown)

        await #expect(throws: AppError.self) {
            try await repository.execute(command)
        }
        #expect(session.sent.isEmpty)
    }

    @Test
    func `payload on a payload-free command is rejected`() async throws {
        let (repository, session) = makeRepository()
        // freeze takes no amount/period — a command carrying them is invalid.
        let command = CardCommand(
            cardId: "card-credit-001",
            type: .freeze,
            amount: 100,
            period: .daily
        )

        await #expect(throws: AppError.self) {
            try await repository.execute(command)
        }
        #expect(session.sent.isEmpty)
    }
}
