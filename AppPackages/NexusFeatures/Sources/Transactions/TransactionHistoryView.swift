import Design
import Entities
import Navigation
import SharedUI
import SwiftUI

/// The per-card transaction history screen: a live balance header plus
/// the searchable, filterable transaction feed.
///
/// A thin switch over the model's `viewState`; the loaded screen owns the
/// search field (`.searchable`), the toolbar Filter button (opening the
/// filter sheet), and the row list. Tapping a row pushes the transaction
/// detail through the router (the app target maps the route to the view).
public struct TransactionHistoryView: View {
    @Environment(TransactionHistoryModel.self) private var model
    @Environment(Router.self) private var router

    public init() {}

    public var body: some View {
        content
            .navigationTitle(Strings.Transactions.title)
            .task { await model.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            LoadingView(message: Strings.Transactions.loadingMessage)
        case let .error(error):
            ErrorView(error: error) {
                Task { await model.load() }
            }
        case .loaded:
            HistoryContent(model: model) { transaction in
                router.navigateTo(
                    .transactionDetail(
                        cardID: transaction.cardId,
                        transactionID: transaction.id,
                    ),
                )
            }
            .searchable(
                text: Binding(
                    get: { model.query.searchText },
                    set: { model.setSearchText($0) },
                ),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(Strings.Transactions.searchPlaceholder),
            )
        }
    }
}

/// The loaded history: the live balance summary on top, then the (already
/// filtered) transaction list. Filters live behind the toolbar Filter
/// button (`FilterSheetView`); empty states distinguish "no transactions at
/// all" from "the filters matched nothing".
private struct HistoryContent: View {
    private let model: TransactionHistoryModel
    private let onSelectTransaction: (Entities.Transaction) -> Void

    init(
        model: TransactionHistoryModel,
        onSelectTransaction: @escaping (Entities.Transaction) -> Void,
    ) {
        self.model = model
        self.onSelectTransaction = onSelectTransaction
    }

    @State private var showFilters = false

    var body: some View {
        List {
            if let balance = model.balance {
                Section(Strings.Transactions.balanceSection) {
                    BalanceHeaderView(balance: balance)
                }
            }
            if !model.query.isDefault, !model.transactions.isEmpty {
                Section {
                    filteredBanner
                }
            }
            if model.transactions.isEmpty {
                emptyTransactions
            } else if model.filteredTransactions.isEmpty {
                noResults
            } else {
                ForEach(model.filteredTransactions) { transaction in
                    TransactionRowView(transaction: transaction)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectTransaction(transaction)
                        }
                        .accessibilityIdentifier(
                            TransactionsAccessibility.transactionRow(transaction.id),
                        )
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier(TransactionsAccessibility.historyScreen)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Label(Strings.Transactions.filterButton, systemImage: Icons.filter)
                        .overlay(alignment: .topTrailing) {
                            if !model.query.isDefault {
                                Circle()
                                    .fill(ColorPalette.brand)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 3, y: -3)
                            }
                        }
                }
                .accessibilityIdentifier(TransactionsAccessibility.filterButton)
                .accessibilityLabel(Strings.Transactions.filterButton)
                .accessibilityValue(
                    model.query.isDefault
                        ? Strings.Transactions.noFilters
                        : Strings.Transactions.filtersActiveTitle,
                )
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheetView(model: model)
        }
    }

    /// The clear in-list signal that the visible history is a filtered
    /// subset, placed directly under the balance: the result count plus the
    /// active-filter summary, with one-tap Edit (reopens the filter sheet)
    /// and Reset (clears every filter) actions.
    private var filteredBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: Icons.filter)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorPalette.brand)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.Transactions.filtersActiveTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ColorPalette.label)
                Text(bannerDetail)
                    .font(.footnote)
                    .foregroundStyle(ColorPalette.secondaryLabel)
            }
            Spacer(minLength: Spacing.md)
            Button {
                showFilters = true
            } label: {
                Text(Strings.Transactions.edit)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(ColorPalette.brand)
            .accessibilityIdentifier(TransactionsAccessibility.filteredBannerEdit)
            Button {
                // Reset clears the filters outright — it never presents the
                // sheet (only the Edit action does).
                model.clearFilters()
            } label: {
                Text(Strings.Transactions.resetFilters)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(ColorPalette.secondaryLabel)
            .accessibilityIdentifier(TransactionsAccessibility.filteredBannerReset)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TransactionsAccessibility.filteredBanner)
    }

    /// "Showing 3 of 9 · Dining, Pending" — count plus the active filters.
    private var bannerDetail: String {
        let count = Strings.Transactions.showingCount(
            model.filteredTransactions.count,
            of: model.transactions.count,
        )
        let summary = activeFilterSummary
        return summary.isEmpty ? count : "\(count) · \(summary)"
    }

    /// The human-readable list of active filters, newest first.
    private var activeFilterSummary: String {
        var parts: [String] = []
        let search = model.query.searchText.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty {
            parts.append("\u{201C}\(search)\u{201D}")
        }
        if let category = model.query.category {
            parts.append(category.displayName)
        }
        if let status = model.query.status {
            parts.append(status.displayName)
        }
        if model.query.dateRange != .all {
            parts.append(transactionDateLabel(model.query.dateRange))
        }
        return parts.joined(separator: ", ")
    }

    /// The filter controls, one full-width row per dimension: the menu
    private var emptyTransactions: some View {
        EmptyStateView(
            systemImage: Icons.card,
            title: Strings.Transactions.emptyTitle,
            message: Strings.Transactions.emptyMessage,
        )
    }

    private var noResults: some View {
        EmptyStateView(
            systemImage: Icons.search,
            title: Strings.Transactions.noResultsTitle,
            message: Strings.Transactions.noResultsMessage,
        )
    }
}

