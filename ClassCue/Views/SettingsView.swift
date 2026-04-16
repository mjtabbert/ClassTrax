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
    private enum SettingsDestination: String, Identifiable, CaseIterable, Hashable {
        case alerts = "Alerts"
        case boundaries = "After Hours"
        case todayLayout = "Today Layout"
        case classroomSetup = "Core Setup"
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

    private enum DiagnosticsTool: String, Identifiable, CaseIterable {
        case launchReadiness
        case debugScreen

        var id: String { rawValue }

        var title: String {
            switch self {
            case .launchReadiness:
                return "Launch Readiness"
            case .debugScreen:
                return "Debug Screen"
            }
        }

        var summary: String {
            switch self {
            case .launchReadiness:
                return "Startup checks and launch-state inspection"
            case .debugScreen:
                return "Deep app-state inspection and troubleshooting"
            }
        }

        @ViewBuilder
        var destinationView: some View {
            switch self {
            case .launchReadiness:
                LaunchPrepView()
            case .debugScreen:
                DebugView()
            }
        }
    }

    private enum DeleteDataTarget: String, Identifiable {
        case savedContexts
        case studentDirectory
        case teachers
        case paras
        case scheduleProfiles
        case dayOverrides
        case scheduleBlocks
        case allUserData

        var id: String { rawValue }

        var title: String {
            switch self {
            case .savedContexts:
                return "Saved Classes / Groups"
            case .studentDirectory:
                return "Student Directory"
            case .teachers:
                return "Teachers"
            case .paras:
                return "Paras"
            case .scheduleProfiles:
                return "Schedule Profiles"
            case .dayOverrides:
                return "Day Overrides"
            case .scheduleBlocks:
                return "Schedule Blocks"
            case .allUserData:
                return "All User Data"
            }
        }

        var buttonTitle: String {
            "Delete \(title)"
        }

        var confirmationMessage: String {
            switch self {
            case .savedContexts:
                return "This permanently removes all saved classes and groups."
            case .studentDirectory:
                return "This permanently removes every saved student profile."
            case .teachers:
                return "This permanently removes every saved teacher contact."
            case .paras:
                return "This permanently removes every saved para contact."
            case .scheduleProfiles:
                return "This permanently removes every saved schedule profile."
            case .dayOverrides:
                return "This permanently removes every saved day override."
            case .scheduleBlocks:
                return "This permanently removes every scheduled block from the live schedule."
            case .allUserData:
                return "This permanently removes schedules, students, teachers, paras, planner items, notes, prep plans, attendance, overrides, and other saved user data so you can start over fresh."
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = HapticPattern.doubleThump.rawValue
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = SoundPattern.classicAlarm.rawValue
    @AppStorage("pref_warning_sound_5min") private var warningFiveSoundRawValue: String = SoundPattern.softChime.rawValue
    @AppStorage("pref_warning_sound_2min") private var warningTwoSoundRawValue: String = SoundPattern.systemGlass.rawValue
    @AppStorage("pref_warning_sound_1min") private var warningOneSoundRawValue: String = SoundPattern.sharpBell.rawValue
    @AppStorage("pref_class_start_notifications_enabled") private var classStartNotificationsEnabled = true
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
    @AppStorage("cloudkit_last_import_event_summary_v1") private var lastCloudKitImportEventSummary: String = "No CloudKit import events observed yet."
    @AppStorage("cloudkit_last_import_event_timestamp_v1") private var lastCloudKitImportEventTimestamp: Double = 0
    @AppStorage("cloudkit_last_export_event_summary_v1") private var lastCloudKitExportEventSummary: String = "No CloudKit export events observed yet."
    @AppStorage("cloudkit_last_export_event_timestamp_v1") private var lastCloudKitExportEventTimestamp: Double = 0
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
    @AppStorage("teacher_workflow_mode_v1") private var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue
    @AppStorage("guided_setup_autolaunch_seen_v2") private var hasSeenGuidedSetupAutolaunch = false
    @AppStorage("feature_attendance_enabled") private var featureAttendanceEnabled = true
    @AppStorage("feature_schedule_enabled") private var featureScheduleEnabled = true
    @AppStorage("feature_homework_enabled") private var featureHomeworkEnabled = true
    @AppStorage("feature_behavior_enabled") private var featureBehaviorEnabled = true

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
    @State private var dashboardCardOrder = TodayDashboardCard.defaultOrder
    @State private var hiddenDashboardCards = Set<TodayDashboardCard>()
    @State private var isLoadingInitialState = false
    @State private var hasLoadedInitialState = false
    @State private var showingWorkspaceSetupWizard = false
    @State private var diagnosticsStatusMessage = ""
    @State private var pendingDeleteTarget: DeleteDataTarget?
    @State private var selectedDiagnosticsTool: DiagnosticsTool?
    @State private var showingQuickAddClassDefinition = false
    @State private var showingQuickAddStudent = false
    @State private var showingTeacherDirectory = false
    @State private var showingParaDirectory = false
    @State private var isQuickStartExpanded = true

    private let diagnosticsToolsEnabled = true

    private var teacherWorkflowMode: TeacherWorkflowMode {
        get { TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom }
        nonmutating set { teacherWorkflowModeRawValue = newValue.rawValue }
    }

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
            .navigationDestination(for: SettingsDestination.self) { destination in
                settingsDestinationView(destination)
            }
            .sheet(isPresented: $showingWorkspaceSetupWizard) {
                NavigationStack {
                    WorkspaceSetupWizardView(
                        teacherWorkflowMode: Binding(
                            get: { teacherWorkflowMode },
                            set: { teacherWorkflowMode = $0 }
                        ),
                        contextCount: classDefinitions.count,
                        studentCount: studentProfiles.count,
                        hasSchedule: !alarms.isEmpty,
                        contextsDestination: AnyView(classDefinitionsDestinationView),
                        studentsDestination: AnyView(studentDirectoryDestinationView),
                        layoutDestination: AnyView(
                            TodayLayoutCustomizationView(
                                cards: $dashboardCardOrder,
                                hiddenCards: $hiddenDashboardCards
                            )
                        ),
                        alertsDestination: AnyView(alertsWizardDestinationView)
                    )
                }
            }
            .sheet(item: $selectedDiagnosticsTool) { tool in
                NavigationStack {
                    tool.destinationView
                }
            }
            .sheet(isPresented: $showingQuickAddClassDefinition) {
                NavigationStack {
                    EditClassDefinitionView(
                        classDefinitions: $classDefinitions,
                        studentProfiles: $studentProfiles,
                        existing: nil
                    )
                }
            }
            .sheet(isPresented: $showingQuickAddStudent) {
                EditStudentSupportView(
                    profiles: $studentProfiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts,
                    existing: nil
                )
            }
            .sheet(isPresented: $showingTeacherDirectory) {
                NavigationStack {
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
                }
            }
            .sheet(isPresented: $showingParaDirectory) {
                NavigationStack {
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
                }
            }
    }

    private var settingsListContent: some View {
        List {
            Section {
                settingsOverviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                DisclosureGroup("Quick Start Guides", isExpanded: $isQuickStartExpanded) {
                    Button {
                        showingWorkspaceSetupWizard = true
                    } label: {
                        settingsRowLabel(
                            title: "Guided Setup",
                            systemImage: "wand.and.stars",
                            detail: "Best first stop for new teachers: mode, classes or groups, students, Today defaults, and alerts"
                        )
                    }

                    NavigationLink(value: SettingsDestination.classroomSetup) {
                        settingsRowLabel(.classroomSetup, detail: "Use after Guided Setup for saved classes or groups, roster tools, and staff setup")
                    }

                    NavigationLink(value: SettingsDestination.todayLayout) {
                        settingsRowLabel(.todayLayout, detail: "Set the default Today workflow before fine-tuning anything else")
                    }

                    NavigationLink(value: SettingsDestination.alerts) {
                        settingsRowLabel(.alerts, detail: "Finish setup with bell sounds, warning cues, and haptics")
                    }
                }
            }

            Section("Daily Use") {
                NavigationLink(value: SettingsDestination.alerts) {
                    settingsRowLabel(.alerts, detail: "Bell sounds, warning cues, and haptics")
                }

                NavigationLink(value: SettingsDestination.boundaries) {
                    settingsRowLabel(.boundaries, detail: "Quiet hours and after-school behavior")
                }

                NavigationLink(value: SettingsDestination.todayLayout) {
                    settingsRowLabel(.todayLayout, detail: "Choose what appears on the Today dashboard")
                }

                NavigationLink(value: SettingsDestination.classroomSetup) {
                    settingsRowLabel(.classroomSetup, detail: "Saved contexts, roster tools, and staff setup")
                }

                NavigationLink(value: SettingsDestination.subPlans) {
                    settingsRowLabel(.subPlans, detail: "Reusable prep templates and daily handoff tools")
                }

                NavigationLink(value: SettingsDestination.data) {
                    settingsRowLabel(.data, detail: "Import, export, and local data utilities")
                }

                NavigationLink(value: SettingsDestination.integrations) {
                    settingsRowLabel(.integrations, detail: "Widgets, watch, and related integrations")
                }

                NavigationLink(value: SettingsDestination.about) {
                    settingsRowLabel(.about, detail: "App details and version information")
                }
            }

            diagnosticsMenuSection
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
            autolaunchGuidedSetupIfNeeded()
            ClassTraxPersistence.refreshCloudKitDiagnosticsStatus()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
    }

    private var settingsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title3.weight(.bold))

                Text("Start with Guided Setup, then add your first real schedule. System controls live here too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                settingsMetric(title: teacherWorkflowMode == .classroom ? "Classes" : "Groups", value: "\(classDefinitions.count)", accent: ClassTraxSemanticColor.primaryAction)
                settingsMetric(title: "Students", value: "\(studentProfiles.count)", accent: ClassTraxSemanticColor.success)
                settingsMetric(title: "Mode", value: teacherWorkflowMode.shortLabel, accent: ClassTraxSemanticColor.reviewWarning)
            }

            Text("Best first run: Guided Setup, then Schedule, then Alerts.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .classTraxCardChrome(accent: ClassTraxSemanticColor.primaryAction, cornerRadius: 22)
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
        .classTraxCardChrome(accent: accent, cornerRadius: 12)
    }

    @ViewBuilder
    private func settingsRowLabel(_ destination: SettingsDestination, detail: String) -> some View {
        settingsRowLabel(
            title: settingsDestinationTitle(destination),
            systemImage: destination.systemImage,
            detail: detail
        )
    }

    @ViewBuilder
    private func settingsRowLabel(title: String, systemImage: String, detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ClassTraxSemanticColor.primaryAction.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClassTraxSemanticColor.primaryAction)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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
            .alert(item: $pendingDeleteTarget) { target in
                Alert(
                    title: Text(target.buttonTitle),
                    message: Text(target.confirmationMessage),
                    primaryButton: .destructive(Text("Delete")) {
                        performDelete(target)
                    },
                    secondaryButton: .cancel()
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
            settingsLink(.classroomSetup, detail: workspaceSetupNavigationSummary)
            settingsLink(.subPlans, detail: "Profiles and substitute prep")
        }
    }

    private var systemSection: some View {
        Section("System") {
            settingsLink(.integrations, detail: "Calendar and reminders")
            settingsLink(.cloudSync, detail: ClassTraxPersistence.activeContainerMode.rawValue)
            settingsLink(.liveActivities, detail: liveActivitiesEnabledPreference ? "Enabled" : "Disabled")
            settingsLink(.data, detail: "Import and export schedule CSV")
            if diagnosticsToolsEnabled {
                settingsLink(.diagnostics, detail: diagnosticsSummaryText)
            }
            settingsLink(.about, detail: "App info")

            Button {
                loadData()
                ClassTraxPersistence.refreshCloudKitDiagnosticsStatus()
            } label: {
                Label("Refresh App Data", systemImage: "arrow.clockwise")
            }
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
            return diagnosticsToolsEnabled ? "\(diagnosticsTools.count)" : "Off"
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
            return diagnosticsToolsEnabled ? .red : .gray
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
            .navigationTitle(settingsDestinationTitle(destination))
            .scrollContentBackground(.hidden)
            .background(settingsBackground)
            .onChange(of: dashboardCardOrder) { _, _ in
                persistTodayLayoutSettings()
            }
            .onChange(of: hiddenDashboardCards) { _, _ in
                persistTodayLayoutSettings()
            }
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
                diagnosticsSection
            case .about:
                aboutSection
            }
        }
        .navigationTitle(settingsDestinationTitle(destination))
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
        .task {
            ensureDataLoadedIfNeeded()
        }
        .onChange(of: selectedSoundRawValue) { _, _ in
            guard destination == .alerts else { return }
            refreshNotifications()
        }
        .onChange(of: warningFiveSoundRawValue) { _, _ in
            guard destination == .alerts else { return }
            refreshNotifications()
        }
        .onChange(of: warningTwoSoundRawValue) { _, _ in
            guard destination == .alerts else { return }
            refreshNotifications()
        }
        .onChange(of: warningOneSoundRawValue) { _, _ in
            guard destination == .alerts else { return }
            refreshNotifications()
        }
        .onChange(of: classStartNotificationsEnabled) { _, _ in
            guard destination == .alerts else { return }
            refreshNotifications()
        }
        .onChange(of: schoolQuietHoursEnabled) { _, _ in
            guard destination == .boundaries else { return }
            syncSchoolQuietStart()
            refreshNotifications()
        }
        .onChange(of: schoolQuietStart) { _, newValue in
            guard destination == .boundaries else { return }
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            schoolQuietHour = components.hour ?? 16
            schoolQuietMinute = components.minute ?? 0
            refreshNotifications()
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
            return teacherWorkflowMode == .classroom
                ? "Manage saved classes, student supports, and the reusable class setup that powers rosters and notes."
                : "Manage reusable classes and groups, students, supports, and staff details that power rosters, notes, and live-day workflows."
        case .subPlans:
            return "Keep substitute handoff details, daily prep packets, and reusable handoff profile information together."
        case .integrations:
            return "Send schedule and task information into other systems without turning ClassTrax into a dependency hub."
        case .cloudSync:
            return "Review the current persistence mode and CloudKit container status for sync troubleshooting."
        case .liveActivities:
            return "Control live activity behavior and review the current activity state."
        case .data:
            return "Import and export the schedule CSV. Student and roster CSV tools live in Student Directory data tools."
        case .diagnostics:
            return diagnosticsToolsEnabled
                ? "Open removable troubleshooting tools when you need to inspect startup behavior or internal app state."
                : "Diagnostics tools are currently hidden from Settings."
        case .about:
            return "View app information and general project details."
        }
    }

    private func settingsDestinationTitle(_ destination: SettingsDestination) -> String {
        switch destination {
        case .classroomSetup:
            switch teacherWorkflowMode {
            case .classroom:
                return "Core Setup"
            case .resourceSped:
                return "Support Setup"
            case .hybrid:
                return "Core Setup"
            }
        default:
            return destination.rawValue
        }
    }

    private var workspaceSetupNavigationSummary: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Classes, students, profiles, and overrides"
        case .resourceSped:
            return "Groups, students, supports, and staff"
        case .hybrid:
            return "Classes, groups, students, and supports"
        }
    }

    private var savedDefinitionsLabel: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Saved Classes"
        case .resourceSped:
            return "Saved Groups"
        case .hybrid:
            return "Saved Classes & Groups"
        }
    }

    private var workspaceSetupChecklistSummary: String {
        var steps: [String] = []
        steps.append(classDefinitions.isEmpty ? "Add at least one saved class or group" : "Classes / groups ready")
        steps.append(studentProfiles.isEmpty ? "Add students or support profiles" : "Students ready")
        steps.append(alarms.isEmpty ? "Build today’s schedule in Schedule" : "Schedule ready")
        return steps.joined(separator: " • ")
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
            .compactMap { TodayDashboardCard(rawValue: String($0)) }
        if storedOrder.isEmpty {
            dashboardCardOrder = TodayDashboardCard.defaultOrder
        } else {
            let missingCards = TodayDashboardCard.defaultOrder.filter { !storedOrder.contains($0) }
            dashboardCardOrder = storedOrder + missingCards
        }

        hiddenDashboardCards = Set(
            storedHiddenDashboardCards
                .split(separator: ",")
                .compactMap { TodayDashboardCard(rawValue: String($0)) }
        )
    }

    private func persistTodayLayoutSettings() {
        storedDashboardCardOrder = dashboardCardOrder.map(\.rawValue).joined(separator: ",")
        storedHiddenDashboardCards = hiddenDashboardCards.map(\.rawValue).sorted().joined(separator: ",")
    }

    private var alertsSection: some View {
        Section("Alerts") {
            Toggle("Class Start Alerts", isOn: $classStartNotificationsEnabled)

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

            Text("Turn this off if the warning bells already give you enough notice. End-of-class and advance warnings stay active.")
                .font(.footnote)
                .foregroundColor(.secondary)
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

            LabeledContent("Last Import Event") {
                Text(lastCloudKitImportEventSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Import Event Time") {
                Text(lastCloudKitImportEventTimestampSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Last Export Event") {
                Text(lastCloudKitExportEventSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Export Event Time") {
                Text(lastCloudKitExportEventTimestampSummary)
                    .font(.footnote)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.secondary)
            }

            LabeledContent("Debug Build") {
                Text(isDebugBuild ? "Yes" : "No")
                    .foregroundColor(isDebugBuild ? .green : .orange)
            }

            LabeledContent("Schema Init Available") {
                Text(isCloudKitSchemaInitializationAvailable ? "Yes" : "No")
                    .foregroundColor(isCloudKitSchemaInitializationAvailable ? .green : .orange)
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
        Section(settingsDestinationTitle(.classroomSetup)) {
            workspaceSetupProgressCard

            Picker("Workflow Mode", selection: Binding(
                get: { teacherWorkflowMode },
                set: { teacherWorkflowMode = $0 }
            )) {
                ForEach(TeacherWorkflowMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Text(teacherWorkflowMode.settingsSummary)
                .font(.footnote)
                .foregroundColor(.secondary)

            featureVisibilityControls

            Button {
                showingWorkspaceSetupWizard = true
            } label: {
                HStack {
                    Label("Guided Setup", systemImage: "wand.and.stars")
                    Spacer()
                    Text(workspaceSetupCompletionLabel)
                        .foregroundStyle(.secondary)
                }
            }

            quickAddSetupRow

            NavigationLink {
                classDefinitionsDestinationView
            } label: {
                LabeledContent(savedDefinitionsLabel) {
                    Text(classDefinitions.isEmpty ? "Start Here" : "\(classDefinitions.count)")
                        .foregroundColor(classDefinitions.isEmpty ? .orange : .primary)
                }
            }

            NavigationLink {
                studentDirectoryDestinationView
            } label: {
                LabeledContent("Student Directory") {
                    Text(studentProfiles.isEmpty ? "Next Step" : "\(studentProfiles.count)")
                        .foregroundColor(studentProfiles.isEmpty ? .orange : .primary)
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

            if hasWorkspaceDataToDelete {
                deleteSectionDataControls
            }

            Text(workspaceSetupSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var featureVisibilityControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Module Visibility")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Toggle("Attendance", isOn: $featureAttendanceEnabled)
            Toggle("Schedule", isOn: $featureScheduleEnabled)
            Toggle("Homework / Missing Work", isOn: $featureHomeworkEnabled)
            Toggle("Behavior", isOn: $featureBehaviorEnabled)

            Text("Turn classroom modules on or off without deleting any saved data. Hidden modules stay stored and can be re-enabled later.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var quickAddSetupRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                setupQuickAddButton(
                    title: teacherWorkflowMode == .classroom ? "Class" : "Group",
                    systemImage: "books.vertical",
                    accent: .blue
                ) {
                    showingQuickAddClassDefinition = true
                }

                setupQuickAddButton(
                    title: "Student",
                    systemImage: "person.badge.plus",
                    accent: .green
                ) {
                    showingQuickAddStudent = true
                }

                setupQuickAddButton(
                    title: "Teacher",
                    systemImage: "person.crop.circle.badge.plus",
                    accent: .teal
                ) {
                    showingTeacherDirectory = true
                }

                setupQuickAddButton(
                    title: "Para",
                    systemImage: "person.2.badge.plus",
                    accent: .orange
                ) {
                    showingParaDirectory = true
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func setupQuickAddButton(
        title: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
    }

    private var workspaceSetupProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build the workspace in this order so Today feels useful immediately.")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                settingsMetric(
                    title: teacherWorkflowMode == .classroom ? "Classes" : "Groups",
                    value: classDefinitions.isEmpty ? "0" : "\(classDefinitions.count)",
                    accent: classDefinitions.isEmpty ? .orange : .blue
                )
                settingsMetric(
                    title: "Students",
                    value: studentProfiles.isEmpty ? "0" : "\(studentProfiles.count)",
                    accent: studentProfiles.isEmpty ? .orange : .green
                )
                settingsMetric(
                    title: "Schedule",
                    value: alarms.isEmpty ? "Next" : "Ready",
                    accent: alarms.isEmpty ? .orange : .indigo
                )
            }

            Text(workspaceSetupChecklistSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open Guided Setup") {
                showingWorkspaceSetupWizard = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }

    private var hasWorkspaceDataToDelete: Bool {
        !classDefinitions.isEmpty ||
        !studentProfiles.isEmpty ||
        !teacherContacts.isEmpty ||
        !paraContacts.isEmpty ||
        !profiles.isEmpty ||
        !overrides.isEmpty
    }

    @ViewBuilder
    private var deleteSectionDataControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Delete Section Data")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if !classDefinitions.isEmpty {
                deleteSectionButton(for: .savedContexts)
            }

            if !studentProfiles.isEmpty {
                deleteSectionButton(for: .studentDirectory)
            }

            if !teacherContacts.isEmpty {
                deleteSectionButton(for: .teachers)
            }

            if !paraContacts.isEmpty {
                deleteSectionButton(for: .paras)
            }

            if !profiles.isEmpty {
                deleteSectionButton(for: .scheduleProfiles)
            }

            if !overrides.isEmpty {
                deleteSectionButton(for: .dayOverrides)
            }
        }
        .padding(.top, 4)
    }

    private func deleteSectionButton(for target: DeleteDataTarget) -> some View {
        Button(role: .destructive) {
            pendingDeleteTarget = target
        } label: {
            Label(target.buttonTitle, systemImage: "trash")
        }
    }

    private var scheduleToolsSection: some View {
        Section("Sub Plans") {
            NavigationLink("Sub Plan Profile") {
                SubPlanProfileSettingsView()
            }

            Text("Keep substitute guidance and reusable handoff details together here.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var dataManagementSection: some View {
        Section("Data Management") {
            NavigationLink {
                ImportView(alarms: $alarms)
            } label: {
                Text("Import Schedule CSV")
            }

            NavigationLink {
                ExportView(alarms: $alarms)
            } label: {
                Text("Export Schedule CSV")
            }

            NavigationLink {
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
                    },
                    onPrepareStudentEditor: {}
                )
            } label: {
                Text("Student Roster Data")
            }

            if !alarms.isEmpty {
                Button(role: .destructive) {
                    pendingDeleteTarget = .scheduleBlocks
                } label: {
                    Label("Delete Schedule Blocks", systemImage: "trash")
                }
            }

            Text("Schedule CSV tools stay here, and student roster CSV import/export now lives here too. Core Setup stays focused on managing students and saved classes / groups.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            if diagnosticsToolsEnabled {
                ForEach(diagnosticsTools) { tool in
                    NavigationLink {
                        tool.destinationView
                    } label: {
                        LabeledContent(tool.title) {
                            Text(tool.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    insertDiagnosticsTestWorkspace()
                } label: {
                    LabeledContent("Load Sample Teacher Day") {
                        Text("Seed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }

                Text("Loads sample classes or groups, students, planner items, commitments, staff, and evening test blocks for the current weekday.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !diagnosticsStatusMessage.isEmpty {
                    Text(diagnosticsStatusMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Diagnostics tools are disabled for this build.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diagnosticsMenuSection: some View {
        Section("Diagnostics") {
            if diagnosticsToolsEnabled {
                Menu {
                    ForEach(diagnosticsTools) { tool in
                        Button(tool.title, systemImage: "wrench.and.screwdriver") {
                            selectedDiagnosticsTool = tool
                        }
                    }

                    Divider()

                    NavigationLink(value: SettingsDestination.liveActivities) {
                        Label("Live Activities", systemImage: SettingsDestination.liveActivities.systemImage)
                    }

                    NavigationLink(value: SettingsDestination.cloudSync) {
                        Label("Cloud Sync", systemImage: SettingsDestination.cloudSync.systemImage)
                    }

                    Divider()

                    Button("Refresh Cloud Sync Status", systemImage: "arrow.clockwise") {
                        refreshCloudKitDiagnostics()
                    }

                    Button("Initialize CloudKit Schema", systemImage: "icloud.and.arrow.up") {
                        initializeCloudKitSchema()
                    }

                    Divider()

                    Button("Load Sample Teacher Day", systemImage: "shippingbox") {
                        insertDiagnosticsTestWorkspace()
                    }

                    Button("Reset All User Data", systemImage: "trash", role: .destructive) {
                        pendingDeleteTarget = .allUserData
                    }
                } label: {
                    settingsRowLabel(.diagnostics, detail: "Hidden testing tools and sample-day actions for demos and QA")
                }

                if !diagnosticsStatusMessage.isEmpty {
                    Text(diagnosticsStatusMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var diagnosticsTools: [DiagnosticsTool] {
        diagnosticsToolsEnabled ? DiagnosticsTool.allCases : []
    }

    private var diagnosticsSummaryText: String {
        diagnosticsTools
            .map(\.title)
            .joined(separator: " • ")
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
            return "Use Guided Setup first, then build reusable classes and groups before spending time on advanced controls."
        }

        return "\(teacherWorkflowMode.displayName) mode is active. ClassTrax currently has \(classDefinitions.count) saved classes / groups and \(studentProfiles.count) students ready to reuse across schedules, planner items, and notes."
    }

    private var workspaceSetupCompletionLabel: String {
        switch (classDefinitions.isEmpty, studentProfiles.isEmpty, alarms.isEmpty) {
        case (true, _, _):
            return "Step 1"
        case (false, true, _):
            return "Step 2"
        case (false, false, true):
            return "Step 3"
        case (false, false, false):
            return "Ready"
        }
    }

    @ViewBuilder
    private var classDefinitionsDestinationView: some View {
        ClassDefinitionsView(classDefinitions: $classDefinitions, profiles: $studentProfiles)
    }

    @ViewBuilder
    private var studentDirectoryDestinationView: some View {
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
            },
            onPrepareStudentEditor: {}
        )
    }

    private var alertsWizardDestinationView: some View {
        Form {
            Section {
                Text(destinationDescription(.alerts))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            alertsSection
        }
        .navigationTitle("Alerts")
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
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

    private var lastCloudKitImportEventTimestampSummary: String {
        formattedSyncTimestamp(lastCloudKitImportEventTimestamp, empty: "No CloudKit import timestamp yet")
    }

    private var lastCloudKitExportEventTimestampSummary: String {
        formattedSyncTimestamp(lastCloudKitExportEventTimestamp, empty: "No CloudKit export timestamp yet")
    }

    private var isDebugBuild: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private var isCloudKitSchemaInitializationAvailable: Bool {
#if DEBUG
        true
#else
        false
#endif
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

    private func autolaunchGuidedSetupIfNeeded() {
        guard !showingWorkspaceSetupWizard else { return }
        guard !hasSeenGuidedSetupAutolaunch else { return }
        guard classDefinitions.isEmpty, studentProfiles.isEmpty, alarms.isEmpty else { return }
        hasSeenGuidedSetupAutolaunch = true
        showingWorkspaceSetupWizard = true
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

    private func performDelete(_ target: DeleteDataTarget) {
        switch target {
        case .savedContexts:
            classDefinitions = []
        case .studentDirectory:
            studentProfiles = []
        case .teachers:
            teacherContacts = []
        case .paras:
            paraContacts = []
        case .scheduleProfiles:
            profiles = []
        case .dayOverrides:
            overrides = []
        case .scheduleBlocks:
            alarms = []
        case .allUserData:
            resetAllUserData()
        }
    }

    private func resetAllUserData() {
        isLoadingInitialState = true

        alarms = []
        todos = []
        commitments = []
        profiles = []
        overrides = []
        studentProfiles = []
        classDefinitions = []
        teacherContacts = []
        paraContacts = []

        ClassTraxPersistence.saveFirstSlice(
            alarms: [],
            studentProfiles: [],
            classDefinitions: [],
            teacherContacts: [],
            paraContacts: [],
            commitments: [],
            into: modelContext
        )
        ClassTraxPersistence.saveSecondSlice(
            todos: [],
            followUpNotes: [],
            subPlans: [],
            dailySubPlans: [],
            into: modelContext
        )
        ClassTraxPersistence.saveThirdSlice(
            attendanceRecords: [],
            profiles: [],
            overrides: [],
            into: modelContext
        )

        savedAlarms = Data()
        savedCommitments = Data()
        savedProfiles = Data()
        savedOverrides = Data()
        savedTodos = Data()
        savedStudentProfiles = Data()
        savedClassDefinitions = Data()

        ignoreUntil = 0
        lastLocalMutationTimestamp = 0
        lastCloudRefreshTimestamp = 0
        lastCloudKitEventSummary = "No CloudKit sync events observed yet."
        lastCloudKitEventTimestamp = 0
        lastCloudKitImportEventSummary = "No CloudKit import events observed yet."
        lastCloudKitImportEventTimestamp = 0
        lastCloudKitExportEventSummary = "No CloudKit export events observed yet."
        lastCloudKitExportEventTimestamp = 0
        storedDashboardCardOrder = ""
        storedHiddenDashboardCards = ""
        hasSeenGuidedSetupAutolaunch = false

        let defaults = UserDefaults.standard
        [
            "attendance_v1_data",
            "sub_plans_v1_data",
            "daily_sub_plans_v1_data",
            "follow_up_notes_v1_data",
            "teacher_contacts_v1_data",
            "para_contacts_v1_data"
        ].forEach { defaults.removeObject(forKey: $0) }

        isLoadingInitialState = false
        diagnosticsStatusMessage = "All saved user data was cleared. Relaunch the app if any old screens are still showing cached data."
    }

    private func insertDiagnosticsTestWorkspace() {
        let prefix = "[Diagnostics]"
        let currentWeekday = Calendar.current.component(.weekday, from: Date())

        let seededTeachers: [ClassStaffContact] = [
            ClassStaffContact(
                name: "\(prefix) Teacher Redwood",
                room: "Room 201",
                cell: "555-0101",
                extensionNumber: "201",
                emailAddress: "redwood.teacher@test.local",
                subject: "Math / Intervention"
            ),
            ClassStaffContact(
                name: "\(prefix) Teacher Bluebird",
                room: "Room 204",
                cell: "555-0102",
                extensionNumber: "204",
                emailAddress: "bluebird.teacher@test.local",
                subject: "ELA / Support"
            )
        ]

        let seededParas: [ClassStaffContact] = [
            ClassStaffContact(
                name: "\(prefix) Para North",
                room: "Room 201",
                cell: "555-0201",
                extensionNumber: "221",
                emailAddress: "north.para@test.local",
                subject: "Push-In Support"
            ),
            ClassStaffContact(
                name: "\(prefix) Para South",
                room: "Room 204",
                cell: "555-0202",
                extensionNumber: "224",
                emailAddress: "south.para@test.local",
                subject: "Small Group Support"
            )
        ]

        let redwoodContext = ClassDefinitionItem(
            name: "\(prefix) Redwood Lab",
            scheduleType: .math,
            gradeLevel: "5",
            defaultLocation: "Room 201",
            teacherContacts: [seededTeachers[0]],
            paraContacts: [seededParas[0]]
        )

        let bluebirdContext = ClassDefinitionItem(
            name: "\(prefix) Bluebird Studio",
            scheduleType: .ela,
            gradeLevel: "6",
            defaultLocation: "Room 204",
            teacherContacts: [seededTeachers[1]],
            paraContacts: [seededParas[1]]
        )

        let seededDefinitions = [redwoodContext, bluebirdContext]

        let redwoodStudents = [
            "Avery Moss",
            "Jordan Hale",
            "Micah Stone",
            "Rowan Price"
        ].map { studentName in
            StudentSupportProfile(
                name: "\(prefix) \(studentName)",
                className: redwoodContext.name,
                gradeLevel: redwoodContext.gradeLevel,
                classDefinitionID: redwoodContext.id,
                classDefinitionIDs: [redwoodContext.id],
                classContexts: [
                    StudentSupportProfile.ClassContext(classDefinitionID: redwoodContext.id)
                ],
                supportTeacherIDs: [seededTeachers[0].id],
                supportParaIDs: [seededParas[0].id],
                supportRooms: redwoodContext.defaultLocation,
                accommodations: "Extended directions, frequent check-ins",
                prompts: "Prompt to start quickly and confirm final answer."
            )
        }

        let bluebirdStudents = [
            "Casey Brook",
            "Elliot Shore",
            "Harper Lane",
            "Parker Wren"
        ].map { studentName in
            StudentSupportProfile(
                name: "\(prefix) \(studentName)",
                className: bluebirdContext.name,
                gradeLevel: bluebirdContext.gradeLevel,
                classDefinitionID: bluebirdContext.id,
                classDefinitionIDs: [bluebirdContext.id],
                classContexts: [
                    StudentSupportProfile.ClassContext(classDefinitionID: bluebirdContext.id)
                ],
                supportTeacherIDs: [seededTeachers[1].id],
                supportParaIDs: [seededParas[1].id],
                supportRooms: bluebirdContext.defaultLocation,
                accommodations: "Chunked reading tasks, small-group prompting",
                prompts: "Preview expectations and redirect after each transition."
            )
        }

        let seededStudents = redwoodStudents + bluebirdStudents
        let redwoodStudentIDs = redwoodStudents.map(\.id)
        let bluebirdStudentIDs = bluebirdStudents.map(\.id)

        let seededBlocks: [AlarmItem] = [
            makeDiagnosticsBlock(
                title: "\(prefix) Redwood Session 1",
                location: redwoodContext.defaultLocation,
                type: .math,
                weekday: currentWeekday,
                gradeLevel: redwoodContext.gradeLevel,
                startHour: 17,
                startMinute: 0,
                endHour: 17,
                endMinute: 45,
                definition: redwoodContext,
                linkedStudentIDs: redwoodStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Bluebird Session 1",
                location: bluebirdContext.defaultLocation,
                type: .ela,
                weekday: currentWeekday,
                gradeLevel: bluebirdContext.gradeLevel,
                startHour: 17,
                startMinute: 50,
                endHour: 18,
                endMinute: 35,
                definition: bluebirdContext,
                linkedStudentIDs: bluebirdStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Redwood Session 2",
                location: redwoodContext.defaultLocation,
                type: .studyTime,
                weekday: currentWeekday,
                gradeLevel: redwoodContext.gradeLevel,
                startHour: 18,
                startMinute: 40,
                endHour: 19,
                endMinute: 25,
                definition: redwoodContext,
                linkedStudentIDs: redwoodStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Bluebird Session 2",
                location: bluebirdContext.defaultLocation,
                type: .ela,
                weekday: currentWeekday,
                gradeLevel: bluebirdContext.gradeLevel,
                startHour: 19,
                startMinute: 30,
                endHour: 20,
                endMinute: 15,
                definition: bluebirdContext,
                linkedStudentIDs: bluebirdStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Redwood Session 3",
                location: redwoodContext.defaultLocation,
                type: .math,
                weekday: currentWeekday,
                gradeLevel: redwoodContext.gradeLevel,
                startHour: 20,
                startMinute: 20,
                endHour: 21,
                endMinute: 5,
                definition: redwoodContext,
                linkedStudentIDs: redwoodStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Bluebird Session 3",
                location: bluebirdContext.defaultLocation,
                type: .studyTime,
                weekday: currentWeekday,
                gradeLevel: bluebirdContext.gradeLevel,
                startHour: 21,
                startMinute: 10,
                endHour: 21,
                endMinute: 55,
                definition: bluebirdContext,
                linkedStudentIDs: bluebirdStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Redwood Session 4",
                location: redwoodContext.defaultLocation,
                type: .math,
                weekday: currentWeekday,
                gradeLevel: redwoodContext.gradeLevel,
                startHour: 22,
                startMinute: 0,
                endHour: 22,
                endMinute: 45,
                definition: redwoodContext,
                linkedStudentIDs: redwoodStudentIDs
            ),
            makeDiagnosticsBlock(
                title: "\(prefix) Bluebird Session 4",
                location: bluebirdContext.defaultLocation,
                type: .ela,
                weekday: currentWeekday,
                gradeLevel: bluebirdContext.gradeLevel,
                startHour: 22,
                startMinute: 50,
                endHour: 23,
                endMinute: 59,
                definition: bluebirdContext,
                linkedStudentIDs: bluebirdStudentIDs
            )
        ]

        let seededTodos: [TodoItem] = [
            TodoItem(
                task: "\(prefix) Prep Redwood warm-up",
                priority: .high,
                dueDate: seededBlocks.first?.startTime,
                category: .prep,
                bucket: .today,
                linkedContext: redwoodContext.name,
                classLink: redwoodContext.id.uuidString
            ),
            TodoItem(
                task: "\(prefix) Check Bluebird reading notes",
                priority: .med,
                dueDate: seededBlocks.dropFirst().first?.startTime,
                category: .grading,
                bucket: .today,
                linkedContext: bluebirdContext.name,
                classLink: bluebirdContext.id.uuidString
            ),
            TodoItem(
                task: "\(prefix) Call Avery Moss family",
                priority: .high,
                dueDate: seededBlocks.last?.endTime,
                category: .parentContact,
                bucket: .today,
                linkedContext: redwoodContext.name,
                studentOrGroup: redwoodStudents[0].name,
                classLink: redwoodContext.id.uuidString,
                studentLink: redwoodStudents[0].id.uuidString
            ),
            TodoItem(
                task: "\(prefix) Prep Bluebird exit ticket copies",
                priority: .low,
                dueDate: seededBlocks.last?.startTime,
                category: .copies,
                bucket: .tomorrow,
                linkedContext: bluebirdContext.name,
                classLink: bluebirdContext.id.uuidString
            )
        ]

        let seededCommitments: [CommitmentItem] = [
            CommitmentItem(
                title: "\(prefix) Team check-in",
                kind: .meeting,
                dayOfWeek: currentWeekday,
                startTime: Calendar.current.date(bySettingHour: 17, minute: 35, second: 0, of: Date()) ?? Date(),
                endTime: Calendar.current.date(bySettingHour: 17, minute: 50, second: 0, of: Date()) ?? Date(),
                location: "Room 201",
                notes: "Quick sample meeting for Planner and Today testing."
            ),
            CommitmentItem(
                title: "\(prefix) Parent follow-up window",
                kind: .reminder,
                dayOfWeek: currentWeekday,
                startTime: Calendar.current.date(bySettingHour: 22, minute: 50, second: 0, of: Date()) ?? Date(),
                endTime: Calendar.current.date(bySettingHour: 23, minute: 10, second: 0, of: Date()) ?? Date(),
                location: "Office",
                notes: "Sample reminder block for end-of-day planning."
            )
        ]

        let updatedTeachers = mergeDiagnosticsContacts(existing: teacherContacts, seeded: seededTeachers, prefix: prefix)
        let updatedParas = mergeDiagnosticsContacts(existing: paraContacts, seeded: seededParas, prefix: prefix)
        let updatedDefinitions = mergeDiagnosticsDefinitions(existing: classDefinitions, seeded: seededDefinitions, prefix: prefix)
        let updatedStudents = mergeDiagnosticsStudents(existing: studentProfiles, seeded: seededStudents, prefix: prefix)
        let updatedAlarms = mergeDiagnosticsAlarms(existing: alarms, seeded: seededBlocks, prefix: prefix)
        let updatedTodos = mergeDiagnosticsTodos(existing: todos, seeded: seededTodos, prefix: prefix)
        let updatedCommitments = mergeDiagnosticsCommitments(existing: commitments, seeded: seededCommitments, prefix: prefix)

        isLoadingInitialState = true
        teacherContacts = updatedTeachers
        paraContacts = updatedParas
        classDefinitions = updatedDefinitions
        studentProfiles = updatedStudents
        alarms = updatedAlarms
        todos = updatedTodos
        commitments = updatedCommitments

        ClassTraxPersistence.saveFirstSlice(
            alarms: updatedAlarms,
            studentProfiles: updatedStudents,
            classDefinitions: updatedDefinitions,
            teacherContacts: updatedTeachers,
            paraContacts: updatedParas,
            commitments: updatedCommitments,
            into: modelContext
        )
        ClassTraxPersistence.saveSecondSlice(
            todos: updatedTodos,
            followUpNotes: ClassTraxPersistence.loadSecondSlice(from: modelContext).followUpNotes,
            subPlans: ClassTraxPersistence.loadSecondSlice(from: modelContext).subPlans,
            dailySubPlans: ClassTraxPersistence.loadSecondSlice(from: modelContext).dailySubPlans,
            into: modelContext
        )

        savedAlarms = (try? JSONEncoder().encode(updatedAlarms)) ?? Data()
        savedCommitments = (try? JSONEncoder().encode(updatedCommitments)) ?? Data()
        savedTodos = (try? JSONEncoder().encode(updatedTodos)) ?? Data()
        savedStudentProfiles = (try? JSONEncoder().encode(updatedStudents)) ?? Data()
        savedClassDefinitions = (try? JSONEncoder().encode(updatedDefinitions)) ?? Data()
        isLoadingInitialState = false
        refreshNotifications()

        diagnosticsStatusMessage = "Loaded a sample teacher day with 2 classes or groups, 8 students, planner items, commitments, staff, and 8 evening test blocks."
    }

    private func makeDiagnosticsBlock(
        title: String,
        location: String,
        type: AlarmItem.ScheduleType,
        weekday: Int,
        gradeLevel: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        definition: ClassDefinitionItem,
        linkedStudentIDs: [UUID]
    ) -> AlarmItem {
        let calendar = Calendar.current
        let referenceDate = Date()
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: referenceDate
        ) ?? referenceDate
        let end = calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: referenceDate
        ) ?? referenceDate

        return AlarmItem(
            dayOfWeek: weekday,
            className: title,
            location: location,
            gradeLevel: gradeLevel,
            startTime: start,
            endTime: end,
            type: type,
            classDefinitionID: definition.id,
            classDefinitionIDs: [definition.id],
            linkedStudentIDs: linkedStudentIDs,
            warningLeadTimes: []
        )
    }

    private func mergeDiagnosticsContacts(
        existing: [ClassStaffContact],
        seeded: [ClassStaffContact],
        prefix: String
    ) -> [ClassStaffContact] {
        let retained = existing.filter { !$0.name.hasPrefix(prefix) }
        return (retained + seeded).sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
    }

    private func mergeDiagnosticsDefinitions(
        existing: [ClassDefinitionItem],
        seeded: [ClassDefinitionItem],
        prefix: String
    ) -> [ClassDefinitionItem] {
        let retained = existing.filter { !$0.name.hasPrefix(prefix) }
        return (retained + seeded).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func mergeDiagnosticsStudents(
        existing: [StudentSupportProfile],
        seeded: [StudentSupportProfile],
        prefix: String
    ) -> [StudentSupportProfile] {
        let retained = existing.filter {
            !$0.name.hasPrefix(prefix) &&
            !$0.className.hasPrefix(prefix)
        }
        return (retained + seeded).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func mergeDiagnosticsAlarms(
        existing: [AlarmItem],
        seeded: [AlarmItem],
        prefix: String
    ) -> [AlarmItem] {
        let retained = existing.filter { !$0.className.hasPrefix(prefix) }
        return (retained + seeded).sorted {
            if $0.dayOfWeek != $1.dayOfWeek {
                return $0.dayOfWeek < $1.dayOfWeek
            }
            return $0.startTime < $1.startTime
        }
    }

    private func mergeDiagnosticsTodos(
        existing: [TodoItem],
        seeded: [TodoItem],
        prefix: String
    ) -> [TodoItem] {
        let retained = existing.filter { !$0.task.hasPrefix(prefix) }
        return (retained + seeded).sorted {
            let leftDate = $0.dueDate ?? .distantFuture
            let rightDate = $1.dueDate ?? .distantFuture
            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return $0.task.localizedCaseInsensitiveCompare($1.task) == .orderedAscending
        }
    }

    private func mergeDiagnosticsCommitments(
        existing: [CommitmentItem],
        seeded: [CommitmentItem],
        prefix: String
    ) -> [CommitmentItem] {
        let retained = existing.filter { !$0.title.hasPrefix(prefix) }
        return (retained + seeded).sorted {
            if $0.dayOfWeek != $1.dayOfWeek {
                return $0.dayOfWeek < $1.dayOfWeek
            }
            return $0.startTime < $1.startTime
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

    private func refreshCloudKitDiagnostics() {
        ClassTraxPersistence.refreshCloudKitDiagnosticsStatus()
        diagnosticsStatusMessage = ClassTraxPersistence.lastCloudKitEventSummary
    }

    private func initializeCloudKitSchema() {
        ClassTraxPersistence.initializeCloudKitDevelopmentSchemaIfNeeded()
        ClassTraxPersistence.refreshCloudKitDiagnosticsStatus()
        diagnosticsStatusMessage = ClassTraxPersistence.lastSchemaInitializationMessage
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

private struct WorkspaceSetupWizardView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var teacherWorkflowMode: TeacherWorkflowMode
    let contextCount: Int
    let studentCount: Int
    let hasSchedule: Bool
    let contextsDestination: AnyView
    let studentsDestination: AnyView
    let layoutDestination: AnyView
    let alertsDestination: AnyView

    @State private var currentStep = 0

    private let totalSteps = 4

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guided Setup")
                        .font(.title2.weight(.bold))

                    Text("Move through the core teacher setup in order so Today, Planner, and Notes feel coherent from the start.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                progressHeader

                Group {
                    switch currentStep {
                    case 0:
                        workflowStep
                    case 1:
                        contextsStep
                    case 2:
                        studentsStep
                    default:
                        finishStep
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                wizardControls
            }
            .padding()
        }
        .navigationTitle("Guided Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule(style: .continuous)
                    .fill(step <= currentStep ? Color.accentColor : Color(.systemGray5))
                    .frame(height: 8)
            }
        }
    }

    private var workflowStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("1. Choose Your Workflow")
                .font(.headline)

            Text("This shapes labels and defaults throughout the app, but it does not lock you in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Workflow Mode", selection: $teacherWorkflowMode) {
                ForEach(TeacherWorkflowMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Text(teacherWorkflowMode.settingsSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var contextsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("2. Save Your Classes / Groups")
                .font(.headline)

            Text("Add the classes, groups, or support sessions you reuse. Schedule blocks, attendance, homework, and notes all depend on these.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            wizardMetricRow(
                title: teacherWorkflowMode == .classroom ? "Saved Classes" : "Saved Groups",
                value: "\(contextCount)",
                accent: contextCount == 0 ? .orange : .blue
            )

            NavigationLink(destination: contextsDestination) {
                Label(contextCount == 0 ? "Open Saved Classes / Groups" : "Review Saved Classes / Groups", systemImage: "books.vertical")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var studentsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("3. Add Students")
                .font(.headline)

            Text("Build the student directory next so roster tools, support profiles, and in-class quick actions have real data to work with.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            wizardMetricRow(
                title: "Students",
                value: "\(studentCount)",
                accent: studentCount == 0 ? .orange : .green
            )

            NavigationLink(destination: studentsDestination) {
                Label(studentCount == 0 ? "Open Student Directory" : "Review Student Directory", systemImage: "person.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("4. Tune Today and Alerts")
                .font(.headline)

            Text("Once classes, groups, and students are in place, tighten the default dashboard and alert behavior. Then switch to Schedule to add your first real block.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            wizardMetricRow(
                title: "Schedule",
                value: hasSchedule ? "Ready" : "Next",
                accent: hasSchedule ? .indigo : .orange
            )

            NavigationLink(destination: layoutDestination) {
                Label("Set Today Defaults", systemImage: "rectangle.grid.1x2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink(destination: alertsDestination) {
                Label("Tune Alerts", systemImage: "bell.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(hasSchedule ? "Your workspace is ready. Keep refining from the live day flow." : "Next stop: open the Schedule tab and add your first block.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var wizardControls: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
            }

            Spacer()

            if currentStep < totalSteps - 1 {
                Button("Next") {
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Finish") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func wizardMetricRow(title: String, value: String, accent: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.12), in: Capsule(style: .continuous))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}
