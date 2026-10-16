import SwiftUI

/// One desk surface in either orientation. The store owns time; layout and sleep policy never do.
struct StudyFocusView: View {
    @ObservedObject var study: StudyLogStore
    @ObservedObject var todo: TodoStore
    let orientation: OrientationGate
    @ObservedObject var activity: StudyLiveActivityCoordinator
    var close: () -> Void
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSize
    @StateObject private var display = StudyDisplayController()
    @State private var visible = false
    @State private var keepAwake = false
    @State private var capture = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = verticalSize == .compact && geometry.size.width >= 560 && !typeSize.isAccessibilitySize
                ScrollView {
                    TimelineView(.periodic(from: .now, by: phase == .active ? 1 : 60)) { context in
                        let date = study.isRunning ? context.date : study.currentDate()
                        Group {
                            if !study.storageAvailable {
                                ContentUnavailableView { Label("Study data unavailable", systemImage: "exclamationmark.triangle") }
                                actions: { Button("Retry") { study.load() }.frame(minHeight: 44) }
                            } else if wide {
                                HStack(alignment: .top, spacing: 32) {
                                    dial(at: date).frame(width: min(280, max(180, (geometry.size.height - 112) * 1.12)))
                                    controls(at: date).frame(maxWidth: 360)
                                }.frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .contain)
                                    .accessibilityIdentifier("study-focus-landscape")
                            } else {
                                VStack(spacing: 24) {
                                    if typeSize.isAccessibilitySize { timerControl }
                                    dial(at: date)
                                    controls(at: date, includeTimer: !typeSize.isAccessibilitySize)
                                }.frame(maxWidth: 440).frame(maxWidth: .infinity)
                                    .accessibilityElement(children: .contain)
                                    .accessibilityIdentifier("study-focus-portrait")
                            }
                        }.padding(.horizontal, 22).padding(.vertical, 16)
                    }
                }
            }
            .background(HubInk.background)
            .navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close", action: close).frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("study-focus-close") } }
        }
        .tint(HubInk.copper)
        .onAppear { visible = true; orientation.setStudyFocusSession(true); updateDisplay() }
        .onDisappear { visible = false; display.release(); orientation.setStudyFocusSession(false) }
        .onChange(of: phase) { _, _ in updateDisplay(); if phase == .active { activity.reconcile() } }
        .onChange(of: study.isRunning) { _, _ in updateDisplay() }
        .onChange(of: study.storageAvailable) { _, _ in updateDisplay() }
        .onChange(of: keepAwake) { _, _ in updateDisplay() }
        .sheet(isPresented: $capture) {
            NavigationStack {
                Form { ThoughtCaptureField { todo.park($0) } }.personalList().navigationTitle("After study")
                    .toolbar { Button("Done") { capture = false } }
                    .personalMessage("To-do", message: $todo.message)
            }
        }
        .personalMessage("Study", message: $study.message)
    }

    private func dial(at date: Date) -> some View {
        VStack(spacing: 12) {
            Label(study.isRunning ? "Studying" : "Paused", systemImage: study.isRunning ? "circle.fill" : "pause.circle")
                .font(.subheadline).foregroundStyle(HubInk.sage)
            StudyDial(studied: study.studiedToday(at: date), target: study.targetToday(at: date))
            Text("\(StudyTimeDisplay.short(study.studiedToday(at: date))) studied today")
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                .accessibilityIdentifier("study-focus-studied")
        }
    }

    private func controls(at date: Date, includeTimer: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !study.selectedTopic.isEmpty { Text(study.selectedTopic).font(.headline).fixedSize(horizontal: false, vertical: true) }
            if let block = study.currentBlock(at: date) {
                Text("Current block · \(StudyTimeDisplay.short(block))").font(.subheadline).monospacedDigit()
                    .accessibilityIdentifier("study-focus-block")
            } else if let end = study.lastPause {
                Text("Break · \(StudyTimeDisplay.short(max(0, date.timeIntervalSince(end))))").font(.subheadline).monospacedDigit()
            }
            if includeTimer { timerControl }
            if study.canUndoEdit { Button("Undo last change") { study.undoEdit() }.frame(minHeight: 44) }
            Toggle("Keep screen awake", isOn: $keepAwake)
                .frame(minHeight: 44).accessibilityIdentifier("study-keep-awake")
            Text("While studying in Focus. Uses more battery.")
                .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if activity.configured {
                DisclosureGroup {
                    Toggle("Show study timer", isOn: $activity.enabled).frame(minHeight: 44)
                    Text(activity.status).font(.footnote).foregroundStyle(.secondary)
                    if activity.enabled && study.isRunning { Button("Show again") { activity.showAgain() }.frame(minHeight: 44) }
                } label: {
                    Text("Lock-screen timer").frame(minHeight: 44)
                }
            }
            Button { capture = true } label: { Label("Park a thought", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44) }
                .buttonStyle(.bordered).accessibilityIdentifier("study-focus-thought")
        }
    }

    private var timerControl: some View {
        Button { study.toggle() } label: {
            Label(study.isRunning ? "Pause studying" : study.studiedToday(at: study.currentDate()) > 0 ? "Resume studying" : "Start studying", systemImage: study.isRunning ? "pause.fill" : "play.fill")
                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.borderedProminent).tint(HubInk.copper).foregroundStyle(HubInk.background)
            .accessibilityIdentifier("study-focus-toggle")
    }

    private func updateDisplay() {
        display.update(visible: visible, active: phase == .active, running: study.isRunning && study.storageAvailable, enabled: keepAwake)
    }
}
