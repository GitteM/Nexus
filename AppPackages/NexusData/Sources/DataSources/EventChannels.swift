import Foundation

/// The app/backend channel namespace, defined once here so the session
/// facade, the data sources, and the demo event generator (tasks.md Day 8)
/// all speak the same names (architecture.md §11.4).
///
/// The contract as of M2:
/// - `card.events.{cardId}` — server→client: live per-card updates
///   (status/balance/transaction/limit payloads). `CardStateDataSource`
///   parses the status-shaped payloads on it.
/// - `card.offers` — server→client: full-list offer snapshots. The payload
///   is an `OffersSnapshotDTO` envelope.
/// - `card.commands` — client→server: outgoing `CardCommand` payloads sent
///   by `CardActionDataSource`. The backend acknowledges by pushing the new
///   state on `card.events.{cardId}` (architecture.md §11.4: "the resulting
///   state arrives through the live event streams").
///
/// The namespace is what the backend mirrors; when the §11.4 REST endpoints
/// land (tasks.md Day 7), the repository layer reuses these names for the
/// matching wire contract.
public enum EventChannels {
    /// Server→client channel carrying one card's live updates.
    public static func cardEvents(cardId: String) -> String {
        "card.events.\(cardId)"
    }

    /// Server→client channel carrying full-list offer snapshots.
    public static let offers = "card.offers"

    /// Client→server channel for outgoing `CardCommand` actions.
    public static let commands = "card.commands"
}
