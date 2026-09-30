import Foundation
import SwiftUI

/// Daily weight, weekly tape measurements and progress photos. Every change is saved before the
/// screen shows it.
@MainActor final class BodyLogStore: ObservableObject {
    @Published private(set) var snapshot = BodyLogSnapshot()
    @Published private(set) var storageAvailable = false
    @Published private(set) var reminderEnabled: Bool
    @Published var message: String?
    /// Your height in inches, entered once in settings. It stays on the phone; the body-fat
    /// estimate needs it and is not shown until it is set.
    @Published var heightInches: Double? {
        didSet { defaults.set(heightInches ?? 0, forKey: Keys.height) }
    }
    /// The weekday you measure, Calendar's 1 (Sunday) … 7 (Saturday). Weekly weight blocks start
    /// on it too, so a week's average and its measurements line up.
    @Published var measurementWeekday: Int {
        didSet {
            defaults.set(measurementWeekday, forKey: Keys.weekday)
            if reminderEnabled { Task { await setReminder(enabled: true) } }
        }
    }
    @Published var reminderHour: Int {
        didSet {
            defaults.set(reminderHour, forKey: Keys.hour)
            if reminderEnabled { Task { await setReminder(enabled: true) } }
        }
    }

    private enum Keys {
        static let height = "body.heightInches"
        static let weekday = "body.measurementWeekday"
        static let hour = "body.reminderHour"
        static let reminder = "body.reminderEnabled"
    }

    private let repository: any BodyLogRepository
    private let photos: BodyPhotoStorage?
    private let reminders: any BodyReminding
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(repository: (any BodyLogRepository)? = nil, photos: BodyPhotoStorage? = nil,
         reminders: (any BodyReminding)? = nil, defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.repository = repository ?? SwiftDataBodyLogRepository()
        self.photos = photos ?? (try? BodyPhotoStorage())
        self.reminders = reminders ?? BodyReminderService()
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        let height = defaults.double(forKey: Keys.height)
        self.heightInches = height > 0 ? height : nil
        let weekday = defaults.integer(forKey: Keys.weekday)
        self.measurementWeekday = (1...7).contains(weekday) ? weekday : 7
        let hour = defaults.object(forKey: Keys.hour) as? Int
        self.reminderHour = hour.map { min(23, max(0, $0)) } ?? 8
        self.reminderEnabled = defaults.bool(forKey: Keys.reminder)
    }

    // MARK: - Reading

    var weights: [BodyWeightEntry] { snapshot.weights }
    var measurements: [BodyMeasurement] { snapshot.measurements }
    var photoRecords: [BodyPhoto] { snapshot.photos }

    var today: String { BodyLog.dayKey(now(), calendar: calendar) }
    var todayWeight: BodyWeightEntry? { snapshot.weights.first { $0.day == today } }
    var rollingAverage: Double? { BodyLog.rollingAverage(snapshot.weights, endingOn: today, calendar: calendar) }
    var weeks: [BodyWeek] {
        BodyLog.weeklyAverages(snapshot.weights, weekday: measurementWeekday, calendar: calendar)
    }

    /// This week's block average and its change from the previous block, when both exist.
    var weekChange: (average: Double, change: Double?)? {
        guard let start = BodyLog.weekStart(for: today, weekday: measurementWeekday, calendar: calendar),
              let current = weeks.first(where: { $0.start == start }) else { return nil }
        let previous = BodyLog.adding(days: -7, to: start, calendar: calendar)
            .flatMap { previousStart in weeks.first { $0.start == previousStart } }
        return (current.average, previous.map { current.average - $0.average })
    }

    var latestMeasurement: BodyMeasurement? { snapshot.measurements.first }

    /// The session inside the current weekly block, if you have measured this week.
    var thisWeekMeasurement: BodyMeasurement? {
        guard let start = BodyLog.weekStart(for: today, weekday: measurementWeekday, calendar: calendar)
        else { return nil }
        return snapshot.measurements.first { $0.day >= start && $0.day <= today }
    }

