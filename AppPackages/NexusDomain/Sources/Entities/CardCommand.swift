import Foundation

/// An outgoing card action sent through `CardActionRepository`.
///
/// `amount` and `period` carry the payload for `.setSpendingLimit` and are
/// nil for every other type. Use the static factories (`freeze`,
/// `unfreeze`, `setSpendingLimit`) instead of the memberwise init where they
/// fit.
public struct CardCommand: Codable, Sendable, Equatable {
    public let cardId: String
    public let type: CardCommandType
    public let amount: Decimal?
    public let period: SpendingLimitPeriod?

    public init(
        cardId: String,
        type: CardCommandType,
        amount: Decimal? = nil,
        period: SpendingLimitPeriod? = nil,
    ) {
        self.cardId = cardId
        self.type = type
        self.amount = amount
        self.period = period
    }
}

public extension CardCommand {
    static func freeze(cardId: String) -> CardCommand {
        CardCommand(cardId: cardId, type: .freeze)
    }

    static func unfreeze(cardId: String) -> CardCommand {
        CardCommand(cardId: cardId, type: .unfreeze)
    }

    static func setSpendingLimit(
        cardId: String,
        period: SpendingLimitPeriod,
        amount: Decimal,
    ) -> CardCommand {
        CardCommand(cardId: cardId, type: .setSpendingLimit, amount: amount, period: period)
    }
}
