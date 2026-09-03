import Entities
import Foundation
import SwiftData

/// SwiftData record for one managed card (architecture.md §6.4, tasks.md
/// Day 7).
///
/// **`@Model` classes never leave NexusData.** `StoredCard` is `internal` to
/// the `Persistence` target on purpose: the only code that ever touches it is
/// `StoredCardModelActor` (same file scope as the store facade). Domain and
/// Features see only `Card` structs; this class is neither `Sendable` nor
/// `Codable` and is never returned from a repository method.
///
/// **Banking-specific storage rule** (architecture.md §6.4): the record holds
/// only what the domain `Card` itself carries — display-safe identity data
/// (`lastFourDigits` at most, never a full PAN). Card numbers, CVV, and auth
/// tokens are never persisted anywhere in plaintext; credentials belong in
/// `KeychainWrapper`.
///
/// Enum `CardType`/`CardStatus` values are stored by raw string so the schema
/// stays primitive (SwiftData stores the raw value, matching the wire
/// encoding, architecture.md §4.1) and are mapped back through their failable
/// inits in `toDomain()` — a corrupted raw value surfaces as
/// `AppError.persistenceError`, never a force-unwrap or a silently wrong
/// card.
@Model
final class StoredCard {
    /// Managed card id (the domain `Card.id`).
    var id: String = ""
    var cardholderName: String = ""
    var lastFourDigits: String = ""
    /// `CardType.rawValue` ("credit", "debit", "prepaid").
    var typeRaw: String = ""
    /// `CardStatus.rawValue` ("active", "frozen", "expired", "lost").
    var statusRaw: String = ""
    var currency: String = ""
    var spendingLimit: Decimal?

    /// Maps a domain `Card` into a storage record. Infallible: a domain
    /// `Card` always carries valid raw values.
    init(card: Card) {
        id = card.id
        cardholderName = card.cardholderName
        lastFourDigits = card.lastFourDigits
        typeRaw = card.type.rawValue
        statusRaw = card.status.rawValue
        currency = card.currency
        spendingLimit = card.spendingLimit
    }

    /// Overwrites every field from a domain `Card` (used both on insert and
    /// when an existing record is updated in place).
    func apply(_ card: Card) {
        id = card.id
        cardholderName = card.cardholderName
        lastFourDigits = card.lastFourDigits
        typeRaw = card.type.rawValue
        statusRaw = card.status.rawValue
        currency = card.currency
        spendingLimit = card.spendingLimit
    }

    /// Maps the record back to a domain `Card`.
    ///
    /// Throws `AppError.persistenceError` when a stored raw value no longer
    /// matches a known `CardType`/`CardStatus` (schema drift or store
    /// corruption). The detail names only the record's id and the offending
    /// raw value so the corrupted row can be located — never a card number,
    /// CVV, or auth token (the display-safe posture of architecture.md
    /// §6.4).
    func toDomain() throws -> Card {
        guard let type = CardType(rawValue: typeRaw) else {
            throw AppError.persistenceError(
                operation: "read_card",
                details: "Stored card '\(id)' has unknown type '\(typeRaw)'.",
            )
        }
        guard let status = CardStatus(rawValue: statusRaw) else {
            throw AppError.persistenceError(
                operation: "read_card",
                details: "Stored card '\(id)' has unknown status '\(statusRaw)'.",
            )
        }
        return Card(
            id: id,
            cardholderName: cardholderName,
            lastFourDigits: lastFourDigits,
            type: type,
            status: status,
            currency: currency,
            spendingLimit: spendingLimit,
        )
    }
}
