import SwiftUI

/// Every past day, on its own screen rather than the dashboard. Each month is a dropdown, newest
/// open, so a long history is one row per month and a month's days are built only when opened.
struct SquatHistoryView: View {
    @EnvironmentObject private var store: SquatStore
    @State private var openMonths = OpenMonths()

    var body: some View {
        let months = SquatDaySummary.byMonth(store.daySummaries)
        List {
            if months.isEmpty {
                Text("Completed and active days will appear here.")
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("pushups-history-empty")
            }
            ForEach(months) { month in
                MonthGroup(title: MonthKey.title(month.id),
                           summary: "\(month.completedSets) sets",
                           isExpanded: $openMonths.month(month.id)) {
                    ForEach(month.days) { day in
                        NavigationLink {
                            ScrollView { SquatDayRecap(day: day).padding(24) }
                                .background(AppBackdrop())
                                .navigationTitle("Summary")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            row(day)
                        }
                    }
                }
                .accessibilityIdentifier("pushups-month-\(month.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openMonths.seed(newest: months.first?.id) }
    }

    private func row(_ day: SquatDaySummary) -> some View {
        AdaptiveRow {
            Text(day.started.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
        } trailing: {
            HStack(spacing: 6) {
                Text(day.completedSets == 1 ? "1 set" : "\(day.completedSets) sets").monospacedDigit()
                if day.goalStatus == .reached {
                    Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                        .accessibilityLabel("goal reached")
                }
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// One day's recap: sets, goal, time, pauses and timeline. Shown after End my day and from history.
struct SquatDayRecap: View {
    let day: SquatDaySummary
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(day.started.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.title2.bold())
            Surface {
                Text("\(day.completedSets)").font(.system(size: countSize, weight: .semibold))
                Text(day.completedSets == 1 ? "set completed" : "sets completed").foregroundStyle(Palette.muted)
                Text(Self.goalDescription(day)).foregroundStyle(Palette.muted)
            }
            Surface {
                Text("Time").font(.headline)
                Text("Started \(day.started.formatted(date: .omitted, time: .shortened))")
                if let end = day.ended { Text("Ended \(end.formatted(date: .omitted, time: .shortened))") }
                else { Text("Day still open") }
                Text("Active \(Self.duration(day.activeDuration)) · Paused \(Self.duration(day.pausedDuration))")
                Text("\(day.sessions.count) session\(day.sessions.count == 1 ? "" : "s") · interval \(day.intervals.map(String.init).joined(separator: ", ")) min")
                Text("\(day.pauseSegments.count) pauses · \(day.snoozeTimes.count) snoozes")
            }
            if !day.pauseSegments.isEmpty {
                Surface {
                    Text("Pauses").font(.headline)
                    ForEach(day.pauseSegments) { pause in
                        AdaptiveRow {
                            Text("\(pause.started.formatted(date: .omitted, time: .shortened))–\(pause.ended.formatted(date: .omitted, time: .shortened))")
                        } trailing: {
                            Text(Self.duration(pause.duration)).foregroundStyle(Palette.muted)
                        }.font(.subheadline)
                    }
                }
            }
            Surface {
                Text("Timeline").font(.headline)
                if day.events.isEmpty { Text("No activity was logged.").foregroundStyle(Palette.muted) }
                ForEach(day.events) { event in
                    AdaptiveRow {
                        Text(Self.eventTitle(event.kind))
                    } trailing: {
                        Text(event.date, style: .time).foregroundStyle(Palette.muted)
                    }.font(.subheadline)
                }
            }
        }
    }

    static func eventTitle(_ kind: SquatEvent.Kind) -> String {
        switch kind {
        case .done: return "Pushup set completed"
        case .pause: return "Reminders paused"
        case .resume: return "Reminders resumed"
        case .snooze: return "Extra nudge requested"
        }
    }

    static func duration(_ value: TimeInterval) -> String {
        let minutes = max(0, Int(value) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func goalDescription(_ day: SquatDaySummary) -> String {
        switch day.goalStatus {
        case .notSet: return "No goal was set for this day."
        case .reached: return "Goal reached: \(day.completedSets) of \(day.goal ?? 0)."
        case .atRisk: return "In progress: \(day.completedSets) of \(day.goal ?? 0)."
        case .missed: return "Goal missed: \(day.completedSets) of \(day.goal ?? 0)."
        }
    }
}
