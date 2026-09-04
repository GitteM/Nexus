# ``Entities``

Value types that make up the app's domain model: the static identity of managed cards and the live data that describes them — balances, transactions, spending limits, and lifecycle state. Every entity is `Codable`, `Sendable`, and `Equatable`, so it can cross the UI, repository, and data layers, and the enums encode by raw value on the wire. Live updates arrive as transport-neutral `BankingEvent` values that each layer decodes into typed entities, outgoing card actions travel as `CardCommand` values, and every failure across boundaries surfaces as `AppError`.

## Topics

### Cards & Commands

- ``Card``
- ``CardCommand``

### Live Account Data

- ``Balance``
- ``Transaction``
- ``SpendingLimit``

### Events & Streams

- ``BankingEvent``
- ``CardState``

### Session & Errors

- ``SessionStatus``
- ``AppError``
