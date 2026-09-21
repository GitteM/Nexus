import CardDetail
import Navigation
import Transactions

extension AppContainer {
    /// Materializes the screen models the current navigation stack needs and
    /// evicts the ones whose route has left it.
    ///
    /// Called from the shell's `.onChange(of: router.routes, initial: true)`
    /// — never during view-body evaluation. SwiftUI may evaluate a
    /// destination more than once around a push, and mutating container state
    /// while a body runs is undefined behaviour, so materializing here keeps
    /// destinations a pure lookup. Reuse per route key keeps a pushed screen's
    /// state stable across those re-evaluations (PR #26); eviction releases
    /// the models — and the subscription tasks they own — as soon as their
    /// route is popped instead of holding them until the container deinits.
    func prepareScreenModels(for routes: [Route]) {
        guard let dependencies else {
            // No graph (live mode without a backend): build nothing and drop
            // anything left over from a previous graph. The state machine
            // already surfaces the configuration gap.
            evictAllScreenModels()
            return
        }

        var cardIDs: Set<String> = []
        var historyCardIDs: Set<String> = []
        var transactionKeys: Set<String> = []

        for route in routes {
            switch route {
            case let .cardDetail(cardID):
                cardIDs.insert(cardID)
                if cardDetailModels[cardID] == nil {
                    cardDetailModels[cardID] = CardDetailModel(
                        cardID: cardID,
                        cardRepository: dependencies.cardRepository,
                        statusRepository: dependencies.statusRepository,
                        actionRepository: dependencies.actionRepository
                    )
                }
            case let .transactionHistory(cardID):
                historyCardIDs.insert(cardID)
                if historyModels[cardID] == nil {
                    historyModels[cardID] = TransactionHistoryModel(
                        cardID: cardID,
                        balanceRepository: dependencies.balanceRepository,
                        transactionRepository: dependencies.transactionRepository
                    )
                }
            case let .transactionDetail(cardID, transactionID):
                let key = Self.transactionDetailKey(cardID: cardID, transactionID: transactionID)
                transactionKeys.insert(key)
                if transactionDetailModels[key] == nil {
                    transactionDetailModels[key] = TransactionDetailModel(
                        cardID: cardID,
                        transactionID: transactionID,
                        transactionRepository: dependencies.transactionRepository
                    )
                }
            }
        }

        evict(&cardDetailModels, keeping: cardIDs)
        evict(&historyModels, keeping: historyCardIDs)
        evict(&transactionDetailModels, keeping: transactionKeys)
    }

    /// The card detail model for a route, or `nil` until
    /// `prepareScreenModels(for:)` has built it. A pure, non-mutating lookup:
    /// destinations read it during body evaluation, so it must never create a
    /// model as a side effect of rendering.
    func cardDetailModel(cardID: String) -> CardDetailModel? {
        cardDetailModels[cardID]
    }

    /// The transaction-history model for a route, or `nil` until prepared.
    func historyModel(cardID: String) -> TransactionHistoryModel? {
        historyModels[cardID]
    }

    /// The transaction-detail model for a (card, transaction) route, or `nil`
    /// until prepared.
    func transactionDetailModel(cardID: String, transactionID: String) -> TransactionDetailModel? {
        transactionDetailModels[Self.transactionDetailKey(
            cardID: cardID,
            transactionID: transactionID
        )]
    }

    /// The dictionary key for a transaction-detail route. One place, so the
    /// creator and the lookup can never disagree.
    static func transactionDetailKey(cardID: String, transactionID: String) -> String {
        "\(cardID):\(transactionID)"
    }

    /// Drops every model whose key is not in `keys`. Every key just created is
    /// present, so equal counts mean nothing to drop — and a no-op avoids an
    /// observation notification on every navigation change.
    private func evict<Model>(_ models: inout [String: Model], keeping keys: Set<String>) {
        guard models.count != keys.count else { return }
        models = models.filter { keys.contains($0.key) }
    }

    private func evictAllScreenModels() {
        cardDetailModels.removeAll()
        historyModels.removeAll()
        transactionDetailModels.removeAll()
    }
}
