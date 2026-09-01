import Entities
import Foundation
import Testing

@Suite("Transaction")
struct TransactionTests {
    // MARK: - Construction

    @Test func `memberwise init sets all properties`() {
        let transaction = Transaction(
            id: "txn-1",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Cafe Central",
            amount: -4.50,
            currency: "EUR",
            category: .dining,
            status: .pending,
            location: "Berlin",
        )
        #expect(transaction.id == "txn-1")
        #expect(transaction.cardId == "card-1")
        #expect(transaction.date == Date(timeIntervalSinceReferenceDate: 800_000_000))
        #expect(transaction.merchant == "Cafe Central")
        #expect(transaction.amount == -4.50)
        #expect(transaction.currency == "EUR")
        #expect(transaction.category == .dining)
        #expect(transaction.status == .pending)
        #expect(transaction.location == "Berlin")
    }

    @Test func `location is optional`() {
        let transaction = Transaction(
            id: "txn-2",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Shoply",
            amount: -129.99,
            currency: "EUR",
            category: .shopping,
            status: .cleared,
            location: nil,
        )
        #expect(transaction.location == nil)
    }

    // MARK: - Equality

    @Test func `equality compares all properties`() {
        let a = Transaction(
            id: "txn-1",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Cafe Central",
            amount: -4.50,
            currency: "EUR",
            category: .dining,
            status: .pending,
            location: "Berlin",
        )
        let same = Transaction(
            id: "txn-1",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Cafe Central",
            amount: -4.50,
            currency: "EUR",
            category: .dining,
            status: .pending,
            location: "Berlin",
        )
        let different = Transaction(
            id: "txn-9",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Cafe Central",
            amount: -4.50,
            currency: "EUR",
            category: .dining,
            status: .cleared,
            location: "Berlin",
        )
        #expect(a == same)
        #expect(a != different)
    }

    // MARK: - Codable

    @Test func `codable round trip preserves all fields`() throws {
        let transaction = Transaction(
            id: "txn-rt",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Cafe Central",
            amount: -4.50,
            currency: "EUR",
            category: .dining,
            status: .pending,
            location: "Berlin",
        )
        let data = try JSONEncoder().encode(transaction)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)
        #expect(decoded == transaction)
        #expect(decoded.amount == Decimal(string: "-4.50"))
    }

    @Test func `codable round trip with nil location`() throws {
        let transaction = Transaction(
            id: "txn-rt-nil",
            cardId: "card-1",
            date: Date(timeIntervalSinceReferenceDate: 800_000_000),
            merchant: "Shoply",
            amount: -129.99,
            currency: "EUR",
            category: .shopping,
            status: .cleared,
            location: nil,
        )
        let data = try JSONEncoder().encode(transaction)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)
        #expect(decoded == transaction)
        #expect(decoded.location == nil)
    }

    @Test func `decoding missing optional location succeeds`() throws {
        let json = Data(
            #"""
            {"id":"t1","cardId":"c1","date":800000000,"merchant":"Shoply",
             "amount":-129.99,"currency":"EUR","category":"shopping","status":"cleared"}
            """#.utf8,
        )
        let decoded = try JSONDecoder().decode(Transaction.self, from: json)
        #expect(decoded.location == nil)
        #expect(decoded.merchant == "Shoply")
    }

    // MARK: - Enums

    @Test func `status round trips through raw values`() throws {
        for status in TransactionStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(TransactionStatus.self, from: data)
            #expect(decoded == status)
        }
    }

    @Test func `category round trips through raw values`() throws {
        for category in TransactionCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(TransactionCategory.self, from: data)
            #expect(decoded == category)
        }
    }

    @Test func `status raw values match wire contract`() {
        #expect(TransactionStatus.allCases.map(\.rawValue) == ["pending", "cleared"])
    }

    @Test func `category raw values match wire contract`() {
        #expect(
            TransactionCategory.allCases.map(\.rawValue)
                == ["dining", "groceries", "shopping", "travel", "entertainment", "bills", "transfer", "other"],
        )
    }

    @Test func `unknown status raw value throws`() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(TransactionStatus.self, from: Data(#""settled""#.utf8))
        }
    }

    @Test func `unknown category raw value throws`() {
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(TransactionCategory.self, from: Data(#""work""#.utf8))
        }
    }

    @Test func `display names match wire contract`() {
        #expect(TransactionStatus.allCases.map(\.displayName) == ["Pending", "Cleared"])
        #expect(
            TransactionCategory.allCases.map(\.displayName)
                == ["Dining", "Groceries", "Shopping", "Travel", "Entertainment", "Bills", "Transfer", "Other"],
        )
    }

    @Test func `icons are non empty for all cases`() {
        for status in TransactionStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
        for category in TransactionCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    // MARK: - Mocks

    @Test func `mock defaults are non empty and unique`() {
        #expect(!Transaction.mockDefaults.isEmpty)
        #expect(Set(Transaction.mockDefaults.map(\.id)).count == Transaction.mockDefaults.count)
    }

    @Test func `mock defaults cover every category`() {
        #expect(Set(Transaction.mockDefaults.map(\.category)) == Set(TransactionCategory.allCases))
    }

    @Test func `mock defaults cover both statuses`() {
        #expect(Set(Transaction.mockDefaults.map(\.status)) == Set(TransactionStatus.allCases))
    }

    @Test func `mock purchases are negative and refunds positive`() {
        for transaction in Transaction.mockDefaults {
            if transaction.id == Transaction.mockRefund.id {
                #expect(transaction.amount > 0)
            } else {
                #expect(transaction.amount < 0)
            }
        }
    }

    @Test func `mock currency is EUR`() {
        for transaction in Transaction.mockDefaults {
            #expect(transaction.currency == "EUR")
        }
    }

    @Test func `mock card id matches card mock`() {
        for transaction in Transaction.mockDefaults {
            #expect(transaction.cardId == Card.mockCreditCard.id)
        }
    }
}
