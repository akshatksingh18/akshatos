import SwiftUI

/// Every finished workout. Each month is a dropdown, newest open, so a long history is one row per
/// month and a month's workouts are built only when opened.
struct LiftLogHistoryView: View {
    @ObservedObject var store: LiftLogStore
    @State private var openMonths = OpenMonths()

    var body: some View {
        let months = LiftWorkoutSession.byMonth(store.workouts)
        List {
            if months.isEmpty {
                Text("Finished workouts will appear here.")
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("lift-history-empty")
            }
            ForEach(months) { month in
                MonthGroup(title: month.month.formatted(.dateTime.month(.wide).year()),
                           summary: month.workouts.count == 1 ? "1 workout" : "\(month.workouts.count) workouts",
                           isExpanded: $openMonths.month(month.id)) {
                    ForEach(month.workouts) { workout in
                        NavigationLink {
                            LiftWorkoutDetailView(workout: workout) { store.deleteWorkout(workout.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                     + (workout.splitName.map { " · \($0)" } ?? ""))
                                    .font(.headline)
                                Text("\(workout.exercises.count) exercises · \(workout.setCount) sets")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("lift-month-\(month.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Lift history")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openMonths.seed(newest: months.first?.id) }
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
                    if let splitName = workout.splitName {
                        Text(splitName).font(.headline).foregroundStyle(Palette.accent)
                    }
                    ForEach(workout.exercises) { exercise in
                        Surface {
                            Text(exercise.name).font(.title3.bold())
                            Text(exercise.loadMode.title).font(.caption).foregroundStyle(Palette.accent)
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
