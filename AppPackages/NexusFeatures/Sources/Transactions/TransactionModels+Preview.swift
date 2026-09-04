#if DEBUG
    import Entities
    import Mocks

    /// Shared-mock factories for the transaction screens.
    ///
    /// Every factory builds the *real* models over the shared `Mock*`
    /// repository doubles; `load()` fires from the views' `.task` when a
    /// preview appears, exactly as in the running app. Release builds
    /// compile this file to nothing: the `Mocks` module is empty outside
    /// DEBUG.
    public extension TransactionHistoryModel {
        /// Default demo content for one card: seeded balance + the standard
        /// transaction set (the credit-card mock feed; other cards preview
        /// with an empty feed and no balance).
        static func preview(cardID: String) -> TransactionHistoryModel {
            detailModel(
                cardID: cardID,
                balances: Balance.mockDefaults,
                transactions: seededTransactions(for: cardID),
            )
        }

        /// Loading preview: the balance fetch parks forever
        /// (`shouldNeverComplete`), so `load()` never leaves `.loading`.
        static func loadingPreview(cardID: String) -> TransactionHistoryModel {
            let balanceRepository = MockBalanceRepository(seed: Balance.mockDefaults)
            balanceRepository.shouldNeverComplete = true
            return TransactionHistoryModel(
                cardID: cardID,
                balanceRepository: balanceRepository,
                transactionRepository: MockTransactionRepository(
                    seed: [cardID: Self.seededTransactions(for: cardID)],
                ),
            )
        }

        /// Error preview: the balance fetch throws (default
        /// `.apiConnectionFailed`), so `load()` lands in `.error`.
        static func errorPreview(
            cardID: String,
            error: AppError = .apiConnectionFailed(),
        ) -> TransactionHistoryModel {
            let balanceRepository = MockBalanceRepository(seed: Balance.mockDefaults)
            balanceRepository.shouldThrowError = true
            balanceRepository.thrownError = error
            return TransactionHistoryModel(
                cardID: cardID,
                balanceRepository: balanceRepository,
                transactionRepository: MockTransactionRepository(
                    seed: [cardID: Self.seededTransactions(for: cardID)],
                ),
            )
        }

        /// The demo transaction set keyed by card; only the mock credit
        /// card carries activity in demo data.
        private static func seededTransactions(for cardID: String) -> [Transaction] {
            cardID == Card.mockCreditCard.id ? Transaction.mockDefaults : []
        }

        private static func detailModel(
            cardID: String,
            balances: [Balance],
            transactions: [Transaction],
        ) -> TransactionHistoryModel {
            TransactionHistoryModel(
                cardID: cardID,
                balanceRepository: MockBalanceRepository(seed: balances),
                transactionRepository: MockTransactionRepository(
                    seed: [cardID: transactions],
                ),
            )
        }
    }

    public extension TransactionDetailModel {
        /// Default detail preview over the shared transaction mock feed.
        static func preview(
            cardID: String,
            transactionID: String,
        ) -> TransactionDetailModel {
            TransactionDetailModel(
                cardID: cardID,
                transactionID: transactionID,
                transactionRepository: MockTransactionRepository(
                    seed: [cardID: cardID == Card.mockCreditCard.id ? Transaction.mockDefaults : []],
                ),
            )
        }
    }
#endif
