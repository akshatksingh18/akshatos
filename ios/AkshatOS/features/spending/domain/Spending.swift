import Foundation

struct Expense: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var category = "Other"
    var cents: Int64
    var currency: String
    var date: Date
}
struct MonthlyBudget: Codable, Equatable, Identifiable {
    var month: String
    var cents: Int64
    var currency: String
    var id: String { month + currency }
}
struct SpendingState: Codable, Equatable {
    static let currencies = ["USD", "EUR", "GBP", "INR"]
    var version = 1
    var expenses: [Expense] = []
    var budgets: [MonthlyBudget] = []
    var currency = "USD"
    func validated() throws -> Self {
        guard version == 1, Self.currencies.contains(currency), expenses.count <= 100_000,
              Set(expenses.map(\.id)).count == expenses.count, Set(budgets.map(\.id)).count == budgets.count,
              expenses.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.title.count <= 1000 && $0.cents > 0 && $0.cents <= 100_000_000_000
                  && Self.currencies.contains($0.currency) }),
              budgets.allSatisfy({ $0.cents >= 0 && $0.cents <= 100_000_000_000
                  && Self.currencies.contains($0.currency)
                  && ActivityDayClock().date($0.month + "-01") != nil }) else {
            throw PersonalDataError.invalid("The Spending file contains invalid amounts, currencies or dates.")
        }
        return self
    }
    static func cents(_ text: String) -> Int64? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^\d{1,9}(?:\.\d{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        let minor = NSDecimalNumber(decimal: decimal * 100).int64Value
        return minor > 0 && minor <= 100_000_000_000 ? minor : nil
    }
    static func month(_ date: Date, calendar: Calendar = .current) -> String {
        String(ActivityDayClock(calendar: calendar).calendarKey(date).prefix(7))
    }
    func total(_ month: String, currency: String, calendar: Calendar = .current) -> Int64 {
        expenses.filter { Self.month($0.date, calendar: calendar) == month && $0.currency == currency }
            .reduce(0) { $0 + $1.cents }
    }
    func budget(_ month: String, currency: String) -> Int64? {
        budgets.first { $0.month == month && $0.currency == currency }?.cents
    }
    var csv: Data {
        let rows = ["id,date,title,category,amount,currency"] + expenses.map {
            [$0.id.uuidString, $0.date.ISO8601Format(), $0.title, $0.category,
             NSDecimalNumber(decimal: Decimal($0.cents) / 100).stringValue, $0.currency]
                .map(LocalDataCoding.csv).joined(separator: ",")
        }
        return Data(rows.joined(separator: "\r\n").utf8)
    }
}
