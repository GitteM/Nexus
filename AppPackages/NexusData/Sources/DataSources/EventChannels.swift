import Foundation

/// The app/backend channel namespace, defined once here so the session
/// facade, the data sources, and the demo event generator all speak the
/// same names.
///
/// The contract:
/// - `card.events.{cardId}` — server→client: live per-card updates
///   (status/balance/transaction/limit payloads). `CardStateDataSource`
///   parses the status-shaped payloads on it.
/// - `card.offers` — server→client: full-list offer snapshots. The payload
///   is an `OffersSnapshotDTO` envelope.
/// - `card.commands` — client→server: outgoing `CardCommand` payloads sent
///   by `CardActionDataSource`. The payload is the JSON encoding of a
///   `CardCommand` (`cardId`, `type`, plus `amount` and `period` only for
///   `.setSpendingLimit`). The backend acknowledges by pushing the new state
///   on `card.events.{cardId}` — the resulting state arrives through the
///   live event streams.
///
/// The namespace is what the backend mirrors; when the REST endpoints land,
/// the repository layer reuses these names for the matching wire contract.
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
