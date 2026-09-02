import Entities
import Foundation
import RepositoryProtocols
import Testing

@Suite("CardActionRepositoryProtocol")
struct CardActionRepositoryProtocolTests {
    // MARK: - Shape

    /// Pins the one-shot shape: `async throws` with no `Result` at the
    /// boundary (architecture.md §4.2, §12.1).
    @Test func `execute is async throws and never returns Result`() {
        let repository: CardActionRepositoryProtocol = TestCardActionRepository()
        let _: (CardCommand) async throws -> Void = repository.execute
    }

    // MARK: - Behavior

    @Test func `execute records the commands in order`() async throws {
        let repository = TestCardActionRepository()
        let freeze = CardCommand.freeze(cardId: "card-1")
        let limit = CardCommand.setSpendingLimit(cardId: "card-1", period: .weekly, amount: 500)

        try await repository.execute(freeze)
        try await repository.execute(limit)

        #expect(repository.commands == [freeze, limit])
    }

    @Test func `execute surfaces the configured AppError and records nothing`() async {
        let repository = TestCardActionRepository()
        repository.error = .cardActionFailed(action: "freeze", details: "card is lost")

        do {
            try await repository.execute(.freeze(cardId: "card-1"))
            Issue.record("Expected execute to throw")
        } catch {
            #expect(error as? AppError == .cardActionFailed(action: "freeze", details: "card is lost"))
        }
        #expect(repository.commands.isEmpty)
    }
}