    func change(for site: BodySite, in measurement: BodyMeasurement) -> Double? {
        BodyLog.change(for: site, in: measurement, history: snapshot.measurements)
    }

    /// From the latest session that has both waist and neck. Labelled an estimate wherever shown.
    var bodyFatEstimate: Double? {
        guard let height = heightInches,
              let session = snapshot.measurements.first(where: { $0.value(.waistNavel) != nil && $0.value(.neck) != nil }),
              let waist = session.value(.waistNavel), let neck = session.value(.neck) else { return nil }
        return BodyLog.navyBodyFat(waist: waist, neck: neck, height: height)
    }

    var waistToHeight: Double? {
        guard let height = heightInches,
              let waist = snapshot.measurements.first(where: { $0.value(.waistNavel) != nil })?.value(.waistNavel)
        else { return nil }
        return BodyLog.waistToHeight(waist: waist, height: height)
    }

    var photosDue: Bool { BodyLog.photosDue(snapshot.photos, today: today, calendar: calendar) }

    func photoURL(_ photo: BodyPhoto) -> URL? { photos?.url(for: photo) }

    // MARK: - Loading

    func load() {
        do {
            snapshot = try repository.load()
            storageAvailable = photos != nil
            if photos == nil { message = "Photo storage is unavailable." }
        } catch {
            storageAvailable = false
            message = "Your body measurements could not be read: \(error.localizedDescription)"
        }
    }

    // MARK: - Weight

    /// Logs today's weigh-in, replacing an earlier one from today.
    func logWeight(_ pounds: Double) {
        guard storageAvailable else { message = "Body storage is unavailable."; return }
        do {
            let value = try BodyLog.validatedWeight(pounds)
            var entry = todayWeight ?? BodyWeightEntry(day: today, pounds: value, recordedAt: now())
            entry.pounds = value
            entry.recordedAt = now()
            try repository.save(entry)
            snapshot.weights.removeAll { $0.id == entry.id }
            snapshot.weights.append(entry)
            snapshot.weights.sort { $0.day > $1.day }
        } catch {
            message = error.localizedDescription
        }
    }

    func deleteWeight(_ entry: BodyWeightEntry) {
        do {
            try repository.delete(id: entry.id)
            snapshot.weights.removeAll { $0.id == entry.id }
        } catch {
            message = "That weigh-in could not be deleted: \(error.localizedDescription)"
        }
    }

    // MARK: - Measurements

