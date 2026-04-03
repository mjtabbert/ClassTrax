//
//  RootTabView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - App Tabs

enum AppTab: Hashable {
    case today
    case attendance
    case schedule
    case students
    case todo
    case notes
}

// MARK: - Root Tab View

struct RootTabView: View {

    private static let cloudSyncRefreshInterval: Duration = .seconds(15)
    private static let localMutationRefreshPauseSeconds: TimeInterval = 4
    private static let runtimeSyncHeartbeatInterval: Duration = .seconds(10)
    private static let persistenceDebounceInterval: Duration = .milliseconds(450)

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: AppTab = .today
    @State private var selectedScheduleDay: WeekdayTab = .today
    @State private var showingSettings = false

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
    @AppStorage("live_activities_enabled") private var liveActivitiesEnabled = true
    @AppStorage("cloud_sync_last_local_mutation_at") private var storedLastLocalMutationAt: Double = 0
    @AppStorage("cloud_sync_last_refresh_at") private var storedLastCloudRefreshAt: Double = 0

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []
    @State private var commitments: [CommitmentItem] = []
    @State private var studentProfiles: [StudentSupportProfile] = []
    @State private var classDefinitions: [ClassDefinitionItem] = []
    @State private var teacherContacts: [ClassStaffContact] = []
    @State private var paraContacts: [ClassStaffContact] = []
    @State private var attendanceRecords: [AttendanceRecord] = []
    @State private var subPlans: [SubPlanItem] = []
    @State private var dailySubPlans: [DailySubPlanItem] = []
    @State private var profiles: [ScheduleProfile] = []
    @State private var overrides: [DayOverride] = []
    @State private var lastLocalMutationAt = Date.distantPast
    @State private var isRefreshingFromPersistence = false
    @State private var pendingLiveActivityStopTask: Task<Void, Never>?
    @State private var pendingNotificationRefreshTask: Task<Void, Never>?
    @State private var pendingFirstSliceSaveTask: Task<Void, Never>?
    @State private var pendingSecondSliceSaveTask: Task<Void, Never>?
    @State private var pendingThirdSliceSaveTask: Task<Void, Never>?
    @State private var lastSyncedWidgetSnapshot: ClassTraxWidgetSnapshot?
    @State private var lastSyncedLiveActivitySnapshot: RootLiveActivitySnapshot?
    @State private var lastNotificationRefreshSignature: NotificationRefreshSignature?
    @State private var lastCloudBackedRefreshAt = Date.distantPast
    @State private var hasBootstrappedInitialData = false

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
            .flatMap { [$0.effectiveStudentLink, $0.effectiveStudentGroupLink, $0.effectiveStudentOrGroup] }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let profileStudents = studentProfiles.map(\.name)
        return normalizedStudentDirectory(profileStudents + taskStudents)
    }

    private var studentSupportsByName: [String: StudentSupportProfile] {
        studentProfiles.reduce(into: [String: StudentSupportProfile]()) { partialResult, profile in
            partialResult[profile.name] = profile
        }
    }

    private var baseTabView: some View {
        TabView(selection: $selectedTab) {
            todayTab
            attendanceTab
            scheduleTab
            studentsTab
            todoTab
            notesTab
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
                    syncSharedSnapshot()
                }
                .onChange(of: ignoreUntil) { _, _ in
                    refreshNotifications(immediate: true)
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
                    syncSharedSnapshot()
                }
                .onChange(of: savedStudentProfiles) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        loadStudentProfiles()
                        reconcileClassDefinitionLinks()
                    }
                }
                .onChange(of: savedClassDefinitions) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        loadClassDefinitions()
                        reconcileClassDefinitionLinks()
                        syncSharedSnapshot()
                    }
                }
                .onChange(of: savedProfiles) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        loadProfiles()
                        refreshNotifications()
                    }
                }
                .onChange(of: savedOverrides) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        loadOverrides()
                        refreshNotifications()
                        syncSharedSnapshot()
                    }
                }
        )

        return AnyView(
            syncView
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        ignoreUntil = ScheduleSnoozeStore.synchronize()
                        refreshFromCloudBackedStore()
                        syncSharedSnapshot()
                    }
                }
                .task {
                    for await _ in NotificationCenter.default.notifications(
                        named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
                    ) {
                        let resolvedIgnoreUntil = ScheduleSnoozeStore.synchronize()
                        await MainActor.run {
                            ignoreUntil = resolvedIgnoreUntil
                        }
                    }
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await runCloudSyncRefreshLoop()
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while scenePhase == .active && !Task.isCancelled {
                        syncRuntimeState(now: Date())
                        try? await Task.sleep(for: Self.runtimeSyncHeartbeatInterval)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        flushPendingPersistenceSaves()
                        syncLiveActivity(now: Date())
                    }
                }
                .onAppear {
                    syncLiveActivity(now: Date())
                }
                .onChange(of: attendanceRecords) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveAttendanceRecords(newValue)
                }
                .onChange(of: subPlans) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveSubPlans(newValue)
                }
                .onChange(of: dailySubPlans) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveDailySubPlans(newValue)
                    syncSharedSnapshot()
                }
        )
    }

    var body: some View {
        makeObservedTabView()
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
    }

    private func handleOnAppear() {
        ignoreUntil = ScheduleSnoozeStore.synchronize()
        selectedScheduleDay = .today

        guard !hasBootstrappedInitialData else {
            syncRuntimeState(now: Date())
            return
        }

        hasBootstrappedInitialData = true

        Task { @MainActor in
            await Task.yield()
            loadSavedData()
            refreshNotifications(immediate: true)
            syncRuntimeState(now: Date())
        }
    }

    private func handleSelectedTabChange(_ newTab: AppTab) {
        if newTab == .schedule {
            selectedScheduleDay = .today
        }
    }

    private func handleAlarmsChange(_ newValue: [AlarmItem]) {
        let normalized = normalizedAlarms(newValue)
        if normalized != newValue {
            alarms = normalized
            return
        }

        saveAlarms(normalized)
        refreshNotifications()
    }

    private func syncSharedSnapshot(now: Date = Date()) {
        let snapshot = watchSnapshot(now: now)
        guard snapshot != lastSyncedWidgetSnapshot else { return }
        lastSyncedWidgetSnapshot = snapshot
        WidgetSnapshotStore.save(snapshot)
        WatchSessionSyncManager.shared.sync(snapshot: snapshot)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassTraxHomeWidget")
#endif
    }

    private func syncLiveActivity(now: Date) {
        pendingLiveActivityStopTask?.cancel()

        guard liveActivitiesEnabled else {
            LiveActivityManager.stop()
            return
        }

        let snapshot = liveActivitySnapshot(now: now)
        guard let snapshot else {
            lastSyncedLiveActivitySnapshot = nil
            pendingLiveActivityStopTask = Task {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                LiveActivityManager.stop()
            }
            return
        }

        guard snapshot != lastSyncedLiveActivitySnapshot else { return }
        lastSyncedLiveActivitySnapshot = snapshot

        LiveActivityManager.sync(
            className: snapshot.className,
            room: snapshot.room,
            endTime: snapshot.endTime,
            isHeld: snapshot.isHeld,
            iconName: snapshot.iconName,
            nextClassName: snapshot.nextClassName,
            nextIconName: snapshot.nextIconName
        )
    }

    private func syncRuntimeState(now: Date) {
        syncSharedSnapshot(now: now)
        syncLiveActivity(now: now)
    }

    private func watchSnapshot(now: Date) -> ClassTraxWidgetSnapshot {
        let schedule = adjustedTodaySchedule(for: now)
        let activeItem = schedule.first {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }
        let nextItem = displayableNextItem(schedule.first {
            startDateToday(for: $0, now: now) > now
        }, now: now)

        func summary(for item: AlarmItem) -> ClassTraxWidgetSnapshot.BlockSummary {
            ClassTraxWidgetSnapshot.BlockSummary(
                id: item.id,
                className: item.className,
                room: item.location.trimmingCharacters(in: .whitespacesAndNewlines),
                gradeLevel: item.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                symbolName: item.scheduleType.symbolName,
                startTime: startDateToday(for: item, now: now),
                endTime: endDateToday(for: item, now: now),
                typeName: item.typeLabel,
                isHeld: SessionControlStore.isHeld(itemID: item.id)
            )
        }

        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: activeItem.map(summary),
            next: nextItem.map(summary)
        )
    }

    private func liveActivitySnapshot(now: Date) -> RootLiveActivitySnapshot? {
        let schedule = adjustedTodaySchedule(for: now)
        guard let activeItem = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }) else {
            return nil
        }

        let nextItem = displayableNextItem(schedule.first {
            startDateToday(for: $0, now: now) > now
        }, now: now)

        let liveHold = liveHoldDuration(for: activeItem, now: now)
        let stableEndTime = endDateToday(for: activeItem, now: now).addingTimeInterval(-liveHold)

        return RootLiveActivitySnapshot(
            className: activeItem.className,
            room: activeItem.location.trimmingCharacters(in: .whitespacesAndNewlines),
            endTime: stableEndTime,
            isHeld: SessionControlStore.isHeld(itemID: activeItem.id),
            iconName: activeItem.scheduleType.symbolName,
            nextClassName: nextItem?.className ?? "",
            nextIconName: nextItem?.scheduleType.symbolName ?? ""
        )
    }

    private func adjustedTodaySchedule(for now: Date) -> [AlarmItem] {
        let weekday = Calendar.current.component(.weekday, from: now)
        let todaysItems = (activeDayOverride?.alarms ?? alarms)
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }

        var cumulativeOffset: TimeInterval = 0
        var adjustedItems: [AlarmItem] = []

        for item in todaysItems {
            var adjusted = item
            adjusted.start = item.start.addingTimeInterval(cumulativeOffset)

            let extra = (SessionControlStore.extraTimeByItemID()[item.id] ?? 0) + liveHoldDuration(for: item, now: now)
            adjusted.end = item.end
                .addingTimeInterval(cumulativeOffset)
                .addingTimeInterval(extra)

            adjustedItems.append(adjusted)
            cumulativeOffset += extra
        }

        return adjustedItems
    }

    private func startDateToday(for item: AlarmItem, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.startTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    private func endDateToday(for item: AlarmItem, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.endTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    private func liveHoldDuration(for item: AlarmItem, now: Date) -> TimeInterval {
        SessionControlStore.liveHoldDuration(for: item.id, now: now)
    }

    private func displayableNextItem(_ item: AlarmItem?, now: Date) -> AlarmItem? {
        guard let item else { return nil }
        guard startDateToday(for: item, now: now).timeIntervalSince(now) <= 7200 else { return nil }
        return item
    }

    @MainActor
    private func manuallyRefreshSyncedData() {
        refreshFromCloudBackedStore(force: true)
    }

    private var todayTab: some View {
        NavigationStack {
            TodayView(
                alarms: $alarms,
                todos: $todos,
                commitments: $commitments,
                studentSupportProfiles: $studentProfiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
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
                }, openStudentsTab: {
                    selectedTab = .students
                }, openTodoTab: {
                    selectedTab = .todo
                }, openNotesTab: {
                    selectedTab = .notes
                }, openSettingsTab: {
                    showingSettings = true
                })
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .tabItem {
            tabLabel(title: "Today", systemImage: "house")
        }
        .accessibilityLabel("Home")
        .tag(AppTab.today)
    }

    private var scheduleTab: some View {
        ScheduleView(
            selectedDay: $selectedScheduleDay,
            alarms: $alarms,
            todos: $todos,
            subPlans: $subPlans,
            dailySubPlans: $dailySubPlans,
            studentProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            teacherContacts: $teacherContacts,
            paraContacts: $paraContacts,
            commitments: $commitments,
            activeOverrideName: activeDayOverride?.displayName,
            overrideSchedule: activeDayOverride?.alarms,
            onRefresh: {
                manuallyRefreshSyncedData()
            },
            openTodayTab: { selectedTab = .today },
            openTodoTab: { selectedTab = .todo },
            openNotesTab: { selectedTab = .notes }
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                overflowMenu
            }
        }
        .tabItem {
            tabLabel(title: "Schedule", systemImage: "calendar")
        }
        .accessibilityLabel("Schedule")
        .tag(AppTab.schedule)
    }

    private var attendanceTab: some View {
        NavigationStack {
            AttendanceWorkspaceView(
                alarms: $alarms,
                studentProfiles: $studentProfiles,
                attendanceRecords: $attendanceRecords,
                overrideSchedule: activeDayOverride?.alarms
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .tabItem {
            tabLabel(title: "Attendance", systemImage: "checklist.checked")
        }
        .accessibilityLabel("Attendance")
        .tag(AppTab.attendance)
    }

    private var studentsTab: some View {
        NavigationStack {
            StudentsHubView(
                profiles: $studentProfiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .tabItem {
            tabLabel(title: "Students", systemImage: "person.3")
        }
        .accessibilityLabel("Classes and Students")
        .tag(AppTab.students)
    }

    private var todoTab: some View {
        NavigationStack {
            TodoListView(
                todos: $todos,
                studentProfiles: $studentProfiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
                suggestedContexts: suggestedTaskContexts,
                suggestedStudents: suggestedStudents,
                studentSupportsByName: studentSupportsByName,
                onRefresh: {
                    manuallyRefreshSyncedData()
                },
                openTodayTab: { selectedTab = .today }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .tabItem {
            tabLabel(title: "Tasks", systemImage: "checklist")
        }
        .accessibilityLabel("To Do")
        .tag(AppTab.todo)
    }

    private var notesTab: some View {
        NavigationStack {
            NotesView(
                studentProfiles: $studentProfiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
                suggestedContexts: suggestedTaskContexts,
                suggestedStudents: suggestedStudents,
                onRefresh: {
                    manuallyRefreshSyncedData()
                },
                openTodayTab: { selectedTab = .today }
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
        }
        .tabItem {
            tabLabel(title: "Notes", systemImage: "square.and.pencil")
        }
        .accessibilityLabel("Notes")
        .tag(AppTab.notes)
    }

    private var overflowMenu: some View {
        Button {
            showingSettings = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: "gearshape")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityLabel("Settings")
    }

    private func tabLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
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
    private func refreshFromCloudBackedStore(force: Bool = false) {
        if !force, Date().timeIntervalSince(lastCloudBackedRefreshAt) < 10 {
            return
        }
        lastCloudBackedRefreshAt = Date()
        storedLastCloudRefreshAt = lastCloudBackedRefreshAt.timeIntervalSince1970
        refreshFromPersistence()
        refreshNotifications()
    }

    private func recordLocalMutation() {
        lastLocalMutationAt = Date()
        storedLastLocalMutationAt = lastLocalMutationAt.timeIntervalSince1970
    }

    private func handleLegacyStorageChange(_ applyLegacySnapshot: () -> Void) {
        if ClassTraxPersistence.activeContainerMode == .cloudKit {
            refreshFromPersistence()
        } else {
            applyLegacySnapshot()
        }
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
                    classDefinitionIDs: linkedClassDefinitionIDs(for: $0),
                    classContexts: $0.classContexts,
                    graduationYear: $0.graduationYear,
                    parentNames: $0.parentNames,
                    parentPhoneNumbers: $0.parentPhoneNumbers,
                    parentEmails: $0.parentEmails,
                    studentEmail: $0.studentEmail,
                    isSped: $0.isSped,
                    supportTeacherIDs: $0.supportTeacherIDs,
                    supportParaIDs: $0.supportParaIDs,
                    supportRooms: $0.supportRooms,
                    supportScheduleNotes: $0.supportScheduleNotes,
                    accommodations: $0.accommodations,
                    prompts: $0.prompts
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        classDefinitions = persistenceSnapshot.classDefinitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        teacherContacts = persistenceSnapshot.teacherContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        paraContacts = persistenceSnapshot.paraContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        todos = secondSliceSnapshot.todos
        savedFollowUpNotes = (try? JSONEncoder().encode(secondSliceSnapshot.followUpNotes)) ?? Data()
        reconcileClassDefinitionLinks()
        attendanceRecords = AttendanceRecord.pruneToCurrentWeek(thirdSliceSnapshot.attendanceRecords)
        subPlans = secondSliceSnapshot.subPlans
        dailySubPlans = secondSliceSnapshot.dailySubPlans
        profiles = thirdSliceSnapshot.profiles
        overrides = thirdSliceSnapshot.overrides
        savedAttendance = (try? JSONEncoder().encode(attendanceRecords)) ?? Data()
        savedProfiles = (try? JSONEncoder().encode(thirdSliceSnapshot.profiles)) ?? Data()
        savedOverrides = (try? JSONEncoder().encode(thirdSliceSnapshot.overrides)) ?? Data()

        Task { @MainActor in
            isRefreshingFromPersistence = false
        }
    }

    // MARK: - Save Alarms

    private func saveAlarms(_ alarms: [AlarmItem]) {
        let normalized = normalizedAlarms(alarms)
        if let encoded = try? JSONEncoder().encode(normalized) {
            savedAlarms = encoded
        }
        scheduleFirstPersistenceSave(
            alarms: normalized,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func normalizedAlarms(_ alarms: [AlarmItem]) -> [AlarmItem] {
        alarms.sorted { lhs, rhs in
            if lhs.dayOfWeek == rhs.dayOfWeek {
                if lhs.startTime == rhs.startTime {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.startTime < rhs.startTime
            }
            return lhs.dayOfWeek < rhs.dayOfWeek
        }
    }

    // MARK: - Save Todos

    private func saveTodos(_ todos: [TodoItem]) {
        if let encoded = try? JSONEncoder().encode(todos) {
            savedTodos = encoded
        }

        scheduleSecondPersistenceSave(
            todos: todos,
            subPlans: subPlans,
            dailySubPlans: dailySubPlans
        )
    }

    private func saveCommitments(_ commitments: [CommitmentItem]) {
        if let encoded = try? JSONEncoder().encode(commitments) {
            savedCommitments = encoded
        }
        scheduleFirstPersistenceSave(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func loadStudentProfiles() {
        let decodedProfiles = decodeLegacyStudentProfiles()
        studentProfiles = decodedProfiles
            .map {
                StudentSupportProfile(
                    id: $0.id,
                    name: $0.name,
                    className: $0.className,
                    gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                    classDefinitionID: $0.classDefinitionID,
                    classDefinitionIDs: linkedClassDefinitionIDs(for: $0),
                    classContexts: $0.classContexts,
                    graduationYear: $0.graduationYear,
                    parentNames: $0.parentNames,
                    parentPhoneNumbers: $0.parentPhoneNumbers,
                    parentEmails: $0.parentEmails,
                    studentEmail: $0.studentEmail,
                    isSped: $0.isSped,
                    supportTeacherIDs: $0.supportTeacherIDs,
                    supportParaIDs: $0.supportParaIDs,
                    supportRooms: $0.supportRooms,
                    supportScheduleNotes: $0.supportScheduleNotes,
                    accommodations: $0.accommodations,
                    prompts: $0.prompts
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadClassDefinitions() {
        classDefinitions = decodeLegacyClassDefinitions().sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func saveStudentProfiles(_ profiles: [StudentSupportProfile]) {
        savedStudentProfiles = (try? JSONEncoder().encode(profiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })) ?? Data()
        scheduleFirstPersistenceSave(
            alarms: alarms,
            studentProfiles: profiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func saveClassDefinitions(_ definitions: [ClassDefinitionItem]) {
        savedClassDefinitions = (try? JSONEncoder().encode(definitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        })) ?? Data()
        scheduleFirstPersistenceSave(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: definitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func saveTeacherContacts(_ contacts: [ClassStaffContact]) {
        teacherContacts = contacts.sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
        scheduleFirstPersistenceSave(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func saveParaContacts(_ contacts: [ClassStaffContact]) {
        paraContacts = contacts.sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
        scheduleFirstPersistenceSave(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
    }

    private func saveAttendanceRecords(_ records: [AttendanceRecord]) {
        let prunedRecords = AttendanceRecord.pruneToCurrentWeek(records)
        if let encoded = try? JSONEncoder().encode(prunedRecords) {
            savedAttendance = encoded
        }
        scheduleThirdPersistenceSave(
            attendanceRecords: prunedRecords,
            profiles: profiles,
            overrides: overrides
        )
    }

    private func saveSubPlans(_ plans: [SubPlanItem]) {
        if let encoded = try? JSONEncoder().encode(plans) {
            savedSubPlans = encoded
        }
        scheduleSecondPersistenceSave(
            todos: todos,
            subPlans: plans,
            dailySubPlans: dailySubPlans
        )
    }

    private func saveDailySubPlans(_ plans: [DailySubPlanItem]) {
        if let encoded = try? JSONEncoder().encode(plans) {
            savedDailySubPlans = encoded
        }
        scheduleSecondPersistenceSave(
            todos: todos,
            subPlans: subPlans,
            dailySubPlans: plans
        )
    }

    private func saveFirstPersistenceSlice(
        alarms: [AlarmItem],
        studentProfiles: [StudentSupportProfile],
        classDefinitions: [ClassDefinitionItem],
        teacherContacts: [ClassStaffContact],
        paraContacts: [ClassStaffContact],
        commitments: [CommitmentItem]
    ) {
        ClassTraxPersistence.saveFirstSlice(
            alarms: alarms,
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
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
            followUpNotes: decodeFollowUpNotes(from: savedFollowUpNotes),
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
                classDefinitionIDs: linkedClassDefinitionIDs(for: $0),
                classContexts: $0.classContexts,
                graduationYear: $0.graduationYear,
                parentNames: $0.parentNames,
                parentPhoneNumbers: $0.parentPhoneNumbers,
                parentEmails: $0.parentEmails,
                studentEmail: $0.studentEmail,
                isSped: $0.isSped,
                supportTeacherIDs: $0.supportTeacherIDs,
                supportParaIDs: $0.supportParaIDs,
                supportRooms: $0.supportRooms,
                supportScheduleNotes: $0.supportScheduleNotes,
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
        let validDefinitionIDs = Set(classDefinitions.map(\.id))

        alarms = alarms.map { alarm in
            var updated = alarm
            if let classDefinitionID = updated.classDefinitionID,
               !validDefinitionIDs.contains(classDefinitionID) {
                updated.classDefinitionID = nil
            }
            if updated.classDefinitionID == nil {
                updated.classDefinitionID = exactClassDefinitionMatch(
                    name: updated.className,
                    gradeLevel: updated.gradeLevel,
                    in: classDefinitions
                )?.id
            }
            if let classDefinitionID = updated.classDefinitionID,
               let definition = classDefinitions.first(where: { $0.id == classDefinitionID }) {
                let trimmedName = updated.className.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedName = trimmedName
                    .lowercased()
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: " ", with: "")

                if trimmedName.isEmpty || normalizedName == "nsmanagedobject" || normalizedName == "managedobject" {
                    updated.name = definition.name
                }
                if updated.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    updated.gradeLevelValue = definition.gradeLevel
                }
            } else if updated.className.localizedCaseInsensitiveContains("managedobject") {
                updated.name = ""
            }
            return updated
        }

        studentProfiles = studentProfiles.map { profile in
            var updated = profile
            let filteredLinkedIDs = linkedClassDefinitionIDs(for: updated)
                .filter { validDefinitionIDs.contains($0) }

            updated = updatingProfile(
                updated,
                linkedTo: filteredLinkedIDs,
                definitions: classDefinitions
            )

            if filteredLinkedIDs.isEmpty,
               let matchedID = exactClassDefinitionMatch(
                    name: updated.className,
                    gradeLevel: updated.gradeLevel,
                    in: classDefinitions
                )?.id {
                updated = updatingProfile(
                    updated,
                    linkedTo: [matchedID],
                    definitions: classDefinitions
                )
            }
            updated.className = classSummary(for: updated, in: classDefinitions)
            return updated
        }
    }

    private func loadProfiles() {
        let decodedProfiles = decodeLegacyProfiles()
        profiles = decodedProfiles
    }

    private func loadOverrides() {
        let decodedOverrides = decodeLegacyOverrides()
        overrides = decodedOverrides
    }

    private func refreshNotifications(immediate: Bool = false) {
        let signature = NotificationRefreshSignature(
            alarms: alarms,
            activeOverride: activeDayOverride,
            overrides: overrides,
            profiles: profiles,
            ignoreUntil: ignoreUntil
        )

        guard signature != lastNotificationRefreshSignature else { return }

        pendingNotificationRefreshTask?.cancel()

        let applyRefresh = { @MainActor in
            lastNotificationRefreshSignature = signature
            NotificationManager.shared.refreshNotifications(
                for: alarms,
                activeOverrideSchedule: activeDayOverride?.alarms,
                activeOverrideDate: activeDayOverride?.date,
                overrides: overrides,
                profiles: profiles
            )
        }

        if immediate {
            Task { @MainActor in
                applyRefresh()
            }
            return
        }

        pendingNotificationRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            applyRefresh()
        }
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

    private func scheduleFirstPersistenceSave(
        alarms: [AlarmItem],
        studentProfiles: [StudentSupportProfile],
        classDefinitions: [ClassDefinitionItem],
        teacherContacts: [ClassStaffContact],
        paraContacts: [ClassStaffContact],
        commitments: [CommitmentItem]
    ) {
        pendingFirstSliceSaveTask?.cancel()
        pendingFirstSliceSaveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.persistenceDebounceInterval)
            guard !Task.isCancelled else { return }
            saveFirstPersistenceSlice(
                alarms: alarms,
                studentProfiles: studentProfiles,
                classDefinitions: classDefinitions,
                teacherContacts: teacherContacts,
                paraContacts: paraContacts,
                commitments: commitments
            )
            pendingFirstSliceSaveTask = nil
        }
    }

    private func scheduleSecondPersistenceSave(
        todos: [TodoItem],
        subPlans: [SubPlanItem],
        dailySubPlans: [DailySubPlanItem]
    ) {
        pendingSecondSliceSaveTask?.cancel()
        pendingSecondSliceSaveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.persistenceDebounceInterval)
            guard !Task.isCancelled else { return }
            saveSecondPersistenceSlice(
                todos: todos,
                subPlans: subPlans,
                dailySubPlans: dailySubPlans
            )
            pendingSecondSliceSaveTask = nil
        }
    }

    private func scheduleThirdPersistenceSave(
        attendanceRecords: [AttendanceRecord],
        profiles: [ScheduleProfile],
        overrides: [DayOverride]
    ) {
        pendingThirdSliceSaveTask?.cancel()
        pendingThirdSliceSaveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.persistenceDebounceInterval)
            guard !Task.isCancelled else { return }
            saveThirdPersistenceSlice(
                attendanceRecords: attendanceRecords,
                profiles: profiles,
                overrides: overrides
            )
            pendingThirdSliceSaveTask = nil
        }
    }

    private func flushPendingPersistenceSaves() {
        pendingFirstSliceSaveTask?.cancel()
        pendingSecondSliceSaveTask?.cancel()
        pendingThirdSliceSaveTask?.cancel()
        pendingFirstSliceSaveTask = nil
        pendingSecondSliceSaveTask = nil
        pendingThirdSliceSaveTask = nil

        saveFirstPersistenceSlice(
            alarms: normalizedAlarms(alarms),
            studentProfiles: studentProfiles,
            classDefinitions: classDefinitions,
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            commitments: commitments
        )
        saveSecondPersistenceSlice(
            todos: todos,
            subPlans: subPlans,
            dailySubPlans: dailySubPlans
        )
        saveThirdPersistenceSlice(
            attendanceRecords: attendanceRecords,
            profiles: profiles,
            overrides: overrides
        )
    }

    private func decodeLegacyAttendanceRecords() -> [AttendanceRecord] {
        AttendanceRecord.pruneToCurrentWeek(
            (try? JSONDecoder().decode([AttendanceRecord].self, from: savedAttendance)) ?? []
        )
    }

    private func decodeLegacyProfiles() -> [ScheduleProfile] {
        (try? JSONDecoder().decode([ScheduleProfile].self, from: savedProfiles)) ?? []
    }

    private func decodeLegacyOverrides() -> [DayOverride] {
        (try? JSONDecoder().decode([DayOverride].self, from: savedOverrides)) ?? []
    }
}

struct AttendanceWorkspaceView: View {
    @Binding var alarms: [AlarmItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var attendanceRecords: [AttendanceRecord]
    let overrideSchedule: [AlarmItem]?

    @State private var selectedBlock: AttendanceBlockSession?

    private var now: Date { Date() }

    private var todaySchedule: [AlarmItem] {
        let weekday = Calendar.current.component(.weekday, from: now)
        return (overrideSchedule ?? alarms)
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }
    }

    private var activeBlock: AlarmItem? {
        todaySchedule.first { now >= startDate(for: $0) && now <= endDate(for: $0) }
    }

    private var earlierBlocks: [AlarmItem] {
        todaySchedule.filter { endDate(for: $0) < now && !rosterStudents(for: $0).isEmpty }
    }

    private var laterBlocks: [AlarmItem] {
        todaySchedule.filter { startDate(for: $0) > now && !rosterStudents(for: $0).isEmpty }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(now.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    Text("Attendance is now a dedicated workspace. Open a class, mark students quickly, and add missing work only when needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Current Block") {
                if let activeBlock {
                    blockButton(for: activeBlock)
                } else {
                    Text("No class is active right now.")
                        .foregroundStyle(.secondary)
                }
            }

            if !earlierBlocks.isEmpty {
                Section("Catch Up") {
                    ForEach(earlierBlocks) { block in
                        blockButton(for: block)
                    }
                }
            }

            if !laterBlocks.isEmpty {
                Section("Later Today") {
                    ForEach(laterBlocks) { block in
                        blockButton(for: block)
                    }
                }
            }
        }
        .navigationTitle("Attendance")
        .sheet(item: $selectedBlock) { session in
            NavigationStack {
                AttendanceEditorView(
                    item: session.item,
                    date: session.date,
                    students: session.students,
                    records: attendanceRecords,
                    onCommit: { attendanceRecords = $0 }
                )
            }
        }
    }

    private func blockButton(for block: AlarmItem) -> some View {
        let students = rosterStudents(for: block)
        let completion = attendanceCompletion(for: block, students: students)

        return Button {
            selectedBlock = AttendanceBlockSession(
                item: block,
                date: now,
                students: students
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(block.className)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(completion.badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(completion.tint)
                }

                Text("\(startDate(for: block).formatted(date: .omitted, time: .shortened)) - \(endDate(for: block).formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !block.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(block.gradeLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(completion.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(students.isEmpty)
    }

    private func attendanceCompletion(for block: AlarmItem, students: [StudentSupportProfile]) -> (badgeText: String, detailText: String, tint: Color) {
        guard !students.isEmpty else {
            return ("No Roster", "Link students to this block before taking attendance.", .secondary)
        }

        let dateKey = AttendanceRecord.dateKey(for: now)
        let markedKeys = Set(
            attendanceRecords
                .filter {
                    !$0.isClassHomeworkNote &&
                    $0.dateKey == dateKey &&
                    recordMatches(block: block, record: $0)
                }
                .compactMap { record in
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName)
                }
        )
        let markedCount = students.filter { student in
            guard let key = attendanceMatchKey(studentID: student.id, studentName: student.name) else { return false }
            return markedKeys.contains(key)
        }.count
        let isComplete = markedCount >= students.count

        return (
            isComplete ? "Done" : "\(markedCount)/\(students.count)",
            isComplete ? "Attendance completed for this block." : "\(students.count - markedCount) student\(students.count - markedCount == 1 ? "" : "s") still unmarked.",
            isComplete ? .green : .orange
        )
    }

    private func recordMatches(block: AlarmItem, record: AttendanceRecord) -> Bool {
        if let blockID = record.blockID {
            return blockID == block.id
        }

        if recordMatchesBlockTime(record, block: block) {
            return true
        }

        if let classDefinitionID = block.classDefinitionID, let recordClassDefinitionID = record.classDefinitionID {
            return classDefinitionID == recordClassDefinitionID
        }

        return record.dateKey == AttendanceRecord.dateKey(for: now) &&
            classNamesMatch(scheduleClassName: block.className, profileClassName: record.className) &&
            normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(block.gradeLevel))
    }

    private func recordMatchesBlockTime(_ record: AttendanceRecord, block: AlarmItem) -> Bool {
        guard
            let recordStartTime = record.blockStartTime,
            let recordEndTime = record.blockEndTime
        else {
            return false
        }

        return blockTimeSignature(start: recordStartTime, end: recordEndTime) ==
            blockTimeSignature(start: block.startTime, end: block.endTime)
    }

    private func blockTimeSignature(start: Date, end: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        return String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    private func attendanceMatchKey(studentID: UUID?, studentName: String) -> String? {
        if let studentID {
            return studentID.uuidString.lowercased()
        }

        let normalizedName = normalizedStudentKey(studentName)
        return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
    }

    private func rosterStudents(for item: AlarmItem) -> [StudentSupportProfile] {
        if !item.linkedStudentIDs.isEmpty {
            let linkedIDs = Set(item.linkedStudentIDs)
            let linkedProfiles = studentProfiles
                .filter { linkedIDs.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if !linkedProfiles.isEmpty {
                return linkedProfiles
            }
        }

        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return studentProfiles
            .filter { profile in
                if let classDefinitionID = item.classDefinitionID {
                    guard profileMatches(classDefinitionID: classDefinitionID, profile: profile) else { return false }
                    if gradeKey.isEmpty { return true }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }

                guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                return gradeKey.isEmpty || profileGradeKey.isEmpty || profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func startDate(for item: AlarmItem) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.startTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    private func endDate(for item: AlarmItem) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.endTime)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }
}

private struct AttendanceBlockSession: Identifiable {
    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]

    var id: UUID { item.id }
}

private struct RootLiveActivitySnapshot: Equatable {
    let className: String
    let room: String
    let endTime: Date
    let isHeld: Bool
    let iconName: String
    let nextClassName: String
    let nextIconName: String
}

private struct NotificationRefreshSignature: Equatable {
    struct AlarmSignature: Equatable {
        let id: UUID
        let dayOfWeek: Int
        let startTime: Date
        let endTime: Date
        let type: AlarmItem.ScheduleType
        let warningLeadTimes: [Int]
    }

    struct OverrideSignature: Equatable {
        let id: UUID
        let date: Date
        let profileID: UUID
    }

    struct ProfileSignature: Equatable {
        let id: UUID
        let name: String
        let alarms: [AlarmSignature]
    }

    struct ActiveOverrideSignature: Equatable {
        let date: Date
        let alarms: [AlarmSignature]
    }

    let alarms: [AlarmSignature]
    let activeOverride: ActiveOverrideSignature?
    let overrides: [OverrideSignature]
    let profiles: [ProfileSignature]
    let ignoreUntil: Double

    init(
        alarms: [AlarmItem],
        activeOverride: ActiveDayOverride?,
        overrides: [DayOverride],
        profiles: [ScheduleProfile],
        ignoreUntil: Double
    ) {
        self.ignoreUntil = ignoreUntil
        self.alarms = alarms
            .map {
                AlarmSignature(
                    id: $0.id,
                    dayOfWeek: $0.dayOfWeek,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
                    type: $0.type,
                    warningLeadTimes: $0.warningLeadTimes
                )
            }
            .sorted {
                ($0.dayOfWeek, $0.startTime, $0.id.uuidString) < ($1.dayOfWeek, $1.startTime, $1.id.uuidString)
            }

        self.activeOverride = activeOverride.map { override in
            ActiveOverrideSignature(
                date: override.date,
                alarms: override.alarms
                    .map {
                        AlarmSignature(
                            id: $0.id,
                            dayOfWeek: $0.dayOfWeek,
                            startTime: $0.startTime,
                            endTime: $0.endTime,
                            type: $0.type,
                            warningLeadTimes: $0.warningLeadTimes
                        )
                    }
                    .sorted {
                        ($0.dayOfWeek, $0.startTime, $0.id.uuidString) < ($1.dayOfWeek, $1.startTime, $1.id.uuidString)
                    }
            )
        }

        self.overrides = overrides
            .map { OverrideSignature(id: $0.id, date: $0.date, profileID: $0.profileID) }
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }

        self.profiles = profiles
            .map {
                ProfileSignature(
                    id: $0.id,
                    name: $0.name,
                    alarms: $0.alarms
                        .map {
                            AlarmSignature(
                                id: $0.id,
                                dayOfWeek: $0.dayOfWeek,
                                startTime: $0.startTime,
                                endTime: $0.endTime,
                                type: $0.type,
                                warningLeadTimes: $0.warningLeadTimes
                            )
                        }
                        .sorted {
                            ($0.dayOfWeek, $0.startTime, $0.id.uuidString) < ($1.dayOfWeek, $1.startTime, $1.id.uuidString)
                        }
                )
            }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

private struct StudentsHubView: View {
    @Binding var profiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    @State private var mode: Mode = .students

    private enum Mode: String, CaseIterable, Identifiable {
        case students = "Students"
        case classes = "Classes"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Directory", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            Group {
                switch mode {
                case .students:
                    StudentDirectoryView(
                        profiles: $profiles,
                        classDefinitions: $classDefinitions,
                        teacherContacts: $teacherContacts,
                        paraContacts: $paraContacts
                    )
                case .classes:
                    ClassDefinitionsView(classDefinitions: $classDefinitions, profiles: $profiles)
                }
            }
        }
        .navigationTitle(mode == .students ? "Students" : "Classes")
    }
}
