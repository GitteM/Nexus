# ``Mocks``

In-memory doubles for previews, tests, and demo mode, compiled only under `#if DEBUG`. Repository-protocol mocks mirror the live contracts — seed state, seeded-stream semantics, failure knobs, and call counts — while `MockSessionManager` stands in for the real transport and `MockEventGenerator` produces the synthetic event cycle that exercises the real `AsyncStream` → model → view pipeline.

## Topics

### Repository doubles

- ``MockCardRepository``
- ``MockStatusRepository``
- ``MockBalanceRepository``
- ``MockTransactionRepository``
- ``MockOffersRepository``
- ``MockActionRepository``

### Demo session and events

- ``MockSessionManager``
- ``MockEventGenerator``

### Backend command echo

- ``MockCommandCoordinator``
