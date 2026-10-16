import SwiftUI
import UniformTypeIdentifiers

/// Today: the time left against the day's target counting down while studying, like the Windows
/// Clock, with the time studied beneath it, one Start/Pause button and today's blocks.
struct StudyLogView: View {
    @ObservedObject var store: StudyLogStore
    @State private var exporting = false
    @State private var exportDocument: StudyLogDocument?
    @State private var importing = false
    @State private var pendingRestore: Data?
    @State private var confirmingRestore = false

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let date = store.isRunning ? context.date : store.currentDate()
                        VStack(alignment: .leading, spacing: 16) {
                            timerCard(at: date)
                            blocksCard(at: date)
                        }
                    }
                    NavigationLink { StudyLogHistoryView(store: store) } label: {
                        Surface {
                            HStack {
                                Text("History").font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Palette.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-study-history")
                    backupCard
                }
                .padding(20)
            }
        }
        .navigationTitle("Study Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if !store.storageAvailable { store.load() } }
        .alert("Study Log", isPresented: Binding(get: { store.message != nil },
                                                 set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
        .alert("Replace Study Log data?", isPresented: $confirmingRestore) {
            Button("Replace", role: .destructive) {
                if let data = pendingRestore {
                    Task {
                        do {
                            let checked = try StudyLogStore.validatedBackup(data)
                            var end: Date?
                            if let running = checked.segments.first(where: \.isRunning) {
                                let backup = try LocalDataCoding.decode(StudyLogBackup.self, data)
                                guard let actual = await store.approveRunningRestore(start: running.start, suggested: backup.exportedAt) else { return }
                                end = actual
                            }
                            _ = store.restoreBackup(data, confirmedRunningEnd: end)
                        } catch { store.message = error.localizedDescription }
                    }
                }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text("A valid backup replaces every study block on this iPhone. Export a backup first if you need this data.")
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: "akshatos-study-log-backup") { result in
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

    private func timerCard(at date: Date) -> some View {
        let studied = store.studiedToday(at: date)
        let target = store.targetToday(at: date)
        let remaining = Double(target) - studied
        return Surface {
            VStack(alignment: .center, spacing: 6) {
                Text(remaining > 0 ? StudyTime.clock(remaining) : "\(StudyTime.hours(target)) reached")
                    .font(.system(size: remaining > 0 ? 64 : 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(remaining > 0 ? "\(StudyTime.clock(remaining)) left" : "Target reached")
                    .accessibilityIdentifier("study-remaining")
                Text("Studied \(StudyTime.clock(studied))")
                    .font(.title3.monospacedDigit()).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("study-studied")
            }
            .frame(maxWidth: .infinity)
            StudyProgressBar(studied: studied, target: target,
                             floor: store.settings.floor, goal: store.settings.goal)
                .padding(.vertical, 4)
            Button {
                store.toggle()
            } label: {
                Text(store.isRunning ? "Pause" : (studied > 0 ? "Resume" : "Start"))
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(ActionStyle(primary: !store.isRunning))
            .accessibilityIdentifier("study-toggle")
            if let block = store.currentBlock(at: date) {
                Text("This block \(StudyTime.clock(block))")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("study-current-block")
            }
        }
    }

    @ViewBuilder private func blocksCard(at date: Date) -> some View {
        let blocks = store.blocksToday(at: date)
        Surface {
            Text("Today").font(.title3.bold())
            if blocks.isEmpty {
                Text("Nothing yet. Tap Start when you sit down to study, and Pause whenever you stop.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                ForEach(blocks.reversed()) { block in
                    StudyBlockRow(block: block)
                }
            }
        }
        .accessibilityIdentifier("study-today-blocks")
    }

    private var backupCard: some View {
        Surface {
            Text("Your data").font(.title3.bold())
            Text("Everything stays on this iPhone unless you export it. The hub's Backup screen includes Study Log too.")
                .font(.caption).foregroundStyle(Palette.muted)
            Button("Export backup") {
                do {
                    exportDocument = StudyLogDocument(data: try store.backupData())
                    exporting = true
                } catch { store.message = error.localizedDescription }
            }
            .buttonStyle(ActionStyle())
            Button("Restore backup") { importing = true }
                .buttonStyle(ActionStyle())
        }
    }
}

/// One block: its times and length. A running block reads "now".
struct StudyBlockRow: View {
    let block: StudyBlock

    var body: some View {
        AdaptiveRow {
            Text(block.start.formatted(date: .omitted, time: .shortened) + " – "
                 + (block.isRunning ? "now" : block.end.formatted(date: .omitted, time: .shortened)))
                .font(.subheadline.monospacedDigit())
        } trailing: {
            Text(StudyTime.short(block.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(block.isRunning ? Palette.accent : Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Studied time against the target, with quiet ticks at the two marks. Passing a mark is shown as
/// progress only; nothing is a verdict.
struct StudyProgressBar: View {
    let studied: TimeInterval
    let target: Int
    let floor: Int
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let fraction = min(1, studied / Double(max(target, 1)))
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.raised)
                    Capsule().fill(Palette.accent).frame(width: max(0, width * fraction))
                    ForEach([floor, goal].filter { $0 > 0 && $0 < target }, id: \.self) { mark in
                        Rectangle()
                            .fill(Double(mark) <= studied ? Palette.background.opacity(0.6) : Palette.muted)
                            .frame(width: 2, height: 14)
                            .offset(x: width * Double(mark) / Double(target) - 1)
                    }
                }
            }
            .frame(height: 14)
            GeometryReader { proxy in
                ForEach([floor, goal].filter { $0 > 0 && $0 < target }, id: \.self) { mark in
                    Text(StudyTime.hours(mark))
                        .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                        .fixedSize()
                        .position(x: proxy.size.width * Double(mark) / Double(target), y: 7)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(StudyTime.short(studied)) of \(StudyTime.hours(target))")
    }
}
