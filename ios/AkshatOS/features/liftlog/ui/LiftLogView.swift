import SwiftUI
import UniformTypeIdentifiers

/// The Lift Log screen: today's workout, then history, splits and backup. The workout is a list,
/// so an exercise can be swiped away (either direction) or dragged into a new place, and the
/// search field finds any exercise in it to log. Logged exercises sit at the top in the order they
/// were done; the rest wait below as compact rows and are left out of the saved workout if never
/// logged, which is how a split can carry alternates that rotate.
struct LiftLogView: View {
    @ObservedObject var store: LiftLogStore
    @State private var showingTemplatePicker = false
    @State private var addingExercise: LiftExerciseDraft?
    @State private var setEditor: LiftSetEditorSelection?
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false
    @State private var confirmingRestore = false
    @State private var pendingRestore: Data?
    @State private var pendingRemoval: LiftExerciseRecord?
    @State private var exportDocument: LiftLogDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = "akshatos-lift-log"
    @State private var exporting = false
    @State private var importing = false
    @State private var search = ""
    @State private var reordering = false
    @State private var showingHistory = false
    @State private var showingSplits = false

    var body: some View {
        List {
            Section { header.liftRow() }
            if let active = store.active {
                activeWorkout(active)
            } else {
                Section { startCard.liftRow() }
            }
            Section {
                history.liftRow()
                splitsRow.liftRow()
                backupControls.liftRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .environment(\.editMode, .constant(reordering ? .active : .inactive))
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Find an exercise")
        .navigationTitle("Lift Log")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingHistory) { LiftLogHistoryView(store: store) }
        .navigationDestination(isPresented: $showingSplits) { LiftSplitsView(store: store) }
        .toolbar {
            if store.active != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(reordering ? "Done" : "Reorder") { reordering.toggle() }
                        .accessibilityIdentifier("reorder-workout")
                }
            }
        }
        .onChange(of: store.active == nil) { _, ended in if ended { reordering = false } }
        .sheet(item: $setEditor) { selection in
            if let exercise = store.exercise(selection.exerciseID) {
                let existingSet = selection.setID.flatMap { setID in
                    exercise.sets.first { $0.id == setID }
                }
                LiftSetEntryView(exercise: exercise, existingSet: existingSet,
                                 reference: store.lastPerformance(for: exercise),
                                 onDelete: deleteAction(selection, existingSet)) { reps, load in
                    if let setID = selection.setID {
                        store.updateSet(exerciseID: selection.exerciseID, setID: setID,
                                        reps: reps, load: load)
                    } else {
                        store.addSet(exerciseID: selection.exerciseID, reps: reps, load: load)
                        // Found by searching: back to the whole workout, where it now sits in order.
                        search = ""
                    }
                }
            }
        }
        .sheet(item: $addingExercise) { draft in
            LiftExerciseForm(draft: draft, suggestions: store.recentExercises) { saved in
                store.addExercise(name: saved.name, loadMode: saved.loadMode,
                                  equipmentNote: saved.equipmentNote)
                search = ""
            }
        }
        .confirmationDialog("Choose workout", isPresented: $showingTemplatePicker,
                            titleVisibility: .visible) {
            ForEach(store.splits) { split in
                Button(split.name) { store.startWorkout(split: split) }
            }
            Button("Empty workout") { store.startWorkout(split: nil) }
                .accessibilityIdentifier("start-empty-workout")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A split loads its exercises in order. Log the ones you do; the rest are not saved with the workout. Exercises you add are added to the split too.")
        }
        .confirmationDialog(removalTitle, isPresented: Binding(get: { pendingRemoval != nil },
                                                               set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible) {
            if let exercise = pendingRemoval {
                if exercise.splitExerciseID != nil, let split = store.activeSplit {
                    Button("Remove from today") { store.removeExercise(exercise.id, fromSplit: false) }
                        .accessibilityIdentifier("remove-exercise-today")
                    Button("Remove from today and \(split.name)", role: .destructive) {
                        store.removeExercise(exercise.id, fromSplit: true)
                    }
                } else {
                    Button("Remove", role: .destructive) { store.removeExercise(exercise.id, fromSplit: false) }
                        .accessibilityIdentifier("remove-exercise-today")
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            if let exercise = pendingRemoval, !exercise.sets.isEmpty {
                Text(exercise.sets.count == 1 ? "Its logged set is deleted." : "Its \(exercise.sets.count) logged sets are deleted.")
            }
        }
        .alert("Finish this workout?", isPresented: $confirmingFinish) {
            Button("Finish workout") { store.finishWorkout() }
            Button("Keep logging", role: .cancel) {}
        } message: {
            Text("Exercises you did not log are left out. You can review the session afterward, but it will no longer accept sets.")
        }
        .alert("Discard this workout?", isPresented: $confirmingDiscard) {
            Button("Discard", role: .destructive) {
                if let id = store.active?.id { store.deleteWorkout(id) }
            }
            Button("Keep workout", role: .cancel) {}
        } message: {
            Text("Every set in the active workout will be deleted. The split is not changed.")
        }
        .alert("Replace Lift Log data?", isPresented: $confirmingRestore) {
            Button("Replace", role: .destructive) {
                if let pendingRestore { store.restoreBackup(pendingRestore) }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("A valid backup will replace every current Lift Log workout. Export a backup first if you need this data.")
        }
        .alert("Lift Log", isPresented: Binding(get: { store.message != nil },
                                                set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .fileExporter(isPresented: $exporting, document: exportDocument,
                      contentType: exportType, defaultFilename: exportName) { result in
            if case let .failure(error) = result { store.message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingRestore = try Data(contentsOf: url)
                confirmingRestore = true
            } catch {
                store.message = "The selected backup could not be opened: \(error.localizedDescription)"
            }
        }
    }

    /// Dragging only while the whole workout is shown; with a search the rows are a subset.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard search.isEmpty else { return nil }
        return { store.moveExercises(from: $0, to: $1) }
    }

    private func deleteAction(_ selection: LiftSetEditorSelection, _ set: LiftSetRecord?) -> (() -> Void)? {
        guard let set else { return nil }
        return { store.removeSet(exerciseID: selection.exerciseID, setID: set.id) }
    }

    private var removalTitle: String {
        "Remove \(pendingRemoval?.name ?? "this exercise")?"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline).foregroundStyle(Palette.muted)
            Text("Loads are plates per side unless an exercise says otherwise.")
                .font(.footnote).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lift-log-header")
    }

    private var startCard: some View {
        Surface {
            Text("No workout in progress").font(.headline)
            Text("Choose one of your splits, or start empty and add exercises as you go.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            Button("Start workout") { showingTemplatePicker = true }
                .buttonStyle(ActionStyle(primary: true))
                .accessibilityIdentifier("start-lift-workout")
                .disabled(!store.storageAvailable)
        }
    }

    /// The exercises the list shows: all of them, or the ones whose name matches the search.
    private func shown(_ workout: LiftWorkoutSession) -> [LiftExerciseRecord] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return workout.exercises }
        return workout.exercises.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Exercises logged before that match the search and are not in this workout, to add in a tap.
    private func addable(_ workout: LiftWorkoutSession) -> [LiftExerciseSuggestion] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return store.recentExercises.filter { suggestion in
            suggestion.name.localizedCaseInsensitiveContains(query)
                && !workout.exercises.contains { LiftSplit.sameName($0.name, suggestion.name) }
        }
    }

    @ViewBuilder
    private func activeWorkout(_ workout: LiftWorkoutSession) -> some View {
        Section {
            Surface {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.splitName ?? "Workout in progress").font(.title3.bold())
                        Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text("\(workout.setCount) sets")
                        .font(.headline.monospacedDigit()).foregroundStyle(Palette.accent)
                }
                Text(workout.exercises.isEmpty
                     ? "Add the exercises you do today."
                     : "Logged exercises move up in the order you do them. The rest wait below and are not saved unless you log them. Swipe one away, or tap Reorder to drag.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            .liftRow()
        }
        Section {
            ForEach(shown(workout)) { exercise in
                Group {
                    if reordering {
                        reorderRow(exercise)
                    } else if exercise.sets.isEmpty {
                        waitingCard(exercise)
                    } else {
                        exerciseCard(exercise)
                    }
                }
                .liftRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) { removeButton(exercise) }
                .swipeActions(edge: .leading, allowsFullSwipe: false) { removeButton(exercise) }
            }
            .onMove(perform: moveAction)
            if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                searchExtras(workout).liftRow()
            }
        }
        Section {
            VStack(spacing: 12) {
                Button {
                    addingExercise = LiftExerciseDraft()
                } label: {
                    Label("Add exercise", systemImage: "plus")
                }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("add-workout-exercise")

                Button("Finish workout") { confirmingFinish = true }
                    .buttonStyle(ActionStyle())
                    .accessibilityIdentifier("finish-lift-workout")
                    .disabled(workout.setCount == 0)
                Button("Discard workout", role: .destructive) { confirmingDiscard = true }
                    .buttonStyle(ActionStyle())
            }
            .liftRow()
        }
    }

