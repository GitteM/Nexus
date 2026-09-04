# ``RepositoryProtocols``

The repository contracts the app consumes: one-shot `async throws` reads plus long-lived subscriptions for managed cards, offers, balances, lifecycle status, and transactions, along with the seam that executes outgoing card commands. Live updates are `AsyncStream`s of entities decoded from `BankingEvent` frames — each stream yields the current value first, then updates as new frames arrive. Protocols are `Sendable` so implementations can be shared across concurrency domains, and failures always surface as `AppError`.

## Topics

### Cards & Offers

- ``CardRepositoryProtocol``
- ``CardActionRepositoryProtocol``
- ``CardOffersRepositoryProtocol``

### Live Status & Activity

- ``CardStatusRepositoryProtocol``
- ``BalanceRepositoryProtocol``
- ``TransactionRepositoryProtocol``
