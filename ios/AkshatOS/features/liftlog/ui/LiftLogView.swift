import SwiftUI
import UniformTypeIdentifiers

struct LiftLogView: View {
    @ObservedObject var store: LiftLogStore
    @State private var showingExercise = false
    @State private var setExercise: ExerciseSelection?
    @State private var confirmingFinish = false
    @State private var confirmingDiscard = false
    @State private var confirmingRestore = false
    @State private var pendingRestore: Data?
    @State private var exportDocument: LiftLogDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = "akshatos-lift-log"
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if let active = store.active { activeWorkout(active) }
                    else { startCard }
                    history
                    backupControls
                }
                .padding(20)
            }
        }
        .navigationTitle("Lift Log")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExercise) {
            AddLiftExerciseView(suggestions: store.recentExercises) { name, mode, note in
                store.addExercise(name: name, loadMode: mode, equipmentNote: note)
            }
        }
        .sheet(item: $setExercise) { selection in
            if let exercise = store.exercise(selection.id) {
                AddLiftSetView(exercise: exercise) { reps, load in
                    store.addSet(exerciseID: selection.id, reps: reps, load: load)
                }
            }
        }
        .alert("Finish this workout?", isPresented: $confirmingFinish) {
            Button("Finish workout") { store.finishWorkout() }
            Button("Keep logging", role: .cancel) {}
        } message: {
            Text("You can review the session afterward, but it will no longer accept sets.")
        }
        .alert("Discard this workout?", isPresented: $confirmingDiscard) {
            Button("Discard", role: .destructive) {
                if let id = store.active?.id { store.deleteWorkout(id) }
            }
            Button("Keep workout", role: .cancel) {}
        } message: {
            Text("Every set in the active workout will be deleted.")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuestBadge(text: "Strength log", icon: "dumbbell.fill", accent: Palette.gold)
            Text("Every working set,\nwithout fake totals.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
            Text("Plates per side is the default. Bar, sled, and machine resistance stay separate unless you actually know them.")
                .foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lift-log-header")
    }

    private var startCard: some View {
        AccentSurface(accent: Palette.gold) {
            Label("Ready for the next session", systemImage: "figure.strengthtraining.traditional")
                .font(.title3.bold())
            Text("Start once, add each exercise, then record every set using that exercise's measurement style.")
                .foregroundStyle(Palette.muted)
            Button("Start workout") { store.startWorkout() }
                .buttonStyle(ActionStyle(primary: true))
                .accessibilityIdentifier("start-lift-workout")
                .disabled(!store.storageAvailable)
        }
    }

    private func activeWorkout(_ workout: LiftWorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            AccentSurface(accent: Palette.gold) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout in progress").font(.title3.bold())
                        Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text("\(workout.setCount) sets")
                        .font(.headline.monospacedDigit()).foregroundStyle(Palette.gold)
                }
                Button("Add exercise") { showingExercise = true }
                    .buttonStyle(ActionStyle(primary: true))
                    .accessibilityIdentifier("add-lift-exercise")
            }

            ForEach(workout.exercises) { exercise in exerciseCard(exercise) }

            Button("Finish workout") { confirmingFinish = true }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("finish-lift-workout")
                .disabled(workout.setCount == 0)
            Button("Discard workout", role: .destructive) { confirmingDiscard = true }
                .buttonStyle(ActionStyle())
        }
    }

    private func exerciseCard(_ exercise: LiftExerciseRecord) -> some View {
        Surface {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name).font(.title3.bold())
                    Text(exercise.loadMode.title).font(.caption).foregroundStyle(Palette.gold)
                    if !exercise.equipmentNote.isEmpty {
                        Text(exercise.equipmentNote).font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                Text("\(exercise.sets.count) sets").font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }

            if exercise.sets.isEmpty {
                Text("No sets yet").foregroundStyle(Palette.muted)
            } else {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    AdaptiveRow {
                        Text("Set \(index + 1)").font(.subheadline.weight(.semibold))
                    } trailing: {
                        Text("\(LiftLogStore.weightText(set.load)) \(exercise.loadMode.shortUnit) × \(set.reps)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                    }
                }
            }

            HStack {
                Button("Log set") { setExercise = ExerciseSelection(id: exercise.id) }
                    .buttonStyle(ActionStyle(primary: true))
                    .accessibilityIdentifier("log-lift-set-\(exercise.id.uuidString)")
                if !exercise.sets.isEmpty {
                    Button("Undo last") { store.removeLastSet(exerciseID: exercise.id) }
                        .buttonStyle(ActionStyle())
                }
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History").font(.title2.bold())
                Spacer()
                Text("\(store.finished.count) sessions").font(.caption).foregroundStyle(Palette.muted)
            }
            if store.finished.isEmpty {
                Surface { Text("Finished workouts will appear here.").foregroundStyle(Palette.muted) }
            } else {
                ForEach(store.finished.prefix(12)) { workout in
                    NavigationLink {
                        LiftWorkoutDetailView(workout: workout) { store.deleteWorkout(workout.id) }
                    } label: {
                        Surface {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                    Text("\(workout.exercises.count) exercises · \(workout.setCount) sets")
                                        .font(.caption).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Palette.gold)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
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

private struct AddLiftExerciseView: View {
    let suggestions: [LiftExerciseSuggestion]
    let onSave: (String, LiftLoadMode, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var mode: LiftLoadMode = .platesPerSide
    @State private var equipmentNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Exercise name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("lift-exercise-name")
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions.prefix(8)) { suggestion in
                                    Button(suggestion.name) {
                                        name = suggestion.name
                                        mode = suggestion.loadMode
                                        equipmentNote = suggestion.equipmentNote
                                    }.buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                Section("How this exercise is measured") {
                    Picker("Measurement", selection: $mode) {
                        ForEach(LiftLoadMode.allCases) { Text($0.title).tag($0) }
                    }
                    Text(mode == .platesPerSide
                         ? "Enter the load on one side. The app shows twice that amount as added plates but never guesses the bar or machine base."
                         : "The recorded number keeps this meaning every time you use the exercise.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Equipment note (optional)", text: $equipmentNote)
                }
            }
            .navigationTitle("Add exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(name, mode, equipmentNote)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-lift-exercise")
                }
            }
        }
    }
}

private struct AddLiftSetView: View {
    let exercise: LiftExerciseRecord
    let onSave: (Int, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var loadText: String
    @State private var validation: String?

    init(exercise: LiftExerciseRecord, onSave: @escaping (Int, Double) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _reps = State(initialValue: exercise.latestSet?.reps ?? 8)
        _loadText = State(initialValue: exercise.latestSet.map { LiftLogStore.weightText($0.load) } ?? "")
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
                    if exercise.loadMode == .platesPerSide,
                       let value = Double(loadText.replacingOccurrences(of: ",", with: ".")) {
                        Text("Added plates: \(LiftLogStore.weightText(value * 2)) lb total; bar or machine base excluded.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let validation { Text(validation).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Log set")
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

private struct LiftWorkoutDetailView: View {
    let workout: LiftWorkoutSession
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(workout.startedAt.formatted(date: .complete, time: .shortened))
                        .font(.title2.bold())
                    ForEach(workout.exercises) { exercise in
                        Surface {
                            Text(exercise.name).font(.title3.bold())
                            Text(exercise.loadMode.title).font(.caption).foregroundStyle(Palette.gold)
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                Text("Set \(index + 1): \(LiftLogStore.weightText(set.load)) \(exercise.loadMode.shortUnit) × \(set.reps)")
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    }
                    Button("Delete workout", role: .destructive) { confirmingDelete = true }
                        .buttonStyle(ActionStyle())
                }.padding(20)
            }
        }
        .navigationTitle("Workout")
        .alert("Delete this workout?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { onDelete(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone unless it exists in an exported backup.") }
    }
}

private struct ExerciseSelection: Identifiable { let id: UUID }
