import ActivityKit
import SwiftUI
import WidgetKit

@main struct StudyActivityWidgets: WidgetBundle {
    var body: some Widget { StudyActivityWidget() }
}

struct StudyActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            StudyActivityCard(state: context.state, stale: context.isStale)
                .activityBackgroundTint(Color(red: 0.098, green: 0.106, blue: 0.102))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "akshatos://study"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Study", systemImage: "book") }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale { Text("Open app") }
                    else { Text(timerInterval: context.state.elapsedRange, countsDown: false, showsHours: true).monospacedDigit() }
                }
                DynamicIslandExpandedRegion(.bottom) { Text(context.isStale ? "Open AkshatOS to refresh" : "Studied today · tap to open timer").font(.caption) }
            } compactLeading: {
                Image(systemName: "book")
            } compactTrailing: {
                if context.isStale { Image(systemName: "arrow.clockwise") }
                else { Text(timerInterval: context.state.elapsedRange, countsDown: false, showsHours: true).monospacedDigit().frame(maxWidth: 80) }
            } minimal: { Image(systemName: "book") }
            .widgetURL(URL(string: "akshatos://study"))
        }
    }
}

