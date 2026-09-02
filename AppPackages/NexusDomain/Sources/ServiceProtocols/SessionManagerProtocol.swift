import Entities

/// The transport seam for the app session (architecture.md §4.3).
///
/// The app is built against this protocol; the Data layer implements it with
/// URLSession (REST + `URLSessionWebSocketTask`) in `APISessionManager`
/// (architecture.md §6.2), and a banking SDK — when one exists — is just
/// another adapter (architecture.md §11.4). No completion handlers anywhere:
/// one-shot calls throw `AppError`, and live events are `AsyncStream`s.
public protocol SessionManagerProtocol: Sendable {
    /// Current connection state, observed by the UI through the container
    /// (`SessionStatusIndicator`, `DisconnectedView`).
    var sessionStatus: SessionStatus { get }

    /// Establishes an authenticated session.
    ///
    /// Throws `AppError` when the handshake fails; `sessionStatus` moves
    /// through `.connecting` while the attempt is in flight.
    func connect() async throws

    /// Tears the session down; active event streams finish.
    func disconnect()

    /// Subscribes to the live events of one channel (e.g. `card.events.{id}`).
    ///
    /// Each call returns an independent stream; termination cleanup happens
    /// through the stream's `onTermination`.
    func events(for channel: String) -> AsyncStream<BankingEvent>

    /// Sends an outgoing payload on a channel.
    ///
    /// Throws `AppError` when the send fails.
    func send(to channel: String, payload: String) async throws
}
