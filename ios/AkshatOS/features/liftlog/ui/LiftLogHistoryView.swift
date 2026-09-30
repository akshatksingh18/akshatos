import SwiftUI

/// Every finished workout, grouped by month in a lazy list so a long history costs only the rows
/// on screen.
struct LiftLogHistoryView: View {
    @ObservedObject var store: LiftLogStore

    var body: some View {
        let months = LiftWorkoutSession.byMonth(store.workouts)
        List {
            if months.isEmpty {
                Text("Finished workouts will appear here.")
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("lift-history-empty")
            }
            ForEach(months) { month in
                Section {
                    ForEach(month.workouts) { workout in
                        NavigationLink {
                            LiftWorkoutDetailView(workout: workout) { store.deleteWorkout(workout.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.headline)
                                Text("\(workout.exercises.count) exercises · \(workout.setCount) sets")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                } header: {
                    AdaptiveRow {
                        Text(month.month.formatted(.dateTime.month(.wide).year()))
                    } trailing: {
                        Text(month.workouts.count == 1 ? "1 workout" : "\(month.workouts.count) workouts")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Lift history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LiftWorkoutDetailView: View {
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
