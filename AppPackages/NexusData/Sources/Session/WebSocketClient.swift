import Entities
import Foundation

/// The transport seam behind `APISessionManager` (architecture.md §6.2).
///
/// `APISessionManager` is the one SDK-touching object and the only type that
/// sees this seam. It exists so tests can substitute a fake "SDK client"
/// (tasks.md Day 5) while the real `URLSessionWebSocketTask` plumbing stays
/// in one place. The seam is plain async/await — no delegate callbacks, no
/// `DispatchQueue`, no `@unchecked Sendable` — and carries `AppError` across
/// the boundary.
///
/// The whole transport stack is main-actor confined: URLSession's async APIs
/// do their work off-main and only resume here, so actor isolation is the
/// synchronization (architecture.md §6.2) and nothing needs `Sendable`
/// gymnastics.
@MainActor
protocol WebSocketClientProtocol {
    /// Opens the connection and confirms the open handshake.
    ///
    /// Throws `AppError` when the socket cannot be established; a call while
    /// already connected is a no-op.
    func connect() async throws

    /// Sends one text frame. Throws `AppError` when the socket is unusable.
    func send(_ text: String) async throws

    /// Returns the next inbound text frame.
    ///
    /// Returns `nil` when the connection ended (clean close or local
    /// teardown) and throws `AppError` on transport failure. The manager
    /// drives exactly one receive loop per connection, so callers await each
    /// frame before requesting the next.
    func receive() async throws -> String?

    /// Closes the connection. Pending and future `receive()` calls return
    /// `nil`; the socket can be reopened with `connect()`.
    func disconnect()
}

/// Default transport: `URLSessionWebSocketTask` over a plain `URLSession`
/// (architecture.md §6.2, "URLSession + async/await ... no SDK required").
///
/// Uses only URLSession's async surface — there is no delegate object, so
/// nothing here needs `@unchecked Sendable`. URLSession offers no async
/// "did open" event, so the open handshake is confirmed with a ping, bridged
/// into `withCheckedThrowingContinuation` (the canonical callback → async
/// bridge; architecture.md §6.2).
@MainActor
final class URLSessionWebSocketClient: WebSocketClientProtocol {
    private let url: URL
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?

    init(url: URL) {
        self.url = url
        urlSession = URLSession(configuration: .default)
    }

    func connect() async throws {
        if let task, task.state == .running {
            return
        }
        let newTask = urlSession.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                newTask.sendPing { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            newTask.cancel(with: .goingAway, reason: nil)
            task = nil
            throw AppError.apiConnectionFailed(details: error.localizedDescription)
        }
    }

    func send(_ text: String) async throws {
        guard let task else {
            throw AppError.apiConnectionFailed(details: "No WebSocket connection.")
        }
        do {
            try await task.send(.string(text))
        } catch {
            throw AppError.apiConnectionFailed(details: error.localizedDescription)
        }
    }

    func receive() async throws -> String? {
        guard let task else {
            return nil
        }
        do {
            let message = try await task.receive()
            switch message {
            case let .string(text):
                return text
            case let .data(data):
                return String(data: data, encoding: .utf8)
            @unknown default:
                return nil
            }
        } catch {
            // A cancelled/completed task or a cancelled error is a clean close
            // (disconnect or server close); anything else is a transport
            // failure.
            if task.state == .canceling || task.state == .completed {
                return nil
            }
            if (error as? URLError)?.code == .cancelled {
                return nil
            }
            throw AppError.apiConnectionFailed(details: error.localizedDescription)
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }
}
