import SwiftUI

struct PersonalProgressView: View {
    @ObservedObject var study: StudyLogStore
    @ObservedObject var todo: TodoStore
    @ObservedObject var journal: JournalStore
    @ObservedObject var preferences: PersonalPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var month = false
    @State private var anchor = ""
    @State private var selected = ""
    @State private var metric = "hours"
    @State private var fullDay = false
    @State private var correction: StudySegment?
    private var clock: ActivityDayClock { ActivityDayClock(calendar: study.clock.calendar) }
    private var effectiveAnchor: String { anchor.isEmpty ? study.today : anchor }
    private var effectiveDay: String { selected.isEmpty ? study.today : selected }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Period", selection: $month) { Text("Week").tag(false); Text("Month").tag(true) }.pickerStyle(.segmented)
                periodControls
                if !study.storageAvailable { ContentUnavailableView("Study history unavailable", systemImage: "exclamationmark.triangle"); Button("Retry") { study.load() } }
                else {
                    if month { monthGrid } else { StudyWeekGraphic(store: study, anchor: effectiveAnchor, selected: $selected) }
                    selectedBlocks
                    Picker("Explore", selection: $metric) {
                        Text("Study hours").tag("hours"); Text("Topics").tag("topics"); Text("When you study").tag("patterns"); Text("Progress & challenges").tag("progress")
                    }
                    switch metric {
                    case "topics": topics
                    case "patterns": patterns
                    case "progress": motivation
                    default: hoursSummary
                    }
                    weeklyReview
                }
            }.padding(22)
        }.background(HubInk.background).navigationTitle("Study history").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        .sheet(item: $correction) { value in StudyCorrectionView(store: study, segment: value) }
        .personalMessage("Study", message: $study.message)
    }
    private var periodControls: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel(month ? "Previous month" : "Previous week")
            Spacer()
            Text(clock.date(effectiveAnchor)?.formatted(month ? .dateTime.month(.wide).year() : .dateTime.month(.abbreviated).day().year()) ?? effectiveAnchor).font(.headline)
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44) }
                .disabled(effectiveAnchor >= study.today).accessibilityLabel(month ? "Next month" : "Next week")
        }
    }
    private func shift(_ direction: Int) {
        guard let date = clock.date(effectiveAnchor), let next = clock.calendar.date(byAdding: month ? .month : .day, value: month ? direction : 7 * direction, to: date) else { return }
        anchor = min(clock.calendarKey(next), study.today); selected = anchor
    }
    private var monthDays: [String] {
        guard let date = clock.date(effectiveAnchor), let interval = clock.calendar.dateInterval(of: .month, for: date),
              let count = clock.calendar.range(of: .day, in: .month, for: date) else { return [] }
        return count.compactMap { day in clock.calendar.date(byAdding: .day, value: day - 1, to: interval.start).map(clock.calendarKey) }
    }
    private var monthGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            if preferences.fullDayChallenge { Toggle("Show full-day challenge", isOn: $fullDay) }
            let days = monthDays, lead = days.first.flatMap(clock.date).map { (clock.calendar.component(.weekday, from: $0) + 5) % 7 } ?? 0
            ScrollView(.horizontal, showsIndicators: false) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, title in Text(title).font(.caption).foregroundStyle(.secondary) }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(minHeight: 44) }
                ForEach(days, id: \.self) { day in
                    let future = day > study.today, completed = dayQualifies(day), planned = !fullDay || (todo.plan(day)?.selected.isEmpty == false)
                    Button { selected = day } label: {
                        Text(String(Int(day.suffix(2)) ?? 0)).font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                            .background(future ? Color.clear : completed ? HubInk.copper.opacity(0.55) : HubInk.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(day == effectiveDay ? HubInk.copper : .clear, lineWidth: 2))
                    }.buttonStyle(.plain).disabled(future)
                        .accessibilityLabel("\(day), \(future ? "upcoming" : fullDay && (!todo.available || !journal.available) ? "data unavailable" : fullDay && day < preferences.fullDayStart ? "before challenge began" : !planned ? "unplanned" : completed ? "completed" : "not completed")")
                }
            }.frame(minWidth: 320)
            }
            if fullDay && (!todo.available || !journal.available) { Text("Full-day history unavailable. Retry the affected store before interpreting this grid.").font(.caption).foregroundStyle(.secondary) }
            Text(fullDay ? "Copper: study mark, chosen priorities and Journal complete. No priorities: unplanned. Today remains open." : "Copper: the recorded study mark reached. The mark and the daily aim are separate.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func dayQualifies(_ day: String) -> Bool {
        let studyFact = study.daySummary(day, at: Date())
        if !fullDay { return studyFact.qualifies == true }
        guard todo.available, journal.available, preferences.fullDayChallenge, !preferences.fullDayStart.isEmpty, day >= preferences.fullDayStart else { return false }
        return studyFact.qualifies == true && todo.daySummary(day, at: Date()).qualifies == true && journal.daySummary(day, at: Date()).qualifies == true
    }
    private var selectedBlocks: some View {
        let day = effectiveDay, now = Date(), blocks = study.log.blocks(now: now, clock: study.clock).filter { $0.day == day }
        return VStack(alignment: .leading, spacing: 12) {
            Text(clock.date(day)?.formatted(date: .abbreviated, time: .omitted) ?? day).font(.headline)
            if blocks.isEmpty { Text(day > study.today ? "Upcoming day" : "No study recorded.").foregroundStyle(.secondary) }
            ForEach(blocks) { block in
                Button {
                    if var original = study.log.segments.first(where: { $0.id == block.segmentID }) {
                        if original.end == nil { original.end = Date() }; correction = original
                    }
                } label: { StudyBlockRow(block: block).frame(minHeight: 44).foregroundStyle(.primary) }.buttonStyle(.plain)
            }
            Button("Add a finished block", systemImage: "plus") {
                let end = min(Date(), (clock.start(day).flatMap { clock.calendar.date(byAdding: .hour, value: 12, to: $0) }) ?? Date())
                correction = StudySegment(start: end.addingTimeInterval(-1800), end: end, source: .manual,
                    dayTarget: study.log.target(for: day, clock: study.clock) ?? study.settings.target,
                    timeZoneID: clock.calendar.timeZone.identifier, dayFloor: study.settings.floor, dayGoal: study.settings.goal)
            }.disabled(day > study.today)
            if study.canUndoEdit { Button("Undo block correction") { study.undoEdit() } }
        }
    }
    private var periodKeys: [String] { month ? monthDays.filter { $0 <= study.today } : clock.week(effectiveAnchor).filter { $0 <= study.today } }
    private var periodBlocks: [StudyBlock] { study.log.blocks(now: Date(), clock: study.clock).filter { periodKeys.contains($0.day) } }
    private var hoursSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("Studied in this period", value: StudyTimeDisplay.short(periodBlocks.reduce(0) { $0 + $1.duration }))
            Text("\(periodKeys.count) elapsed days · current day included where present").font(.caption).foregroundStyle(.secondary)
            let closed = study.days(at: Date()).filter { $0.day < study.today }
            if let best = closed.max(by: { $0.studied < $1.studied }) {
                Label("Personal best: \(StudyTimeDisplay.short(best.studied)) · \(best.day)", systemImage: "chart.bar.fill")
                    .foregroundStyle(.purple).font(.subheadline)
            } else { Text("Personal bests appear after a study day closes.").font(.subheadline).foregroundStyle(.secondary) }
            momentum
        }
    }
    private var momentum: some View {
        let first = study.days(at: Date()).map(\.day).min()
        let recent = (1...7).compactMap { clock.shifted(study.today, by: -$0) }
        let previous = (8...14).compactMap { clock.shifted(study.today, by: -$0) }
        let totals = Dictionary(uniqueKeysWithValues: study.days(at: Date()).map { ($0.day, $0.studied) })
        return VStack(alignment: .leading, spacing: 8) {
            Text("Momentum").font(.headline)
            if let first, let earliest = previous.min(), first <= earliest {
                let a = recent.reduce(0) { $0 + (totals[$1] ?? 0) } / 7, b = previous.reduce(0) { $0 + (totals[$1] ?? 0) } / 7
                Text("\(StudyTimeDisplay.short(a))/day vs \(StudyTimeDisplay.short(b))/day")
                    .foregroundStyle(a > b ? .green : .primary)
                Text("\(recent.min() ?? "")–\(recent.max() ?? "") vs \(previous.min() ?? "")–\(previous.max() ?? ""). Closed days only.").font(.caption).foregroundStyle(.secondary)
            } else { Text("Building history · comparisons need fourteen closed calendar days of coverage.").font(.subheadline).foregroundStyle(.secondary) }
        }
    }
    private var topics: some View {
        let groups = Dictionary(grouping: periodBlocks) { block in study.log.segments.first { $0.id == block.segmentID }?.topic ?? "Untagged" }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Study topics").font(.headline)
            if groups.isEmpty { Text("Tag a block to see topic hours here.").foregroundStyle(.secondary) }
            ForEach(groups.keys.sorted(), id: \.self) { title in
                let amount = groups[title, default: []].reduce(0) { $0 + $1.duration }
                LabeledContent(title, value: StudyTimeDisplay.short(amount))
                ProgressView(value: amount, total: max(1, periodBlocks.reduce(0) { $0 + $1.duration })).tint(HubInk.copper)
            }
        }
    }
    private var patterns: some View {
        let bins = study.timeDistribution(days: Set(periodKeys))
        return VStack(alignment: .leading, spacing: 12) {
            Text("When you study").font(.headline)
            ForEach(0..<4) { index in
                LabeledContent(["Midnight–6 AM", "6 AM–noon", "Noon–6 PM", "6 PM–midnight"][index], value: StudyTimeDisplay.short(bins[index]))
                ProgressView(value: bins[index], total: max(1, bins.reduce(0, +))).tint(HubInk.copper)
            }
            Text("Recorded time distribution in each block’s saved zone; older blocks use the current zone. This does not measure learning quality.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var motivation: some View {
        VStack(alignment: .leading, spacing: 16) {
            let days = study.days(at: Date()).filter { $0.studied > 0 }.count
            Text("Milestones").font(.headline)
            Text("\(days) days with study recorded")
            ForEach(ActivityProgress.milestones, id: \.self) { number in
                Label("\(number) study days", systemImage: days >= number ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(days >= number ? HubInk.copper : .secondary)
            }
            if todo.available {
                let qualified = Set(todo.state.plans.filter(\.qualifies).map(\.day))
                let streak = ActivityProgress.streak(qualified, today: todo.today, clock: clock)
                LabeledContent("Priority streak", value: "\(streak.current) · best \(streak.best)")
            } else { Text("Priority history unavailable").foregroundStyle(.secondary) }
            if journal.available {
                let qualified = Set(journal.entries.filter(\.qualifies).map(\.day))
                if !journal.isLocked {
                    let streak = ActivityProgress.streak(qualified, today: journal.today, clock: clock)
                    LabeledContent("Writing streak", value: "\(streak.current) · best \(streak.best)")
                } else { Text("Unlock Journal to see writing history.").foregroundStyle(.secondary) }
            }
            Divider()
            Text("Daily challenge").font(.headline)
            if preferences.challengeAccepted && preferences.challengeDay == study.today {
                let seconds = study.secondsSince(preferences.challengeStartedAt ?? Date())
                Label(seconds >= 1200 ? "20 extra minutes completed" : "\(StudyTimeDisplay.short(seconds)) of 20 extra minutes", systemImage: seconds >= 1200 ? "checkmark.circle.fill" : "timer")
                Button("Dismiss challenge") { preferences.challengeAccepted = false }
            } else {
                Text("Study 20 more minutes today. Optional; no deadline or reminder.").font(.subheadline).foregroundStyle(.secondary)
                Button("Accept suggestion") { preferences.challengeDay = study.today; preferences.challengeStartedAt = Date(); preferences.challengeAccepted = true }
            }
            if preferences.fullDayChallenge {
                let qualified = Set(todo.state.plans.map(\.day).filter { day in
                    day >= preferences.fullDayStart && study.daySummary(day, at: Date()).qualifies == true
                        && todo.daySummary(day, at: Date()).qualifies == true && journal.daySummary(day, at: Date()).qualifies == true
                })
                if todo.available && journal.available {
                    let streak = ActivityProgress.streak(qualified, today: study.today, clock: clock)
                    LabeledContent("Full-day streak", value: "\(streak.current) · best \(streak.best)")
                } else { Text("Full-day history unavailable").foregroundStyle(.secondary) }
                Text("Started \(preferences.fullDayStart). Full-day challenge: the recorded study mark + every chosen priority + a saved Journal entry marked Done. Fitness is not included.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var weeklyReview: some View {
        let week = clock.week(effectiveAnchor), key = week.first ?? effectiveAnchor
        return DisclosureGroup("Weekly review") {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(week.first ?? "")–\(week.last ?? "") · \((week.last ?? "") >= study.today ? "week in progress" : "closed week")").font(.caption).foregroundStyle(.secondary)
                LabeledContent("Study", value: StudyTimeDisplay.short(study.log.blocks(now: Date(), clock: study.clock).filter { week.contains($0.day) }.reduce(0) { $0 + $1.duration }))
                if todo.available { LabeledContent("Completed priorities", value: String(todo.state.plans.filter { week.contains($0.day) }.reduce(0) { $0 + $1.completed.count })) }
                if journal.isLocked {
                    Button("Unlock Journal for reflection") { Task { _ = await journal.authenticate(reason: "Write your private weekly review") } }
                } else {
                    TextField("One focus for next week", text: Binding(get: { journal.weekNote(key) }, set: { journal.setWeekNote($0, week: key) }), axis: .vertical)
                    ForEach(journal.entries.filter { week.contains($0.day) }) { entry in
                        DisclosureGroup(entry.day) {
                            Text(entry.text).font(.subheadline)
                            if let mood = entry.mood { Text("Mood \(mood)/5").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }.padding(.vertical, 12)
        }
    }
}
