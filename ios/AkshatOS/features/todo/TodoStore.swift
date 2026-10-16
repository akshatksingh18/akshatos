import Foundation
import SwiftData

enum TodoSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Snapshot.self] }
    @Model final class Snapshot {
        @Attribute(.unique) var key: String
        var payload: Data
        init(payload: Data) { key = "todo"; self.payload = payload }
    }
}

@MainActor final class TodoStore: ObservableObject, HubDayPart {
    @Published private(set) var state = TodoState()
    @Published private(set) var available = false
    @Published var message: String?
    @Published private(set) var undoAvailable = false
    var onChange: (() -> Void)?
    private var container: ModelContainer?
    private let now: () -> Date
    let clock: ActivityDayClock
    private var undoCompletion: (id: UUID, child: TodoItem?, completedAt: Date, until: Date)?
    init(container: ModelContainer? = nil, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.container = container; self.now = now; clock = ActivityDayClock(calendar: calendar)
    }
    var today: String { clock.key(now()) }
    var visible: [TodoItem] { state.tasks.filter { $0.archivedAt == nil } }
    var nextTimed: TodoItem? {
        visible.filter { $0.completedAt == nil && $0.hasTime && ($0.due ?? .distantPast) >= now() }
            .min { $0.due! < $1.due! }
    }
    func plan(_ day: String) -> PriorityPlan? { state.plans.first { $0.day == day } }
    func priorities(_ day: String) -> [TodoItem] {
        (plan(day)?.selected ?? []).compactMap { id in state.tasks.first { $0.id == id } }
    }
    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: TodoSchemaV1.self)
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Todo", schema: schema)])
        }
        return container!.mainContext
    }
    func load() {
        do {
            let rows = try context().fetch(FetchDescriptor<TodoSchemaV1.Snapshot>())
            state = try rows.first.map { try LocalDataCoding.decode(TodoState.self, $0.payload).validated() } ?? TodoState()
            available = true
        } catch { available = false; message = "To-do could not be read. Your data has not been replaced: \(error.localizedDescription)" }
    }
    @discardableResult func commit(_ value: TodoState, replacingUnavailable: Bool = false) -> Bool {
        guard available || replacingUnavailable else { message = "Local data is unavailable. Retry loading before making changes."; return false }
        do {
            let checked = try value.validated(), payload = try LocalDataCoding.encode(checked), context = try context()
            do {
                let rows = try context.fetch(FetchDescriptor<TodoSchemaV1.Snapshot>())
                if let row = rows.first { row.payload = payload } else { context.insert(TodoSchemaV1.Snapshot(payload: payload)) }
                try context.save()
            } catch { context.rollback(); throw error }
            state = checked; available = true; onChange?(); return true
        } catch { message = "To-do was not saved: \(error.localizedDescription)"; return false }
    }
    @discardableResult func add(_ text: String) -> Bool {
        let parsed = QuickTask.parse(text, now: now(), calendar: clock.calendar)
        guard !parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var next = state
        var item = TodoItem(title: parsed.title, due: parsed.due, hasTime: parsed.hasTime)
        item.createdAt = now(); next.tasks.append(item)
        return commit(next)
    }
    func save(_ item: TodoItem) {
        var next = state
        if let index = next.tasks.firstIndex(where: { $0.id == item.id }) { next.tasks[index] = item }
        else { next.tasks.append(item) }
        _ = commit(next)
    }
    func archive(_ id: UUID) {
        guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { return }
        var next = state; next.tasks[index].archivedAt = now()
        // Retain the row and historical snapshots; deleting a task never awards a completion.
        if commit(next) { undoCompletion = nil; undoAvailable = false }
    }
    func choose(_ id: UUID, day: String) {
        var next = state
        do { try next.select(id, for: day, clock: clock); _ = commit(next) }
        catch { message = error.localizedDescription }
    }
    func removePriority(_ id: UUID, day: String) { var next = state; next.unselect(id, for: day); _ = commit(next) }
    func toggle(_ id: UUID) {
        guard let original = state.tasks.first(where: { $0.id == id }) else { return }
        guard original.completedAt == nil else {
            message = "Use Undo just after completion. Edit the daily plan to replace a previously completed task."
            return
        }
        var next = state
        do {
            let date = now(), childID = try next.complete(id, at: date, clock: clock)
            if commit(next) {
                undoCompletion = (id, next.tasks.first { $0.id == childID }, date, date.addingTimeInterval(10))
                undoAvailable = true
            }
        } catch { message = error.localizedDescription }
    }
    func undo() {
        guard let undo = undoCompletion, now() <= undo.until,
              let index = state.tasks.firstIndex(where: { $0.id == undo.id }),
              state.tasks[index].completedAt == undo.completedAt else {
            undoAvailable = false; message = "The Undo window has ended."; return
        }
        var next = state
        if let child = undo.child {
            guard next.tasks.first(where: { $0.id == child.id }) == child else {
                message = "The next repeat was edited. Undo cannot remove that edited task."; return
            }
            next.tasks.removeAll { $0.id == child.id }
        }
        next.tasks[index].completedAt = nil
        for i in next.plans.indices { next.plans[i].completed.remove(undo.id) }
        if commit(next) { undoAvailable = false; undoCompletion = nil }
    }
    @discardableResult func park(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        var next = state
        next.thoughts.append(ParkedThought(text: value, createdAt: now(), day: today, zone: clock.calendar.timeZone.identifier))
        return commit(next)
    }
    func sortThought(_ id: UUID, move: Bool) {
        guard let thought = state.thoughts.first(where: { $0.id == id }) else { return }
        var next = state; next.thoughts.removeAll { $0.id == id }
        if move { next.tasks.append(TodoItem(title: thought.text, createdAt: now())) }
        _ = commit(next)
    }
    func daySummary(_ day: String, at date: Date) -> HubDaySummary {
        let plan = plan(day)
        return HubDaySummary(source: "todo", day: day, asOf: date,
            availability: !available ? .unavailable : plan?.selected.isEmpty == false ? .available : .noData,
            completed: plan?.completed.count ?? 0, selected: plan?.selected.count ?? 0,
            qualifies: available && plan?.selected.isEmpty == false ? plan?.qualifies : nil)
    }
    func csv() -> Data {
        let rows = ["id,title,area,due,has_time,completed,note"] + state.tasks.map {
            [$0.id.uuidString, $0.title, $0.area, $0.due?.ISO8601Format() ?? "", String($0.hasTime),
             $0.completedAt?.ISO8601Format() ?? "", $0.note].map(LocalDataCoding.csv).joined(separator: ",")
        }
        return Data(rows.joined(separator: "\r\n").utf8)
    }
}

extension TodoStore: HubBackupPart {
    var backupID: String { "todo" }
    var backupTitle: String { "To-do" }
    func writeBackup(into folder: URL) async throws -> String? {
        if !available { load() }; guard available else { throw PersonalDataError.invalid("To-do cannot be read.") }
        try LocalDataCoding.encode(state).write(to: folder.appendingPathComponent("todo.json"), options: .atomic)
        return "todo.json"
    }
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let checked = try LocalDataCoding.decode(TodoState.self, Data(contentsOf: item)).validated()
        return HubBackupRestore { [self] in
            undoAvailable = false; undoCompletion = nil
            return commit(checked, replacingUnavailable: true) ? .restored : .failed(message ?? "To-do restore failed")
        }
    }
}