/// The filter sheet behind the toolbar Filter button: the full filtering
/// UI (category / status / date rows) plus Reset. Selections apply to the
/// model immediately — the list behind the sheet updates live — and Done
/// dismisses.
private struct FilterSheetView: View {
    private let model: TransactionHistoryModel
    @Environment(\.dismiss) private var dismiss

    init(model: TransactionHistoryModel) {
        self.model = model
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryRow
                    statusRow
                    dateRow
                }
                if !model.query.isDefault {
                    Section {
                        Button(Strings.Transactions.resetFilters) {
                            // Clearing from the sheet also dismisses it: the
                            // user asked to reset, not to keep editing.
                            model.clearFilters()
                            dismiss()
                        }
                        .foregroundStyle(ColorPalette.brand)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Strings.Transactions.filtersSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.Common.done) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Rows

    /// One full-width row per dimension: the menu label names the dimension
    /// and the trailing text shows the active selection (All categories /
    /// Dining / …). Stacked vertically so long selections and Dynamic Type
    /// never squash the labels.
    private var categoryRow: some View {
        Menu {
            checkedButton(
                label: Strings.Transactions.allCategories,
                isOn: model.query.category == nil,
            ) {
                model.setCategoryFilter(nil)
            }
            ForEach(TransactionCategory.allCases, id: \.self) { category in
                checkedButton(
                    label: category.displayName,
                    isOn: model.query.category == category,
                ) {
                    model.setCategoryFilter(category)
                }
            }
        } label: {
            filterRowLabel(
                title: Strings.Transactions.filterCategory,
                value: model.query.category?.displayName ?? Strings.Transactions.allCategories,
            )
        }
    }

    private var statusRow: some View {
        Menu {
            checkedButton(
                label: Strings.Transactions.allStatuses,
                isOn: model.query.status == nil,
            ) {
                model.setStatusFilter(nil)
            }
            ForEach(TransactionStatus.allCases, id: \.self) { status in
                checkedButton(
                    label: status.displayName,
                    isOn: model.query.status == status,
                ) {
                    model.setStatusFilter(status)
                }
            }
        } label: {
            filterRowLabel(
                title: Strings.Transactions.filterStatus,
                value: model.query.status?.displayName ?? Strings.Transactions.allStatuses,
            )
        }
    }

    private var dateRow: some View {
        Menu {
            ForEach(TransactionDateRange.allCases, id: \.self) { range in
                checkedButton(label: dateLabel(range), isOn: model.query.dateRange == range) {
                    model.setDateRange(range)
                }
            }
        } label: {
            filterRowLabel(
                title: Strings.Transactions.filterDate,
                value: dateLabel(model.query.dateRange),
            )
        }
    }

    private func filterRowLabel(title: String, value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .foregroundStyle(ColorPalette.label)
            Spacer(minLength: Spacing.md)
            Text(value)
                .foregroundStyle(ColorPalette.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
            Image(systemName: Icons.chevronRight)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(ColorPalette.secondaryLabel)
        }
        .contentShape(Rectangle())
    }

    private func checkedButton(
        label: String,
        isOn: Bool,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            if isOn {
                Label(label, systemImage: Icons.added)
            } else {
                Text(label)
            }
        }
    }

