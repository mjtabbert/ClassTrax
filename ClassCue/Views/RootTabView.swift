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
    case settings
    case manage
}

// MARK: - Root Tab View

struct RootTabView: View {

    private enum PlannerWorkspaceTab: String, Hashable, CaseIterable {
        case tasks
        case notes

        var title: String {
            switch self {
            case .tasks:
                return "Tasks"
            case .notes:
                return "Notes"
            }
        }
    }

    private enum ManageDestinationKey {
        static let rollCall = "rollCall"
        static let students = "students"
        static let settings = "settings"
    }

    private struct FirstSliceDomain: OptionSet {
        let rawValue: Int

        static let alarms = FirstSliceDomain(rawValue: 1 << 0)
        static let studentProfiles = FirstSliceDomain(rawValue: 1 << 1)
        static let classDefinitions = FirstSliceDomain(rawValue: 1 << 2)
        static let supportStaff = FirstSliceDomain(rawValue: 1 << 3)
        static let commitments = FirstSliceDomain(rawValue: 1 << 4)
        static let all: FirstSliceDomain = [.alarms, .studentProfiles, .classDefinitions, .supportStaff, .commitments]
    }

    private static let cloudSyncRefreshInterval: Duration = .seconds(30)
    private static let localMutationRefreshPauseSeconds: TimeInterval = 120
    private static let runtimeSyncHeartbeatInterval: Duration = .seconds(30)
    private static let persistenceDebounceInterval: Duration = .milliseconds(450)

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var appStore = ClassTraxAppStore()
    private let appCoordinator = ClassTraxAppCoordinator()
    @State private var plannerWorkspaceTab: PlannerWorkspaceTab = .tasks
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("commitments_v1_data") private var savedCommitments: Data = Data()
    @AppStorage("student_support_profiles_v1_data") private var savedStudentProfiles: Data = Data()
    @AppStorage("class_definitions_v1_data") private var savedClassDefinitions: Data = Data()
    @AppStorage("teacher_contacts_v1_data") private var savedTeacherContacts: Data = Data()
    @AppStorage("para_contacts_v1_data") private var savedParaContacts: Data = Data()
    @AppStorage("attendance_v1_data") private var savedAttendance: Data = Data()
    @AppStorage("behavior_logs_v1_data") private var savedBehaviorLogs: Data = Data()
    @AppStorage("sub_plans_v1_data") private var savedSubPlans: Data = Data()
    @AppStorage("daily_sub_plans_v1_data") private var savedDailySubPlans: Data = Data()
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()
    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("live_activities_enabled") private var liveActivitiesEnabled = true
    @AppStorage("pref_class_start_notifications_enabled") private var classStartNotificationsEnabled = true
    @AppStorage("classtrax_sounds_muted_v1") private var soundsMuted = false
    @AppStorage("feature_attendance_enabled") private var featureAttendanceEnabled = true
    @AppStorage("feature_schedule_enabled") private var featureScheduleEnabled = true
    @AppStorage("feature_homework_enabled") private var featureHomeworkEnabled = true
    @AppStorage("feature_behavior_enabled") private var featureBehaviorEnabled = true
    @AppStorage("cloud_sync_last_local_mutation_at") private var storedLastLocalMutationAt: Double = 0
    @AppStorage("cloud_sync_last_refresh_at") private var storedLastCloudRefreshAt: Double = 0
    @AppStorage("cloudkit_last_event_summary_v1") private var lastCloudKitEventSummary: String = "No CloudKit sync events observed yet."
    @AppStorage("cloudkit_last_event_timestamp_v1") private var lastCloudKitEventTimestamp: Double = 0

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []
    @State private var commitments: [CommitmentItem] = []
    @State private var studentProfiles: [StudentSupportProfile] = []
    @State private var classDefinitions: [ClassDefinitionItem] = []
    @State private var teacherContacts: [ClassStaffContact] = []
    @State private var paraContacts: [ClassStaffContact] = []
    @State private var attendanceRecords: [AttendanceRecord] = []
    @State private var behaviorLogs: [BehaviorLogItem] = []
    @State private var subPlans: [SubPlanItem] = []
    @State private var dailySubPlans: [DailySubPlanItem] = []
    @State private var profiles: [ScheduleProfile] = []
    @State private var overrides: [DayOverride] = []
    @State private var lastLocalMutationAt = Date.distantPast
    @State private var isRefreshingFromPersistence = false
    @State private var pendingLiveActivityStopTask: Task<Void, Never>?
    @State private var pendingNotificationRefreshTask: Task<Void, Never>?
    @State private var pendingFirstSliceSaveTask: Task<Void, Never>?
    @State private var pendingFirstSliceDomains: FirstSliceDomain = []
    @State private var pendingSecondSliceSaveTask: Task<Void, Never>?
    @State private var pendingThirdSliceSaveTask: Task<Void, Never>?
    @State private var lastSyncedWidgetSnapshot: ClassTraxWidgetSnapshot?
    @State private var lastSyncedLiveActivitySnapshot: RootLiveActivitySnapshot?
    @State private var lastNotificationRefreshSignature: NotificationRefreshSignature?
    @State private var lastCloudBackedRefreshAt = Date.distantPast
    @State private var hasBootstrappedInitialData = false

    private var selectedTab: AppTab {
        get {
            switch appStore.selectedTabKey {
            case "attendance":
                return .attendance
            case "schedule":
                return .schedule
            case "students":
                return .students
            case "todo":
                return .todo
            case "settings":
                return .settings
            case "manage":
                return .manage
            default:
                return .today
            }
        }
        nonmutating set {
            switch newValue {
            case .today:
                appStore.selectedTabKey = "today"
            case .attendance:
                appStore.selectedTabKey = "attendance"
            case .schedule:
                appStore.selectedTabKey = "schedule"
            case .students:
                appStore.selectedTabKey = "students"
            case .todo:
                appStore.selectedTabKey = "todo"
            case .settings:
                appStore.selectedTabKey = "settings"
            case .manage:
                appStore.selectedTabKey = "manage"
            }
        }
    }

    private var selectedScheduleDay: WeekdayTab {
        get { WeekdayTab(rawValue: appStore.selectedScheduleDayRawValue) ?? .today }
        nonmutating set { appStore.selectedScheduleDayRawValue = newValue.rawValue }
    }

    private var focusedScheduleItemID: UUID? {
        get { appStore.focusedScheduleItemID }
        nonmutating set { appStore.focusedScheduleItemID = newValue }
    }

    private var focusedTodoID: UUID? {
        get { appStore.focusedTodoID }
        nonmutating set { appStore.focusedTodoID = newValue }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
    }

    private var selectedScheduleDayBinding: Binding<WeekdayTab> {
        Binding(
            get: { selectedScheduleDay },
            set: { selectedScheduleDay = $0 }
        )
    }

    private var focusedScheduleItemIDBinding: Binding<UUID?> {
        Binding(
            get: { focusedScheduleItemID },
            set: { focusedScheduleItemID = $0 }
        )
    }

