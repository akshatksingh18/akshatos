import Foundation

/// Study Log: a countdown study timer that records real study time. Start and Pause save each block
/// as it happens; the running block is only its start time, so the app being suspended, killed or
/// relaunched never changes what was studied. Everything stays on this iPhone.
@MainActor final class StudyLogStore: ObservableObject {
    @Published private(set) var log = StudyLog()
    @Published private(set) var settings: StudySettings
    @Published private(set) var storageAvailable = false
    @Published var message: String?
    @Published var selectedTopic = ""
    @Published var runningRestoreReview: StudyRunningRestoreReview?
    @Published private(set) var canUndoEdit = false
    var onChange: (() -> Void)?
    private var restoreContinuation: CheckedContinuation<Date?, Never>?
    private var editUndo: (before: [StudySegment], after: [StudySegment], until: Date)?

    private let repository: any StudyLogRepository
    private let defaults: UserDefaults
    private let now: () -> Date
    let clock: StudyDayClock

    private enum Keys {
        static let settings = "studylog.settings"
    }

    init(repository: (any StudyLogRepository)? = nil, defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository ?? SwiftDataStudyLogRepository()
        self.defaults = defaults
        self.now = now
        clock = StudyDayClock(calendar: calendar)
        settings = (defaults.data(forKey: Keys.settings)
            .flatMap { try? JSONDecoder().decode(StudySettings.self, from: $0) } ?? .standard).validated()
        selectedTopic = defaults.string(forKey: "studylog.topic") ?? ""
    }

    func load() {
        do {
            log = StudyLog(segments: try repository.load())
            storageAvailable = true
        } catch {
            storageAvailable = false
            message = "Your study log could not be read: \(error.localizedDescription)"
        }
    }

    var isRunning: Bool { log.running != nil }
    var today: String { clock.key(for: now()) }

    /// Time studied in the study day that is current at `date`, counting a running block up to then.
    func studiedToday(at date: Date) -> TimeInterval {
        log.studied(on: clock.key(for: date), now: date, clock: clock)
    }

    /// Today's target: the one the day's first block recorded, else the current setting.
    func targetToday(at date: Date) -> Int {
        log.target(for: clock.key(for: date), clock: clock) ?? settings.target
    }

    func blocksToday(at date: Date) -> [StudyBlock] {
        let day = clock.key(for: date)
        return log.blocks(now: date, clock: clock).filter { $0.day == day }
    }

    /// How long the running block has gone, or nil when paused.
    func currentBlock(at date: Date) -> TimeInterval? {
        log.running?.duration(now: date)
    }

    func days(at date: Date) -> [StudyDaySummary] {
        log.days(now: date, clock: clock, fallbackTarget: settings.target)
    }

    /// The current time, for screens that need the same clock as the store.
    func currentDate() -> Date { now() }

    // MARK: - Start and Pause

    func start() {
        if !storageAvailable { load() }
        guard storageAvailable else { return }
        var updated = log
        guard let segment = updated.start(at: now(), target: settings.target,
            topic: selectedTopic.isEmpty ? nil : selectedTopic, timeZoneID: clock.calendar.timeZone.identifier, dayFloor: settings.floor, dayGoal: settings.goal) else { return }
        do {
            try repository.save(segment)
            log = updated
            defaults.set(selectedTopic, forKey: "studylog.topic")
            editUndo = nil; canUndoEdit = false; onChange?()
        } catch {
            message = "Start could not be saved: \(error.localizedDescription)"
        }
    }

    func pause() {
        guard let running = log.running else { return }
        var updated = log
        do {
            if let finished = updated.pause(at: now()) {
                try repository.save(finished)
            } else {
                try repository.delete(id: running.id)
            }
            log = updated
            editUndo = nil; canUndoEdit = false; onChange?()
        } catch {
            message = "Pause could not be saved: \(error.localizedDescription)"
        }
    }

    func toggle() { isRunning ? pause() : start() }

    // MARK: - Backup

