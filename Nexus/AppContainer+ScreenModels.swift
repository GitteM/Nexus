import CardDetail
import Transactions

extension AppContainer {
    /// The card detail model for a route, created once per card id.
    /// Destinations can be evaluated more than once around a push and must
    /// always present the same screen state (PR #26) — the container owns
    /// the models, so reuse is guaranteed here.
    func cardDetailModel(cardID: String) -> CardDetailModel {
        if let existing = cardDetailModels[cardID] {
            return existing
        }
        guard let dependencies else {
            fatalError("container has no dependencies")
        }
        let model = CardDetailModel(
            cardID: cardID,
            cardRepository: dependencies.cardRepository,
            statusRepository: dependencies.statusRepository,
            actionRepository: dependencies.actionRepository,
        )
        cardDetailModels[cardID] = model
        return model
    }

    /// The transaction-history model for a route, created once per card.
    func historyModel(cardID: String) -> TransactionHistoryModel {
        if let existing = historyModels[cardID] {
            return existing
        }
        guard let dependencies else {
            fatalError("container has no dependencies")
        }
        let model = TransactionHistoryModel(
            cardID: cardID,
            balanceRepository: dependencies.balanceRepository,
            transactionRepository: dependencies.transactionRepository,
        )
        historyModels[cardID] = model
        return model
    }

    /// The transaction-detail model for a route, created once per
    /// (card, transaction) pair.
    func transactionDetailModel(cardID: String, transactionID: String) -> TransactionDetailModel {
        let key = "\(cardID):\(transactionID)"
        if let existing = transactionDetailModels[key] {
            return existing
        }
        guard let dependencies else {
            fatalError("container has no dependencies")
        }
        let model = TransactionDetailModel(
            cardID: cardID,
            transactionID: transactionID,
            transactionRepository: dependencies.transactionRepository,
        )
        transactionDetailModels[key] = model
        return model
    }
}
