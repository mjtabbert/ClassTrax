//
//  RootTabView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import SwiftUI
import SwiftData

// MARK: - App Tabs

enum AppTab: Hashable {
    case today
    case schedule
    case todo
    case notes
    case settings
}

// MARK: - Root Tab View

struct RootTabView: View {

    private static let cloudSyncRefreshInterval: Duration = .seconds(8)
    private static let localMutationRefreshPauseSeconds: TimeInterval = 4

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today
    @State private var selectedScheduleDay: WeekdayTab = .today

    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("commitments_v1_data") private var savedCommitments: Data = Data()
    @AppStorage("student_support_profiles_v1_data") private var savedStudentProfiles: Data = Data()
    @AppStorage("class_definitions_v1_data") private var savedClassDefinitions: Data = Data()
    @AppStorage("attendance_v1_data") private var savedAttendance: Data = Data()
    @AppStorage("sub_plans_v1_data") private var savedSubPlans: Data = Data()
    @AppStorage("daily_sub_plans_v1_data") private var savedDailySubPlans: Data = Data()
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()
    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []
    @State private var commitments: [CommitmentItem] = []
    @State private var studentProfiles: [StudentSupportProfile] = []
    @State private var classDefinitions: [ClassDefinitionItem] = []
    @State private var attendanceRecords: [AttendanceRecord] = []
    @State private var subPlans: [SubPlanItem] = []
    @State private var dailySubPlans: [DailySubPlanItem] = []
    @State private var profiles: [ScheduleProfile] = []
    @State private var overrides: [DayOverride] = []
    @State private var lastLocalMutationAt = Date.distantPast
    @State private var isRefreshingFromPersistence = false

    private var ignoreDate: Date? {
        ignoreUntil > 0 ? Date(timeIntervalSince1970: ignoreUntil) : nil
    }

    private var activeDayOverride: ActiveDayOverride? {
        resolvedDayOverride(
            for: Date(),
            overrides: overrides,
            profiles: profiles
        )
    }

    private var suggestedTaskContexts: [String] {
        let classContexts = alarms
            .map(\.className)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let commitmentContexts = commitments
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Array(Set((classContexts + commitmentContexts).filter { !$0.isEmpty }))
            .sorted()
    }

    private var suggestedStudents: [String] {
        let taskStudents = todos
            .map(\.studentOrGroup)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let profileStudents = studentProfiles.map(\.name)
        return normalizedStudentDirectory(profileStudents + taskStudents)
    }

    private var studentSupportsByName: [String: StudentSupportProfile] {
        Dictionary(uniqueKeysWithValues: studentProfiles.map { ($0.name, $0) })
    }

    private var baseTabView: some View {
        TabView(selection: $selectedTab) {
            todayTab
            scheduleTab
            todoTab
            notesTab
            settingsTab
        }
    }