    private var focusedTodoIDBinding: Binding<UUID?> {
        Binding(
            get: { focusedTodoID },
            set: { focusedTodoID = $0 }
        )
    }

    private var managePathBinding: Binding<NavigationPath> {
        Binding(
            get: { appStore.managePath },
            set: { appStore.managePath = $0 }
        )
    }

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
        let savedContexts = classDefinitions
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let classContexts = alarms
            .map(\.className)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let commitmentContexts = commitments
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Array(Set((savedContexts + classContexts + commitmentContexts).filter { !$0.isEmpty }))
            .sorted()
    }

    private var suggestedStudents: [String] {
        let taskStudents = todos
            .map(\.effectiveStudentLink)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let profileStudents = studentProfiles.map(\.name)
        return normalizedStudentDirectory(profileStudents + taskStudents)
    }

    private var suggestedStudentGroups: [String] {
        let savedGroups = classDefinitions
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let taskGroups = todos
            .map(\.effectiveStudentGroupLink)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(savedGroups + taskGroups))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var studentSupportsByName: [String: StudentSupportProfile] {
        studentProfiles.reduce(into: [String: StudentSupportProfile]()) { partialResult, profile in
            partialResult[profile.name] = profile
        }
    }

    private var baseTabView: some View {
        TabView(selection: selectedTabBinding) {
            todayTab
            if featureScheduleEnabled {
                scheduleTab
            }
            todoTab
            manageTab
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
                .onChange(of: teacherContacts) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveSupportStaff(teacherContacts: newValue, paraContacts: paraContacts)
                }
                .onChange(of: paraContacts) { _, newValue in
                    guard !isRefreshingFromPersistence else { return }
                    recordLocalMutation()
                    saveSupportStaff(teacherContacts: teacherContacts, paraContacts: newValue)
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
                .onChange(of: savedAttendance) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        attendanceRecords = decodeLegacyAttendanceRecords()
                        syncSharedSnapshot()
                    }
                }
                .onChange(of: savedBehaviorLogs) { _, _ in
                    guard !isRefreshingFromPersistence else { return }
                    handleLegacyStorageChange {
                        behaviorLogs = decodeLegacyBehaviorLogs()
                        syncSharedSnapshot()
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
                .onChange(of: lastCloudKitEventTimestamp) { _, newValue in
                    guard scenePhase == .active else { return }
                    handleCloudKitEventChange(timestamp: newValue, summary: lastCloudKitEventSummary)
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
                .task(id: runtimeHeartbeatTaskID) {
                    guard scenePhase == .active, shouldRunRuntimeHeartbeat else { return }
                    while scenePhase == .active && !Task.isCancelled {
                        syncRuntimeState(now: Date())
                        try? await Task.sleep(for: Self.runtimeSyncHeartbeatInterval)
                        guard shouldRunRuntimeHeartbeat else { return }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase != .active {
                        flushPendingPersistenceSaves()
                        syncLiveActivity(now: Date())
                    }
                }
                .onChange(of: featureScheduleEnabled) { _, isEnabled in
                    if !isEnabled, selectedTab == .schedule {
                        selectedTab = .today
                    }
                }
                .onChange(of: classStartNotificationsEnabled) { _, _ in
                    refreshNotifications(immediate: true)
                }
                .onChange(of: soundsMuted) { _, _ in
                    refreshNotifications(immediate: true)
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
    }

    private func handleOnAppear() {
        let launchPlan = appCoordinator.launchPlan(
            hasBootstrappedInitialData: hasBootstrappedInitialData,
            synchronizedIgnoreUntil: ScheduleSnoozeStore.synchronize()
        )

        ignoreUntil = {
            switch launchPlan {
            case .syncOnly(let synchronizedIgnoreUntil),
                    .bootstrap(let synchronizedIgnoreUntil):
                return synchronizedIgnoreUntil
            }
        }()
        selectedScheduleDay = .today

        switch launchPlan {
        case .syncOnly:
            syncRuntimeState(now: Date())
        case .bootstrap:
            hasBootstrappedInitialData = true
            Task { @MainActor in
                await Task.yield()
                loadSavedData()
                refreshNotifications(immediate: true)
                syncRuntimeState(now: Date())
            }
        }
    }

    private func handleSelectedTabChange(_ newTab: AppTab) {
        let selectionPlan = appCoordinator.tabSelectionPlan(
            isScheduleTab: newTab == .schedule,
            isSettingsTab: newTab == .settings
        )

        if selectionPlan.resetScheduleDayToToday {
            selectedScheduleDay = .today
        }

        if selectionPlan.refreshCloudBackedStore {
            refreshFromCloudBackedStore(force: true)
        }
        if selectionPlan.syncRuntimeState {
            syncRuntimeState(now: Date())
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
                isHeld: SessionControlStore.isHeld(itemID: item.id),
                bellSkipped: SessionControlStore.skippedBellItemIDs().contains(item.id)
            )
        }

        func attendanceStatus(for profile: StudentSupportProfile, in item: AlarmItem) -> String? {
            let dateKey = AttendanceRecord.dateKey(for: now)
            let targetKey = {
                let normalizedName = normalizedStudentKey(profile.name)
                return normalizedName.isEmpty ? profile.id.uuidString.lowercased() : profile.id.uuidString.lowercased()
            }()

            return attendanceRecords.first(where: { record in
                let recordKey: String? = {
                    if let studentID = record.studentID {
                        return studentID.uuidString.lowercased()
                    }
                    let normalizedName = normalizedStudentKey(record.studentName)
                    return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
                }()

                let blockMatches: Bool = {
                    if let blockID = record.blockID {
                        return blockID == item.id
                    }

                    if let recordStartTime = record.blockStartTime,
                       let recordEndTime = record.blockEndTime {
                        let calendar = Calendar(identifier: .gregorian)
                        let recordSignature = String(
                            format: "%02d:%02d-%02d:%02d",
                            calendar.component(.hour, from: recordStartTime),
                            calendar.component(.minute, from: recordStartTime),
                            calendar.component(.hour, from: recordEndTime),
                            calendar.component(.minute, from: recordEndTime)
                        )
                        let blockSignature = String(
                            format: "%02d:%02d-%02d:%02d",
                            calendar.component(.hour, from: item.startTime),
                            calendar.component(.minute, from: item.startTime),
                            calendar.component(.hour, from: item.endTime),
                            calendar.component(.minute, from: item.endTime)
                        )
                        if recordSignature == blockSignature {
                            return true
                        }
                    }

                    if item.matchesLinkedClassDefinition(record.classDefinitionID) {
                        return true
                    }

                    return record.dateKey == AttendanceRecord.dateKey(for: now) &&
                        classNamesMatch(scheduleClassName: item.className, profileClassName: record.className) &&
                        normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
                }()

                return record.isAttendanceEntry &&
                    record.dateKey == dateKey &&
                    blockMatches &&
                    recordKey == targetKey
            })?.status.rawValue
        }

        func behaviorRating(for profile: StudentSupportProfile, in item: AlarmItem) -> String? {
            let segmentKey = normalizedSegmentTitle(item.className)

            return behaviorLogs.first(where: { log in
                log.studentID == profile.id &&
                Calendar.current.isDateInToday(log.timestamp) &&
                (log.blockID == item.id || normalizedSegmentTitle(log.segmentTitle) == segmentKey)
            })?.rating.rawValue
        }

        let currentRoster: [ClassTraxWidgetSnapshot.StudentSummary] = activeItem.map { item in
            let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
            let roster = studentProfiles
                .filter { profile in
                    if item.linkedStudentIDs.contains(profile.id) {
                        return true
                    }

                    if let classDefinitionID = item.classDefinitionID,
                       profile.classDefinitionIDs.contains(classDefinitionID) || profile.classDefinitionID == classDefinitionID {
                        return true
                    }

                    if !item.linkedClassDefinitionIDs.isEmpty {
                        let matchesLinkedContext = item.linkedClassDefinitionIDs.contains { linkedID in
                            profile.classDefinitionIDs.contains(linkedID) || profile.classDefinitionID == linkedID
                        }
                        guard matchesLinkedContext else { return false }
                        if gradeKey.isEmpty { return true }
                        let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                        return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                    }

                    guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return gradeKey.isEmpty || profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            return roster.map { profile in
                ClassTraxWidgetSnapshot.StudentSummary(
                    id: profile.id,
                    name: profile.name,
                    gradeLevel: profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                    attendanceStatusRawValue: attendanceStatus(for: profile, in: item),
                    behaviorRatingRawValue: behaviorRating(for: profile, in: item)
                )
            }
        } ?? []

        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: activeItem.map(summary),
            next: nextItem.map(summary),
            currentRoster: currentRoster,
            ignoreUntil: ignoreDate
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
            activeItemID: activeItem.id,
            className: activeItem.className,
            room: activeItem.location.trimmingCharacters(in: .whitespacesAndNewlines),
            endTime: stableEndTime,
            isHeld: SessionControlStore.isHeld(itemID: activeItem.id),
            iconName: activeItem.scheduleType.symbolName,
            nextItemID: nextItem?.id,
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
        refreshFromCloudBackedStore(force: true, bypassLocalMutationPause: true)
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
                isAttendanceEnabled: featureAttendanceEnabled,
                isScheduleEnabled: featureScheduleEnabled,
                isHomeworkEnabled: featureHomeworkEnabled,
                isBehaviorEnabled: featureBehaviorEnabled,
                onRefresh: {
                    manuallyRefreshSyncedData()
                },
                onRefreshNotifications: {
                    refreshNotifications(immediate: true)
                },
                openAttendanceTab: {
                    appStore.resetManagePath()
                    appStore.requestManageDestination(ManageDestinationKey.rollCall)
                    selectedTab = .manage
                },
                openScheduleTab: {
                    selectedTab = .schedule
                },
                openScheduleBlock: { item in
                    appStore.openScheduleBlock(itemID: item.id, weekdayRawValue: item.dayOfWeek)
                },
                openStudentsTab: {
                    appStore.resetManagePath()
                    appStore.requestManageDestination(ManageDestinationKey.students)
                    selectedTab = .manage
                }, openTodoTab: {
                    plannerWorkspaceTab = .tasks
                    selectedTab = .todo
                }, openTodoItem: { item in
                    plannerWorkspaceTab = .tasks
                    focusedTodoID = item.id
                    selectedTab = .todo
                }, openNotesTab: {
                    plannerWorkspaceTab = .notes
                    selectedTab = .todo
                }, openSettingsTab: {
                    appStore.resetManagePath()
                    appStore.requestManageDestination(ManageDestinationKey.settings)
                    selectedTab = .manage
                },
                behaviorLogs: behaviorLogs,
                behaviorLogsForStudent: { profile in
                    behaviorLogsForStudent(profile)
                },
                behaviorSegmentsForStudent: { profile in
                    behaviorSegments(for: profile)
                },
                preferredBehaviorSegmentID: { profile in
                    preferredBehaviorSegment(for: profile, now: Date())?.id
                },
                preferredBehaviorSegmentTitle: { profile in
                    preferredBehaviorSegmentTitle(for: profile)
                },
                onLogBehavior: { profile, behavior, rating, segmentID in
                    logBehavior(for: profile, behavior: behavior, rating: rating, segmentID: segmentID)
                },
                onLogBehaviorWithNote: { profile, behavior, rating, segmentID, note, timestamp in
                    logBehavior(
                        for: profile,
                        behavior: behavior,
                        rating: rating,
                        segmentID: segmentID,
                        note: note,
                        now: timestamp,
                        shouldToggleOffMatching: false
                    )
                }
            )
            .toolbar(.hidden, for: .tabBar)
        }
        .tabItem {
            tabLabel(title: "Today", systemImage: "house")
        }
        .accessibilityLabel("Home")
        .tag(AppTab.today)
    }

    private var scheduleTab: some View {
        ScheduleView(
            selectedDay: selectedScheduleDayBinding,
            focusedItemID: focusedScheduleItemIDBinding,
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
            openTodoTab: {
                plannerWorkspaceTab = .tasks
                selectedTab = .todo
            },
            openNotesTab: {
                plannerWorkspaceTab = .notes
                selectedTab = .todo
            }
        )
        .toolbar(.hidden, for: .tabBar)
        .tabItem {
            tabLabel(title: "Schedule", systemImage: "calendar")
        }
        .accessibilityLabel("Schedule")
        .tag(AppTab.schedule)
    }

    private var attendanceWorkspace: some View {
        AttendanceWorkspaceView(
            alarms: $alarms,
            studentProfiles: $studentProfiles,
            attendanceRecords: $attendanceRecords,
            overrideSchedule: activeDayOverride?.alarms,
            openTodayTab: { selectedTab = .today },
            openScheduleSetup: {
                selectedScheduleDay = .today
                selectedTab = .schedule
            },
            openStudentsSetup: {
                appStore.resetManagePath()
                appStore.requestManageDestination(ManageDestinationKey.students)
                selectedTab = .manage
            }
        )
    }

    private var studentsWorkspace: some View {
        StudentsHubView(
            profiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            teacherContacts: $teacherContacts,
            paraContacts: $paraContacts,
            attendanceRecords: $attendanceRecords,
            onImportedStudents: { importedProfiles in
                persistStudentProfilesImmediately(importedProfiles)
            },
            onSavedProfiles: { updatedProfiles in
                persistStudentProfilesImmediately(updatedProfiles)
            },
            onSavedTeacherContacts: { updatedContacts in
                persistSupportStaffImmediately(
                    teacherContacts: updatedContacts,
                    paraContacts: paraContacts
                )
            },
            onSavedParaContacts: { updatedContacts in
                persistSupportStaffImmediately(
                    teacherContacts: teacherContacts,
                    paraContacts: updatedContacts
                )
            },
            onSavedClassDefinitions: { updatedDefinitions, updatedProfiles in
                persistClassDefinitionsImmediately(updatedDefinitions, profiles: updatedProfiles)
            },
            onDeleteClassDefinition: { definition in
                deleteClassDefinitionImmediately(definition)
            },
            onPrepareStudentEditor: {
                flushPendingPersistenceSaves()
            },
            behaviorLogsForStudent: { profile in
                behaviorLogsForStudent(profile)
            },
            behaviorSegmentsForStudent: { profile in
                behaviorSegments(for: profile)
            },
            preferredBehaviorSegmentID: { profile in
                preferredBehaviorSegment(for: profile, now: Date())?.id
            },
            preferredBehaviorSegmentTitle: { profile in
                preferredBehaviorSegmentTitle(for: profile)
            },
            onLogBehavior: { profile, behavior, rating, segmentID in
                logBehavior(for: profile, behavior: behavior, rating: rating, segmentID: segmentID)
            },
            onLogBehaviorWithNote: { profile, behavior, rating, segmentID, note, timestamp in
                logBehavior(
                    for: profile,
                    behavior: behavior,
                    rating: rating,
                    segmentID: segmentID,
                    note: note,
                    now: timestamp,
                    shouldToggleOffMatching: false
                )
            }
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedTab = .today
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("Today")
            }
        }
    }

    private var todoTab: some View {
        VStack(spacing: 0) {
            Picker("Planner Workspace", selection: $plannerWorkspaceTab) {
                ForEach(PlannerWorkspaceTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 2)

            Group {
                switch plannerWorkspaceTab {
                case .tasks:
                    TodoListView(
                        todos: $todos,
                        studentProfiles: $studentProfiles,
                        classDefinitions: $classDefinitions,
                        teacherContacts: $teacherContacts,
                        paraContacts: $paraContacts,
                        focusedTodoID: focusedTodoIDBinding,
                        suggestedContexts: suggestedTaskContexts,
                        suggestedStudents: suggestedStudents,
                        suggestedStudentGroups: suggestedStudentGroups,
                        studentSupportsByName: studentSupportsByName,
                        onRefresh: {
                            manuallyRefreshSyncedData()
                        },
                        openTodayTab: { selectedTab = .today }
                    )
                case .notes:
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
                }
            }
        }
        .tabItem {
            tabLabel(title: "Planner", systemImage: "checklist")
        }
        .accessibilityLabel("Planner")
        .tag(AppTab.todo)
    }

    private var settingsWorkspace: some View {
        SettingsView(
            studentProfiles: $studentProfiles,
            classDefinitions: $classDefinitions,
            teacherContacts: $teacherContacts,
            paraContacts: $paraContacts
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    selectedTab = .today
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("Today")
            }
        }
    }

    private var manageTab: some View {
        NavigationStack(path: managePathBinding) {
            List {
                Section {
                    manageOverviewCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("Jump Back In") {
                    hubSwitchRow(
                        title: "Today",
                        detail: "Go back to the live classroom dashboard.",
                        systemImage: "house",
                        accent: ClassTraxSemanticColor.primaryAction
                    ) {
                        selectedTab = .today
                    }

                    hubSwitchRow(
                        title: "Planner",
                        detail: "Open tasks, notes, and student-linked planning in one workspace.",
                        systemImage: "checklist",
                        accent: ClassTraxSemanticColor.reviewWarning
                    ) {
                        plannerWorkspaceTab = .tasks
                        selectedTab = .todo
                    }

                    hubSwitchRow(
                        title: "Notes",
                        detail: "Jump into school log, class notes, and student notes inside Planner.",
                        systemImage: "square.and.pencil",
                        accent: ClassTraxSemanticColor.secondaryAction
                    ) {
                        plannerWorkspaceTab = .notes
                        selectedTab = .todo
                    }
                }

                Section("Daily Tools") {
                    if featureAttendanceEnabled {
                        NavigationLink(value: ManageDestinationKey.rollCall) {
                            manageRow(
                                title: "Attendance",
                                detail: "Open the dedicated attendance workspace and catch up any missed blocks.",
                                systemImage: "checklist.checked"
                            )
                        }
                    }
                }

                Section("Workspace") {
                    NavigationLink(value: ManageDestinationKey.students) {
                        manageRow(
                            title: "Students & Supports",
                            detail: "Open the student directory, class rosters, and support profiles.",
                            systemImage: "person.3"
                        )
                    }

                    NavigationLink(value: ManageDestinationKey.settings) {
                        manageRow(
                            title: "Settings",
                            detail: "Open setup, alerts, layout defaults, integrations, and data tools.",
                            systemImage: "gearshape"
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        ClassTraxSemanticColor.primaryAction.opacity(0.04),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedTab = .today
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel("Today")
                }
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case ManageDestinationKey.rollCall:
                    attendanceWorkspace
                case ManageDestinationKey.students:
                    studentsWorkspace
                case ManageDestinationKey.settings:
                    settingsWorkspace
                default:
                    EmptyView()
                }
            }
        }
        .onChange(of: appStore.requestedManageDestinationKey) { _, destination in
            guard let destination else { return }
            appStore.resetManagePath()
            appStore.managePath.append(destination)
            appStore.requestedManageDestinationKey = nil
        }
        .tabItem {
            tabLabel(title: "Hub", systemImage: "square.grid.2x2")
        }
        .accessibilityLabel("Hub")
        .tag(AppTab.manage)
    }

    private func tabLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
    }

    @ViewBuilder
    private func manageRow(title: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var manageOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Overview")
                    .font(.title3.weight(.bold))

                Text("Keep setup, attendance recovery, supports, and settings together while Today, Planner, and Notes stay focused on live work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                hubMetric(title: "Students", value: "\(studentProfiles.count)", accent: .blue) {
                    appStore.resetManagePath()
                    appStore.managePath.append(ManageDestinationKey.students)
                }
                hubMetric(title: "Classes", value: "\(classDefinitions.count)", accent: .indigo) {
                    appStore.resetManagePath()
                    appStore.managePath.append(ManageDestinationKey.students)
                }
                hubMetric(title: "Teachers", value: "\(teacherContacts.count)", accent: .teal) {
                    appStore.resetManagePath()
                    appStore.managePath.append(ManageDestinationKey.students)
                }
                hubMetric(title: "Paras", value: "\(paraContacts.count)", accent: .orange) {
                    appStore.resetManagePath()
                    appStore.managePath.append(ManageDestinationKey.students)
                }
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func hubMetric(title: String, value: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
            .classTraxCardChrome(accent: accent, cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private func hubSwitchRow(title: String, detail: String, systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
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
        let legacyBehaviorLogs = decodeLegacyBehaviorLogs()
        let legacyProfiles = decodeLegacyProfiles()
        let legacyOverrides = decodeLegacyOverrides()

        if ClassTraxPersistence.activeContainerMode != .cloudKit {
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
        }

        refreshFromPersistence()
        behaviorLogs = legacyBehaviorLogs
    }

    @MainActor
    private func refreshFromCloudBackedStore(
        force: Bool = false,
        bypassLocalMutationPause: Bool = false
    ) {
        let refreshPlan = appCoordinator.cloudRefreshPlan(
            force: force,
            bypassLocalMutationPause: bypassLocalMutationPause,
            now: Date(),
            lastCloudBackedRefreshAt: lastCloudBackedRefreshAt,
            lastLocalMutationAt: lastLocalMutationAt,
            minimumRefreshInterval: 10,
            localMutationRefreshPauseSeconds: Self.localMutationRefreshPauseSeconds
        )
        guard refreshPlan.shouldRefresh else { return }

        lastCloudBackedRefreshAt = Date()
        storedLastCloudRefreshAt = lastCloudBackedRefreshAt.timeIntervalSince1970
        refreshFromPersistence()
        refreshNotifications()
    }

    private func recordLocalMutation() {
        lastLocalMutationAt = Date()
        storedLastLocalMutationAt = lastLocalMutationAt.timeIntervalSince1970
    }

    private func handleCloudKitEventChange(timestamp: Double, summary: String) {
        if appCoordinator.shouldRefreshForCloudKitEvent(
            isCloudKitMode: ClassTraxPersistence.activeContainerMode == .cloudKit,
            timestamp: timestamp,
            summary: summary,
            lastCloudBackedRefreshAt: lastCloudBackedRefreshAt
        ) {
            refreshFromCloudBackedStore(force: true, bypassLocalMutationPause: true)
        }
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
            let shouldRefresh = appCoordinator.shouldRunCloudSyncRefreshTick(
                isCloudKitMode: ClassTraxPersistence.activeContainerMode == .cloudKit,
                isSettingsTab: selectedTab == .settings,
                isStudentsTab: selectedTab == .students,
                now: Date(),
                lastLocalMutationAt: lastLocalMutationAt,
                localMutationRefreshPauseSeconds: Self.localMutationRefreshPauseSeconds
            )
            guard shouldRefresh else { continue }
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
        let shouldPreferCloudBackedSnapshot = ClassTraxPersistence.activeContainerMode == .cloudKit
        let localStudentProfiles = decodeLegacyStudentProfiles()
        let localClassDefinitions = decodeLegacyClassDefinitions()
        let localTeacherContacts = decodeLegacyTeacherContacts()
        let localParaContacts = decodeLegacyParaContacts()
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
        studentProfiles = normalizedStudentProfiles(
            from: shouldPreferCloudBackedSnapshot || (savedStudentProfiles.isEmpty && localStudentProfiles.isEmpty)
                ? persistenceSnapshot.studentProfiles
                : localStudentProfiles
        )
        classDefinitions = (shouldPreferCloudBackedSnapshot || (savedClassDefinitions.isEmpty && localClassDefinitions.isEmpty)
            ? persistenceSnapshot.classDefinitions
            : localClassDefinitions
        ).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        teacherContacts = (shouldPreferCloudBackedSnapshot || (savedTeacherContacts.isEmpty && localTeacherContacts.isEmpty)
            ? persistenceSnapshot.teacherContacts
            : localTeacherContacts
        ).sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        paraContacts = (shouldPreferCloudBackedSnapshot || (savedParaContacts.isEmpty && localParaContacts.isEmpty)
            ? persistenceSnapshot.paraContacts
            : localParaContacts
        ).sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        }
        todos = secondSliceSnapshot.todos
        savedFollowUpNotes = (try? JSONEncoder().encode(secondSliceSnapshot.followUpNotes)) ?? Data()
        reconcileClassDefinitionLinks()
        attendanceRecords = AttendanceRecord.pruneToCurrentWeek(thirdSliceSnapshot.attendanceRecords)
        behaviorLogs = decodeLegacyBehaviorLogs()
        subPlans = secondSliceSnapshot.subPlans
        dailySubPlans = secondSliceSnapshot.dailySubPlans
        profiles = thirdSliceSnapshot.profiles
        overrides = thirdSliceSnapshot.overrides
        if shouldPreferCloudBackedSnapshot {
            savedStudentProfiles = (try? JSONEncoder().encode(studentProfiles)) ?? Data()
            savedClassDefinitions = (try? JSONEncoder().encode(classDefinitions)) ?? Data()
            savedTeacherContacts = (try? JSONEncoder().encode(teacherContacts)) ?? Data()
            savedParaContacts = (try? JSONEncoder().encode(paraContacts)) ?? Data()
        }
        savedAttendance = (try? JSONEncoder().encode(attendanceRecords)) ?? Data()
        savedProfiles = (try? JSONEncoder().encode(thirdSliceSnapshot.profiles)) ?? Data()
        savedOverrides = (try? JSONEncoder().encode(thirdSliceSnapshot.overrides)) ?? Data()

        Task { @MainActor in
            isRefreshingFromPersistence = false
        }
    }

    private func normalizedStudentProfiles(from profiles: [StudentSupportProfile]) -> [StudentSupportProfile] {
        profiles
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

    // MARK: - Save Alarms

    private func saveAlarms(_ alarms: [AlarmItem]) {
        let normalized = normalizedAlarms(alarms)
        if let encoded = try? JSONEncoder().encode(normalized) {
            savedAlarms = encoded
        }
        scheduleFirstPersistenceSave(for: .alarms)
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
        scheduleFirstPersistenceSave(for: .commitments)
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
        scheduleFirstPersistenceSave(for: .studentProfiles)
    }

    private func saveClassDefinitions(_ definitions: [ClassDefinitionItem]) {
        savedClassDefinitions = (try? JSONEncoder().encode(definitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        })) ?? Data()
        scheduleFirstPersistenceSave(for: .classDefinitions)
    }

    private func saveSupportStaff(teacherContacts: [ClassStaffContact], paraContacts: [ClassStaffContact]) {
        savedTeacherContacts = (try? JSONEncoder().encode(teacherContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        })) ?? Data()
        savedParaContacts = (try? JSONEncoder().encode(paraContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        })) ?? Data()
        scheduleFirstPersistenceSave(for: .supportStaff)
    }

    private func persistStudentProfilesImmediately(_ profiles: [StudentSupportProfile]) {
        recordLocalMutation()
        savedStudentProfiles = (try? JSONEncoder().encode(profiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        })) ?? Data()
        ClassTraxPersistence.saveFirstSliceStudentProfiles(profiles, into: modelContext)
    }

    private func persistClassDefinitionsImmediately(
        _ definitions: [ClassDefinitionItem],
        profiles: [StudentSupportProfile]
    ) {
        recordLocalMutation()
        classDefinitions = definitions.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        studentProfiles = profiles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        savedClassDefinitions = (try? JSONEncoder().encode(classDefinitions)) ?? Data()
        savedStudentProfiles = (try? JSONEncoder().encode(studentProfiles)) ?? Data()
        ClassTraxPersistence.saveFirstSliceClassDefinitions(classDefinitions, into: modelContext)
        ClassTraxPersistence.saveFirstSliceStudentProfiles(studentProfiles, into: modelContext)
    }

    private func deleteClassDefinitionImmediately(_ definition: ClassDefinitionItem) {
        let updatedDefinitions = classDefinitions.filter { $0.id != definition.id }
        let updatedProfiles = studentProfiles.map { profile in
            let linkedIDs = linkedClassDefinitionIDs(for: profile)
            guard linkedIDs.contains(definition.id) else { return profile }
            return updatingProfile(
                profile,
                linkedTo: linkedIDs.filter { $0 != definition.id },
                definitions: updatedDefinitions
            )
        }

        persistClassDefinitionsImmediately(updatedDefinitions, profiles: updatedProfiles)
        reconcileClassDefinitionLinks()
        syncSharedSnapshot()
    }

    private func persistSupportStaffImmediately(
        teacherContacts: [ClassStaffContact],
        paraContacts: [ClassStaffContact]
    ) {
        recordLocalMutation()
        savedTeacherContacts = (try? JSONEncoder().encode(teacherContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        })) ?? Data()
        savedParaContacts = (try? JSONEncoder().encode(paraContacts.sorted {
            $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending
        })) ?? Data()
        ClassTraxPersistence.saveFirstSliceSupportStaff(
            teacherContacts: teacherContacts,
            paraContacts: paraContacts,
            into: modelContext
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

    private func saveBehaviorLogs(_ logs: [BehaviorLogItem]) {
        let normalizedLogs = logs.sorted { $0.timestamp > $1.timestamp }
        savedBehaviorLogs = (try? JSONEncoder().encode(normalizedLogs)) ?? Data()
        behaviorLogs = normalizedLogs
    }

    private func decodeLegacyBehaviorLogs() -> [BehaviorLogItem] {
        guard !savedBehaviorLogs.isEmpty,
              let decodedLogs = try? JSONDecoder().decode([BehaviorLogItem].self, from: savedBehaviorLogs) else {
            return []
        }

        return decodedLogs.sorted { $0.timestamp > $1.timestamp }
    }

    private func behaviorLogsForStudent(_ profile: StudentSupportProfile) -> [BehaviorLogItem] {
        behaviorLogs
            .filter { $0.studentID == profile.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func logBehavior(
        for profile: StudentSupportProfile,
        behavior: BehaviorLogItem.BehaviorKind,
        rating: BehaviorLogItem.Rating,
        segmentID: UUID? = nil,
        note: String = "",
        now: Date = Date(),
        shouldToggleOffMatching: Bool = true
    ) {
        let currentSegment = resolvedBehaviorSegment(for: profile, segmentID: segmentID, now: now)
        let segmentTitle = currentSegment?.className ?? profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingIndex = behaviorLogs.firstIndex(where: { log in
            log.studentID == profile.id &&
            log.behavior == behavior &&
            Calendar.current.isDate(log.timestamp, inSameDayAs: now) &&
            normalizedSegmentTitle(log.segmentTitle) == normalizedSegmentTitle(segmentTitle)
        })

        var updatedLogs = behaviorLogs
        if let matchingIndex {
            if updatedLogs[matchingIndex].rating == rating && shouldToggleOffMatching && trimmedNote.isEmpty {
                updatedLogs.remove(at: matchingIndex)
            } else {
                updatedLogs[matchingIndex] = BehaviorLogItem(
                    id: updatedLogs[matchingIndex].id,
                    studentID: profile.id,
                    studentName: profile.name,
                    timestamp: now,
                    behavior: behavior,
                    rating: rating,
                    blockID: currentSegment?.id,
                    classDefinitionID: currentSegment?.classDefinitionID ?? profile.classDefinitionID,
                    segmentTitle: segmentTitle,
                    note: trimmedNote.isEmpty ? updatedLogs[matchingIndex].note : note
                )
            }
        } else {
            updatedLogs.insert(
                BehaviorLogItem(
                    studentID: profile.id,
                    studentName: profile.name,
                    timestamp: now,
                    behavior: behavior,
                    rating: rating,
                    blockID: currentSegment?.id,
                    classDefinitionID: currentSegment?.classDefinitionID ?? profile.classDefinitionID,
                    segmentTitle: segmentTitle,
                    note: note
                ),
                at: 0
            )
        }

        recordLocalMutation()
        saveBehaviorLogs(updatedLogs)
    }

    private func preferredBehaviorSegment(for profile: StudentSupportProfile, now: Date) -> AlarmItem? {
        let schedule = adjustedTodaySchedule(for: now)

        if let activeMatch = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) &&
            now <= endDateToday(for: $0, now: now) &&
            alarm($0, matches: profile)
        }) {
            return activeMatch
        }

        if let nextMatch = schedule.first(where: {
            startDateToday(for: $0, now: now) > now && alarm($0, matches: profile)
        }) {
            return nextMatch
        }

        return schedule.first(where: { alarm($0, matches: profile) })
    }

    private func behaviorSegments(for profile: StudentSupportProfile, now: Date = Date()) -> [BehaviorSegmentOption] {
        adjustedTodaySchedule(for: now)
            .filter { alarm($0, matches: profile) }
            .map {
                BehaviorSegmentOption(
                    id: $0.id,
                    title: $0.className.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
    }

    private func resolvedBehaviorSegment(for profile: StudentSupportProfile, segmentID: UUID?, now: Date) -> AlarmItem? {
        let matchingSchedule = adjustedTodaySchedule(for: now).filter { alarm($0, matches: profile) }

        if let segmentID,
           let selectedSegment = matchingSchedule.first(where: { $0.id == segmentID }) {
            return selectedSegment
        }

        return preferredBehaviorSegment(for: profile, now: now)
    }

    private func alarm(_ alarm: AlarmItem, matches profile: StudentSupportProfile) -> Bool {
        if alarm.linkedStudentIDs.contains(profile.id) {
            return true
        }

        if let classDefinitionID = alarm.classDefinitionID,
           profile.classDefinitionIDs.contains(classDefinitionID) || profile.classDefinitionID == classDefinitionID {
            return true
        }

        let profileClassName = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        let alarmClassName = alarm.className.trimmingCharacters(in: .whitespacesAndNewlines)
        return !profileClassName.isEmpty && profileClassName.localizedCaseInsensitiveCompare(alarmClassName) == .orderedSame
    }

    private func preferredBehaviorSegmentTitle(for profile: StudentSupportProfile) -> String {
        preferredBehaviorSegment(for: profile, now: Date())?.className.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSegmentTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    private func saveFirstPersistenceSlice(domains: FirstSliceDomain) {
        if domains.contains(.alarms) {
            ClassTraxPersistence.saveFirstSliceAlarms(normalizedAlarms(alarms), into: modelContext)
        }
        if domains.contains(.studentProfiles) {
            ClassTraxPersistence.saveFirstSliceStudentProfiles(studentProfiles, into: modelContext)
        }
        if domains.contains(.classDefinitions) {
            ClassTraxPersistence.saveFirstSliceClassDefinitions(classDefinitions, into: modelContext)
        }
        if domains.contains(.supportStaff) {
            ClassTraxPersistence.saveFirstSliceSupportStaff(
                teacherContacts: teacherContacts,
                paraContacts: paraContacts,
                into: modelContext
            )
        }
        if domains.contains(.commitments) {
            ClassTraxPersistence.saveFirstSliceCommitments(commitments, into: modelContext)
        }
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
            ignoreUntil: ignoreUntil,
            classStartNotificationsEnabled: classStartNotificationsEnabled,
            soundsMuted: soundsMuted
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

    private func scheduleFirstPersistenceSave(for domains: FirstSliceDomain) {
        pendingFirstSliceDomains.formUnion(domains)
        pendingFirstSliceSaveTask?.cancel()
        pendingFirstSliceSaveTask = Task { @MainActor in
            try? await Task.sleep(for: Self.persistenceDebounceInterval)
            guard !Task.isCancelled else { return }
            let domainsToSave = pendingFirstSliceDomains
            pendingFirstSliceDomains = []
            saveFirstPersistenceSlice(domains: domainsToSave)
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

        pendingFirstSliceDomains = []
        saveFirstPersistenceSlice(domains: .all)
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

    private func decodeLegacyTeacherContacts() -> [ClassStaffContact] {
        ((try? JSONDecoder().decode([ClassStaffContact].self, from: savedTeacherContacts)) ?? [])
            .sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
    }

    private func decodeLegacyParaContacts() -> [ClassStaffContact] {
        ((try? JSONDecoder().decode([ClassStaffContact].self, from: savedParaContacts)) ?? [])
            .sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
    }

    private var shouldRunRuntimeHeartbeat: Bool {
        switch selectedTab {
        case .today, .schedule:
            return true
        case .attendance, .students, .todo, .settings, .manage:
            return false
        }
    }

    private var runtimeHeartbeatTaskID: String {
        "\(scenePhase == .active)-\(selectedTab)"
    }
}

struct AttendanceWorkspaceView: View {
    @Binding var alarms: [AlarmItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var attendanceRecords: [AttendanceRecord]
    let overrideSchedule: [AlarmItem]?
    let openTodayTab: () -> Void
    let openScheduleSetup: () -> Void
    let openStudentsSetup: () -> Void

    @State private var selectedBlock: AttendanceBlockSession?
    @State private var groupActionSession: TodayGroupActionSession?

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
        todaySchedule.filter { endDate(for: $0) < now }
    }

    private var laterBlocks: [AlarmItem] {
        todaySchedule.filter { startDate(for: $0) > now }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(now.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    Text("Attendance is a focused workspace. Open a class or group, mark students quickly, and only drop into notes when you need them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Current Class / Group") {
                if let activeBlock {
                    blockButton(for: activeBlock)
                } else if todaySchedule.isEmpty {
                    setupPrompt(
                        title: "No classes scheduled for today.",
                        detail: "Set up today's blocks first, then attendance will open the matching class or group.",
                        primaryTitle: "Open Schedule Setup",
                        primarySystemImage: "calendar.badge.plus",
                        primaryAction: openScheduleSetup
                    )
                } else {
                    Text("No class or group is active right now.")
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

            if !todaySchedule.isEmpty && todaySchedule.allSatisfy({ rosterStudents(for: $0).isEmpty }) {
                Section("Set Up Attendance") {
                    setupPrompt(
                        title: "Today's classes need roster links.",
                        detail: "Open Schedule to assign the block, then open Students & Supports if you still need to build the class roster.",
                        primaryTitle: "Open Schedule",
                        primarySystemImage: "calendar",
                        primaryAction: openScheduleSetup,
                        secondaryTitle: "Students & Supports",
                        secondarySystemImage: "person.3",
                        secondaryAction: openStudentsSetup
                    )
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    openTodayTab()
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("Today")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if todaySchedule.isEmpty {
                        Text("No classes scheduled for today")
                    } else {
                        Section("Review Today's Classes") {
                            ForEach(todaySchedule) { block in
                                Button {
                                    openAttendanceBlock(block)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(block.className)
                                        Text("\(startDate(for: block).formatted(date: .omitted, time: .shortened)) - \(endDate(for: block).formatted(date: .omitted, time: .shortened))")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Attendance Actions")
            }
        }
        .sheet(item: $selectedBlock) { session in
            NavigationStack {
                AttendanceEditorView(
                    item: session.item,
                    date: session.date,
                    students: session.students,
                    targetClassDefinitionID: session.targetClassDefinitionID,
                    targetTitle: session.targetTitle,
                    records: attendanceRecords,
                    onCommit: { attendanceRecords = $0 }
                )
            }
        }
        .sheet(item: $groupActionSession) { session in
            NavigationStack {
                TodayGroupActionPickerView(
                    session: session,
                    onChoose: { selection in
                        groupActionSession = nil
                        handleGroupSelection(selection)
                    }
                )
            }
        }
    }

    private func blockButton(for block: AlarmItem) -> some View {
        let students = rosterStudents(for: block)
        let completion = attendanceCompletion(for: block, students: students)

        return Button {
            openAttendanceBlock(block)
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
    }

    private func openAttendanceBlock(_ block: AlarmItem) {
        let students = rosterStudents(for: block)
        if students.isEmpty {
            openScheduleSetup()
        } else if let session = makeGroupActionSession(for: block) {
            groupActionSession = session
        } else {
            selectedBlock = AttendanceBlockSession(
                item: block,
                date: now,
                students: students,
                targetClassDefinitionID: nil,
                targetTitle: nil
            )
        }
    }

    @ViewBuilder
    private func setupPrompt(
        title: String,
        detail: String,
        primaryTitle: String,
        primarySystemImage: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondarySystemImage: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                primaryAction()
            } label: {
                Label(primaryTitle, systemImage: primarySystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let secondaryTitle, let secondarySystemImage, let secondaryAction {
                Button {
                    secondaryAction()
                } label: {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func attendanceCompletion(for block: AlarmItem, students: [StudentSupportProfile]) -> (badgeText: String, detailText: String, tint: Color) {
        guard !students.isEmpty else {
            return ("No Roster", "Link students to this block before taking attendance.", .secondary)
        }

        let selectableLinkedGroups = block.linkedClassDefinitionIDs.filter {
            !rosterStudents(for: block, targetClassDefinitionID: $0).isEmpty
        }
        if selectableLinkedGroups.count > 1 {
            return (
                "\(selectableLinkedGroups.count) Groups",
                "Choose one linked group to take attendance.",
                .blue
            )
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
            isComplete ? "Roll call completed for this block." : "\(students.count - markedCount) student\(students.count - markedCount == 1 ? "" : "s") still unmarked.",
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

        if block.matchesLinkedClassDefinition(record.classDefinitionID) {
            return true
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
        rosterStudents(for: item, targetClassDefinitionID: nil)
    }

    private func rosterStudents(for item: AlarmItem, targetClassDefinitionID: UUID?) -> [StudentSupportProfile] {
        let explicitLinkedProfiles: [StudentSupportProfile] = {
            guard !item.linkedStudentIDs.isEmpty else { return [] }
            let linkedIDs = Set(item.linkedStudentIDs)
            return studentProfiles
                .filter { linkedIDs.contains($0.id) }
                .filter { profile in
                    guard let targetClassDefinitionID else { return true }
                    return profileMatches(classDefinitionID: targetClassDefinitionID, profile: profile)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }()

        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        let contextMatchedProfiles = studentProfiles
            .filter { profile in
                if !item.linkedClassDefinitionIDs.isEmpty {
                    let matchesLinkedContext: Bool
                    if let targetClassDefinitionID {
                        matchesLinkedContext = profileMatches(classDefinitionID: targetClassDefinitionID, profile: profile)
                    } else {
                        matchesLinkedContext = item.linkedClassDefinitionIDs.contains { linkedID in
                            profileMatches(classDefinitionID: linkedID, profile: profile)
                        }
                    }
                    guard matchesLinkedContext else { return false }
                    if gradeKey.isEmpty { return true }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }

                guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                return gradeKey.isEmpty || profileGradeKey.isEmpty || profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard !explicitLinkedProfiles.isEmpty else {
            return contextMatchedProfiles
        }

        var mergedProfiles = explicitLinkedProfiles
        let existingIDs = Set(explicitLinkedProfiles.map(\.id))
        mergedProfiles.append(contentsOf: contextMatchedProfiles.filter { !existingIDs.contains($0.id) })
        return mergedProfiles
    }

    private func makeGroupActionSession(for item: AlarmItem) -> TodayGroupActionSession? {
        let linkedDefinitions = item.linkedClassDefinitionIDs
            .filter { !rosterStudents(for: item, targetClassDefinitionID: $0).isEmpty }

        guard linkedDefinitions.count > 1 else { return nil }

        let choices = linkedDefinitions.map { linkedID in
            TodayGroupActionSession.Selection(
                itemID: item.id,
                action: .rollCall,
                classDefinitionID: linkedID,
                title: resolveGroupTitle(for: linkedID, item: item),
                studentCount: rosterStudents(for: item, targetClassDefinitionID: linkedID).count
            )
        }

        return TodayGroupActionSession(action: .rollCall, choices: choices)
    }

    private func handleGroupSelection(_ selection: TodayGroupActionSession.Selection) {
        guard let item = alarms.first(where: { $0.id == selection.itemID }) ?? todaySchedule.first(where: { $0.id == selection.itemID }) else {
            return
        }

        selectedBlock = AttendanceBlockSession(
            item: item,
            date: now,
            students: rosterStudents(for: item, targetClassDefinitionID: selection.classDefinitionID),
            targetClassDefinitionID: selection.classDefinitionID,
            targetTitle: selection.title
        )
    }

    private func resolveGroupTitle(for classDefinitionID: UUID, item: AlarmItem) -> String {
        let matchedProfiles = studentProfiles.filter { profileMatches(classDefinitionID: classDefinitionID, profile: $0) }
        if let title = matchedProfiles
            .map(\.className)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return title
        }

        return item.className
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
    let targetClassDefinitionID: UUID?
    let targetTitle: String?

    var id: String { "\(item.id.uuidString)-\(targetClassDefinitionID?.uuidString ?? "all")" }
}

private struct RootLiveActivitySnapshot: Equatable {
    let activeItemID: UUID
    let className: String
    let room: String
    let endTime: Date
    let isHeld: Bool
    let iconName: String
    let nextItemID: UUID?
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
    let classStartNotificationsEnabled: Bool
    let soundsMuted: Bool

    init(
        alarms: [AlarmItem],
        activeOverride: ActiveDayOverride?,
        overrides: [DayOverride],
        profiles: [ScheduleProfile],
        ignoreUntil: Double,
        classStartNotificationsEnabled: Bool,
        soundsMuted: Bool
    ) {
        self.ignoreUntil = ignoreUntil
        self.classStartNotificationsEnabled = classStartNotificationsEnabled
        self.soundsMuted = soundsMuted
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
    @Binding var attendanceRecords: [AttendanceRecord]
    let onImportedStudents: ([StudentSupportProfile]) -> Void
    let onSavedProfiles: ([StudentSupportProfile]) -> Void
    let onSavedTeacherContacts: ([ClassStaffContact]) -> Void
    let onSavedParaContacts: ([ClassStaffContact]) -> Void
    let onSavedClassDefinitions: ([ClassDefinitionItem], [StudentSupportProfile]) -> Void
    let onDeleteClassDefinition: (ClassDefinitionItem) -> Void
    let onPrepareStudentEditor: () -> Void
    let behaviorLogsForStudent: (StudentSupportProfile) -> [BehaviorLogItem]
    let behaviorSegmentsForStudent: (StudentSupportProfile) -> [BehaviorSegmentOption]
    let preferredBehaviorSegmentID: (StudentSupportProfile) -> UUID?
    let preferredBehaviorSegmentTitle: (StudentSupportProfile) -> String
    let onLogBehavior: (StudentSupportProfile, BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?) -> Void
    let onLogBehaviorWithNote: (StudentSupportProfile, BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?, String, Date) -> Void
    var body: some View {
        StudentDirectoryView(
            profiles: $profiles,
            classDefinitions: $classDefinitions,
            teacherContacts: $teacherContacts,
            paraContacts: $paraContacts,
            attendanceRecords: attendanceRecords,
            onImportedStudents: { importedProfiles in
                onImportedStudents(importedProfiles)
            },
            onSavedProfiles: { updatedProfiles in
                onSavedProfiles(updatedProfiles)
            },
            onSavedClassDefinitions: { updatedDefinitions, updatedProfiles in
                onSavedClassDefinitions(updatedDefinitions, updatedProfiles)
            },
            onSavedTeacherContacts: { updatedContacts in
                onSavedTeacherContacts(updatedContacts)
            },
            onSavedParaContacts: { updatedContacts in
                onSavedParaContacts(updatedContacts)
            },
            onPrepareStudentEditor: {
                onPrepareStudentEditor()
            },
            behaviorLogsForStudent: behaviorLogsForStudent,
            behaviorSegmentsForStudent: behaviorSegmentsForStudent,
            preferredBehaviorSegmentID: preferredBehaviorSegmentID,
            preferredBehaviorSegmentTitle: preferredBehaviorSegmentTitle,
            onLogBehavior: onLogBehavior,
            onLogBehaviorWithNote: onLogBehaviorWithNote
        )
        .navigationTitle("Students")
    }
}
