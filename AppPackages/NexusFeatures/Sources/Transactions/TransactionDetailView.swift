import Design
import Entities
import SharedUI
import SwiftUI

/// The transaction detail screen: a snapshot deep view of one transaction
/// — merchant, amount, category, status, date, optional location, and the
/// transaction id.
public struct TransactionDetailView: View {
    @Environment(TransactionDetailModel.self) private var model

    public init() {}

    public var body: some View {
        content
            .navigationTitle(navigationTitle)
            .task { await model.load() }
    }

    /// Navigation title: the merchant once loaded, a generic label before.
    private var navigationTitle: String {
        if case let .loaded(transaction) = model.viewState {
            return transaction.merchant
        }
        return Strings.Transactions.title
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            LoadingView(message: Strings.Transactions.loadingMessage)
        case .missing:
            EmptyStateView(
                systemImage: Icons.search,
                title: Strings.Transactions.noResultsTitle,
                message: Strings.Transactions.noResultsMessage,
            )
        case let .error(error):
            ErrorView(error: error) {
                Task { await model.load() }
            }
        case let .loaded(transaction):
            DetailContent(transaction: transaction)
        }
    }
}

private struct DetailContent: View {
    private let transaction: Entities.Transaction

    init(transaction: Entities.Transaction) {
        self.transaction = transaction
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(transaction.merchant)
                        .font(.title3.weight(.semibold))
                    Text(signedAmount)
                        .font(.title.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(
                            transaction.amount > 0 ? ColorPalette.brand : ColorPalette.label,
                        )
                        .accessibilityIdentifier(TransactionsAccessibility.detailAmount)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section {
                row(Strings.Transactions.category, value: transaction.category.displayName)
                row(Strings.Transactions.status, value: transaction.status.displayName)
                row(Strings.Transactions.date, value: transaction.date.formatted(date: .long, time: .shortened))
                if let location = transaction.location {
                    row(Strings.Transactions.location, value: location)
                }
                row(
                    Strings.Transactions.transactionID,
                    value: transaction.id,
                    monospaced: true,
                    valueIdentifier: TransactionsAccessibility.detailTransactionID,
                )
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier(TransactionsAccessibility.detailScreen)
    }

    private func row(
        _ label: String,
        value: String,
        monospaced: Bool = false,
        valueIdentifier: String? = nil,
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(ColorPalette.secondaryLabel)
            Spacer()
            valueText(value, monospaced: monospaced, identifier: valueIdentifier)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func valueText(_ value: String, monospaced: Bool, identifier: String?) -> some View {
        if let identifier {
            Text(value)
                .monospaced()
                .accessibilityIdentifier(identifier)
        } else if monospaced {
            Text(value).monospaced()
        } else {
            Text(value)
        }
    }

    private var signedAmount: String {
        let formatted = abs(transaction.amount).formatted(.currency(code: transaction.currency))
        return transaction.amount > 0 ? "+\(formatted)" : "-\(formatted)"
    }
}

#if DEBUG
    #Preview("Loaded") {
        NavigationStack {
            TransactionDetailView()
                .environment(
                    TransactionDetailModel.preview(
                        cardID: Transaction.mockFlightPurchase.cardId,
                        transactionID: Transaction.mockFlightPurchase.id,
                    ),
                )
        }
    }

    #Preview("Missing") {
        NavigationStack {
            TransactionDetailView()
                .environment(
                    TransactionDetailModel.preview(cardID: "card-credit-001", transactionID: "txn-gone"),
                )
        }
    }
#endif
