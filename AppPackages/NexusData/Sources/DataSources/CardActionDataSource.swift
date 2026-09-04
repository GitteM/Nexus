import Entities
import Foundation
import ServiceProtocols
import Session

/// Stateless one-shot source for outgoing card actions.
///
/// `CardActionRepositoryProtocol` validates and adds operation context on
/// top of this struct. The struct itself encodes a `CardCommand` and sends
/// it on the `card.commands` channel; the resulting state arrives back on
/// the live per-card event channel, which is what `CardStateDataSource`
/// streams.
///
/// `Sendable`: stateless, safe to pass across concurrency domains — both
/// collaborators are `Sendable` protocol requirements.
public struct CardActionDataSource: Sendable {
    private let eventSubscriptionManager: any EventSubscriptionManagerProtocol
    private let logger: any LoggerProtocol

    public init(
        eventSubscriptionManager: any EventSubscriptionManagerProtocol,
        logger: any LoggerProtocol,
    ) {
        self.eventSubscriptionManager = eventSubscriptionManager
        self.logger = logger
    }

    /// Sends one `CardCommand` to the backend.
    ///
    /// Throws `AppError.validationError` for commands that cannot be sent
    /// (empty card id, `.unknown` type, payload attached to the wrong type or
    /// missing from `.setSpendingLimit`), `AppError.serializationError` when
    /// encoding fails, and the session's `AppError` when the send fails (a
    /// non-`AppError` from a misbehaving transport is mapped defensively).
    public func execute(_ command: CardCommand) async throws {
        try validate(command)
        let payload: String
        do {
            let data = try JSONEncoder().encode(command)
            guard let text = String(data: data, encoding: .utf8) else {
                throw AppError.serializationError(
                    type: "CardCommand",
                    details: "Encoded payload is not valid UTF-8.",
                )
            }
            payload = text
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.serializationError(
                type: "CardCommand",
                details: error.localizedDescription,
            )
        }
        do {
            try await eventSubscriptionManager.send(
                to: EventChannels.commands,
                payload: payload,
            )
        } catch {
            let mapped = (error as? AppError)
                ?? AppError.apiConnectionFailed(details: error.localizedDescription)
            logger.log(
                "Card command \(command.type.displayName) for card \(command.cardId) failed to send.",
                level: .error,
            )
            throw mapped
        }
    }

    // MARK: - Validation

    /// Rejects commands the app must never put on the wire.
    private func validate(_ command: CardCommand) throws {
        guard !command.cardId.isEmpty else {
            throw AppError.validationError(
                field: "cardId",
                reason: "Card id must not be empty.",
            )
        }
        guard command.type != .unknown else {
            throw AppError.validationError(
                field: "type",
                reason: "Cannot send an unknown card action.",
            )
        }
        switch command.type {
        case .setSpendingLimit:
            guard command.period != nil else {
                throw AppError.validationError(
                    field: "period",
                    reason: "setSpendingLimit requires a period.",
                )
            }
            guard command.amount != nil else {
                throw AppError.validationError(
                    field: "amount",
                    reason: "setSpendingLimit requires an amount.",
                )
            }
        default:
            guard command.amount == nil, command.period == nil else {
                throw AppError.validationError(
                    field: "payload",
                    reason: "\(command.type.displayName) takes no amount or period.",
                )
            }
        }
    }
}
