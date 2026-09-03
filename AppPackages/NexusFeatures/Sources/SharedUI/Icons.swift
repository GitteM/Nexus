/// Central catalog of SF Symbol names used by shared UI (architecture.md
/// §9.4, tasks.md Day 9).
///
/// Components look up symbols here instead of spelling out names at each
/// call site. Status icons that belong to domain concepts (`CardStatus.icon`,
/// `SessionStatus.icon`) stay on the domain enums (§4.1) — this catalog holds
/// the generic UI vocabulary: retry, offline, warnings, chevrons, etc.
public enum Icons {
    /// Generic back/left chevron for the shared `BackToolbarItem`.
    public static let back = "chevron.left"

    /// Generic forward chevron for rows that push a destination.
    public static let chevronRight = "chevron.right"

    /// Close / dismiss.
    public static let close = "xmark"

    /// Retry an operation (`ErrorView`, `AppErrorView`).
    public static let retry = "arrow.clockwise"

    /// Offline / session dropped (`DisconnectedView`).
    public static let offline = "wifi.slash"

    /// Attention icon for `WarningRow` and error surfaces.
    public static let warning = "exclamationmark.triangle.fill"

    /// Informational icon for `InfoRow`.
    public static let info = "info.circle.fill"

    /// A card concept (used by empty states and app surfaces).
    public static let card = "creditcard.fill"
}
