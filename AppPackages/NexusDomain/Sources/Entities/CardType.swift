/// The kind of card a customer holds or is offered.
///
/// Encoded by its raw value on the wire, e.g. `"credit"`.
public enum CardType: String, Codable, CaseIterable, Sendable, Equatable {
    case credit
    case debit
    case prepaid
}

public extension CardType {
    /// Human-readable label for UI, e.g. "Credit".
    var displayName: String {
        switch self {
        case .credit: "Credit"
        case .debit: "Debit"
        case .prepaid: "Prepaid"
        }
    }

    /// SF Symbol name used by the UI for this card type.
    var icon: String {
        switch self {
        case .credit: "creditcard"
        case .debit: "banknote"
        case .prepaid: "giftcard"
        }
    }
}
