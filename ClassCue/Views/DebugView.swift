//
//  DebugView.swift
//  ClassTrax
//
//  Created by Mike Tabbert on 3/10/26.
//


//
//  DebugView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassTrax Dev Build 23
//

import SwiftUI

struct DebugView: View {
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("notes_v1") private var savedNotes: String = ""
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = ""
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = ""
    @AppStorage("live_activities_enabled") private var liveActivitiesEnabled = true

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []
    @State private var notificationSnapshot: NotificationManager.DebugSnapshot?
    @State private var widgetSnapshot: ClassTraxWidgetSnapshot?
    @State private var liveActivityStatusMessage = ""
    @State private var liveActivityDebugState: LiveActivityManager.DebugState?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    debugOverviewCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Testing Readiness") {
                    LabeledContent("Notifications", value: notificationSnapshot?.authorizationStatus ?? "Loading…")
                    LabeledContent("Alerts", value: notificationSnapshot?.alertSetting ?? "Loading…")
                    LabeledContent("Sound", value: notificationSnapshot?.soundSetting ?? "Loading…")
                    LabeledContent("Badges", value: notificationSnapshot?.badgeSetting ?? "Loading…")
                    LabeledContent("Pending Requests", value: "\(notificationSnapshot?.pendingRequestCount ?? 0)")
                    LabeledContent("ClassTrax Pending", value: "\(notificationSnapshot?.classTraxPendingCount ?? 0)")
                    LabeledContent("Next Scheduled", value: notificationSnapshot?.nextClassTraxTrigger ?? "Loading…")
                    LabeledContent("Next Identifier", value: notificationSnapshot?.nextClassTraxIdentifier ?? "Loading…")
                    LabeledContent("Live Activities", value: liveActivitiesEnabled ? "Enabled" : "Disabled")
                    LabeledContent("Live Activity Status", value: liveActivityStatusMessage.isEmpty ? "Unknown" : liveActivityStatusMessage)
                    LabeledContent("Live Activity Active", value: liveActivityDebugState?.isActive == true ? "Yes" : "No")
                    LabeledContent("Live Activity Class", value: liveActivityDebugState?.className ?? "None")
                    LabeledContent("Live Activity End", value: liveActivityEndText)
                    LabeledContent("Live Activity Held", value: liveActivityDebugState?.isHeld == true ? "Yes" : "No")
                    LabeledContent("Live Activity Next", value: liveActivityDebugState?.nextClassName.isEmpty == false ? (liveActivityDebugState?.nextClassName ?? "None") : "None")
                    LabeledContent("Live Activity Refresh", value: liveActivityDebugUpdatedAtText)
                    LabeledContent("Widget Snapshot", value: widgetSnapshotStatusText)
                    LabeledContent("Last Snapshot Update", value: widgetSnapshotUpdatedAtText)
                    LabeledContent("Watch Sync Age", value: watchSyncAgeText)

                    Button("Refresh Debug Status") {
                        loadData()
                    }
                    .tint(ClassTraxSemanticColor.primaryAction)