    private func removeButton(_ exercise: LiftExerciseRecord) -> some View {
        Button(role: .destructive) {
            pendingRemoval = exercise
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .accessibilityIdentifier("remove-exercise-\(exercise.id.uuidString)")
    }

    /// What the search adds below its matches: exercises logged before that are not in today's
    /// workout, and a new exercise by the typed name.
    @ViewBuilder
    private func searchExtras(_ workout: LiftWorkoutSession) -> some View {
        let query = search.trimmingCharacters(in: .whitespaces)
        let matches = shown(workout)
        let suggestions = addable(workout)
        VStack(alignment: .leading, spacing: 10) {
            if matches.isEmpty {
                Text("Not in today's workout.").font(.caption).foregroundStyle(Palette.muted)
            }
            ForEach(suggestions) { suggestion in
                Button {
                    store.addExercise(name: suggestion.name, loadMode: suggestion.loadMode,
                                      equipmentNote: suggestion.equipmentNote)
                } label: {
                    Label("Add \(suggestion.name)", systemImage: "plus")
                }
                .buttonStyle(ActionStyle())
            }
            if !matches.contains(where: { LiftSplit.sameName($0.name, query) })
                && !suggestions.contains(where: { LiftSplit.sameName($0.name, query) }) {
                Button {
                    var draft = LiftExerciseDraft()
                    draft.name = query
                    addingExercise = draft
                } label: {
                    Label("Add \u{201C}\(query)\u{201D}", systemImage: "plus")
                }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("add-searched-exercise")
            }
        }
    }

    /// A compact row while reordering, so many exercises fit for dragging.
    private func reorderRow(_ exercise: LiftExerciseRecord) -> some View {
        HStack {
            Text(exercise.name).font(.headline)
            Spacer()
            Text(exercise.sets.isEmpty ? "Not started" : "\(exercise.sets.count) sets")
                .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 6)
    }

    /// An exercise not logged yet today: its name, how its weight is entered, what you did last
    /// time and a button to log the first set.
    private func waitingCard(_ exercise: LiftExerciseRecord) -> some View {
        Surface {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.equipmentNote.isEmpty ? exercise.loadMode.title
                         : "\(exercise.loadMode.title) · \(exercise.equipmentNote)")
                        .font(.caption).foregroundStyle(Palette.accent)
                    if let reference = store.lastPerformance(for: exercise) {
                        Text("Last: \(LiftLogStore.performanceSummary(reference.exercise))")
                            .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                            .lineLimit(2)
                    } else {
                        Text("Last performance: none yet for this exercise and measurement mode.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                Spacer(minLength: 0)
                Button("Log set") {
                    setEditor = LiftSetEditorSelection(exerciseID: exercise.id, setID: nil)
                }
                .buttonStyle(ActionStyle(primary: true))
                .frame(width: 104)
                .accessibilityIdentifier("log-lift-set-\(exercise.id.uuidString)")
            }
        }
    }

    private func exerciseCard(_ exercise: LiftExerciseRecord) -> some View {
        Surface {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.title3.bold())
                    Text(exercise.loadMode.title).font(.caption).foregroundStyle(Palette.accent)
                    if !exercise.equipmentNote.isEmpty {
                        Text(exercise.equipmentNote).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                Text("\(exercise.sets.count) sets").font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }

            if let reference = store.lastPerformance(for: exercise) {
                LastPerformanceView(reference: reference)
            } else {
                Text("Last performance: none yet for this exercise and measurement mode.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                AdaptiveRow {
                    Text("Set \(index + 1)").font(.subheadline.weight(.semibold))
                } trailing: {
                    HStack(spacing: 10) {
                        Text("\(LiftLogStore.weightText(set.load)) \(exercise.loadMode.shortUnit) × \(set.reps)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                        Button {
                            setEditor = LiftSetEditorSelection(exerciseID: exercise.id, setID: set.id)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit or delete set \(index + 1) for \(exercise.name)")
                        .accessibilityIdentifier("edit-lift-set-\(set.id.uuidString)")
                    }
                }
            }

            HStack {
                Button("Log set") {
                    setEditor = LiftSetEditorSelection(exerciseID: exercise.id, setID: nil)
                }
                .buttonStyle(ActionStyle(primary: true))
                .accessibilityIdentifier("log-lift-set-\(exercise.id.uuidString)")
                Button("Undo last") { store.removeLastSet(exerciseID: exercise.id) }
                    .buttonStyle(ActionStyle())
            }
        }
    }

    /// One row into the full history.
    private var history: some View {
        Button {
            showingHistory = true
        } label: {
            Surface {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History").font(.title2.bold())
                        Text(store.finished.count == 1 ? "1 session" : "\(store.finished.count) sessions")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-lift-history")
    }

    /// Your workout days, edited on their own screen.
    private var splitsRow: some View {
        Button {
            showingSplits = true
        } label: {
            Surface {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Splits").font(.title2.bold())
                        Text(store.splits.map(\.name).joined(separator: " · "))
                            .font(.caption).foregroundStyle(Palette.muted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-lift-splits")
    }

    private var backupControls: some View {
        Surface {
            Text("Your data").font(.title3.bold())
            Text("Everything stays on this iPhone unless you explicitly export it. JSON is the restorable backup; CSV is for reviewing your sets elsewhere.")
                .font(.caption).foregroundStyle(Palette.muted)
            Button("Export backup") {
                do {
                    exportDocument = LiftLogDocument(data: try store.backupData())
                    exportType = .json
                    exportName = "akshatos-lift-log-backup"
                    exporting = true
                } catch { store.message = error.localizedDescription }
            }.buttonStyle(ActionStyle())
            Button("Export CSV") {
                exportDocument = LiftLogDocument(data: store.csvData())
                exportType = .commaSeparatedText
                exportName = "akshatos-lift-log"
                exporting = true
            }.buttonStyle(ActionStyle())
            Button("Restore backup") { importing = true }
                .buttonStyle(ActionStyle())
        }
    }
}

private extension View {
    /// A card sitting in the list on the screen's own background, without list chrome.
    func liftRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
    }
}

private struct LiftSetEntryView: View {
    let exercise: LiftExerciseRecord
    let existingSet: LiftSetRecord?
    let reference: LiftPerformanceReference?
    /// Deletes the set being edited; nil when logging a new one.
    let onDelete: (() -> Void)?
    let onSave: (Int, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var loadText: String
    @State private var validation: String?

    init(exercise: LiftExerciseRecord, existingSet: LiftSetRecord?,
         reference: LiftPerformanceReference?, onDelete: (() -> Void)? = nil,
         onSave: @escaping (Int, Double) -> Void) {
        self.exercise = exercise
        self.existingSet = existingSet
        self.reference = reference
        self.onDelete = onDelete
        self.onSave = onSave
        _reps = State(initialValue: existingSet?.reps ?? exercise.latestSet?.reps ?? 8)
        let startingLoad = existingSet?.load ?? exercise.latestSet?.load
        _loadText = State(initialValue: startingLoad.map(LiftLogStore.weightText) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(exercise.name) {
                    TextField(exercise.loadMode.title, text: $loadText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("lift-set-load")
                    Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                    Text("Saved as \(exercise.loadMode.shortUnit).")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Meaning: \(exercise.loadMode.guidance)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(exercise.loadMode.example)
                        .font(.caption).foregroundStyle(.secondary)
                    if exercise.loadMode == .platesPerSide,
                       let value = Double(loadText.replacingOccurrences(of: ",", with: ".")) {
                        Text("Added plates: \(LiftLogStore.weightText(value * 2)) lb total; bar or machine base excluded.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let validation { Text(validation).foregroundStyle(.red) }
                }
                if let onDelete {
                    Section {
                        Button("Delete set", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .accessibilityIdentifier("delete-lift-set")
                    }
                }
                Section("Last performance") {
                    if let reference {
                        LastPerformanceView(reference: reference)
                    } else {
                        Text("No previous finished workout contains this exercise with the same measurement mode.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existingSet == nil ? "Log set" : "Edit set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let load = Double(loadText.replacingOccurrences(of: ",", with: ".")),
                              load >= 0 else {
                            validation = "Enter a valid weight."
                            return
                        }
                        onSave(reps, load)
                        dismiss()
                    }
                    .accessibilityIdentifier("save-lift-set")
                }
            }
        }
    }
}

private struct LastPerformanceView: View {
    let reference: LiftPerformanceReference

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last performance · \(reference.workoutDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
            Text(LiftLogStore.performanceSummary(reference.exercise))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("last-performance-sets")
            if !reference.exercise.equipmentNote.isEmpty {
                Text(reference.exercise.equipmentNote)
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LiftSetEditorSelection: Identifiable {
    let exerciseID: UUID
    let setID: UUID?
    var id: String { "\(exerciseID.uuidString)-\(setID?.uuidString ?? "new")" }
}
