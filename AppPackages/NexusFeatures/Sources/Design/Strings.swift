import Foundation

/// Single source of UI copy (architecture.md §9.4, tasks.md Day 9).
///
/// Every user-facing string that shared components and screens render goes
/// through `String(localized:)` here — never a literal at a call site. Real
/// translations land later (v1.0 ships English only); this enum is the
/// localization seam.
///
/// Copy that describes a *domain* value stays on the domain type
/// (`SessionStatus.displayName`, `CardStatus.displayName`, `AppError`
/// surfaces, §4.1/§5) so the label travels with the value; `Strings` owns
/// app- and component-level copy.
public enum Strings {
    public enum Common {
        public static let retry = String(localized: "Retry")
        public static let refresh = String(localized: "Refresh")
        public static let cancel = String(localized: "Cancel")
        public static let done = String(localized: "Done")
        public static let ok = String(localized: "OK")
        public static let add = String(localized: "Add")
        public static let added = String(localized: "Added")
        public static let loading = String(localized: "Loading")
    }

    public enum Dashboard {
        public static let title = String(localized: "Dashboard")
        public static let loadingMessage = String(localized: "Loading your cards")
        public static let cardsSection = String(localized: "Your cards")
        public static let offersSection = String(localized: "Explore offers")
        public static let emptyTitle = String(localized: "No cards yet")
        public static let emptyMessage = String(localized: "Cards you add and offers you can browse will appear here.")

        /// Accessibility value for one carousel page: "Card 1 of 3".
        public static func cardPage(_ page: Int, of total: Int) -> String {
            String(localized: "Card \(page) of \(total)")
        }

        /// Accessibility label for an offer's add action: "Add Cashback Card".
        public static func addOffer(_ title: String) -> String {
            String(localized: "Add \(title)")
        }

        /// Title of the alert shown when adding an offer fails.
        public static let addOfferFailedTitle = String(localized: "Couldn't Add Card")
    }

    public enum Navigation {
        public static let back = String(localized: "Back")
    }

    public enum Connection {
        public static let title = String(localized: "You're offline")
        public static let message = String(localized: "Reconnect to keep your cards and balances up to date.")
        public static let reconnect = String(localized: "Reconnect")
    }

    public enum App {
        public static let title = String(localized: "Nexus")
        public static let errorTitle = String(localized: "Something went wrong")
        public static let errorMessage = String(localized: "Nexus couldn't start. Please try again.")
    }

    public enum Errors {
        public static let technicalDetail = String(localized: "Details")
    }
}
