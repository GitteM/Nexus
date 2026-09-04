import Foundation

/// Single source of UI copy.
///
/// Every user-facing string that shared components and screens render goes
/// through `String(localized:)` here — never a literal at a call site. Real
/// translations land later (English only for now); this enum is the
/// localization seam.
///
/// Copy that describes a *domain* value stays on the domain type
/// (`SessionStatus.displayName`, `CardStatus.displayName`, `AppError`
/// surfaces) so the label travels with the value; `Strings` owns
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

    public enum CardDetail {
        /// Navigation title for the detail screen, e.g. "Card ••4821".
        public static func title(lastFour: String) -> String {
            String(localized: "Card ••\(lastFour)")
        }

        public static let loadingMessage = String(localized: "Loading your card")
        public static let controlsSection = String(localized: "Card controls")
        public static let freeze = String(localized: "Freeze card")
        public static let unfreeze = String(localized: "Unfreeze card")
        public static let freezeConfirmTitle = String(localized: "Freeze this card?")
        public static let freezeConfirmMessage = String(localized: "New purchases and withdrawals will be blocked until you unfreeze.")
        public static let unfreezeConfirmTitle = String(localized: "Unfreeze this card?")
        public static let unfreezeConfirmMessage = String(localized: "The card will work again immediately.")
        public static let reportLostOrStolen = String(localized: "Report lost or stolen")
        public static let reportLost = String(localized: "Report lost")
        public static let reportStolen = String(localized: "Report stolen")
        public static let reportConfirmTitle = String(localized: "Report this card lost or stolen?")
        public static let reportConfirmMessage = String(localized: "The card will be blocked right away. You can request a replacement next.")
        public static let lostCardTitle = String(localized: "This card is lost")
        public static let lostCardMessage = String(localized: "The card is blocked. Request a replacement card.")
        public static let requestReplacement = String(localized: "Request replacement")
        public static let requestReplacementConfirmTitle = String(localized: "Request a replacement card?")
        public static let requestReplacementConfirmMessage = String(localized: "A replacement offer will appear on your Dashboard. The lost card stays blocked.")
        public static let replacementRequestedTitle = String(localized: "Replacement requested")
        public static let replacementRequestedMessage = String(localized: "Find your new card offer on the Dashboard and add it.")
        public static let limitsSection = String(localized: "Spending limits")
        public static let currentLimit = String(localized: "Current limit")
        public static let notSet = String(localized: "Not set")
        public static let activitySection = String(localized: "Account activity")
        public static let transactionsRow = String(localized: "Transactions")

        /// Title of the per-period set-limit sheet: "Set Daily limit".
        public static func setLimitTitle(period: String) -> String {
            String(localized: "Set \(period) limit")
        }

        public static let amountPlaceholder = String(localized: "Amount")
        public static let save = String(localized: "Save")

        /// Title of the alert shown when a card action fails.
        public static let actionFailedTitle = String(localized: "Couldn't Update Card")
    }

    public enum Transactions {
        public static let title = String(localized: "Transactions")
        public static let loadingMessage = String(localized: "Loading transactions")
        public static let balanceSection = String(localized: "Balance")
        public static let available = String(localized: "Available")
        public static let creditLimit = String(localized: "Credit limit")
        public static let searchPlaceholder = String(localized: "Search by merchant")
        public static let filterButton = String(localized: "Filter")
        public static let filtersSheetTitle = String(localized: "Filter transactions")
        public static let resetFilters = String(localized: "Reset")
        public static let filtersActiveTitle = String(localized: "Filters active")
        public static let edit = String(localized: "Edit")

        /// "Showing 3 of 9" — the banner line under the active-filters title.
        public static func showingCount(_ shown: Int, of total: Int) -> String {
            String(localized: "Showing \(shown) of \(total)")
        }

        public static let filterCategory = String(localized: "Category")
        public static let filterStatus = String(localized: "Status")
        public static let filterDate = String(localized: "Date")
        public static let allCategories = String(localized: "All categories")
        public static let allStatuses = String(localized: "All statuses")
        public static let allDates = String(localized: "All time")
        public static let last7Days = String(localized: "Last 7 days")
        public static let last30Days = String(localized: "Last 30 days")
        public static let last90Days = String(localized: "Last 90 days")
        public static let emptyTitle = String(localized: "No transactions yet")
        public static let emptyMessage = String(localized: "Transactions for this card will appear here.")
        public static let noResultsTitle = String(localized: "No matching transactions")
        public static let noResultsMessage = String(localized: "Try clearing a filter or searching for something else.")
        public static let pending = String(localized: "Pending")
        public static let refund = String(localized: "Refund")
        public static let merchant = String(localized: "Merchant")
        public static let location = String(localized: "Location")
        public static let category = String(localized: "Category")
        public static let status = String(localized: "Status")
        public static let date = String(localized: "Date")
        public static let transactionID = String(localized: "Transaction ID")
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

        /// Demo-only reset action.
        public static let resetDemo = String(localized: "Reset demo")
    }

    public enum Errors {
        public static let technicalDetail = String(localized: "Details")
    }
}
