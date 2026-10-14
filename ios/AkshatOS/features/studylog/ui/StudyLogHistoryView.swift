import SwiftUI

/// Study history: a week of bars against the marks, then every day with study grouped by month
/// (newest open), each opening its blocks.
struct StudyLogHistoryView: View {
    @ObservedObject var store: StudyLogStore
    @State private var openMonths = OpenMonths()
    /// 0 is this week, -1 the week before, and so on.
    @State private var weekOffset = 0

    var body: some View {
        let date = store.currentDate()
        let days = store.days(at: date)
        let months = Dictionary(grouping: days) { String($0.day.prefix(7)) }
        let monthKeys = months.keys.sorted(by: >)
        List {
            weekCard(days: days, today: store.clock.key(for: date))
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            if monthKeys.isEmpty {
                Text("Days you study will appear here.")
                    .foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("study-history-empty")
            }
            ForEach(monthKeys, id: \.self) { month in
                let monthDays = months[month] ?? []
                MonthGroup(title: MonthKey.title(month),
                           summary: StudyTime.short(monthDays.reduce(0) { $0 + $1.studied }),
                           isExpanded: $openMonths.month(month)) {
                    ForEach(monthDays) { day in
                        NavigationLink {
                            StudyDayDetailView(summary: day, title: title(of: day.day, style: .long))
                        } label: {
                            AdaptiveRow {
                                Text(title(of: day.day, style: .short)).font(.headline)
                            } trailing: {
                                Text(StudyTime.short(day.studied))
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                        }
                        .accessibilityIdentifier("study-day-\(day.day)")
                    }
                }
                .accessibilityIdentifier("study-month-\(month)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Study history")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openMonths.seed(newest: monthKeys.first) }
    }

    private enum TitleStyle { case short, long }

    private func title(of day: String, style: TitleStyle) -> String {
        guard let date = store.clock.date(of: day) else { return day }
        switch style {
        case .short: return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .long: return date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }
    }

    /// The week's days as bars, scaled to the larger of the target and the longest day, with the
    /// two marks as faint lines. The week's total and its average per day studied so far.
    private func weekCard(days: [StudyDaySummary], today: String) -> some View {
        var anchor = today
        for _ in 0..<abs(weekOffset) {
            for _ in 0..<7 { anchor = store.clock.previous(anchor) ?? anchor }
        }
        let week = store.clock.week(containing: anchor)
        let studied = Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0.studied) })
        let values = week.map { studied[$0] ?? 0 }
        let settings = store.settings
        let scale = max(Double(settings.target), values.max() ?? 0, 1)
        let elapsed = week.filter { $0 <= today }.count
        let total = values.reduce(0, +)
        return Surface {
            HStack {
                Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous week")
                    .accessibilityIdentifier("study-week-previous")
                Spacer()
                Text(weekTitle(week)).font(.headline)
                Spacer()
                Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(weekOffset >= 0)
                    .accessibilityLabel("Next week")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.accent)
            GeometryReader { proxy in
                let height = proxy.size.height
                ZStack(alignment: .bottom) {
                    ForEach([settings.floor, settings.goal].filter { $0 > 0 }, id: \.self) { mark in
                        Rectangle().fill(Palette.muted.opacity(0.35)).frame(height: 1)
                            .offset(y: -height * Double(mark) / scale)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(week.indices, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(week[index] == today ? Palette.accent : Palette.accent.opacity(0.55))
                                .frame(height: max(values[index] > 0 ? 3 : 0, height * values[index] / scale))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .frame(height: 120)
            HStack(spacing: 8) {
                ForEach(week, id: \.self) { day in
                    Text(store.clock.date(of: day)?.formatted(.dateTime.weekday(.narrow)) ?? "")
                        .font(.caption2).foregroundStyle(day == today ? Color.primary : Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            AdaptiveRow {
                Text("Total \(StudyTime.short(total))").font(.subheadline.monospacedDigit())
            } trailing: {
                Text("Average \(StudyTime.short(total / Double(max(elapsed, 1)))) a day")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study-week")
    }

    private func weekTitle(_ week: [String]) -> String {
        guard let first = week.first.flatMap(store.clock.date(of:)),
              let last = week.last.flatMap(store.clock.date(of:)) else { return "This week" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

/// One day's blocks.
struct StudyDayDetailView: View {
    let summary: StudyDaySummary
    let title: String

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title).font(.title2.bold())
                    Surface {
                        AdaptiveRow {
                            Text("Studied").font(.headline)
                        } trailing: {
                            Text(StudyTime.clock(summary.studied)).font(.headline.monospacedDigit())
                        }
                        Text("Target \(StudyTime.hours(summary.target))")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    Surface {
                        Text(summary.blocks.count == 1 ? "1 block" : "\(summary.blocks.count) blocks")
                            .font(.title3.bold())
                        ForEach(summary.blocks) { block in
                            StudyBlockRow(block: block)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Study day")
        .navigationBarTitleDisplayMode(.inline)
    }
}
