# ``Repositories``

Thin, domain-facing implementations of the `RepositoryProtocols` from NexusDomain. Each repository wraps one data source or store, adds boundary validation and the error contract models rely on (every failure surfaces as `AppError`), and hides Data-layer types behind protocol conformance. `CardRepository` additionally enforces offer validation and atomic duplicate rejection on the managed-card store.

## Topics

### Cards

- ``CardRepository``
- ``CardStatusRepository``
- ``CardActionRepository``

### Offers, balance, and transactions

- ``CardOffersRepository``
- ``BalanceRepository``
- ``TransactionsRepository``
