import Foundation
import SwiftData

enum SpendingSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Snapshot.self] }
    @Model final class Snapshot {
        @Attribute(.unique) var key: String
        var payload: Data
        init(payload: Data) { key = "spending"; self.payload = payload }
    }
}

@MainActor final class SpendingStore: ObservableObject {
    @Published private(set) var state = SpendingState()
    @Published private(set) var available = false
    @Published var message: String?
    private var container: ModelContainer?
    init(container: ModelContainer? = nil) { self.container = container }
    func add(title: String, amount: String, category: String, date: Date) -> Bool {
        guard let cents = SpendingState.cents(amount) else { message = "Enter a positive amount with up to two decimal places."; return false }
        var next = state
        next.expenses.append(Expense(title: title, category: category, cents: cents, currency: state.currency, date: date))
        return commit(next)
    }
    func remove(_ id: UUID) { var next = state; next.expenses.removeAll { $0.id == id }; _ = commit(next) }
    func update(_ expense: Expense) {
        guard let index = state.expenses.firstIndex(where: { $0.id == expense.id }) else { return }
        var next = state; next.expenses[index] = expense; _ = commit(next)
    }
    func setCurrency(_ currency: String) { var next = state; next.currency = currency; _ = commit(next) }
    func setBudget(_ text: String, month: String) {
        var next = state
        next.budgets.removeAll { $0.month == month && $0.currency == state.currency }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let amount = SpendingState.cents(text) else { message = "Enter a positive budget, or leave it blank to remove the budget."; return }
            next.budgets.append(MonthlyBudget(month: month, cents: amount, currency: state.currency))
        }
        _ = commit(next)
    }
    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: SpendingSchemaV1.self)
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Spending", schema: schema)])
        }
        return container!.mainContext
    }
    func load() {
        do {
            let rows = try context().fetch(FetchDescriptor<SpendingSchemaV1.Snapshot>())
            state = try rows.first.map { try LocalDataCoding.decode(SpendingState.self, $0.payload).validated() } ?? SpendingState()
            available = true
        } catch { available = false; message = "Spending could not be read. Your data has not been replaced: \(error.localizedDescription)" }
    }
    @discardableResult func commit(_ value: SpendingState, replacingUnavailable: Bool = false) -> Bool {
        guard available || replacingUnavailable else { message = "Local data is unavailable. Retry loading before making changes."; return false }
        do {
            let checked = try value.validated(), payload = try LocalDataCoding.encode(checked), context = try context()
            do {
                let rows = try context.fetch(FetchDescriptor<SpendingSchemaV1.Snapshot>())
                if let row = rows.first { row.payload = payload } else { context.insert(SpendingSchemaV1.Snapshot(payload: payload)) }
                try context.save()
            } catch { context.rollback(); throw error }
            state = checked; available = true; return true
        } catch { message = "Spending was not saved: \(error.localizedDescription)"; return false }
    }
}

extension SpendingStore: HubBackupPart {
    var backupID: String { "spending" }
    var backupTitle: String { "Spending" }
    func writeBackup(into folder: URL) async throws -> String? {
        if !available { load() }; guard available else { throw PersonalDataError.invalid("Spending cannot be read.") }
        try LocalDataCoding.encode(state).write(to: folder.appendingPathComponent("spending.json"), options: .atomic)
        return "spending.json"
    }
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let checked = try LocalDataCoding.decode(SpendingState.self, Data(contentsOf: item)).validated()
        return HubBackupRestore { [self] in commit(checked, replacingUnavailable: true) ? .restored : .failed(message ?? "Spending restore failed") }
    }
}
