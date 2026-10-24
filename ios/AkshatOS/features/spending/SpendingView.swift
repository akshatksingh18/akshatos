import SwiftUI
import UniformTypeIdentifiers

struct SpendingView: View {
    @ObservedObject var store: SpendingStore
    @State private var month = Date()
    @State private var editing: Expense?
    @State private var budgetText = ""
    @State private var budgetSheet = false
    @State private var export = false
    @State private var document: PortableDocument?
    @State private var exportType = UTType.json
    @State private var importing = false
    @State private var restore: SpendingState?
    @State private var deleting: UUID?
    private var key: String { SpendingState.month(month) }
    var body: some View {
        List {
            if store.available {
            Section {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }.buttonStyle(.plain).accessibilityLabel("Previous month")
                    Spacer(); Text(month.formatted(.dateTime.month(.wide).year())).font(.headline); Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }.buttonStyle(.plain).accessibilityLabel("Next month")
                }
                Picker("Currency", selection: Binding(get: { store.state.currency }, set: { store.setCurrency($0) })) {
                    ForEach(SpendingState.currencies, id: \.self) { Text($0).tag($0) }
                }
                let total = store.state.total(key, currency: store.state.currency)
                LabeledContent("Spent", value: money(total, currency: store.state.currency))
                if let budget = store.state.budget(key, currency: store.state.currency) {
                    ProgressView(value: min(Double(total), Double(budget)), total: Double(max(1, budget))).tint(HubInk.accent)
                    LabeledContent(total > budget ? "Over budget" : "Remaining", value: money(abs(budget - total), currency: store.state.currency))
                } else { Text("No budget set").foregroundStyle(.secondary) }
                Button("Set this month’s budget") {
                    budgetText = store.state.budget(key, currency: store.state.currency).map { NSDecimalNumber(decimal: Decimal($0) / 100).stringValue } ?? ""
                    budgetSheet = true
                }
            } header: { Text("Month") }
              footer: { Text("Each currency has its own total and monthly budget.") }

            Section("Expenses") {
                let values = store.state.expenses.filter { SpendingState.month($0.date) == key && $0.currency == store.state.currency }.sorted { $0.date > $1.date }
                if values.isEmpty { Text("No expenses recorded.").foregroundStyle(.secondary); Button("Add expense", systemImage: "plus") { editing = Expense(title: "", cents: 0, currency: store.state.currency, date: Date()) } }
                ForEach(values) { expense in
                    Button { editing = expense } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) { Text(expense.title); Text(expense.date.formatted(date: .abbreviated, time: .omitted) + " · " + expense.category).font(.caption).foregroundStyle(.secondary) }
                            Spacer(); Text(money(expense.cents, currency: expense.currency)).monospacedDigit()
                        }.foregroundStyle(.primary)
                    }.swipeActions { Button("Delete", role: .destructive) { deleting = expense.id } }
                }
            }
            } else { Section { Text("Spending is unavailable."); Button("Retry") { store.load() } } }
        }.personalList().navigationTitle("Spending").task { if !store.available { store.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add expense", systemImage: "plus") { editing = Expense(title: "", cents: 0, currency: store.state.currency, date: Date()) }
                    Button("Export CSV") { prepare(.commaSeparatedText) }
                    Button("Export backup") { prepare(.json) }
                    Button("Restore backup") { importing = true }
                } label: { Label("Spending actions", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(item: $editing) { expense in ExpenseEditor(store: store, expense: expense) }
        .sheet(isPresented: $budgetSheet) {
            NavigationStack {
                Form { TextField("Budget in \(store.state.currency)", text: $budgetText).keyboardType(.decimalPad); Text("Leave blank to remove the budget.").font(.footnote).foregroundStyle(.secondary) }
                    .personalList().navigationTitle("\(key) budget")
                    .toolbar { Button("Cancel") { budgetSheet = false }; Button("Save") { store.message = nil; store.setBudget(budgetText, month: key); if store.message == nil { budgetSheet = false } } }
                    .personalMessage("Budget", message: $store.message)
            }
        }
        .personalMessage("Spending", message: $store.message)
        .fileExporter(isPresented: $export, document: document, contentType: exportType, defaultFilename: "akshatos-spending") { result in if case .failure(let error) = result { store.message = error.localizedDescription } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                restore = try LocalDataCoding.decode(SpendingState.self, Data(contentsOf: url)).validated()
            } catch { store.message = error.localizedDescription }
        }
        .alert("Replace Spending?", isPresented: Binding(get: { restore != nil }, set: { if !$0 { restore = nil } })) {
            Button("Replace", role: .destructive) { if let restore { _ = store.commit(restore, replacingUnavailable: true) }; restore = nil }
            Button("Cancel", role: .cancel) { restore = nil }
        } message: { Text("This replaces expenses and budgets. Export a backup first.") }
        .confirmationDialog("Delete this expense?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete expense", role: .destructive) { if let deleting { store.remove(deleting) }; deleting = nil }
        }
    }
    private func moveMonth(_ offset: Int) { if let next = Calendar.current.date(byAdding: .month, value: offset, to: month) { month = next } }
    private func money(_ cents: Int64, currency: String) -> String { (Double(cents) / 100).formatted(.currency(code: currency)) }
    private func prepare(_ type: UTType) {
        guard store.available else { store.message = "Load Spending before exporting."; return }
        do { document = PortableDocument(data: type == .json ? try LocalDataCoding.encode(store.state) : store.state.csv); exportType = type; export = true }
        catch { store.message = error.localizedDescription }
    }
}

private struct ExpenseEditor: View {
    @ObservedObject var store: SpendingStore
    @State var expense: Expense
    @State private var amount = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Expense", text: $expense.title)
                TextField("Amount in \(expense.currency)", text: $amount).keyboardType(.decimalPad)
                TextField("Category", text: $expense.category)
                DatePicker("Date", selection: $expense.date, displayedComponents: [.date, .hourAndMinute])
            }.personalList().navigationTitle("Expense")
            .onAppear { if expense.cents > 0 { amount = NSDecimalNumber(decimal: Decimal(expense.cents) / 100).stringValue } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let cents = SpendingState.cents(amount) else { store.message = "Enter a positive amount with up to two decimals."; return }
                    expense.cents = cents; var next = store.state
                    if let index = next.expenses.firstIndex(where: { $0.id == expense.id }) { next.expenses[index] = expense }
                    else { next.expenses.append(expense) }
                    if store.commit(next) { dismiss() }
                }.disabled(expense.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.personalMessage("Expense", message: $store.message)
        }
    }
}