    private func makeObservedTabView() -> AnyView {
        let lifecycleView = AnyView(
            baseTabView
                .onAppear { handleOnAppear() }
                .onChange(of: selectedTab) { _, newTab in
                    handleSelectedTabChange(newTab)
                }
                .onChange(of: alarms) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    handleAlarmsChange(newValue)
                }
                .onChange(of: todos) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveTodos(newValue)
                }
                .onChange(of: commitments) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveCommitments(newValue)
                }
        )

        let syncView = AnyView(
            lifecycleView
                .onChange(of: studentProfiles) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveStudentProfiles(newValue)
                }
                .onChange(of: classDefinitions) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveClassDefinitions(newValue)
                    reconcileClassDefinitionLinks()
                }
                .onChange(of: savedStudentProfiles) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    loadStudentProfiles()
                    reconcileClassDefinitionLinks()
                }
                .onChange(of: savedClassDefinitions) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    loadClassDefinitions()
                    reconcileClassDefinitionLinks()
                }
                .onChange(of: savedProfiles) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    loadProfiles()
                    refreshNotifications()
                }
                .onChange(of: savedOverrides) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    loadOverrides()
                    refreshNotifications()
                }
        )

        return AnyView(
            syncView
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        refreshFromCloudBackedStore()
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await runCloudSyncRefreshLoop()
                }
                .onChange(of: attendanceRecords) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    if let encoded = try? JSONEncoder().encode(newValue) {
                        savedAttendance = encoded
                    }
                    saveThirdPersistenceSlice(
                        attendanceRecords: newValue,
                        profiles: profiles,
                        overrides: overrides
                    )
                }
                .onChange(of: subPlans) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    if let encoded = try? JSONEncoder().encode(newValue) {
                        savedSubPlans = encoded
                    }
                    saveSecondPersistenceSlice(
                        todos: todos,
                        subPlans: newValue,
                        dailySubPlans: dailySubPlans
                    )
                }
                .onChange(of: dailySubPlans) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    if let encoded = try? JSONEncoder().encode(newValue) {
                        savedDailySubPlans = encoded
                    }
                    saveSecondPersistenceSlice(
                        todos: todos,
                        subPlans: subPlans,
                        dailySubPlans: newValue
                    )
                }
        )
    }

    var body: some View {
        makeObservedTabView()
    }

    private func handleOnAppear() {
        loadSavedData()
        selectedScheduleDay = .today
        refreshNotifications()
    }

    private func handleSelectedTabChange(_ newTab: AppTab) {
        if newTab == .schedule {
            selectedScheduleDay = .today
        }
    }

    private func handleAlarmsChange(_ newValue: [AlarmItem]) {
        saveAlarms(newValue)
        refreshNotifications()
    }

    @MainActor
    private func manuallyRefreshSyncedData() {
        refreshFromCloudBackedStore()
    }

    private var todayTab: some View {
        TodayView(
            alarms: $alarms,
            todos: $todos,
            commitments: $commitments,
            studentSupportProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            attendanceRecords: $attendanceRecords,
            subPlans: $subPlans,
            dailySubPlans: $dailySubPlans,
            suggestedStudents: suggestedStudents,
            studentSupportsByName: studentSupportsByName,
            activeOverrideName: activeDayOverride?.displayName,
            overrideSchedule: activeDayOverride?.alarms,
            ignoreDate: ignoreDate,
            onRefresh: {
                manuallyRefreshSyncedData()
            },
            openScheduleTab: {
            selectedTab = .schedule
        }, openTodoTab: {
            selectedTab = .todo
        }, openNotesTab: {
            selectedTab = .notes
        }, openSettingsTab: {
            selectedTab = .settings
        })
        .toolbar(.hidden, for: .tabBar)
        .tabItem {
            Label("Home", systemImage: "house")
        }
        .tag(AppTab.today)
    }

    private var scheduleTab: some View {
        ScheduleView(
            selectedDay: $selectedScheduleDay,
            alarms: $alarms,
            studentProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            activeOverrideName: activeDayOverride?.displayName,
            overrideSchedule: activeDayOverride?.alarms,
            onRefresh: {
                manuallyRefreshSyncedData()
            },
            openTodayTab: { selectedTab = .today }
        )
        .tabItem {
            Label("Schedule", systemImage: "calendar")
        }
        .tag(AppTab.schedule)
    }

    private var todoTab: some View {
        TodoListView(
            todos: $todos,
            studentProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            suggestedContexts: suggestedTaskContexts,
            suggestedStudents: suggestedStudents,
            studentSupportsByName: studentSupportsByName,
            onRefresh: {
                manuallyRefreshSyncedData()
            },
            openTodayTab: { selectedTab = .today }
        )
        .tabItem {
            Label("To Do", systemImage: "checklist")
        }
        .tag(AppTab.todo)
    }

    private var notesTab: some View {
        NotesView(
            todos: $todos,
            studentProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            suggestedContexts: suggestedTaskContexts,
            suggestedStudents: suggestedStudents,
            onRefresh: {
                manuallyRefreshSyncedData()
            },
            openTodayTab: { selectedTab = .today }
        )
            .tabItem {
                Label("Notes", systemImage: "note.text")
            }
            .tag(AppTab.notes)
    }

    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
    }

    // MARK: - Data Loading

    private func loadSavedData() {
        let legacyAlarms = decodeLegacyAlarms()
        let legacyCommitments = decodeLegacyCommitments()
        let legacyStudentProfiles = decodeLegacyStudentProfiles()
        let legacyClassDefinitions = decodeLegacyClassDefinitions()
        let legacyTodos = decodeLegacyTodos()
        let legacyFollowUpNotes = decodeLegacyFollowUpNotes()
        let legacySubPlans = decodeLegacySubPlans()
        let legacyDailySubPlans = decodeLegacyDailySubPlans()
        let legacyAttendanceRecords = decodeLegacyAttendanceRecords()
        let legacyProfiles = decodeLegacyProfiles()
        let legacyOverrides = decodeLegacyOverrides()

        ClassTraxPersistence.importFirstSliceIfNeeded(
            legacyAlarms: legacyAlarms,
            legacyStudentProfiles: legacyStudentProfiles,
            legacyClassDefinitions: legacyClassDefinitions,
            legacyCommitments: legacyCommitments,
            into: modelContext
        )
        ClassTraxPersistence.importSecondSliceIfNeeded(
            legacyTodos: legacyTodos,
            legacyFollowUpNotes: legacyFollowUpNotes,
            legacySubPlans: legacySubPlans,
            legacyDailySubPlans: legacyDailySubPlans,
            into: modelContext
        )
        ClassTraxPersistence.importThirdSliceIfNeeded(
            legacyAttendanceRecords: legacyAttendanceRecords,
            legacyProfiles: legacyProfiles,
            legacyOverrides: legacyOverrides,
            into: modelContext
        )

        refreshFromPersistence()
    }

    @MainActor
    private func refreshFromCloudBackedStore() {
        refreshFromPersistence()
        refreshNotifications()
    }

    private func recordLocalMutation() {
        lastLocalMutationAt = Date()
    }

    private func runCloudSyncRefreshLoop() async {
        while !Task.isCancelled && scenePhase == .active {
            try? await Task.sleep(for: Self.cloudSyncRefreshInterval)
            guard !Task.isCancelled, scenePhase == .active else { return }
            guard ClassTraxPersistence.activeContainerMode == .cloudKit else { continue }
            guard Date().timeIntervalSince(lastLocalMutationAt) >= Self.localMutationRefreshPauseSeconds else {
                continue
            }
            await MainActor.run {
                refreshFromCloudBackedStore()
            }
        }
    }

    private func refreshFromPersistence() {
        isRefreshingFromPersistence = true
        let persistenceSnapshot = ClassTraxPersistence.loadFirstSlice(from: modelContext)
        let secondSliceSnapshot = ClassTraxPersistence.loadSecondSlice(from: modelContext)
        let thirdSliceSnapshot = ClassTraxPersistence.loadThirdSlice(from: modelContext)
        alarms = persistenceSnapshot.alarms.map {
            AlarmItem(
                id: $0.id,
                dayOfWeek: $0.dayOfWeek,
                className: $0.className,
                location: $0.location,
                gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                startTime: $0.startTime,
                endTime: $0.endTime,
                type: $0.type,
                classDefinitionID: $0.classDefinitionID,
                linkedStudentIDs: $0.linkedStudentIDs
            )
        }
        commitments = persistenceSnapshot.commitments
        studentProfiles = persistenceSnapshot.studentProfiles
            .map {
                StudentSupportProfile(
                    id: $0.id,
                    name: $0.name,
                    className: $0.className,
                    gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                    classDefinitionID: $0.classDefinitionID,
                    graduationYear: $0.graduationYear,
                    parentNames: $0.parentNames,
                    parentPhoneNumbers: $0.parentPhoneNumbers,
                    parentEmails: $0.parentEmails,
                    studentEmail: $0.studentEmail,
                    accommodations: $0.accommodations,
                    prompts: $0.prompts
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        classDefinitions = persistenceSnapshot.classDefinitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        todos = secondSliceSnapshot.todos
        savedFollowUpNotes = (try? JSONEncoder().encode(secondSliceSnapshot.followUpNotes)) ?? Data()
        reconcileClassDefinitionLinks()
        attendanceRecords = thirdSliceSnapshot.attendanceRecords
        subPlans = secondSliceSnapshot.subPlans
        dailySubPlans = secondSliceSnapshot.dailySubPlans
        profiles = thirdSliceSnapshot.profiles
        overrides = thirdSliceSnapshot.overrides
        savedAttendance = (try? JSONEncoder().encode(thirdSliceSnapshot.attendanceRecords)) ?? Data()
        savedProfiles = (try? JSONEncoder().encode(thirdSliceSnapshot.profiles)) ?? Data()
        savedOverrides = (try? JSONEncoder().encode(thirdSliceSnapshot.overrides)) ?? Data()

        Task { @MainActor in
            isRefreshingFromPersistence = false
        }
    }

    // MARK: - Save Alarms

    private func saveAlarms(_ alarms: [AlarmItem]) {
        saveFirstPersistenceSlice(alarms: alarms, studentProfiles: studentProfiles, classDefinitions: classDefinitions, commitments: commitments)
        if let encoded = try? JSONEncoder().encode(alarms) {
            savedAlarms = encoded
        }
    }

    // MARK: - Save Todos

    private func saveTodos(_ todos: [TodoItem]) {
        saveSecondPersistenceSlice(
            todos: todos,
            subPlans: subPlans,
            dailySubPlans: dailySubPlans
        )

        if let encoded = try? JSONEncoder().encode(todos) {
            savedTodos = encoded
        }
    }

    private func saveCommitments(_ commitments: [CommitmentItem]) {
        saveFirstPersistenceSlice(alarms: alarms, studentProfiles: studentProfiles, classDefinitions: classDefinitions, commitments: commitments)
        if let encoded = try? JSONEncoder().encode(commitments) {
            savedCommitments = encoded
        }
    }

    private func loadStudentProfiles() {
        let snapshot = ClassTraxPersistence.loadFirstSlice(from: modelContext)
        studentProfiles = snapshot.studentProfiles
            .map {
                StudentSupportProfile(
                    id: $0.id,
                    name: $0.name,
                    className: $0.className,
                    gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                    classDefinitionID: $0.classDefinitionID,
                    graduationYear: $0.graduationYear,
                    parentNames: $0.parentNames,
                    parentPhoneNumbers: $0.parentPhoneNumbers,
                    parentEmails: $0.parentEmails,
                    studentEmail: $0.studentEmail,
                    accommodations: $0.accommodations,
                    prompts: $0.prompts
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadClassDefinitions() {
        let snapshot = ClassTraxPersistence.loadFirstSlice(from: modelContext)
        classDefinitions = snapshot.classDefinitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func saveStudentProfiles(_ profiles: [StudentSupportProfile]) {
        saveFirstPersistenceSlice(alarms: alarms, studentProfiles: profiles, classDefinitions: classDefinitions, commitments: commitments)
        savedStudentProfiles = (try? JSONEncoder().encode(profiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })) ?? Data()
    }

    private func saveClassDefinitions(_ definitions: [ClassDefinitionItem]) {
        saveFirstPersistenceSlice(alarms: alarms, studentProfiles: studentProfiles, classDefinitions: definitions, commitments: commitments)
        savedClassDefinitions = (try? JSONEncoder().encode(definitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        })) ?? Data()
    }

    private func saveFirstPersistenceSlice(
        alarms: [AlarmItem],
        studentProfiles: [StudentSupportProfile],
        classDefinitions: [ClassDefinitionItem],
        commitments: [CommitmentItem]
    ) {
        ClassTraxPersistence.saveFirstSlice(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            commitments: commitments,
            into: modelContext
        )
    }

    private func saveSecondPersistenceSlice(
        todos: [TodoItem],
        subPlans: [SubPlanItem],
        dailySubPlans: [DailySubPlanItem]
    ) {
        ClassTraxPersistence.saveSecondSlice(
            todos: todos,
            followUpNotes: ClassTraxPersistence.loadFollowUpNotes(from: modelContext),
            subPlans: subPlans,
            dailySubPlans: dailySubPlans,
            into: modelContext
        )
    }

    private func decodeLegacyAlarms() -> [AlarmItem] {
        guard let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) else {
            return []
        }
        return decodedAlarms.map {
            AlarmItem(
                id: $0.id,
                dayOfWeek: $0.dayOfWeek,
                className: $0.className,
                location: $0.location,
                gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                startTime: $0.startTime,
                endTime: $0.endTime,
                type: $0.type,
                classDefinitionID: $0.classDefinitionID,
                linkedStudentIDs: $0.linkedStudentIDs
            )
        }
    }

    private func decodeLegacyCommitments() -> [CommitmentItem] {
        (try? JSONDecoder().decode([CommitmentItem].self, from: savedCommitments)) ?? []
    }

    private func decodeLegacyStudentProfiles() -> [StudentSupportProfile] {
        guard let decoded = try? JSONDecoder().decode([StudentSupportProfile].self, from: savedStudentProfiles) else {
            return []
        }
        return decoded.map {
            StudentSupportProfile(
                id: $0.id,
                name: $0.name,
                className: $0.className,
                gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                classDefinitionID: $0.classDefinitionID,
                graduationYear: $0.graduationYear,
                parentNames: $0.parentNames,
                parentPhoneNumbers: $0.parentPhoneNumbers,
                parentEmails: $0.parentEmails,
                studentEmail: $0.studentEmail,
                accommodations: $0.accommodations,
                prompts: $0.prompts
            )
        }
    }

    private func decodeLegacyClassDefinitions() -> [ClassDefinitionItem] {
        (try? JSONDecoder().decode([ClassDefinitionItem].self, from: savedClassDefinitions)) ?? []
    }

    private func decodeLegacyTodos() -> [TodoItem] {
        (try? JSONDecoder().decode([TodoItem].self, from: savedTodos)) ?? []
    }

    private func decodeLegacyFollowUpNotes() -> [FollowUpNoteItem] {
        (try? JSONDecoder().decode([FollowUpNoteItem].self, from: savedFollowUpNotes)) ?? []
    }

    private func decodeLegacySubPlans() -> [SubPlanItem] {
        (try? JSONDecoder().decode([SubPlanItem].self, from: savedSubPlans)) ?? []
    }

    private func decodeLegacyDailySubPlans() -> [DailySubPlanItem] {
        (try? JSONDecoder().decode([DailySubPlanItem].self, from: savedDailySubPlans)) ?? []
    }

    private func reconcileClassDefinitionLinks() {
        alarms = alarms.map { alarm in
            var updated = alarm
            if updated.classDefinitionID == nil {
                updated.classDefinitionID = exactClassDefinitionMatch(
                    name: updated.className,
                    gradeLevel: updated.gradeLevel,
                    in: classDefinitions
                )?.id
            }
            return updated
        }

        studentProfiles = studentProfiles.map { profile in
            var updated = profile
            if updated.classDefinitionID == nil {
                updated.classDefinitionID = exactClassDefinitionMatch(
                    name: updated.className,
                    gradeLevel: updated.gradeLevel,
                    in: classDefinitions
                )?.id
            }
            return updated
        }
    }

    private func loadProfiles() {
        let decodedProfiles = decodeLegacyProfiles()
        saveThirdPersistenceSlice(
            attendanceRecords: attendanceRecords,
            profiles: decodedProfiles,
            overrides: overrides
        )
        profiles = decodedProfiles
    }

    private func loadOverrides() {
        let decodedOverrides = decodeLegacyOverrides()
        saveThirdPersistenceSlice(
            attendanceRecords: attendanceRecords,
            profiles: profiles,
            overrides: decodedOverrides
        )
        overrides = decodedOverrides
    }

    private func refreshNotifications() {
        NotificationManager.shared.refreshNotifications(
            for: alarms,
            activeOverrideSchedule: activeDayOverride?.alarms,
            activeOverrideDate: activeDayOverride?.date,
            overrides: overrides,
            profiles: profiles
        )
    }

    private func saveThirdPersistenceSlice(
        attendanceRecords: [AttendanceRecord],
        profiles: [ScheduleProfile],
        overrides: [DayOverride]
    ) {
        ClassTraxPersistence.saveThirdSlice(
            attendanceRecords: attendanceRecords,
            profiles: profiles,
            overrides: overrides,
            into: modelContext
        )
    }

    private func decodeLegacyAttendanceRecords() -> [AttendanceRecord] {
        (try? JSONDecoder().decode([AttendanceRecord].self, from: savedAttendance)) ?? []
    }

    private func decodeLegacyProfiles() -> [ScheduleProfile] {
        (try? JSONDecoder().decode([ScheduleProfile].self, from: savedProfiles)) ?? []
    }

    private func decodeLegacyOverrides() -> [DayOverride] {
        (try? JSONDecoder().decode([DayOverride].self, from: savedOverrides)) ?? []
    }
}