                    Button("Refresh Live Activity") {
                        LiveActivityManager.refreshFromLastKnownState()
                        Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            await MainActor.run { loadData() }
                        }
                    }
                    .disabled(liveActivityDebugState == nil)
                    .tint(ClassTraxSemanticColor.secondaryAction)

                    Button("Restart Live Activity") {
                        LiveActivityManager.restartFromLastKnownState()
                        Task {
                            try? await Task.sleep(for: .milliseconds(700))
                            await MainActor.run { loadData() }
                        }
                    }
                    .disabled(liveActivityDebugState == nil)
                    .tint(ClassTraxSemanticColor.reviewWarning)
                }

                Section("App State") {
                    LabeledContent("Alarm Count", value: "\(alarms.count)")
                    LabeledContent("Todo Count", value: "\(todos.count)")
                    LabeledContent("Notes Length", value: "\(savedNotes.count)")
                    LabeledContent("Haptic", value: selectedHapticRawValue)
                    LabeledContent("Sound", value: selectedSoundRawValue)

                    if ignoreUntil > Date().timeIntervalSince1970 {
                        LabeledContent(
                            "Alert Snooze",
                            value: Date(timeIntervalSince1970: ignoreUntil)
                                .formatted(date: .abbreviated, time: .shortened)
                        )
                    } else {
                        LabeledContent("Alert Snooze", value: "Off")
                    }
                }

                Section("Loaded Schedule") {
                    if alarms.isEmpty {
                        Text("No alarms loaded.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(alarms.sorted { lhs, rhs in
                            if lhs.dayOfWeek == rhs.dayOfWeek {
                                return lhs.startTime < rhs.startTime
                            }
                            return lhs.dayOfWeek < rhs.dayOfWeek
                        }) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.className)
                                    .font(.headline)

                                Text("Day: \(item.dayOfWeek)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if !item.gradeLevel.isEmpty {
                                    Text("Grade: \(item.gradeLevel)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if !item.location.isEmpty {
                                    Text("Location: \(item.location)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("Type: \(String(describing: item.type))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Loaded To Do Items") {
                    if todos.isEmpty {
                        Text("No todos loaded.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(todos) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.task)
                                    .font(.headline)

                                Text("Completed: \(item.isCompleted ? "Yes" : "No")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Priority: \(item.priority.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let due = item.dueDate {
                                    Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Due: None")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Debug")
            .onAppear {
                loadData()
            }
        }
    }

    private var debugOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspect runtime state quickly.")
                .font(.headline.weight(.semibold))

            Text("This screen is for internal testing, notification checks, widget validation, and live activity troubleshooting while the app is in development.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                debugMetric(title: "Alarms", value: "\(alarms.count)", accent: ClassTraxSemanticColor.primaryAction)
                debugMetric(title: "Todos", value: "\(todos.count)", accent: ClassTraxSemanticColor.secondaryAction)
                debugMetric(title: "Live", value: liveActivityDebugState?.isActive == true ? "Active" : "Idle", accent: ClassTraxSemanticColor.reviewWarning)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func debugMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private func loadData() {
        if let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) {
            alarms = decodedAlarms
        } else {
            alarms = []
        }

        if let decodedTodos = try? JSONDecoder().decode([TodoItem].self, from: savedTodos) {
            todos = decodedTodos
        } else {
            todos = []
        }

        widgetSnapshot = WidgetSnapshotStore.load()
        liveActivityDebugState = LiveActivityManager.debugState()
        Task {
            notificationSnapshot = await NotificationManager.shared.debugSnapshot()
            liveActivityStatusMessage = LiveActivityManager.lastStatusMessage
            liveActivityDebugState = LiveActivityManager.debugState()
        }
    }

    private var widgetSnapshotStatusText: String {
        guard let widgetSnapshot else { return "No Snapshot" }
        if widgetSnapshot.isStale {
            return "Stale"
        }
        if widgetSnapshot.current != nil {
            return "Current Block"
        }
        if widgetSnapshot.next != nil {
            return "Next Block Only"
        }
        return "Day Wrapped"
    }

    private var widgetSnapshotUpdatedAtText: String {
        widgetSnapshot?.updatedAt.formatted(date: .abbreviated, time: .shortened) ?? "None"
    }

    private var watchSyncAgeText: String {
        guard let updatedAt = widgetSnapshot?.updatedAt else { return "Unknown" }
        let seconds = max(Int(Date().timeIntervalSince(updatedAt)), 0)
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }

    private var liveActivityEndText: String {
        liveActivityDebugState?.endTime.formatted(date: .omitted, time: .shortened) ?? "None"
    }

    private var liveActivityDebugUpdatedAtText: String {
        liveActivityDebugState?.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened) ?? "None"
    }
}
