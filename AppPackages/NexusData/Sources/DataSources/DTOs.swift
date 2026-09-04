import Entities
import Foundation

/// Wire payload shapes, defined once in NexusData as DTOs — the backend
/// mirrors them.
///
/// The event payloads whose shape *is* an entity (`CardState`, `Balance`,
/// `Transaction`, `SpendingLimit`, outbound `CardCommand`) decode straight
/// into those Codable entities — no duplicate DTO layer. This file holds the
/// shapes that are not entity-shaped:
///
/// - `OffersSnapshotDTO` — the `card.offers` payload. A full-list
///   replacement is wrapped in an envelope (rather than a bare array) so the
///   backend can later add a version/generation field without breaking
///   clients, and so a decode either yields the whole list or fails as one
///   unit. Malformed payloads are logged and skipped, never partially
///   applied.
///
/// REST response DTOs for the repository one-shots extend this file when
/// that wire contract is written.
public struct OffersSnapshotDTO: Codable, Sendable, Equatable {
    /// The offers available right now, in display order.
    public let offers: [CardOffer]

    public init(offers: [CardOffer]) {
        self.offers = offers
    }
}
