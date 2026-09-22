import Entities
import Testing

/// `CardStatus.permits(_:)` — the lifecycle legality the card-detail model
/// enforces, tested once here instead of through the feature model.
@Suite("Card status command legality")
struct CardCommandLegalityTests {
    @Test func `active card permits freeze, limit changes, and reporting an issue`() {
        #expect(CardStatus.active.permits(.freeze))
        #expect(CardStatus.active.permits(.setSpendingLimit))
        #expect(CardStatus.active.permits(.reportLost))
        #expect(CardStatus.active.permits(.reportStolen))
        #expect(!CardStatus.active.permits(.unfreeze))
        #expect(!CardStatus.active.permits(.requestReplacement))
    }

    @Test func `frozen card permits unfreeze, limit changes, and reporting an issue`() {
        #expect(CardStatus.frozen.permits(.unfreeze))
        #expect(CardStatus.frozen.permits(.setSpendingLimit))
        #expect(CardStatus.frozen.permits(.reportLost))
        #expect(CardStatus.frozen.permits(.reportStolen))
        #expect(!CardStatus.frozen.permits(.freeze))
        #expect(!CardStatus.frozen.permits(.requestReplacement))
    }

    @Test func `expired card permits no action`() {
        for command in CardCommandType.allCases {
            #expect(!CardStatus.expired.permits(command), "permits \(command) unexpectedly")
        }
    }

    @Test func `lost card permits a replacement only`() {
        #expect(CardStatus.lost.permits(.requestReplacement))
        #expect(!CardStatus.lost.permits(.freeze))
        #expect(!CardStatus.lost.permits(.unfreeze))
        #expect(!CardStatus.lost.permits(.reportLost))
        #expect(!CardStatus.lost.permits(.setSpendingLimit))
    }

    @Test func `unknown command is never permitted`() {
        for status in CardStatus.allCases {
            #expect(!status.permits(.unknown), "\(status) permits .unknown")
        }
    }
}
