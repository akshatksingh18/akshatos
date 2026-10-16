import Foundation
precondition(SpendingState.cents("12.34") == 1234)
precondition(SpendingState.cents("12.345") == nil)
precondition(SpendingState.cents("-2") == nil)
precondition(SpendingState.cents("1e9") == nil)
let date = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!
var state = SpendingState(expenses: [Expense(title: "=SUM(A1)", cents: 1234, currency: "USD", date: date), Expense(title: "Synthetic", cents: 999, currency: "INR", date: date)])
precondition(state.total("2026-10", currency: "USD") == 1234)
precondition(String(data: state.csv, encoding: .utf8)!.contains("'=SUM(A1)"))
state.expenses.append(state.expenses[0])
do { _ = try state.validated(); fatalError("Duplicate expense accepted") } catch {}
print("Spending: exact cents, currency separation, CSV safety and invalid restore passed")
