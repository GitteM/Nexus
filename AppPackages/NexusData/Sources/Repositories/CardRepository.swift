import Entities
import Persistence
import RepositoryProtocols

/// Domain-facing implementation of `CardRepositoryProtocol`
/// (architecture.md §6.3, tasks.md Day 7): the managed-card repository the
/// models call (architecture.md §4.4 example — the dashboard adds an offer
/// via `CardRepository.addCard`).
///
/// The repository is thin: it holds the `SwiftDataCardRepository` durable
/// store (architecture.md §6.4) and adds only the rules the Domain protocol
/// contract states — offer validation and duplicate rejection on `addCard`
/// — plus boundary validation on `removeCard`. The store maps `@Model`
/// records to domain `Card` structs and wraps SwiftData errors as
/// `AppError.persistenceError`; neither `@Model` types nor raw errors cross
/// this boundary.
///
/// **Provisional offer → card mapping.** Until the §11.4 issuance REST
/// contract lands (a backend that provisions a real card and returns its
/// PAN tail), a locally accepted offer is recorded as a `Card` that shares
/// the offer's id, starts `.active`, and carries empty holder/`lastFourDigits`
/// — the fields only the issuance endpoint can fill. No card number is ever
/// fabricated, stored, or logged (architecture.md §6.4). Demo mode does not
/// use this path at all: demo offers become cards through the Day 8 mock
/// repositories.
public struct CardRepository: CardRepositoryProtocol, Sendable {
    private let store: SwiftDataCardRepository

    public init(store: SwiftDataCardRepository) {
        self.store = store
    }

    /// All managed cards, in stable id order (durable SwiftData read).
    public func getCards() async throws -> [Card] {
        try await store.fetchCards()
    }

    /// Turns an accepted `CardOffer` into a managed `Card`.
    ///
    /// - Throws `AppError.validationError` when the offer cannot be
    ///   persisted (empty id or currency).
    /// - Throws `AppError.cardAlreadyExists` when an offer with the same id
    ///   is already managed (architecture.md §4.2 contract).
    public func addCard(_ offer: CardOffer) async throws -> Card {
        try Self.validate(offer)
        let existing = try await store.fetchCards()
        guard !existing.contains(where: { $0.id == offer.id }) else {
            throw AppError.cardAlreadyExists(cardId: offer.id)
        }
        let card = Self.provisionedCard(from: offer)
        try await store.insert(card)
        return card
    }

    /// Removes a managed card by id. Removing an unknown id is a no-op
    /// (idempotent, mirroring the store's delete semantics).
    public func removeCard(cardId: String) async throws {
        try Self.validate(cardId)
        try await store.delete(cardId: cardId)
    }

    // MARK: - Validation

    /// Rejects offers that cannot produce a persisted `Card`. The id is the
    /// natural key (and the duplicate check's identity); the currency is a
    /// required `Card` field with no local default.
    private static func validate(_ offer: CardOffer) throws {
        guard !offer.id.isEmpty else {
            throw AppError.validationError(
                field: "offerId",
                reason: "Offer id must not be empty.",
            )
        }
        guard !offer.currency.isEmpty else {
            throw AppError.validationError(
                field: "currency",
                reason: "Offer currency must not be empty.",
            )
        }
    }

    /// Rejects empty ids before they reach the store.
    private static func validate(_ cardId: String) throws {
        guard !cardId.isEmpty else {
            throw AppError.validationError(
                field: "cardId",
                reason: "Card id must not be empty.",
            )
        }
    }

    /// The provisional local record for an accepted offer (see the type
    /// documentation for the mapping caveat).
    private static func provisionedCard(from offer: CardOffer) -> Card {
        Card(
            id: offer.id,
            cardholderName: "",
            lastFourDigits: "",
            type: offer.type,
            status: .active,
            currency: offer.currency,
            spendingLimit: nil,
        )
    }
}
