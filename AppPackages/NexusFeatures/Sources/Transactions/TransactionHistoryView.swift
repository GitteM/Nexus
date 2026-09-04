import Design
import Entities
import Navigation
import SharedUI
import SwiftUI

/// The per-card transaction history screen (architecture.md §9.3, tasks.md
/// Day 13): a live balance header plus the searchable, filterable
/// transaction feed.
///
/// A thin switch over the model's `viewState`; the loaded screen owns the
/// search field (`.searchable`), the category/status/date filter menus, and
/// the row list. Tapping a row pushes the transaction detail through the
/// router (the app target maps the route to the view).
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

/// The loaded history: balance summary on top, then the filter bar and the
/// (already filtered) transaction list. Empty states distinguish "no
/// transactions at all" from "the filters matched nothing".
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

    var body: some View {
        List {
            if let balance = model.balance {
                Section(Strings.Transactions.balanceSection) {
                    BalanceHeaderView(balance: balance)
                }
            }
            Section {
                filterBar
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
    }

    /// Category / status / date filter menus, with the active filters
    /// summarized in the menu labels.
    private var filterBar: some View {
        HStack(spacing: Spacing.md) {
            categoryMenu
            statusMenu
            dateMenu
            if !model.query.isDefault {
                Button(Strings.Transactions.clearFilters) {
                    model.clearFilters()
                }
            }
        }
        .font(.subheadline)
    }

    private var categoryMenu: some View {
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
            Label(
                model.query.category?.displayName ?? Strings.Transactions.allCategories,
                systemImage: Icons.filter,
            )
        }
        .accessibilityLabel(Strings.Transactions.filterCategory)
    }

    private var statusMenu: some View {
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
            Label(
                model.query.status?.displayName ?? Strings.Transactions.allStatuses,
                systemImage: Icons.filter,
            )
        }
        .accessibilityLabel(Strings.Transactions.filterStatus)
    }

    private var dateMenu: some View {
        Menu {
            ForEach(TransactionDateRange.allCases, id: \.self) { range in
                checkedButton(label: dateLabel(range), isOn: model.query.dateRange == range) {
                    model.setDateRange(range)
                }
            }
        } label: {
            Label(dateLabel(model.query.dateRange), systemImage: Icons.filter)
        }
        .accessibilityLabel(Strings.Transactions.filterDate)
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
        switch range {
        case .all: Strings.Transactions.allDates
        case .last7Days: Strings.Transactions.last7Days
        case .last30Days: Strings.Transactions.last30Days
        case .last90Days: Strings.Transactions.last90Days
        }
    }

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
                    if transaction.status == .pending {
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
