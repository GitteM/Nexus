# ``Logging``

The Data layer's logging infrastructure: `LoggingService` is the OSLog-backed implementation of Domain's `LoggerProtocol`. It maps the Domain `LogLevel` to the matching `OSLogType` and records every message through the unified system log with `.public` privacy — safe because the caller contract is that messages carry display-safe data only.

## Topics

### Logging service

- ``LoggingService``
