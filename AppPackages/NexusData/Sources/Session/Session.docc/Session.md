# ``Session``

The live transport layer: `APISessionManager` is the app's one SDK-touching object, a URLSession-backed `SessionManagerProtocol` implementation that connects a WebSocket, decodes inbound frames into `BankingEvent`s, and fans them out to per-channel `AsyncStream` subscribers. `EventSubscriptionManager` is the narrow facade data sources receive (never the manager or the SDK behind it), and `EventSubscriptionManagerProtocol` is the Sendable seam they depend on. Subscriptions registered while disconnected queue as pending until the next successful `connect()`.

## Topics

### Session management

- ``APISessionManager``

### Event subscriptions

- ``EventSubscriptionManagerProtocol``
- ``EventSubscriptionManager``
