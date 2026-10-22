import AppIntents

struct StartStudyIntent: AppIntent {
    static var title: LocalizedStringResource = "Start studying"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        let services = AppServices.shared
        services.studyLog.load()
        guard services.studyLog.storageAvailable else { throw PersonalDataError.invalid("Study data is unavailable. Open AkshatOS and retry.") }
        services.studyLog.start()
        guard services.studyLog.isRunning else { throw PersonalDataError.invalid(services.studyLog.message ?? "Study could not start.") }
        services.navigator.request(.studyLog)
        return .result()
    }
}
struct PauseStudyIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause studying"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        let services = AppServices.shared
        services.studyLog.load()
        guard services.studyLog.storageAvailable else { throw PersonalDataError.invalid("Study data is unavailable.") }
        services.studyLog.pause()
        guard !services.studyLog.isRunning else { throw PersonalDataError.invalid(services.studyLog.message ?? "Study could not pause.") }
        services.navigator.request(.studyLog)
        return .result()
    }
}
struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a task"
    static var openAppWhenRun = true
    @Parameter(title: "Task") var text: String
    @MainActor func perform() async throws -> some IntentResult {
        let services = AppServices.shared
        services.todo.load()
        guard services.todo.add(text) else { throw PersonalDataError.invalid(services.todo.message ?? "Enter a task to save.") }
        services.navigator.request(.todo)
        return .result()
    }
}
struct ParkThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "Park a thought"
    static var openAppWhenRun = true
    @Parameter(title: "Thought") var text: String
    @MainActor func perform() async throws -> some IntentResult {
        let services = AppServices.shared
        services.todo.load()
        guard services.todo.park(text) else { throw PersonalDataError.invalid(services.todo.message ?? "Enter a thought to save.") }
        services.navigator.request(.todo)
        return .result()
    }
}
struct OpenJournalIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Journal"
    static var openAppWhenRun = true
    static var isDiscoverable = false
    @MainActor func perform() async throws -> some IntentResult {
        // Keep the identifier for already-saved Shortcuts, without exposing a retired screen.
        throw PersonalDataError.invalid("Journal has been removed from AkshatOS.")
        return .result()
    }
}
struct StudyTimeTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Study time today"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        let store = AppServices.shared.studyLog; store.load()
        guard store.storageAvailable else { throw PersonalDataError.invalid("Study data is unavailable.") }
        return .result(value: store.studiedToday(at: Date()) / 60)
    }
}
struct PersonalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartStudyIntent(), phrases: ["Start studying with \(.applicationName)"], shortTitle: "Start studying", systemImageName: "play.fill")
        AppShortcut(intent: PauseStudyIntent(), phrases: ["Pause studying with \(.applicationName)"], shortTitle: "Pause studying", systemImageName: "pause.fill")
        AppShortcut(intent: AddTodoIntent(), phrases: ["Add a task in \(.applicationName)"], shortTitle: "Add a task", systemImageName: "checkmark.circle")
        AppShortcut(intent: ParkThoughtIntent(), phrases: ["Park a thought in \(.applicationName)"], shortTitle: "Park a thought", systemImageName: "tray")
        AppShortcut(intent: StudyTimeTodayIntent(), phrases: ["Study time today in \(.applicationName)"], shortTitle: "Study minutes today", systemImageName: "timer")
    }
}
