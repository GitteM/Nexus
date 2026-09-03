import Entities
import Foundation
import RepositoryProtocols
import ServiceProtocols

// Minimal in-target conformers proving the Day 4 protocol shapes compile
// and mock cleanly.
//
// The shared, seeded `#if DEBUG` mocks live in `NexusData/Mocks`
// (architecture.md §9.5, tasks.md Day 8); these doubles exist only so the
// NexusDomain test target can exercise the protocols without leaving the
// package. Each double is created per test, so mutable state never crosses
// concurrency domains. The repository protocols are `Sendable` (§4.2), so
// the doubles are main-actor classes (implicitly Sendable), matching the
// `@MainActor` mock repositories.

// MARK: - Repository doubles

@MainActor
final class TestCardRepository: CardRepositoryProtocol {
    private(set) var cards: [Card]
    var error: AppError?

    init(cards: [Card] = Card.mockDefaults) {
        self.cards = cards
    }

    func getCards() async throws -> [Card] {
        if let error {
            throw error
        }
        return cards
    }

    func addCard(_ offer: CardOffer) async throws -> Card {
        if let error {
            throw error
        }
        let card = Card(
            id: offer.id,
            cardholderName: "Jordan Avery",
            lastFourDigits: "0000",
            type: offer.type,
            status: .active,
            currency: offer.currency,
            spendingLimit: nil,
        )
        cards.append(card)
        return card
    }

    func removeCard(cardId: String) async throws {
        if let error {
            throw error
        }
        cards.removeAll { $0.id == cardId }
    }
}

@MainActor
final class TestCardOffersRepository: CardOffersRepositoryProtocol {
    private(set) var offers: [CardOffer]
    var error: AppError?
    var subscribeError: AppError?
    private var continuations: [AsyncStream<[CardOffer]>.Continuation] = []

    init(offers: [CardOffer] = CardOffer.mockDefaults) {
        self.offers = offers
    }

    func getAvailableOffers() async throws -> [CardOffer] {
        if let error {
            throw error
        }
        return offers
    }

    func subscribeToOffers() async throws -> AsyncStream<[CardOffer]> {
        if let subscribeError {
            throw subscribeError
        }
        let (stream, continuation) = AsyncStream<[CardOffer]>.makeStream()
        continuation.yield(offers)
        continuations.append(continuation)
        return stream
    }

    /// Pushes an updated offer list to every active subscription.
    func emit(_ offers: [CardOffer]) {
        self.offers = offers
        for continuation in continuations {
            continuation.yield(offers)
        }
    }
}

@MainActor
final class TestCardStatusRepository: CardStatusRepositoryProtocol {
    private(set) var states: [String: CardState]
    var error: AppError?
    var subscribeError: AppError?
    private var continuations: [String: [AsyncStream<CardState>.Continuation]] = [:]

    init(states: [CardState] = []) {
        self.states = Dictionary(uniqueKeysWithValues: states.map { ($0.cardId, $0) })
    }

    func getCardStatus(cardId: String) async throws -> CardState? {
        if let error {
            throw error
        }
        return states[cardId]
    }

    func subscribeToCardStatus(cardId: String) async throws -> AsyncStream<CardState> {
        if let subscribeError {
            throw subscribeError
        }
        let (stream, continuation) = AsyncStream<CardState>.makeStream()
        if let state = states[cardId] {
            continuation.yield(state)
        }
        continuations[cardId, default: []].append(continuation)
        return stream
    }

    /// Pushes an updated state to every subscriber of that card.
    func emit(_ state: CardState) {
        states[state.cardId] = state
        for continuation in continuations[state.cardId, default: []] {
            continuation.yield(state)
        }
    }

    /// Ends every active subscription.
    func finishAllSubscriptions() {
        for channelContinuations in continuations.values {
            for continuation in channelContinuations {
                continuation.finish()
            }
        }
        continuations = [:]
    }
}

@MainActor
final class TestCardActionRepository: CardActionRepositoryProtocol {
    private(set) var commands: [CardCommand] = []
    var error: AppError?

    func execute(_ command: CardCommand) async throws {
        if let error {
            throw error
        }
        commands.append(command)
    }
}

// MARK: - Service doubles

/// Equality carrier so `TestLogger` can assert recorded calls.
struct LogEntry: Equatable {
    let message: String
    let level: LogLevel
}

@MainActor
final class TestLogger: @preconcurrency LoggerProtocol {
    private(set) var entries: [LogEntry] = []

    func log(_ message: String, level: LogLevel) {
        entries.append(LogEntry(message: message, level: level))
    }
}

@MainActor
final class TestSessionManager: @preconcurrency SessionManagerProtocol {
    private(set) var sessionStatus: SessionStatus = .disconnected
    var connectError: AppError?
    var sendError: AppError?
    private(set) var sent: [(channel: String, payload: String)] = []
    private var continuations: [String: [AsyncStream<BankingEvent>.Continuation]] = [:]

    func connect() async throws {
        if let connectError {
            throw connectError
        }
        sessionStatus = .connected
    }

    func disconnect() {
        sessionStatus = .disconnected
        finishAllStreams()
    }

    func events(for channel: String) -> AsyncStream<BankingEvent> {
        let (stream, continuation) = AsyncStream<BankingEvent>.makeStream()
        continuations[channel, default: []].append(continuation)
        return stream
    }

    func send(to channel: String, payload: String) async throws {
        if let sendError {
            throw sendError
        }
        sent.append((channel, payload))
    }

    /// Pushes an event to every subscriber of its channel.
    func emit(_ event: BankingEvent) {
        for continuation in continuations[event.channel, default: []] {
            continuation.yield(event)
        }
    }

    /// Ends every active stream (like real session teardown).
    func finishAllStreams() {
        for channelContinuations in continuations.values {
            for continuation in channelContinuations {
                continuation.finish()
            }
        }
        continuations = [:]
    }
}
