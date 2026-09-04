# ``Transactions``

One card's account activity: the transaction history screen with its live balance header and searchable, filterable feed, plus the transaction detail deep view. `TransactionHistoryModel` owns the balance and feed subscriptions and publishes the query that the pure `TransactionQuery` filtering rule applies; `TransactionDetailModel` fetches the feed once and resolves the matching transaction. Both screens switch on explicit view states — loading, loaded, error, and a missing state for a stale detail link.

## Topics

### Models

- ``TransactionHistoryModel``
- ``TransactionDetailModel``

### Filtering

- ``TransactionQuery``
- ``TransactionDateRange``

### Views

- ``TransactionHistoryView``
- ``TransactionDetailView``

### View State

- ``TransactionHistoryViewState``
- ``TransactionDetailViewState``
