# ``ServiceProtocols``

The service seams the app is built against: `SessionManagerProtocol` is the transport, connecting and disconnecting the authenticated session, streaming the live `BankingEvent`s of a channel, and sending outgoing payloads. `LoggerProtocol` with its `LogLevel` severity taxonomy is the logging seam every layer receives through its initializer. There are no completion handlers anywhere — one-shot calls throw `AppError` and live events are `AsyncStream`s — and the Data layer supplies the concrete adapters behind these protocols.

## Topics

### Session

- ``SessionManagerProtocol``

### Logging

- ``LoggerProtocol``
- ``LogLevel``
