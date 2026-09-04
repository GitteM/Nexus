# ``DataSources``

The live per-card data sources: actors (and one stateless struct) that subscribe to the session's event channels, parse only the payload shape they own, cache the latest decoded state per card id, and hand out seeded `AsyncStream`s that yield current state first, then live updates. `OffersSnapshotDTO` and `EventChannels` define the wire contract once, and the `JSONDecoder` extension makes every decode failure a contextual `AppError.deserializationError`.

## Topics

### Live per-card sources

- ``CardStateDataSource``
- ``CardBalanceDataSource``
- ``CardTransactionsDataSource``
- ``OffersDataSource``
- ``CardActionDataSource``

### Wire formats and channels

- ``OffersSnapshotDTO``
- ``EventChannels``
