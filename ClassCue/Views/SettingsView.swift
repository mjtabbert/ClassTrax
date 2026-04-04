//
//  SettingsView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import SwiftUI
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif
import SwiftData

struct SettingsView: View {
    private enum SettingsDestination: String, Identifiable, CaseIterable {
        case alerts = "Alerts"
        case boundaries = "After Hours"
        case todayLayout = "Today Layout"
        case classroomSetup = "Classroom Setup"
        case subPlans = "Sub Plans"
        case integrations = "Integrations"
        case cloudSync = "Cloud Sync"
        case liveActivities = "Live Activities"
        case data = "Data Management"
        case diagnostics = "Diagnostics"
        case about = "About"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .alerts:
                return "bell.badge"
            case .boundaries:
                return "moon.zzz"
            case .todayLayout:
                return "rectangle.grid.1x2"
            case .classroomSetup:
                return "books.vertical"
            case .subPlans:
                return "doc.text"
            case .integrations:
                return "square.stack.3d.up"
            case .cloudSync:
                return "icloud"
            case .liveActivities:
                return "rectangle.and.text.magnifyingglass"
            case .data:
                return "tray.and.arrow.down"
            case .diagnostics:
                return "wrench.and.screwdriver"
            case .about:
                return "info.circle"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = HapticPattern.doubleThump.rawValue
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = SoundPattern.classicAlarm.rawValue
    @AppStorage("pref_warning_sound_5min") private var warningFiveSoundRawValue: String = SoundPattern.softChime.rawValue
    @AppStorage("pref_warning_sound_2min") private var warningTwoSoundRawValue: String = SoundPattern.systemGlass.rawValue
    @AppStorage("pref_warning_sound_1min") private var warningOneSoundRawValue: String = SoundPattern.sharpBell.rawValue
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("commitments_v1_data") private var savedCommitments: Data = Data()
    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("student_support_profiles_v1_data") private var savedStudentProfiles: Data = Data()
    @AppStorage("class_definitions_v1_data") private var savedClassDefinitions: Data = Data()
    @AppStorage("cloud_sync_last_local_mutation_at") private var lastLocalMutationTimestamp: Double = 0
    @AppStorage("cloud_sync_last_refresh_at") private var lastCloudRefreshTimestamp: Double = 0
    @AppStorage("cloudkit_last_event_summary_v1") private var lastCloudKitEventSummary: String = "No CloudKit sync events observed yet."
    @AppStorage("cloudkit_last_event_timestamp_v1") private var lastCloudKitEventTimestamp: Double = 0
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0
    @AppStorage("school_show_end_of_day_wrap_up") private var showEndOfDayWrapUp = true
    @AppStorage("school_offer_task_carryover") private var offerTaskCarryover = true
    @AppStorage("school_hide_dashboard_after_hours") private var hideSchoolDashboardAfterHours = true
    @AppStorage("school_show_personal_focus_card") private var showPersonalFocusCard = true
    @AppStorage("school_default_personal_capture_after_hours") private var defaultPersonalCaptureAfterHours = true
    @AppStorage("live_activities_enabled") private var liveActivitiesEnabledPreference = true
    @AppStorage("today_dashboard_card_order_v1") private var storedDashboardCardOrder = ""
    @AppStorage("today_dashboard_hidden_cards_v1") private var storedHiddenDashboardCards = ""

