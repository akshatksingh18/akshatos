import SwiftUI

/// Your workout days. Add, rename, reorder or delete them; each one's exercises load in order when
/// a workout starts from it.
struct LiftSplitsView: View {
    @ObservedObject var store: LiftLogStore
    @State private var editing: LiftSplit?
    @State private var pendingDelete: LiftSplit?

    var body: some View {
        List {
            Section {
                if store.splits.isEmpty {
                    Text("No splits. Add one, or start an empty workout and add exercises as you go.")
                        .foregroundStyle(Palette.muted)
                }
                ForEach(store.splits) { split in
                    Button {
                        editing = split
                    } label: {
                        AdaptiveRow {
                            Text(split.name).foregroundStyle(.primary)
                        } trailing: {
                            Text(split.exercises.count == 1 ? "1 exercise" : "\(split.exercises.count) exercises")
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { pendingDelete = split }
                    }
                    .swipeActions(edge: .leading) {
                        Button("Delete", role: .destructive) { pendingDelete = split }
                    }
                }
                .onMove { store.moveSplits(from: $0, to: $1) }
            } footer: {
                Text("Workouts you already logged keep their split's name even if you rename or delete it here.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Splits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editing = LiftSplit(name: "")
                } label: {
                    Label("Add split", systemImage: "plus")
                }
                .accessibilityIdentifier("add-lift-split")
            }
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .sheet(item: $editing) { split in
            LiftSplitEditor(store: store, split: split)
        }
        .alert("Delete \(pendingDelete?.name ?? "this split")?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let pendingDelete { store.deleteSplit(pendingDelete.id) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Past workouts are kept.")
        }
    }
}

/// One split's name and its exercises in priority order.
struct LiftSplitEditor: View {
    @ObservedObject var store: LiftLogStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LiftSplit
    @State private var exerciseEditor: LiftExerciseDraft?
    @State private var problem: String?
    private let isNew: Bool

    init(store: LiftLogStore, split: LiftSplit) {
        self.store = store
        _draft = State(initialValue: split)
        isNew = !store.splits.contains { $0.id == split.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Chest day", text: $draft.name)
                        .accessibilityIdentifier("lift-split-name")
                }
                Section {
                    ForEach(draft.exercises) { exercise in
                        Button {
                            exerciseEditor = LiftExerciseDraft(exercise)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name).foregroundStyle(.primary)
                                Text(exercise.loadMode.title).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        .swipeActions(edge: .trailing) { removeButton(exercise) }
                        .swipeActions(edge: .leading) { removeButton(exercise) }
                    }
                    .onDelete { draft.exercises.remove(atOffsets: $0) }
                    .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button {
                        exerciseEditor = LiftExerciseDraft()
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .accessibilityIdentifier("add-split-exercise")
                } header: {
                    Text("Exercises, most important first")
                } footer: {
                    Text("They load in this order when you start this split; keep alternates here too, since only the ones you log are saved with a workout. Saving also updates a workout open from this split. Hold and drag to reorder, swipe either way to remove.")
                }
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            .navigationTitle(isNew ? "New split" : "Edit split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.saveSplit(draft)
                            dismiss()
                        } catch {
                            problem = error.localizedDescription
                        }
                    }
                    .accessibilityIdentifier("save-lift-split")
                }
            }
            .sheet(item: $exerciseEditor) { editing in
                LiftExerciseForm(draft: editing, suggestions: store.recentExercises) { saved in
                    let exercise = saved.splitExercise
                    if let index = draft.exercises.firstIndex(where: { $0.id == exercise.id }) {
                        draft.exercises[index] = exercise
                    } else {
                        draft.exercises.append(exercise)
                    }
                }
            }
        }
    }
}

extension LiftSplitEditor {
    fileprivate func removeButton(_ exercise: LiftSplitExercise) -> some View {
        Button("Remove", role: .destructive) { draft.exercises.removeAll { $0.id == exercise.id } }
    }
}

/// The exercise being typed in a split or during a workout.
struct LiftExerciseDraft: Identifiable {
    let id: UUID
    var name: String
    var loadMode: LiftLoadMode
    var equipmentNote: String
    let isNew: Bool

    init() {
        id = UUID()
        name = ""
        loadMode = .platesPerSide
        equipmentNote = ""
        isNew = true
    }

    init(_ exercise: LiftSplitExercise) {
        id = exercise.id
        name = exercise.name
        loadMode = exercise.loadMode
        equipmentNote = exercise.equipmentNote
        isNew = false
    }

    var splitExercise: LiftSplitExercise {
        LiftSplitExercise(id: id, name, loadMode, equipmentNote: equipmentNote)
    }
}

/// Name, how its weight is entered, and an optional note. Exercises you have logged before are
/// offered as you type, so the same exercise keeps one name and its last performance stays linked.
struct LiftExerciseForm: View {
    let suggestions: [LiftExerciseSuggestion]
    let onSave: (LiftExerciseDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LiftExerciseDraft
    @State private var problem: String?

    init(draft: LiftExerciseDraft, suggestions: [LiftExerciseSuggestion],
         onSave: @escaping (LiftExerciseDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.suggestions = suggestions
        self.onSave = onSave
    }

    private var matches: [LiftExerciseSuggestion] {
        let typed = draft.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !typed.isEmpty else { return [] }
        return Array(suggestions.filter {
            $0.name.lowercased().contains(typed) && $0.name.lowercased() != typed
        }.prefix(5))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Dumbbell biceps curl", text: $draft.name)
                        .accessibilityIdentifier("lift-exercise-name")
                    ForEach(matches, id: \.name) { suggestion in
                        Button {
                            draft.name = suggestion.name
                            draft.loadMode = suggestion.loadMode
                            draft.equipmentNote = suggestion.equipmentNote
                        } label: {
                            Label(suggestion.name, systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
                Section {
                    Picker("Weight entered as", selection: $draft.loadMode) {
                        ForEach(LiftLoadMode.allCases) { Text($0.title).tag($0) }
                    }
                } footer: {
                    Text("\(draft.loadMode.guidance) \(draft.loadMode.example)")
                }
                Section("Note (optional)") {
                    TextField("e.g. Bar weight excluded", text: $draft.equipmentNote)
                }
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
            }
            .navigationTitle(draft.isNew ? "Add exercise" : "Edit exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isNew ? "Add" : "Save") {
                        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            problem = LiftLogError.emptyExerciseName.localizedDescription
                            return
                        }
                        onSave(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("save-lift-exercise")
                }
            }
        }
    }
}