    func backupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(StudyLogBackup(exportedAt: now(), segments: log.segments, settings: settings))
    }

    /// Decodes and checks a backup without changing anything.
    static func validatedBackup(_ data: Data) throws -> (segments: [StudySegment], settings: StudySettings?) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(StudyLogBackup.self, from: data)
        return (try backup.validatedSegments(), backup.settings?.validated())
    }

    /// Replaces every block, and the settings when the backup has them, with a checked backup.
    @discardableResult
    func restoreBackup(_ data: Data, confirmedRunningEnd: Date? = nil) -> Bool {
        do {
            var restored = try Self.validatedBackup(data)
            if let index = restored.segments.firstIndex(where: \.isRunning) {
                guard let end = confirmedRunningEnd, end >= restored.segments[index].start, end <= now() else {
                    throw PersonalDataError.invalid("Choose the actual end of the backed-up running block before restoring. Elapsed time is not automatically accepted.")
                }
                restored.segments[index].end = end
                restored.segments = try StudyLog.validated(restored.segments)
            }
            try repository.replaceAll(with: restored.segments)
            log = StudyLog(segments: restored.segments)
            if let restoredSettings = restored.settings { save(restoredSettings) }
            storageAvailable = true
            editUndo = nil; canUndoEdit = false; onChange?()
            message = "Study Log restored: \(restored.segments.count == 1 ? "1 block" : "\(restored.segments.count) blocks")."
            return true
        } catch {
            message = "That backup was not restored: \(error.localizedDescription)"
            return false
        }
    }

    private func save(_ value: StudySettings) {
        settings = value.validated()
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Keys.settings) }
    }

    func updateSettings(target: Int, floor: Int, goal: Int) {
        save(StudySettings(target: target, floor: floor, goal: goal)); onChange?()
    }
    @discardableResult func setTopic(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count <= 200 else { message = "Use a shorter topic name."; return false }
        do {
            if var running = log.running {
                running.topic = value.isEmpty ? nil : value
                try repository.save(running)
                if let index = log.segments.firstIndex(where: { $0.id == running.id }) { log.segments[index] = running }
            }
            selectedTopic = value; defaults.set(value, forKey: "studylog.topic"); onChange?(); return true
        } catch { message = "The topic was not saved."; return false }
    }
    func secondsSince(_ date: Date) -> Double {
        log.blocks(now: now(), clock: clock).filter { $0.day == today }.reduce(0) {
            $0 + max(0, $1.end.timeIntervalSince(max(date, $1.start)))
        }
    }
    func timeDistribution(days: Set<String>) -> [Double] {
        var bins = Array(repeating: 0.0, count: 4)
        for block in log.blocks(now: now(), clock: clock) where days.contains(block.day) {
            var calendar = clock.calendar
            if let name = log.segments.first(where: { $0.id == block.segmentID })?.timeZoneID,
               let zone = TimeZone(identifier: name) { calendar.timeZone = zone }
            var cursor = block.start
            while cursor < block.end {
                guard let interval = calendar.dateInterval(of: .hour, for: cursor), interval.end > cursor else { break }
                let end = min(interval.end, block.end), bin = min(3, max(0, calendar.component(.hour, from: cursor) / 6))
                bins[bin] += end.timeIntervalSince(cursor); cursor = end
            }
        }
        return bins
    }
    var lastPause: Date? { isRunning ? nil : log.segments.compactMap(\.end).max() }
    var needsRunningReview: Bool { log.running.map { $0.duration(now: now()) >= 3600 } ?? false }
    @discardableResult func saveSegment(_ segment: StudySegment) -> Bool {
        guard segment.end != nil, segment.start <= now(), (segment.end ?? .distantFuture) <= now() else {
            message = "Choose a finished block with start and end times no later than now."; return false
        }
        var values = log.segments
        if let index = values.firstIndex(where: { $0.id == segment.id }) { values[index] = segment }
        else { values.append(segment) }
        return replaceForEdit(values)
    }
    func removeSegment(_ id: UUID) {
        guard log.running?.id != id else { message = "Pause the running block before removing it."; return }
        _ = replaceForEdit(log.segments.filter { $0.id != id })
    }
    private func replaceForEdit(_ values: [StudySegment]) -> Bool {
        guard storageAvailable else { message = "Study data is unavailable. Retry loading it first."; return false }
        do {
            let checked = try StudyLog.validated(values), previous = log.segments
            try repository.replaceAll(with: checked); log = StudyLog(segments: checked)
            editUndo = (previous, checked, now().addingTimeInterval(10)); canUndoEdit = true; onChange?(); return true
        } catch { message = "The correction was not saved: \(error.localizedDescription)"; return false }
    }
    func undoEdit() {
        guard let undo = editUndo, now() <= undo.until, log.segments == undo.after else {
            message = "The Undo window ended or the timer changed."; canUndoEdit = false; return
        }
        do {
            try repository.replaceAll(with: undo.before); log = StudyLog(segments: undo.before)
            editUndo = nil; canUndoEdit = false; onChange?()
        } catch { message = "Undo could not be saved." }
    }
    func correctRunning(end: Date) {
        guard var running = log.running else { return }
        running.end = end; _ = saveSegment(running)
    }
    func approveRunningRestore(start: Date, suggested: Date) async -> Date? {
        guard restoreContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            restoreContinuation = continuation
            runningRestoreReview = StudyRunningRestoreReview(start: start, suggestedEnd: min(max(suggested, start), now()))
        }
    }
    func finishRunningRestore(_ end: Date?) {
        let continuation = restoreContinuation; restoreContinuation = nil; runningRestoreReview = nil
        continuation?.resume(returning: end)
    }
}

struct StudyRunningRestoreReview: Identifiable {
    var id = UUID()
    var start: Date
    var suggestedEnd: Date
}

extension StudyLogStore: HubDayPart {
    func daySummary(_ day: String, at date: Date) -> HubDaySummary {
        let seconds = log.studied(on: day, now: date, clock: clock)
        return HubDaySummary(source: "study", day: day, asOf: date,
            availability: !storageAvailable ? .unavailable : seconds > 0 ? .available : .noData,
            completed: Int(seconds), selected: log.target(for: day, clock: clock) ?? settings.target,
            qualifies: storageAvailable ? seconds >= Double(log.settings(for: day, clock: clock)?.floor ?? settings.floor) : nil)
    }
}
