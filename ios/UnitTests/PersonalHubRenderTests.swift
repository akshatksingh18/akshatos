import XCTest
import SwiftUI
import SwiftData
@testable import AkshatOS

/// Native SwiftUI captures with synthetic, feature-owned records. These complement the UI tests;
/// they do not claim that Face ID or a physical device was exercised.
@MainActor final class PersonalHubRenderTests: XCTestCase {
    private func container(_ version: any VersionedSchema.Type) throws -> ModelContainer {
        let schema = Schema(versionedSchema: version)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }
    func testNativeTodayAndUnlockedJournalAtPhoneSizes() async throws {
        let suite = "native-render-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "journal.lock-enabled")
        let now = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let study = StudyLogStore(repository: SwiftDataStudyLogRepository(container: try container(StudyLogSchemaV1.self)), defaults: defaults, now: { now })
        study.load()
        XCTAssertTrue(study.saveSegment(StudySegment(start: now.addingTimeInterval(-5400), end: now.addingTimeInterval(-1800), source: .manual, dayTarget: 21600, topic: "Synthetic topic")))
        let todo = TodoStore(container: try container(TodoSchemaV1.self), now: { now }); todo.load()
        XCTAssertTrue(todo.add("Read one chapter")); XCTAssertTrue(todo.add("Review a practice problem"))
        for task in todo.visible { todo.choose(task.id, day: todo.today) }
        let routine = RoutineItem(title: "Read a chapter", period: .morning, targetMinute: 510)
        XCTAssertTrue(todo.saveRoutine(routine))
        XCTAssertTrue(todo.saveRoutine(RoutineItem(title: "Review the day", period: .evening)))
        todo.recordRoutine(routine.id, status: .done, day: todo.today)
        let journal = JournalStore(container: try container(JournalSchemaV1.self), defaults: defaults); journal.load()
        var entry = journal.newEntry(journal.today)
        entry.text = "A synthetic entry for visual testing. I kept the session small and returned after the break."
        entry.mood = 4; entry.energy = 3; XCTAssertTrue(journal.save(entry))
        let preferences = PersonalPreferences(defaults: defaults)
        let today = PersonalTodayView(study: study, todo: todo, journal: journal, preferences: preferences, orientation: OrientationGate(), studyActivity: StudyLiveActivityCoordinator(study: study, defaults: defaults, configured: false), keepGoing: {}, openTodo: {})
        await capture(NavigationStack { today }, name: "Native Today 390", size: CGSize(width: 390, height: 844))
        await capture(NavigationStack { today.environment(\.dynamicTypeSize, .accessibility3) }, name: "Native Today 320 accessibility", size: CGSize(width: 320, height: 568))
        await capture(NavigationStack { ScrollView { DailyRoutineSection(store: todo).padding(22) }.background(HubInk.background).navigationTitle("Today") }, name: "Native routine 390", size: CGSize(width: 390, height: 844))
        await capture(NavigationStack { ScrollView { DailyRoutineSection(store: todo).padding(22) }.background(HubInk.background).environment(\.dynamicTypeSize, .accessibility3).navigationTitle("Today") }, name: "Native routine 320 accessibility", size: CGSize(width: 320, height: 568))
        await capture(RoutineManager(store: todo), name: "Native routine manager 390", size: CGSize(width: 390, height: 844))
        let activity = StudyLiveActivityCoordinator(study: study, defaults: defaults, configured: false)
        let focus = StudyFocusView(study: study, todo: todo, orientation: OrientationGate(), activity: activity, close: {})
        await capture(focus, name: "Native Focus portrait 390", size: CGSize(width: 390, height: 844))
        await capture(focus.environment(\.verticalSizeClass, .compact), name: "Native Focus landscape 844", size: CGSize(width: 844, height: 390))
        await capture(focus.environment(\.dynamicTypeSize, .accessibility3).environment(\.verticalSizeClass, .compact), name: "Native Focus landscape accessibility", size: CGSize(width: 844, height: 390))
        let activityState = StudyActivityAttributes.ContentState(anchor: Date(), studiedAtAnchor: 5400, target: 21600, validUntil: Date().addingTimeInterval(3600))
        let card = StudyActivityCard(state: activityState, stale: false).frame(width: 358, height: 160).background(HubInk.background).ignoresSafeArea()
        let staleCard = StudyActivityCard(state: activityState, stale: true).frame(width: 358, height: 160).background(HubInk.background).ignoresSafeArea()
        await capture(card, name: "Native study lock-screen card", size: CGSize(width: 358, height: 160))
        await capture(staleCard, name: "Native study lock-screen stale", size: CGSize(width: 358, height: 160))
        await capture(card.environment(\.dynamicTypeSize, .accessibility3), name: "Native study lock-screen accessibility", size: CGSize(width: 358, height: 160))
        await capture(staleCard.environment(\.dynamicTypeSize, .accessibility3), name: "Native study lock-screen stale accessibility", size: CGSize(width: 358, height: 160))
        let facts = JournalDayFacts(activityDay: journal.today, capturedAt: now, studySeconds: 3600, studyBlocks: 1,
            completedTasks: 0, selectedPriorities: 2, completedPriorities: 0)
        await capture(NavigationStack { JournalView(store: journal, facts: { _ in facts }, planTomorrow: {}) }, name: "Native Journal unlocked 390", size: CGSize(width: 390, height: 844))
    }
    private func capture<V: View>(_ view: V, name: String, size: CGSize) async {
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        if let scene = previous?.windowScene { window.windowScene = scene }
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.preferredColorScheme(.dark).tint(HubInk.copper).environment(\.scenePhase, .active))
        window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds
        try? await Task.sleep(nanoseconds: 250_000_000)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: size).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true; previous?.makeKeyAndVisible()
    }
}