    @State private var holidayModeEnabled = false
    @State private var holidayResumeDate = Date().addingTimeInterval(60 * 60 * 24)
    @State private var schoolQuietStart = Calendar.current.date(
        bySettingHour: 16,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []
    @State private var profiles: [ScheduleProfile] = []
    @State private var overrides: [DayOverride] = []
    @Binding private var studentProfiles: [StudentSupportProfile]
    @Binding private var classDefinitions: [ClassDefinitionItem]
    @Binding private var teacherContacts: [ClassStaffContact]
    @Binding private var paraContacts: [ClassStaffContact]
    @State private var commitments: [CommitmentItem] = []
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var dashboardCardOrder = TodayView.TodayDashboardCard.defaultOrder
    @State private var hiddenDashboardCards = Set<TodayView.TodayDashboardCard>()
    @State private var isLoadingInitialState = false
    @State private var hasLoadedInitialState = false

    init(
        studentProfiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>
    ) {
        _studentProfiles = studentProfiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
    }

    var body: some View {
        settingsContent
    }

    private var settingsListContent: some View {
        List {
            Section {
                settingsOverviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("Daily Use") {
                NavigationLink {
                    settingsDestinationView(.alerts)
                        .onChange(of: selectedSoundRawValue) { _, _ in refreshNotifications() }
                        .onChange(of: warningFiveSoundRawValue) { _, _ in refreshNotifications() }
                        .onChange(of: warningTwoSoundRawValue) { _, _ in refreshNotifications() }
                        .onChange(of: warningOneSoundRawValue) { _, _ in refreshNotifications() }
                } label: {
                    settingsRowLabel(.alerts, detail: "Bell sounds, warning cues, and haptics")
                }

                NavigationLink {
                    settingsDestinationView(.boundaries)
                        .onChange(of: schoolQuietHoursEnabled) { _, _ in
                            syncSchoolQuietStart()
                            refreshNotifications()
                        }
                        .onChange(of: schoolQuietStart) { _, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            schoolQuietHour = components.hour ?? 16
                            schoolQuietMinute = components.minute ?? 0
                            refreshNotifications()
                        }
                } label: {
                    settingsRowLabel(.boundaries, detail: "Quiet hours and after-school behavior")
                }

                NavigationLink {
                    settingsDestinationView(.todayLayout)
                        .onChange(of: dashboardCardOrder) { _, _ in
                            persistTodayLayoutSettings()
                        }
                        .onChange(of: hiddenDashboardCards) { _, _ in
                            persistTodayLayoutSettings()
                        }
                } label: {
                    settingsRowLabel(.todayLayout, detail: "Choose what appears on the Today dashboard")
                }

                NavigationLink {
                    settingsDestinationView(.classroomSetup)
                } label: {
                    settingsRowLabel(.classroomSetup, detail: "Saved classes, roster tools, and staff setup")
                }

                NavigationLink {
                    settingsDestinationView(.subPlans)
                } label: {
                    settingsRowLabel(.subPlans, detail: "Reusable sub plans and daily prep")
                }

                NavigationLink {
                    settingsDestinationView(.data)
                } label: {
                    settingsRowLabel(.data, detail: "Import, export, and local data utilities")
                }

                NavigationLink {
                    settingsDestinationView(.liveActivities)
                } label: {
                    settingsRowLabel(.liveActivities, detail: "Live Activity and lock screen controls")
                }

                NavigationLink {
                    settingsDestinationView(.cloudSync)
                } label: {
                    settingsRowLabel(.cloudSync, detail: "CloudKit status and sync diagnostics")
                }

                NavigationLink {
                    settingsDestinationView(.integrations)
                } label: {
                    settingsRowLabel(.integrations, detail: "Widgets, watch, and related integrations")
                }

                NavigationLink {
                    settingsDestinationView(.diagnostics)
                } label: {
                    settingsRowLabel(.diagnostics, detail: "Debug details, logs, and troubleshooting")
                }

                NavigationLink {
                    settingsDestinationView(.about)
                } label: {
                    settingsRowLabel(.about, detail: "App details and version information")
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .onAppear {
            ignoreUntil = ScheduleSnoozeStore.synchronize()
            loadTodayLayoutSettings()
            configureHolidayMode()
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
    }

    private var settingsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.headline.weight(.semibold))

                Text("System preferences, sync controls, and classroom setup tools live here now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                settingsMetric(title: "Classes", value: "\(classDefinitions.count)", accent: .blue)
                settingsMetric(title: "Students", value: "\(studentProfiles.count)", accent: .green)
                settingsMetric(title: "Tasks", value: "\(todos.count)", accent: .orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.08),
                            Color(.secondarySystemGroupedBackground).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    @ViewBuilder
    private func settingsMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    @ViewBuilder
    private func settingsRowLabel(_ destination: SettingsDestination, detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: destination.systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private var settingsContent: some View {
        settingsListContent
            .onChange(of: alarms) { _, newValue in
                guard !isLoadingInitialState else { return }
                saveAlarms(newValue)
            }
            .onChange(of: profiles) { _, newValue in
                guard !isLoadingInitialState else { return }
                saveProfiles(newValue)
            }
            .onChange(of: overrides) { _, newValue in
                guard !isLoadingInitialState else { return }
                saveOverrides(newValue)
            }
            .onChange(of: studentProfiles) { _, newValue in
                guard !isLoadingInitialState else { return }
                ClassTraxPersistence.saveFirstSlice(
                    alarms: alarms,
                    studentProfiles: newValue,
                    classDefinitions: classDefinitions,
                    teacherContacts: teacherContacts,
                    paraContacts: paraContacts,
                    commitments: commitments,
                    into: modelContext
                )
                savedStudentProfiles = (try? JSONEncoder().encode(newValue.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })) ?? Data()
            }
            .onChange(of: classDefinitions) { _, newValue in
                guard !isLoadingInitialState else { return }
                ClassTraxPersistence.saveFirstSlice(
                    alarms: alarms,
                    studentProfiles: studentProfiles,
                    classDefinitions: newValue,
                    teacherContacts: teacherContacts,
                    paraContacts: paraContacts,
                    commitments: commitments,
                    into: modelContext
                )
                savedClassDefinitions = (try? JSONEncoder().encode(newValue.sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                })) ?? Data()
            }
            .onChange(of: teacherContacts) { _, newValue in
                guard !isLoadingInitialState else { return }
                ClassTraxPersistence.saveFirstSlice(
                    alarms: alarms,
                    studentProfiles: studentProfiles,
                    classDefinitions: classDefinitions,
                    teacherContacts: newValue,
                    paraContacts: paraContacts,
                    commitments: commitments,
                    into: modelContext
                )
            }
            .onChange(of: paraContacts) { _, newValue in
                guard !isLoadingInitialState else { return }
                ClassTraxPersistence.saveFirstSlice(
                    alarms: alarms,
                    studentProfiles: studentProfiles,
                    classDefinitions: classDefinitions,
                    teacherContacts: teacherContacts,
                    paraContacts: newValue,
                    commitments: commitments,
                    into: modelContext
                )
            }
    }

    private var settingsList: some View {
        List {
            controlCenterSection
            dailyUseSection
            systemSection
        }
        .listStyle(.insetGrouped)
    }

    private var controlCenterSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("ClassTrax Control Center")
                    .font(.headline.weight(.bold))

                Text("Manage alerts, classroom setup, substitute planning, sync, and diagnostics from one place.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    settingsSummaryPill(
                        title: "Classes",
                        value: hasLoadedInitialState ? "\(classDefinitions.count)" : "Open",
                        accent: .blue
                    )
                    settingsSummaryPill(
                        title: "Students",
                        value: hasLoadedInitialState ? "\(studentProfiles.count)" : "Open",
                        accent: .green
                    )
                    settingsSummaryPill(
                        title: "Alerts",
                        value: ignoreUntil > Date().timeIntervalSince1970 ? "Snoozed" : "Live",
                        accent: ignoreUntil > Date().timeIntervalSince1970 ? .orange : .indigo
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(controlCenterCardBackground)
            .overlay(controlCenterCardBorder)
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var dailyUseSection: some View {
        Section("Daily Use") {
            settingsLink(.alerts, detail: "Bell sounds, haptics, and snooze")
            settingsLink(.boundaries, detail: "After-hours behavior and focus")
            settingsLink(.todayLayout, detail: "\(visibleTodayCardCount) cards visible")
            settingsLink(.classroomSetup, detail: "Classes, students, profiles, and overrides")
            settingsLink(.subPlans, detail: "Profiles and substitute prep")
        }
    }

    private var systemSection: some View {
        Section("System") {
            settingsLink(.integrations, detail: "Calendar and reminders")
            settingsLink(.cloudSync, detail: ClassTraxPersistence.activeContainerMode.rawValue)
            settingsLink(.liveActivities, detail: liveActivitiesEnabledPreference ? "Enabled" : "Disabled")
            settingsLink(.data, detail: "Import and export schedule CSV")
            settingsLink(.diagnostics, detail: "Launch readiness and debug")
            settingsLink(.about, detail: "App info")
        }
    }

    @ViewBuilder
    private func settingsLink(_ destination: SettingsDestination, detail: String) -> some View {
        NavigationLink {
            settingsDestinationView(destination)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                settingsLinkIcon(destination)

                VStack(alignment: .leading, spacing: 4) {
                    Text(destination.rawValue)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(sectionStatusLabel(for: destination))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(sectionStatusColor(for: destination))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(sectionStatusColor(for: destination).opacity(0.12))
                        )

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func settingsSummaryPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
    }

    private func settingsLinkIcon(_ destination: SettingsDestination) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(sectionStatusColor(for: destination).opacity(0.12))
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: destination.systemImage)
                    .font(.headline)
                    .foregroundStyle(sectionStatusColor(for: destination))
            }
    }

    private var controlCenterCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.14),
                        Color.orange.opacity(0.08),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var controlCenterCardBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
    }

    private func sectionStatusLabel(for destination: SettingsDestination) -> String {
        switch destination {
        case .alerts:
            return ignoreUntil > Date().timeIntervalSince1970 ? "Snoozed" : "Ready"
        case .boundaries:
            return schoolQuietHoursEnabled ? "On" : "Off"
        case .todayLayout:
            return "\(visibleTodayCardCount)"
        case .classroomSetup:
            return "\(classDefinitions.count)"
        case .subPlans:
            return "Profile"
        case .integrations:
            return "Tools"
        case .cloudSync:
            return ClassTraxPersistence.activeContainerMode == .cloudKit ? "Cloud" : "Local"
        case .liveActivities:
            return liveActivitiesEnabledPreference ? "On" : "Off"
        case .data:
            return "CSV"
        case .diagnostics:
            return "Inspect"
        case .about:
            return "Info"
        }
    }

    private func sectionStatusColor(for destination: SettingsDestination) -> Color {
        switch destination {
        case .alerts:
            return ignoreUntil > Date().timeIntervalSince1970 ? .orange : .indigo
        case .boundaries:
            return schoolQuietHoursEnabled ? .blue : .gray
        case .todayLayout:
            return .teal
        case .classroomSetup:
            return .green
        case .subPlans:
            return .brown
        case .integrations:
            return .pink
        case .cloudSync:
            return ClassTraxPersistence.activeContainerMode == .cloudKit ? .green : .orange
        case .liveActivities:
            return liveActivitiesEnabledPreference ? .mint : .gray
        case .data:
            return .cyan
        case .diagnostics:
            return .red
        case .about:
            return .blue
        }
    }

    @ViewBuilder
    private func settingsDestinationView(_ destination: SettingsDestination) -> some View {
        if destination == .todayLayout {
            TodayLayoutCustomizationView(
                cards: $dashboardCardOrder,
                hiddenCards: $hiddenDashboardCards
            )
            .navigationTitle(destination.rawValue)
            .scrollContentBackground(.hidden)
            .background(settingsBackground)
        } else {
        Form {
            Section {
                Text(destinationDescription(destination))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            switch destination {
            case .alerts:
                alertsSection
            case .boundaries:
                schoolBoundariesSection
                holidaySection
            case .todayLayout:
                EmptyView()
            case .classroomSetup:
                workspaceSetupSection
            case .subPlans:
                scheduleToolsSection
            case .integrations:
                integrationsSection
            case .cloudSync:
                cloudSyncStatusSection
            case .liveActivities:
                liveActivityStatusSection
            case .data:
                dataManagementSection
            case .diagnostics:
                appToolsSection
            case .about:
                aboutSection
            }
        }
        .navigationTitle(destination.rawValue)
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
        .task {
            ensureDataLoadedIfNeeded()
        }
        }
    }

    private func destinationDescription(_ destination: SettingsDestination) -> String {
        switch destination {
        case .alerts:
            return "Choose the bell, haptic, and warning sounds ClassTrax uses during the school day."
        case .boundaries:
            return "Tune after-hours behavior and temporarily snooze alerts when you do not want schedule interruptions."
        case .todayLayout:
            return "Choose which cards appear on Today, reorder them, and reset the dashboard when you want a cleaner home screen."
        case .classroomSetup:
            return "Manage saved classes, student supports, and the reusable classroom context that powers rosters and notes."
        case .subPlans:
            return "Keep substitute handoff details and reusable teacher profile information together."
        case .integrations:
            return "Send schedule and task information into other systems without turning ClassTrax into a dependency hub."
        case .cloudSync:
            return "Review the current persistence mode and CloudKit container status for sync troubleshooting."
        case .liveActivities:
            return "Control live activity behavior and review the current activity state."
        case .data:
            return "Import and export the schedule CSV. Student and class roster CSV tools live in Class List."
        case .diagnostics:
            return "Open launch readiness and debugging tools when you need to inspect the app state."
        case .about:
            return "View app information and general project details."
        }
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.05),
                Color.orange.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var visibleTodayCardCount: Int {
        dashboardCardOrder.filter { !hiddenDashboardCards.contains($0) }.count
    }

    private func ensureDataLoadedIfNeeded() {
        guard !hasLoadedInitialState else { return }
        isLoadingInitialState = true
        loadData()
        hasLoadedInitialState = true
        isLoadingInitialState = false
    }

    private func loadTodayLayoutSettings() {
        let storedOrder = storedDashboardCardOrder
            .split(separator: ",")
            .compactMap { TodayView.TodayDashboardCard(rawValue: String($0)) }
        if storedOrder.isEmpty {
            dashboardCardOrder = TodayView.TodayDashboardCard.defaultOrder
        } else {
            let missingCards = TodayView.TodayDashboardCard.defaultOrder.filter { !storedOrder.contains($0) }
            dashboardCardOrder = storedOrder + missingCards
        }

        hiddenDashboardCards = Set(
            storedHiddenDashboardCards
                .split(separator: ",")
                .compactMap { TodayView.TodayDashboardCard(rawValue: String($0)) }
        )
    }

    private func persistTodayLayoutSettings() {
        storedDashboardCardOrder = dashboardCardOrder.map(\.rawValue).joined(separator: ",")
        storedHiddenDashboardCards = hiddenDashboardCards.map(\.rawValue).sorted().joined(separator: ",")
    }

    private var alertsSection: some View {
        Section("Alerts") {
            Picker("Haptic Pattern", selection: $selectedHapticRawValue) {
                ForEach(HapticPattern.SourceGroup.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(HapticPattern.allCases.filter { $0.sourceGroup == group }, id: \.rawValue) { pattern in
                            Text(pattern.rawValue).tag(pattern.rawValue)
                        }
                    }
                }
            }

            Picker("Sound Pattern", selection: $selectedSoundRawValue) {
                ForEach(SoundPattern.SourceGroup.allCases, id: \.self) { group in
                    Section(group.rawValue) {
                        ForEach(SoundPattern.allCases.filter { $0.sourceGroup == group }, id: \.rawValue) { pattern in
                            Text(pattern.displayName).tag(pattern.rawValue)
                        }
                    }
                }
            }

            Picker("5 Minute Warning", selection: $warningFiveSoundRawValue) {
                soundPatternOptions
            }

            Picker("2 Minute Warning", selection: $warningTwoSoundRawValue) {
                soundPatternOptions
            }

            Picker("1 Minute Warning", selection: $warningOneSoundRawValue) {
                soundPatternOptions
            }

            if let selectedHaptic = HapticPattern(rawValue: selectedHapticRawValue) {
                LabeledContent("Haptic Source", value: selectedHaptic.sourceGroup.rawValue)
                    .font(.footnote)
            }

            if let selectedSound = SoundPattern(rawValue: selectedSoundRawValue) {
                LabeledContent("Sound Source", value: selectedSound.sourceGroup.rawValue)
                    .font(.footnote)
            }

            if let warningFiveSound = SoundPattern(rawValue: warningFiveSoundRawValue) {
                LabeledContent("5 Minute Source", value: warningFiveSound.sourceGroup.rawValue)
                    .font(.footnote)
            }

            if let warningTwoSound = SoundPattern(rawValue: warningTwoSoundRawValue) {
                LabeledContent("2 Minute Source", value: warningTwoSound.sourceGroup.rawValue)
                    .font(.footnote)
            }

            if let warningOneSound = SoundPattern(rawValue: warningOneSoundRawValue) {
                LabeledContent("1 Minute Source", value: warningOneSound.sourceGroup.rawValue)
                    .font(.footnote)
            }

            Button {
                testBell()
            } label: {
                Label("Test Bell", systemImage: "bell.fill")
            }
        }
    }

    private var holidaySection: some View {
        Section("Alert Snooze") {
            Toggle("Snooze Alerts", isOn: $holidayModeEnabled)

            if holidayModeEnabled {
                DatePicker(
                    "Resume Alerts On",
                    selection: $holidayResumeDate,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Button("Save Snooze") {
                    ScheduleSnoozeStore.setPause(until: holidayResumeDate)
                    ignoreUntil = holidayResumeDate.timeIntervalSince1970
                }

                Button("Turn Off Snooze", role: .destructive) {
                    ScheduleSnoozeStore.setPause(until: nil)
                    ignoreUntil = 0
                    holidayModeEnabled = false
                }
            } else {
                holidayStatusText
            }
        }
    }

    private var cloudSyncStatusSection: some View {
        Section("Cloud Sync") {
            LabeledContent("Persistence Mode") {
                Text(ClassTraxPersistence.activeContainerMode.rawValue)
                    .foregroundColor(
                        ClassTraxPersistence.activeContainerMode == .cloudKit ? .green : .orange
                    )
            }

            LabeledContent("CloudKit Container") {
                Text(ClassTraxPersistence.cloudKitContainerIdentifier)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Last Container Event") {
                Text(ClassTraxPersistence.lastContainerStatusMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Last Sync Event") {
                Text(lastCloudKitEventSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Sync Event Time") {
                Text(lastCloudKitEventTimestampSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Schema Init Status") {
                Text(ClassTraxPersistence.lastSchemaInitializationMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Loaded Snapshot") {
                Text(syncSnapshotSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Planning Data") {
                Text(planningSnapshotSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Last Cloud Refresh") {
                Text(lastCloudRefreshSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Last Local Change") {
                Text(lastLocalMutationSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            if ClassTraxPersistence.activeContainerMode == .cloudKit {
                Text("SwiftData initialized with the CloudKit-backed store. If data still does not appear on another device, the remaining issue is sync propagation or schema deployment rather than local fallback.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("The app is currently using the local fallback store. Cross-device sync will not happen until the CloudKit-backed container initializes successfully on this device.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var liveActivityStatusSection: some View {
        Section("Live Activities") {
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
            Toggle("Enable Live Activities", isOn: $liveActivitiesEnabledPreference)

            LabeledContent("iPhone Allows Live Activities") {
                Text(liveActivitiesEnabled ? "On" : "Off")
                    .foregroundColor(liveActivitiesEnabled ? .green : .red)
            }

            LabeledContent("Class Trax Activity Running") {
                Text(activeLiveActivityCount > 0 ? "Yes" : "No")
                    .foregroundColor(activeLiveActivityCount > 0 ? .green : .secondary)
            }

            LabeledContent("Last Live Activity Event") {
                Text(LiveActivityManager.lastStatusMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            if activeLiveActivityCount > 0 {
                Text("Class Trax currently has \(activeLiveActivityCount) active Live Activit\(activeLiveActivityCount == 1 ? "y" : "ies").")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("If this says \"No\" during an active class, the app is not successfully starting the lock screen activity yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text("Turning this off removes the Dynamic Island and lock-screen Live Activity entirely.")
                .font(.footnote)
                .foregroundColor(.secondary)
#else
            Text("Live Activities are unavailable on this platform. Class Trax sync, schedule editing, students, tasks, notes, and sub plans remain available.")
                .font(.footnote)
                .foregroundColor(.secondary)
#endif
        }
    }

    @ViewBuilder
    private var holidayStatusText: some View {
        if ignoreUntil > Date().timeIntervalSince1970 {
            Text("Alerts snoozed until \(Date(timeIntervalSince1970: ignoreUntil).formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else {
            Text("Alerts are active.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var schoolBoundariesSection: some View {
        Section("After Hours") {
            Toggle("Quiet School Alerts After Hours", isOn: $schoolQuietHoursEnabled)
            Toggle("Show End-of-Day Wrap Up", isOn: $showEndOfDayWrapUp)
            Toggle("Offer Task Carryover to Tomorrow", isOn: $offerTaskCarryover)
            Toggle("Hide School Dashboard After Quiet Hours", isOn: $hideSchoolDashboardAfterHours)
            Toggle("Show Personal Focus After Quiet Hours", isOn: $showPersonalFocusCard)
            Toggle("Default New Capture to Personal After Quiet Hours", isOn: $defaultPersonalCaptureAfterHours)

            if schoolQuietHoursEnabled {
                DatePicker(
                    "Quiet Starting At",
                    selection: $schoolQuietStart,
                    displayedComponents: .hourAndMinute
                )

                Text("This applies every day. ClassTrax quiets routine school alerts after this time and resumes them again the next day before your first scheduled alert.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Use after-hours quieting to keep school notifications from following you into personal time.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var integrationsSection: some View {
        Section("Integrations") {
            Button {
                exportTodayScheduleToCalendar()
            } label: {
                Label("Export Today's Schedule to Calendar", systemImage: "calendar.badge.plus")
            }
            .disabled(todayScheduleForExport.isEmpty)

            Button {
                exportOpenTasksToReminders()
            } label: {
                Label("Export Open Tasks to Reminders", systemImage: "checklist.checked")
            }

            Text("This is the first integration layer: ClassTrax can package today’s schedule as a calendar file and open tasks as a reminders checklist, so you can push data into other systems without making the app dependent on them.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var workspaceSetupSection: some View {
        Section("Classroom Setup") {
            NavigationLink {
                StudentDirectoryView(
                    profiles: $studentProfiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts,
                    onSavedProfiles: { updatedProfiles in
                        studentProfiles = updatedProfiles
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: updatedProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: teacherContacts,
                            paraContacts: paraContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    },
                    onSavedTeacherContacts: { updatedContacts in
                        teacherContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: updatedContacts,
                            paraContacts: paraContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    },
                    onSavedParaContacts: { updatedContacts in
                        paraContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: teacherContacts,
                            paraContacts: updatedContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    }
                )
            } label: {
                LabeledContent("Student Directory") {
                    Text(studentProfiles.isEmpty ? "Not Set" : "\(studentProfiles.count)")
                        .foregroundColor(studentProfiles.isEmpty ? .secondary : .primary)
                }
            }

            NavigationLink {
                ClassDefinitionsView(classDefinitions: $classDefinitions, profiles: $studentProfiles)
            } label: {
                LabeledContent("Saved Classes") {
                    Text(classDefinitions.isEmpty ? "Not Set" : "\(classDefinitions.count)")
                        .foregroundColor(classDefinitions.isEmpty ? .secondary : .primary)
                }
            }

            NavigationLink {
                SupportStaffDirectoryView(
                    title: "Teachers",
                    role: .teacher,
                    contacts: $teacherContacts,
                    onCommitContacts: { updatedContacts in
                        teacherContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: updatedContacts,
                            paraContacts: paraContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    }
                )
            } label: {
                LabeledContent("Teachers") {
                    Text(teacherContacts.isEmpty ? "Not Set" : "\(teacherContacts.count)")
                        .foregroundColor(teacherContacts.isEmpty ? .secondary : .primary)
                }
            }

            NavigationLink {
                SupportStaffDirectoryView(
                    title: "Paras",
                    role: .para,
                    contacts: $paraContacts,
                    onCommitContacts: { updatedContacts in
                        paraContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: teacherContacts,
                            paraContacts: updatedContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    }
                )
            } label: {
                LabeledContent("Paras") {
                    Text(paraContacts.isEmpty ? "Not Set" : "\(paraContacts.count)")
                        .foregroundColor(paraContacts.isEmpty ? .secondary : .primary)
                }
            }

            NavigationLink("Schedule Profiles") {
                ProfilesView(alarms: $alarms, profiles: $profiles)
            }

            NavigationLink("Day Overrides") {
                DayOverridesView(overrides: $overrides, profiles: $profiles)
            }

            Text(workspaceSetupSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var scheduleToolsSection: some View {
        Section("Sub Plans") {
            NavigationLink("Sub Plan Profile") {
                SubPlanProfileSettingsView()
            }

            Text("Keep substitute guidance and reusable classroom handoff details together here.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
            NavigationLink("Import Schedule CSV") {
                ImportView(alarms: $alarms)
            }

            NavigationLink("Export Schedule CSV") {
                ExportView(alarms: $alarms)
            }

            NavigationLink("Student Roster Data") {
                StudentDirectoryView(
                    profiles: $studentProfiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts,
                    showsRosterDataTools: true,
                    onSavedProfiles: { updatedProfiles in
                        studentProfiles = updatedProfiles
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: updatedProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: teacherContacts,
                            paraContacts: paraContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    },
                    onSavedTeacherContacts: { updatedContacts in
                        teacherContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: updatedContacts,
                            paraContacts: paraContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    },
                    onSavedParaContacts: { updatedContacts in
                        paraContacts = updatedContacts
                        ClassTraxPersistence.saveFirstSlice(
                            alarms: alarms,
                            studentProfiles: studentProfiles,
                            classDefinitions: classDefinitions,
                            teacherContacts: teacherContacts,
                            paraContacts: updatedContacts,
                            commitments: commitments,
                            into: modelContext
                        )
                    }
                )
            }

            Text("Schedule CSV tools stay here, and student roster CSV import/export now lives here too. Class List stays focused on managing students and saved classes.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var appToolsSection: some View {
        Section("Diagnostics") {
            NavigationLink("Launch Readiness") {
                LaunchPrepView()
            }

            NavigationLink("Debug Screen") {
                DebugView()
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("About Class Trax") {
                AboutView()
            }
        }
    }

    private var workspaceSetupSummary: String {
        if studentProfiles.isEmpty && classDefinitions.isEmpty {
            return "Open Student Directory and Saved Classes to build the reusable classroom context that powers rosters, tasks, and quick capture."
        }

        return "ClassTrax currently has \(classDefinitions.count) saved classes and \(studentProfiles.count) students ready to reuse across schedules, rosters, and notes."
    }

    private var syncSnapshotSummary: String {
        "\(alarms.count) blocks • \(todos.count) tasks • \(studentProfiles.count) students • \(classDefinitions.count) classes"
    }

    private var planningSnapshotSummary: String {
        "\(commitments.count) commitments • \(profiles.count) profiles • \(overrides.count) overrides"
    }

    private var lastCloudRefreshSummary: String {
        formattedSyncTimestamp(lastCloudRefreshTimestamp, empty: "No CloudKit refresh recorded yet")
    }

    private var lastLocalMutationSummary: String {
        formattedSyncTimestamp(lastLocalMutationTimestamp, empty: "No local changes recorded yet")
    }

    private var lastCloudKitEventTimestampSummary: String {
        formattedSyncTimestamp(lastCloudKitEventTimestamp, empty: "No CloudKit event timestamp yet")
    }

    private func formattedSyncTimestamp(_ timestamp: Double, empty: String) -> String {
        guard timestamp > 0 else { return empty }
        return Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened)
    }

    private func testBell() {
        let haptic = HapticPattern(rawValue: selectedHapticRawValue) ?? .doubleThump
        let sound = BellSound.fromStoredPreference(selectedSoundRawValue)
        BellFeedbackManager.shared.play(haptic: haptic, bellSound: sound)
    }

    @ViewBuilder
    private var soundPatternOptions: some View {
        ForEach(SoundPattern.SourceGroup.allCases, id: \.self) { group in
            Section(group.rawValue) {
                ForEach(SoundPattern.allCases.filter { $0.sourceGroup == group }, id: \.rawValue) { pattern in
                    Text(pattern.displayName).tag(pattern.rawValue)
                }
            }
        }
    }

    private func configureHolidayMode() {
        if ignoreUntil > Date().timeIntervalSince1970 {
            holidayModeEnabled = true
            holidayResumeDate = Date(timeIntervalSince1970: ignoreUntil)
        } else {
            holidayModeEnabled = false
        }

        syncSchoolQuietStart()
    }

    private func loadData() {
        let firstSlice = ClassTraxPersistence.loadFirstSlice(from: modelContext)
        let secondSlice = ClassTraxPersistence.loadSecondSlice(from: modelContext)
        let thirdSlice = ClassTraxPersistence.loadThirdSlice(from: modelContext)

        if ClassTraxPersistence.activeContainerMode == .cloudKit {
            alarms = firstSlice.alarms
            commitments = firstSlice.commitments
            todos = secondSlice.todos
        } else {
            if let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) {
                alarms = decodedAlarms
            } else {
                alarms = []
            }

            if let decodedCommitments = try? JSONDecoder().decode([CommitmentItem].self, from: savedCommitments) {
                commitments = decodedCommitments
            } else {
                commitments = []
            }

            if let decodedTodos = try? JSONDecoder().decode([TodoItem].self, from: savedTodos) {
                todos = decodedTodos
            } else {
                todos = []
            }
        }

        profiles = thirdSlice.profiles
        studentProfiles = firstSlice.studentProfiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        classDefinitions = firstSlice.classDefinitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        teacherContacts = firstSlice.teacherContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        paraContacts = firstSlice.paraContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        overrides = thirdSlice.overrides
    }

    private func saveAlarms(_ alarms: [AlarmItem]) {
        if let encoded = try? JSONEncoder().encode(alarms) {
            savedAlarms = encoded
        }
    }

    private func saveProfiles(_ profiles: [ScheduleProfile]) {
        let snapshot = ClassTraxPersistence.loadThirdSlice(from: modelContext)
        ClassTraxPersistence.saveThirdSlice(
            attendanceRecords: snapshot.attendanceRecords,
            profiles: profiles,
            overrides: overrides,
            into: modelContext
        )
        if let encoded = try? JSONEncoder().encode(profiles) {
            savedProfiles = encoded
        }
    }

    private func saveOverrides(_ overrides: [DayOverride]) {
        let snapshot = ClassTraxPersistence.loadThirdSlice(from: modelContext)
        ClassTraxPersistence.saveThirdSlice(
            attendanceRecords: snapshot.attendanceRecords,
            profiles: profiles,
            overrides: overrides,
            into: modelContext
        )
        if let encoded = try? JSONEncoder().encode(overrides) {
            savedOverrides = encoded
        }
    }

    private func syncSchoolQuietStart() {
        schoolQuietStart = Calendar.current.date(
            bySettingHour: schoolQuietHour,
            minute: schoolQuietMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func refreshNotifications() {
        let activeOverride = activeOverrideForToday()

        NotificationManager.shared.refreshNotifications(
            for: alarms,
            activeOverrideSchedule: activeOverride?.alarms,
            activeOverrideDate: activeOverride?.date,
            overrides: overrides,
            profiles: profiles
        )
    }

    private func activeOverrideForToday() -> (date: Date, alarms: [AlarmItem])? {
        let today = Calendar.current.startOfDay(for: Date())

        guard let override = overrides.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) else {
            return nil
        }

        guard let profile = profiles.first(where: { $0.id == override.profileID }) else {
            return nil
        }

        let weekday = Calendar.current.component(.weekday, from: today)
        return (today, overrideAlarms(for: profile, weekday: weekday))
    }

    private func overrideAlarms(for profile: ScheduleProfile, weekday: Int) -> [AlarmItem] {
        let directMatches = profile.alarms
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }

        let source = directMatches.isEmpty
            ? profile.alarms.sorted { $0.startTime < $1.startTime }
            : directMatches

        return source.map { item in
            AlarmItem(
                id: item.id,
                dayOfWeek: weekday,
                className: item.className,
                location: item.location,
                gradeLevel: item.gradeLevel,
                startTime: item.startTime,
                endTime: item.endTime,
                type: item.type
            )
        }
    }

    private var liveActivitiesEnabled: Bool {
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        ActivityAuthorizationInfo().areActivitiesEnabled
#else
        false
#endif
    }

    private var activeLiveActivityCount: Int {
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        Activity<ClassTraxActivityAttributes>.activities.count
#else
        0
#endif
    }

    private var todayScheduleForExport: [AlarmItem] {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        if let activeOverride = activeOverrideForToday() {
            return activeOverride.alarms.sorted { $0.startTime < $1.startTime }
        }
        return alarms
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }
    }

    private func exportTodayScheduleToCalendar() {
        let title = "Class Trax \(Date().formatted(date: .abbreviated, time: .omitted))"
        let text = calendarICS(
            title: title,
            date: Date(),
            alarms: todayScheduleForExport,
            overrideLabel: activeOverrideForToday().map { _ in "Active Day Override" }
        )
        shareTextFile(named: "classtrax-today-schedule.ics", contents: text)
    }

    private func exportOpenTasksToReminders() {
        let text = remindersChecklist(date: Date(), todos: todos)
        shareTextFile(named: "classtrax-open-tasks.txt", contents: text)
    }

    private func shareTextFile(named filename: String, contents: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
    }

    private func calendarICS(
        title: String,
        date: Date,
        alarms: [AlarmItem],
        overrideLabel: String? = nil
    ) -> String {
        let events = alarms.sorted { $0.startTime < $1.startTime }.map { alarm in
            let start = anchoredDate(alarm.startTime, on: date)
            let end = anchoredDate(alarm.endTime, on: date)
            let descriptionParts = [
                overrideLabel.map { "Override: \($0)" },
                alarm.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Grade: \(alarm.gradeLevel)",
                alarm.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Location: \(alarm.location)"
            ].compactMap { $0 }

            return """
            BEGIN:VEVENT
            UID:\(alarm.id.uuidString)@classtrax
            DTSTAMP:\(icsTimestamp(from: Date()))
            DTSTART:\(icsTimestamp(from: start))
            DTEND:\(icsTimestamp(from: end))
            SUMMARY:\(escapedICS(alarm.className))
            LOCATION:\(escapedICS(alarm.location))
            DESCRIPTION:\(escapedICS(descriptionParts.joined(separator: "\\n")))
            END:VEVENT
            """
        }.joined(separator: "\n")

        return """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//ClassTrax//Teacher Workspace//EN
        CALSCALE:GREGORIAN
        X-WR-CALNAME:\(escapedICS(title))
        \(events)
        END:VCALENDAR
        """
    }

    private func remindersChecklist(date: Date, todos: [TodoItem]) -> String {
        let openTodos = todos.filter { !$0.isCompleted }
        let header = "Class Trax Tasks\n\(date.formatted(date: .complete, time: .omitted))"

        guard !openTodos.isEmpty else {
            return "\(header)\n\nNo open tasks."
        }

        let body = openTodos.map { todo in
            let parts = [
                todo.task,
                todo.bucket.displayName,
                todo.category.displayName,
                todo.linkedContext.isEmpty ? nil : todo.linkedContext,
                todo.studentOrGroup.isEmpty ? nil : todo.studentOrGroup
            ].compactMap { $0 }.joined(separator: " • ")
            return "- \(parts)"
        }.joined(separator: "\n")

        return "\(header)\n\n\(body)"
    }

    private func anchoredDate(_ time: Date, on day: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func icsTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter.string(from: date)
    }

    private func escapedICS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
struct SubPlanProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var profile = SubPlanProfile()
    @State private var hasLoaded = false
    @State private var saveStatusMessage = ""

    var body: some View {
        Form {
            Section("Teacher Contact") {
                TextField("Teacher name", text: $profile.teacherName)
                TextField("Default room", text: $profile.room)
                TextField("Contact email", text: $profile.contactEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Contact phone", text: $profile.contactPhone)
                    .keyboardType(.phonePad)
                TextField("School / front office contact", text: $profile.schoolFrontOfficeContact, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Neighboring teacher", text: $profile.neighboringTeacher)
            }

            Section("Emergency / Drill") {
                TextField("Emergency / drill procedures", text: $profile.emergencyDrillProcedures, axis: .vertical)
                    .lineLimit(4...8)
                TextField("Emergency / drill file link", text: $profile.emergencyDrillFileLink, axis: .vertical)
                    .lineLimit(2...4)

                Text("Paste either the procedures themselves or a shared file link. Both will be included in sub-plan exports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Access / Extensions") {
                TextField("General passwords / access notes", text: $profile.passwordsAccessNotes, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Phone extensions", text: $profile.phoneExtensions, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Application Credentials") {
                if profile.appCredentials.isEmpty {
                    Text("Add login details for the applications a substitute may need.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach($profile.appCredentials) { $credential in
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Application", text: $credential.applicationName)
                        TextField("Application link", text: $credential.applicationLink, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .lineLimit(2...4)
                        TextField("Username", text: $credential.username)
                            .textInputAutocapitalization(.never)
                        TextField("Password", text: $credential.password)
                            .textInputAutocapitalization(.never)

                        Button("Remove App", role: .destructive) {
                            removeCredential(id: credential.id)
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    profile.appCredentials.append(SubPlanProfile.AppCredential())
                } label: {
                    Label("Add App Credential", systemImage: "plus.circle")
                }
            }

            Section("Static Notes") {
                TextField("Reusable static notes for every sub plan", text: $profile.staticNotes, axis: .vertical)
                    .lineLimit(4...8)
            }

            if !saveStatusMessage.isEmpty {
                Section {
                    Text(saveStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Sub Plan Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            profile = ClassTraxPersistence.loadSubPlanProfile(from: modelContext)
            hasLoaded = true
        }
    }

    private func saveProfile() {
        let cleaned = cleanedProfile(profile)
        profile = cleaned
        ClassTraxPersistence.saveSubPlanProfile(cleaned, into: modelContext)
        saveStatusMessage = "Saved \(Date.now.formatted(date: .omitted, time: .shortened))"
    }

    private func removeCredential(id: UUID) {
        profile.appCredentials.removeAll { $0.id == id }
    }

    private func cleanedProfile(_ profile: SubPlanProfile) -> SubPlanProfile {
        var cleaned = profile
        cleaned.appCredentials = profile.appCredentials.filter(\.hasContent)
        return cleaned
    }
}