    private func dateLabel(_ range: TransactionDateRange) -> String {
        transactionDateLabel(range)
    }
}

/// The date-window label for filter UI, shared by the banner summary and
/// the filter sheet (copy lives in `Strings.Transactions`).
private func transactionDateLabel(_ range: TransactionDateRange) -> String {
    switch range {
    case .all: Strings.Transactions.allDates
    case .last7Days: Strings.Transactions.last7Days
    case .last30Days: Strings.Transactions.last30Days
    case .last90Days: Strings.Transactions.last90Days
    }
}

/// The live balance summary: current balance prominent, available and
/// credit limit below. Card currency comes from the balance value.
struct BalanceHeaderView: View {
    private let balance: Balance

    init(balance: Balance) {
        self.balance = balance
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(balance.current.formatted(.currency(code: balance.currency)))
                .font(.title.weight(.semibold))
                .monospacedDigit()
                .accessibilityIdentifier(TransactionsAccessibility.balanceSummary)
            HStack(spacing: Spacing.lg) {
                balanceLine(
                    Strings.Transactions.available,
                    value: balance.available,
                )
                if let creditLimit = balance.creditLimit {
                    balanceLine(
                        Strings.Transactions.creditLimit,
                        value: creditLimit,
                    )
                }
            }
            .font(.footnote)
            .foregroundStyle(ColorPalette.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func balanceLine(_ label: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
            Text(value.formatted(.currency(code: balance.currency)))
                .monospacedDigit()
        }
    }
}

/// One transaction row: category icon, merchant + date (+ pending marker),
/// and the signed amount.
struct TransactionRowView: View {
    private let transaction: Entities.Transaction

    init(transaction: Entities.Transaction) {
        self.transaction = transaction
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: transaction.category.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorPalette.brand)
                .frame(width: 32, height: 32)
                .background(ColorPalette.brand.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: Spacing.xs) {
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    if transaction.amount > 0 {
                        // Positive amounts are refunds/credits — label them so
                        // a green row at a merchant never reads as an error.
                        Text(Strings.Transactions.refund)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorPalette.brand)
                    } else if transaction.status == .pending {
                        Text(Strings.Transactions.pending)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ColorPalette.warning)
                    }
                }
                .font(.footnote)
                .foregroundStyle(ColorPalette.secondaryLabel)
            }
            Spacer(minLength: Spacing.sm)
            Text(signedAmount)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.amount > 0 ? ColorPalette.brand : ColorPalette.label)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var signedAmount: String {
        let formatted = abs(transaction.amount).formatted(.currency(code: transaction.currency))
        return transaction.amount > 0 ? "+\(formatted)" : "-\(formatted)"
    }
}

#if DEBUG
    #Preview("Loaded — credit card") {
        NavigationStack {
            TransactionHistoryView()
                .environment(TransactionHistoryModel.preview(cardID: Card.mockCreditCard.id))
                .environment(Router())
        }
    }

    #Preview("Loading") {
        NavigationStack {
            TransactionHistoryView()
                .environment(TransactionHistoryModel.loadingPreview(cardID: Card.mockCreditCard.id))
                .environment(Router())
        }
    }

    #Preview("Error") {
        NavigationStack {
            TransactionHistoryView()
                .environment(TransactionHistoryModel.errorPreview(cardID: Card.mockCreditCard.id))
                .environment(Router())
        }
    }
#endif