    /// Saves a session. Passing `editing` updates it in place; otherwise a new session is dated today.
    @discardableResult
    func saveMeasurement(_ values: [BodySite: Double], editing: BodyMeasurement? = nil) -> Bool {
        guard storageAvailable else { message = "Body storage is unavailable."; return false }
        do {
            let inches = try BodyLog.validatedInches(values)
            var session = editing ?? BodyMeasurement(day: today, recordedAt: now(), inches: [:])
            // Keep any site a newer build recorded that this one does not know about.
            let unknown = session.inches.filter { BodySite(rawValue: $0.key) == nil }
            session.inches = inches.merging(unknown) { current, _ in current }
            try repository.save(session)
            snapshot.measurements.removeAll { $0.id == session.id }
            snapshot.measurements.append(session)
            snapshot.measurements.sort { ($0.day, $0.recordedAt) > ($1.day, $1.recordedAt) }
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func deleteMeasurement(_ measurement: BodyMeasurement) {
        do {
            try repository.delete(id: measurement.id)
            snapshot.measurements.removeAll { $0.id == measurement.id }
        } catch {
            message = "That measurement could not be deleted: \(error.localizedDescription)"
        }
    }

    // MARK: - Photos

    func addPhoto(_ imageData: Data, pose: BodyPhotoPose) async {
        guard storageAvailable, let photos else { message = "Photo storage is unavailable."; return }
        let jpeg = await Task.detached(priority: .userInitiated) { BodyPhotoStorage.jpeg(from: imageData) }.value
        guard let jpeg else { message = "That image could not be read."; return }
        let photo = BodyPhoto(day: today, pose: pose, recordedAt: now())
        do {
            try photos.write(jpeg, for: photo)
            do {
                try repository.save(photo)
            } catch {
                photos.remove(photo)
                throw error
            }
            snapshot.photos.insert(photo, at: 0)
            snapshot.photos.sort { ($0.day, $0.recordedAt) > ($1.day, $1.recordedAt) }
        } catch {
            message = "The photo could not be saved: \(error.localizedDescription)"
        }
    }

    func deletePhoto(_ photo: BodyPhoto) {
        do {
            try repository.delete(id: photo.id)
            photos?.remove(photo)
            snapshot.photos.removeAll { $0.id == photo.id }
        } catch {
            message = "That photo could not be deleted: \(error.localizedDescription)"
        }
    }

    // MARK: - Reminder

    func setReminder(enabled: Bool) async {
        if enabled {
            do {
                let allowed = try await reminders.enable(weekday: measurementWeekday, hour: reminderHour, minute: 0)
                reminderEnabled = allowed
                if !allowed {
                    message = "Notifications are off for AkshatOS. Turn them on in iOS Settings to get the weekly reminder."
                }
            } catch {
                reminderEnabled = false
                message = "The reminder could not be scheduled: \(error.localizedDescription)"
            }
        } else {
            reminders.disable()
            reminderEnabled = false
        }
        defaults.set(reminderEnabled, forKey: Keys.reminder)
    }

    // MARK: - Export and restore

    func csvData() -> Data { Data(BodyLog.csv(snapshot).utf8) }

    /// Stages a folder holding `body-log.json` and every photo, for the system file mover.
    func stageBackup() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("BodyLogExport-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("AkshatOS Body \(today)", isDirectory: true)
        let photoFolder = folder.appendingPathComponent(BodyLogBackup.photosFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: photoFolder, withIntermediateDirectories: true)
        var exported = snapshot
        if let photos {
            exported.photos = snapshot.photos.filter { photo in
                (try? FileManager.default.copyItem(at: photos.url(for: photo),
                                                   to: photoFolder.appendingPathComponent(photo.fileName))) != nil
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(BodyLogBackup(exportedAt: now(), snapshot: exported))
            .write(to: folder.appendingPathComponent(BodyLogBackup.manifestName), options: .atomic)
        return folder
    }

    /// Replaces everything with a backup folder (or a lone manifest, which restores no photos).
    /// The whole backup and every photo file are checked and staged before anything changes.
    func restore(from source: URL) {
        guard let photos else { message = "Photo storage is unavailable."; return }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        var staging: URL?
        do {
            let isFolder = (try? source.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            let manifest = isFolder ? source.appendingPathComponent(BodyLogBackup.manifestName) : source
            let backup = try JSONDecoder().decode(BodyLogBackup.self, from: Data(contentsOf: manifest))
                .validated(calendar: calendar)
            let stage = try photos.makeStaging()
            staging = stage
            var restored = backup.snapshot
            restored.photos = backup.photos.filter { photo in
                guard isFolder else { return false }
                let file = source.appendingPathComponent(BodyLogBackup.photosFolder)
                    .appendingPathComponent(photo.fileName)
                return (try? FileManager.default.copyItem(at: file, to: stage.appendingPathComponent(photo.fileName))) != nil
            }
            let previous = try photos.swapIn(stage)
            staging = nil
            do {
                try repository.replaceAll(with: restored)
            } catch {
                photos.rollBack(previous)
                throw error
            }
            photos.discard(previous)
            load()
            let skipped = backup.photos.count - restored.photos.count
            message = skipped > 0
                ? "Restored. \(skipped) photo\(skipped == 1 ? " was" : "s were") missing from the backup and skipped."
                : "Restored."
        } catch let error as DecodingError {
            message = "That file is not an AkshatOS body backup: \(error.localizedDescription)"
        } catch {
            message = "Nothing was restored: \(error.localizedDescription)"
        }
        if let staging { try? FileManager.default.removeItem(at: staging) }
    }
}
