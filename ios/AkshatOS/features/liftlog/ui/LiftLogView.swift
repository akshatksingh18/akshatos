import SwiftUI
import UniformTypeIdentifiers

struct LiftLogView: View {
    @ObservedObject var store: LiftLogStore
    @State private var showingTemplatePicker = false
    @State private var setEditor: LiftSetEditorSelection?
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
        .sheet(item: $setEditor) { selection in
            if let exercise = store.exercise(selection.exerciseID) {
                let existingSet = selection.setID.flatMap { setID in
                    exercise.sets.first { $0.id == setID }
                }
                LiftSetEntryView(exercise: exercise, existingSet: existingSet,
                                 reference: store.lastPerformance(for: exercise)) { reps, load in
                    if let setID = selection.setID {
                        store.updateSet(exerciseID: selection.exerciseID, setID: setID,
                                        reps: reps, load: load)
                    } else {
                        store.addSet(exerciseID: selection.exerciseID, reps: reps, load: load)
                    }
                }
            }
        }
        .confirmationDialog("Choose workout", isPresented: $showingTemplatePicker,
                            titleVisibility: .visible) {
            ForEach(LiftWorkoutTemplate.allCases) { template in
                Button(template.title) { store.startWorkout(template: template) }
                    .accessibilityIdentifier("start-\(template.rawValue)-workout")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every exercise loads in priority order. Leave the lower-priority ones empty when time is short.")
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
            Text("Choose Upper or Lower. Your exercises load in priority order, ready for set entry.")
                .foregroundStyle(Palette.muted)
            Button("Start workout") { showingTemplatePicker = true }
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
                Text("Exercises are ordered from highest to lowest priority. Skip from the bottom when time is short.")
                    .font(.caption).foregroundStyle(Palette.muted)
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

            if let reference = store.lastPerformance(for: exercise) {
                LastPerformanceView(reference: reference, compact: true)
            } else {
                Text("Last performance: none yet for this exercise and measurement mode.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }

            if exercise.sets.isEmpty {
                Text("No sets yet").foregroundStyle(Palette.muted)
            } else {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    AdaptiveRow {
                        Text("Set \(index + 1)").font(.subheadline.weight(.semibold))
                    } trailing: {
                        HStack(spacing: 10) {
                            Text("\(LiftLogStore.weightText(set.load)) \(exercise.loadMode.shortUnit) × \(set.reps)")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                            Button {
                                setEditor = LiftSetEditorSelection(exerciseID: exercise.id,
                                                                   setID: set.id)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit set \(index + 1) for \(exercise.name)")
                            .accessibilityIdentifier("edit-lift-set-\(set.id.uuidString)")
                        }
                    }
                }
            }

            HStack {
                Button("Log set") {
                    setEditor = LiftSetEditorSelection(exerciseID: exercise.id, setID: nil)
                }
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

private struct LiftSetEntryView: View {
    let exercise: LiftExerciseRecord
    let existingSet: LiftSetRecord?
    let reference: LiftPerformanceReference?
    let onSave: (Int, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reps: Int
    @State private var loadText: String
    @State private var validation: String?

    init(exercise: LiftExerciseRecord, existingSet: LiftSetRecord?,
         reference: LiftPerformanceReference?, onSave: @escaping (Int, Double) -> Void) {
        self.exercise = exercise
        self.existingSet = existingSet
        self.reference = reference
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
                Section("Last performance") {
                    if let reference {
                        LastPerformanceView(reference: reference, compact: false)
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
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last performance · \(reference.workoutDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
            Text(setSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Palette.muted)
            if !reference.exercise.equipmentNote.isEmpty {
                Text(reference.exercise.equipmentNote)
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var setSummary: String {
        let displayedSets = compact ? Array(reference.exercise.sets.prefix(3)) : reference.exercise.sets
        let summary = displayedSets.enumerated().map { index, set in
            "S\(index + 1) \(LiftLogStore.weightText(set.load)) \(reference.exercise.loadMode.shortUnit) × \(set.reps)"
        }.joined(separator: " · ")
        let hiddenCount = reference.exercise.sets.count - displayedSets.count
        return hiddenCount > 0 ? "\(summary) · +\(hiddenCount) more" : summary
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

private struct LiftSetEditorSelection: Identifiable {
    let exerciseID: UUID
    let setID: UUID?
    var id: String { "\(exerciseID.uuidString)-\(setID?.uuidString ?? "new")" }
}
