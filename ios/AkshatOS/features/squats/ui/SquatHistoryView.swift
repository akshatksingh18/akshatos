import SwiftUI

/// Every past day, on its own screen rather than the dashboard, grouped by month in a lazy list so
/// a long history costs only the rows on screen.
struct SquatHistoryView: View {
    @EnvironmentObject private var store: SquatStore

    var body: some View {
        let months = SquatDaySummary.byMonth(store.daySummaries)
        List {
            if months.isEmpty {
                Text("Completed and active days will appear here.")
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("pushups-history-empty")
            }
            ForEach(months) { month in
                Section {
                    ForEach(month.days) { day in
                        NavigationLink {
                            ScrollView { SquatDayRecap(day: day).padding(24) }
                                .background(AppBackdrop())
                                .navigationTitle("Quest recap")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            row(day)
                        }
                    }
                } header: {
                    AdaptiveRow {
                        Text(Self.monthTitle(month.id))
                    } trailing: {
                        Text("\(month.completedSets) sets").monospacedDigit()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Past quests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ day: SquatDaySummary) -> some View {
        AdaptiveRow {
            Label(day.started.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                  systemImage: day.goalStatus == .reached ? "trophy.fill" : "clock.arrow.circlepath")
        } trailing: {
            Text("\(day.completedSets) pushup sets").monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    /// `yyyy-MM` as a readable month, such as "September 2026".
    static func monthTitle(_ key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

/// One day's recap: sets, goal, time, pauses and timeline. Shown after End my day and from history.
struct SquatDayRecap: View {
    let day: SquatDaySummary
    @ScaledMetric(relativeTo: .largeTitle) private var countSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            QuestBadge(text: "Quest recap", icon: "trophy.fill", accent: Palette.gold)
            Text("Power gained.\nDay saved.").font(.system(.largeTitle, design: .rounded, weight: .black))
            AccentSurface(accent: Palette.gold) {
                Text("\(day.completedSets)").font(.system(size: countSize, weight: .bold, design: .rounded)).foregroundStyle(Palette.lime)
                Text("pushup sets completed this day").foregroundStyle(Palette.muted)
                Text(day.started.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.headline)
                Text(Self.goalDescription(day)).foregroundStyle(Palette.muted)
            }
            Surface {
                Label("Time in your day", systemImage: "clock").font(.headline)
                Text("Started \(day.started.formatted(date: .omitted, time: .shortened))")
                if let end = day.ended { Text("Ended \(end.formatted(date: .omitted, time: .shortened))") }
                else { Text("Day still open") }
                Text("Active \(Self.duration(day.activeDuration)) · Paused \(Self.duration(day.pausedDuration))")
                Text("\(day.sessions.count) session\(day.sessions.count == 1 ? "" : "s") · interval \(day.intervals.map(String.init).joined(separator: ", ")) min")
                Text("\(day.pauseSegments.count) pauses · \(day.snoozeTimes.count) snoozes")
            }
            if !day.pauseSegments.isEmpty {
                Surface {
                    Label("Pause segments", systemImage: "pause.circle").font(.headline)
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
                Label("Daily timeline", systemImage: "list.bullet").font(.headline)
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
        case .reached: return "Quest cleared: \(day.completedSets)/\(day.goal ?? 0) pushup sets."
        case .atRisk: return "Quest in progress: \(day.completedSets)/\(day.goal ?? 0) pushup sets."
        case .missed: return "Quest not cleared: \(day.completedSets)/\(day.goal ?? 0) pushup sets."
        }
    }
}
