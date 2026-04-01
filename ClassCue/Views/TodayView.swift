//
//  TodayView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 25
//

import SwiftUI
import SwiftData
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

struct TodayView: View {
    enum TodayDashboardCard: String, CaseIterable, Identifiable {
        case teacherContext
        case currentClass
        case attendance
        case commitments
        case upcoming
        case tasks
        case support
        case notes
        case endOfDay
        case subPlan

        var id: String { rawValue }

        var title: String {
            switch self {
            case .teacherContext:
                return "Teacher Context"
            case .currentClass:
                return "Current / Next Class"
            case .attendance:
                return "Attendance"
            case .commitments:
                return "Commitments"
            case .upcoming:
                return "Upcoming"
            case .tasks:
                return "Tasks"
            case .support:
                return "Class Support"
            case .notes:
                return "Notes Snapshot"
            case .endOfDay:
                return "End of Day"
            case .subPlan:
                return "Sub Plan"
            }
        }

        var systemImage: String {
            switch self {
            case .teacherContext:
                return "sparkles"
            case .currentClass:
                return "studentdesk"
            case .attendance:
                return "checklist.checked"
            case .commitments:
                return "briefcase"
            case .upcoming:
                return "calendar.badge.clock"
            case .tasks:
                return "checklist"
            case .support:
                return "person.crop.circle.badge.checkmark"
            case .notes:
                return "square.and.pencil"
            case .endOfDay:
                return "sun.max"
            case .subPlan:
                return "doc.text"
            }
        }

        static let defaultOrder: [TodayDashboardCard] = [
            .teacherContext,
            .currentClass,
            .attendance,
            .commitments,
            .upcoming,
            .tasks,
            .support,
            .notes,
            .endOfDay,
            .subPlan
        ]
    }

    @Binding var alarms: [AlarmItem]
    @Binding var todos: [TodoItem]
    @Binding var commitments: [CommitmentItem]
    @Binding var studentSupportProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]
    @Binding var dailySubPlans: [DailySubPlanItem]
    let suggestedStudents: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    let activeOverrideName: String?
    let overrideSchedule: [AlarmItem]?
    let ignoreDate: Date?
    let onRefresh: @MainActor () -> Void
    let openScheduleTab: () -> Void
    let openStudentsTab: () -> Void
    let openTodoTab: () -> Void
    let openNotesTab: () -> Void
    let openSettingsTab: () -> Void

    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("personal_notes_v1") private var personalNotesText: String = ""
    @AppStorage("today_quick_note_draft_v1") private var todayQuickNoteDraft = ""
    @AppStorage("today_quick_note_draft_token_v1") private var todayQuickNoteDraftToken: Double = 0
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0
    @AppStorage("school_show_end_of_day_wrap_up") private var showEndOfDayWrapUp = true
    @AppStorage("school_offer_task_carryover") private var offerTaskCarryover = true
    @AppStorage("school_hide_dashboard_after_hours") private var hideSchoolDashboardAfterHours = true
    @AppStorage("school_show_personal_focus_card") private var showPersonalFocusCard = true
    @AppStorage("live_activities_enabled") private var liveActivitiesEnabled = true
    @AppStorage("today_dashboard_card_order_v1") private var storedDashboardCardOrder = ""
    @AppStorage("today_dashboard_hidden_cards_v1") private var storedHiddenDashboardCards = ""

    @State private var activeWarning: InAppWarning?
    @State private var lastWarningKey: String?
    @State private var warningDismissTask: Task<Void, Never>?
    @AppStorage("classtrax_extra_time_by_item_v1") private var storedExtraTimeByItemID: Data = Data()
    @AppStorage("classtrax_held_item_id_v1") private var storedHeldItemID: String = ""
    @AppStorage("classtrax_hold_started_at_v1") private var storedHoldStartedAt: Double = 0
    @AppStorage("classtrax_skipped_bell_item_ids_v1") private var storedSkippedBellItemIDs: Data = Data()
    @State private var lastActiveItemID: UUID?
    @State private var showingSessionActions = false
    @State private var showingAddCommitment = false
    @State private var showingCommitmentsManager = false
    @State private var editingCommitment: CommitmentItem?
    @State private var showingQuickCapture = false
    @State private var editingAlarm: AlarmItem?
    @State private var showingStudentDirectory = false
    @State private var rosterItem: AlarmItem?
    @State private var attendanceSession: AttendanceSession?
    @State private var homeworkCaptureSession: HomeworkCaptureSession?
    @State private var showingHomeworkReview = false
    @State private var homeworkReviewDate = Date()
    @State private var subPlanItem: AlarmItem?
    @State private var showingDailySubPlan = false
    @State private var dailySubPlanDate = Date()
    @State private var todayAttendanceExportURL: URL?
    @State private var showingTodayAttendanceShareSheet = false
    @State private var quickSchoolNoteText = ""
    @State private var pendingLiveActivityStopTask: Task<Void, Never>?
    @State private var dashboardCardOrder = TodayDashboardCard.defaultOrder
    @State private var hiddenDashboardCards = Set<TodayDashboardCard>()
    @State private var scrollTargetCard: TodayDashboardCard?

    private var extraTimeByItemID: [UUID: TimeInterval] {
        SessionControlStore.extraTimeByItemID()
    }

    private var skippedBellItemIDs: Set<UUID> {
        SessionControlStore.skippedBellItemIDs()
    }

    var body: some View {

        TimelineView(.periodic(from: .now, by: 1.0)) { context in

            let now = context.date
            let schedule = adjustedTodaySchedule(for: now)

            let activeItem = schedule.first {
                now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
            }

            let nextItem = schedule.first {
                startDateToday(for: $0, now: now) > now
            }

            let warning = warningForUpcomingBlock(nextItem, now: now)
            let highlightItem = activeItem ?? nextItem
            let activeItemID = activeItem?.id
            let todayCommitments = commitmentsForToday(now: now)

            ZStack(alignment: .top) {

                todayBackground(for: highlightItem)
                    .ignoresSafeArea()

                GeometryReader { geo in

                    let isLandscape = geo.size.width > geo.size.height

                    Group {
                        if isLandscape {
                            landscapeDashboard(
                                availableSize: geo.size,
                                now: now,
                                schedule: schedule,
                                activeItem: activeItem,
                                nextItem: nextItem,
                                todayCommitments: todayCommitments
                            )
                        } else {
                            portraitDashboard(
                                now: now,
                                schedule: schedule,
                                activeItem: activeItem,
                                nextItem: nextItem,
                                todayCommitments: todayCommitments
                            )
                        }
                    }
                }

                if let activeWarning {
                    InAppWarningBanner(warning: activeWarning)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }

                floatingActionMenu(activeItem: activeItem, now: now)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .zIndex(1)

            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: activeWarning?.id)
            .onChange(of: warning?.id) { _, newValue in
                handleWarningTrigger(warning, key: newValue)
            }
            .onChange(of: activeItemID) { _, newValue in
                handleActiveItemChange(newValue)
            }
            .onChange(of: activeItemID) { _, _ in
                processBellIfNeeded(activeItem, now: now)
            }
            .onChange(of: now) {
                processBellIfNeeded(activeItem, now: now)
            }
            .confirmationDialog(
                activeItem == nil ? "Class Controls" : "\(activeItem?.className ?? "Class") Controls",
                isPresented: $showingSessionActions,
                titleVisibility: .visible
            ) {
                if let activeItem {
                    Button(
                        skippedBellItemIDs.contains(activeItem.id) ? "Bell Already Skipped" : "Skip Bell",
                        role: skippedBellItemIDs.contains(activeItem.id) ? .cancel : nil
                    ) {
                        if !skippedBellItemIDs.contains(activeItem.id) {
                            skipBell(for: activeItem)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddCommitment) {
                AddCommitmentView(
                    commitments: $commitments,
                    defaultDay: Calendar.current.component(.weekday, from: now)
                )
            }
            .sheet(isPresented: $showingCommitmentsManager) {
                NavigationStack {
                    TodayCommitmentsManagerView(
                        commitments: $commitments,
                        onAdd: {
                            showingAddCommitment = true
                        },
                        onEdit: { commitment in
                            editingCommitment = commitment
                        }
                    )
                }
            }
            .sheet(item: $editingCommitment) { commitment in
                AddCommitmentView(
                    commitments: $commitments,
                    defaultDay: commitment.dayOfWeek,
                    existing: commitment
                )
            }
            .sheet(isPresented: $showingQuickCapture) {
                QuickCaptureView(
                    todos: $todos,
                    suggestedContexts: suggestedTaskContexts,
                    suggestedStudents: suggestedStudents,
                    preferredContext: preferredCaptureContext(for: adjustedTodaySchedule(for: Date())),
                    preferredCategory: preferredCaptureCategory(for: adjustedTodaySchedule(for: Date()), now: Date())
                )
            }
            .sheet(item: $editingAlarm) { item in
                AddEditView(
                    alarms: $alarms,
                    studentProfiles: studentSupportProfiles,
                    classDefinitions: classDefinitions,
                    day: item.dayOfWeek,
                    existing: item
                )
            }
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(profiles: $studentSupportProfiles, classDefinitions: $classDefinitions)
                }
            }
            .sheet(item: $rosterItem) { item in
                NavigationStack {
                    TodayClassRosterView(
                        item: item,
                        alarms: $alarms,
                        profiles: $studentSupportProfiles,
                        classDefinitions: classDefinitions
                    )
                }
            }
            .sheet(item: $subPlanItem) { item in
                NavigationStack {
                    TodayClassSubPlanView(
                        item: item,
                        date: now,
                        students: rosterStudents(for: item),
                        alarms: alarms,
                        commitments: commitments,
                        activeOverrideName: activeOverrideName,
                        attendanceRecords: attendanceRecords,
                        subPlans: $subPlans
                    )
                }
            }
            .sheet(isPresented: $showingDailySubPlan) {
                NavigationStack {
                    TodayDailySubPlanView(
                        date: dailySubPlanDate,
                        alarms: alarms,
                        commitments: commitments,
                        activeOverrideName: activeOverrideName,
                        students: studentSupportProfiles,
                        attendanceRecords: attendanceRecords,
                        subPlans: $subPlans,
                        dailySubPlans: $dailySubPlans
                    )
                }
            }
            .sheet(isPresented: $showingTodayAttendanceShareSheet) {
                if let todayAttendanceExportURL {
                    ShareSheet(activityItems: [todayAttendanceExportURL])
                }
            }
            .onAppear {
                loadDashboardCardOrderIfNeeded()
            }
            .onChange(of: dashboardCardOrder) { _, newValue in
                persistDashboardCardOrder(newValue)
            }
            .onChange(of: hiddenDashboardCards) { _, newValue in
                persistHiddenDashboardCards(newValue)
            }
        }
        .sheet(item: $attendanceSession) { session in
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
        .sheet(item: $homeworkCaptureSession) { session in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: session.item.className,
                    helperText: "This homework note is saved with today's class and included in attendance exports.",
                    initialText: classHomeworkText(for: session.item, now: session.date),
                    onSave: { saveClassHomework($0, for: session.item, now: session.date) }
                )
            }
        }
        .sheet(isPresented: $showingHomeworkReview) {
            NavigationStack {
                DailyHomeworkReviewView(
                    attendanceRecords: $attendanceRecords,
                    classDefinitions: classDefinitions,
                    date: homeworkReviewDate
                )
            }
        }
    }

    // MARK: Header

    func header(now: Date) -> some View {
        let accent = currentHeaderAccent(now: now)
        let blockCount = todaysBlockCount(for: now)
        let commitmentCount = commitmentsForToday(now: now).count
        let taskCount = topTasks(for: now).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(now.formatted(.dateTime.weekday(.wide)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .tracking(4)

                    Text(now.formatted(.dateTime.month().day()))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(headerStatusText(for: now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: currentHeaderSymbol(now: now))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
            }

            HStack(spacing: 10) {
                todayHeaderStat(
                    title: "Blocks",
                    value: "\(blockCount)",
                    accent: accent
                ) {
                    openScheduleTab()
                }
                todayHeaderStat(
                    title: "Tasks",
                    value: "\(taskCount)",
                    accent: .orange
                ) {
                    scrollTargetCard = .tasks
                }
                todayHeaderStat(
                    title: "Commitments",
                    value: "\(commitmentCount)",
                    accent: .indigo
                ) {
                    scrollTargetCard = .commitments
                }
            }

            if let ignoreDate, ignoreDate > now {
                notificationPauseBadge(until: ignoreDate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(todayHeaderBackground(accent: accent))
        .overlay(todayHeaderBorder(accent: accent))
        .padding(.horizontal)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func todayBackground(for item: AlarmItem?) -> some View {

        let accent = item?.accentColor ?? Color.blue
        let secondary = secondaryBackgroundColor(for: item)

        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(0.28),
                    secondary.opacity(0.20),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 22)
                .offset(x: 110, y: -180)

            Circle()
                .fill(secondary.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 18)
                .offset(x: -140, y: -90)
        }
    }

    private func emptyState(for now: Date) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("No blocks scheduled for today.")
                .font(.headline)

            Text("Add a few test blocks in the Schedule tab and they will appear here right away.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                openScheduleTab()
            } label: {
                Label("Open Schedule", systemImage: "calendar")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func portraitDashboard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {

                header(now: now)

                if let activeOverrideName {
                    overrideBanner(name: activeOverrideName)
                        .padding(.horizontal)
                }

                if shouldShowDayStatus(now: now, schedule: schedule, activeItem: activeItem) {
                    dayStatusCard(now: now, schedule: schedule, activeItem: activeItem)
                        .padding(.horizontal)
                }

                if let active = activeItem {
                    Button {
                        editingAlarm = active
                    } label: {
                        ActiveTimerCard(
                            item: active,
                            now: now,
                            isHeld: isHeld(active),
                            bellSkipped: skippedBellItemIDs.contains(active.id)
                        )
                        .frame(height: 260)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                } else if let next = nextItem {
                    NextUpSummaryCard(item: next, now: now)
                        .padding(.horizontal)
                }

                dashboardSummaryRow(
                    now: now,
                    schedule: schedule,
                    activeItem: activeItem,
                    nextItem: nextItem,
                    todayCommitments: todayCommitments
                )
                .padding(.horizontal)

                if schedule.isEmpty {
                    emptyState(for: now)
                        .padding(.horizontal)
                }
                }
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 96)
                .padding(.top, -6)
            }
            .onChange(of: scrollTargetCard) { _, newValue in
                guard let newValue else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    proxy.scrollTo(newValue, anchor: .top)
                }
            }
        }
        .refreshable {
            onRefresh()
        }
    }

    @ViewBuilder
    private func landscapeDashboard(
        availableSize: CGSize,
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {

        VStack(spacing: 4) {

            if ignoreDate != nil {
                landscapeHeader(now: now)
            }

            if let activeOverrideName {
                overrideBanner(name: activeOverrideName)
            }

            HStack(alignment: .top, spacing: 16) {
                let primaryCardMaxHeight = min(max(availableSize.height - 48, 320), 520)

                Group {
                    if let active = activeItem {
                        Button {
                            editingAlarm = active
                        } label: {
                            ActiveTimerCard(
                                item: active,
                                now: now,
                                isTeacherMode: true,
                                isHeld: isHeld(active),
                                bellSkipped: skippedBellItemIDs.contains(active.id)
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let next = nextItem {
                        NextUpSummaryCard(
                            item: next,
                            now: now,
                            isCompact: true
                        )
                    } else {
                        emptyState(for: now)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: primaryCardMaxHeight, alignment: .top)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            dashboardSummaryColumn(
                                now: now,
                                schedule: schedule,
                                activeItem: activeItem,
                                nextItem: nextItem,
                                todayCommitments: todayCommitments
                            )
                        }
                        .padding(.bottom, 24)
                    }
                    .frame(width: 320)
                    .onChange(of: scrollTargetCard) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                    .refreshable {
                        onRefresh()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func dashboardSummaryRow(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {
        VStack(spacing: 12) {
            if shouldShowAfterHoursPersonalMode(now: now, schedule: schedule) {
                schoolBoundaryCard(now: now, schedule: schedule)
                if showPersonalFocusCard {
                    personalFocusCard(now: now)
                }
                if showEndOfDayWrapUp {
                    endOfDayCard(now: now, schedule: schedule)
                }
            } else {
                orderedDashboardCards(
                    now: now,
                    schedule: schedule,
                    activeItem: activeItem,
                    nextItem: nextItem,
                    todayCommitments: todayCommitments,
                    compact: false
                )
            }
        }
    }

    @ViewBuilder
    private func dashboardSummaryColumn(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {
        VStack(spacing: 12) {
            if shouldShowAfterHoursPersonalMode(now: now, schedule: schedule) {
                schoolBoundaryCard(now: now, schedule: schedule, compact: true)
                if showPersonalFocusCard {
                    personalFocusCard(now: now, compact: true)
                }
                if showEndOfDayWrapUp {
                    endOfDayCard(now: now, schedule: schedule, compact: true)
                }
            } else {
                if shouldShowDayStatus(now: now, schedule: schedule, activeItem: schedule.first(where: {
                    now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
                })) {
                    dayStatusCard(now: now, schedule: schedule, activeItem: schedule.first(where: {
                        now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
                    }), compact: true)
                }

                orderedDashboardCards(
                    now: now,
                    schedule: schedule,
                    activeItem: activeItem,
                    nextItem: nextItem,
                    todayCommitments: todayCommitments,
                    compact: true
                )
            }
        }
    }

    @ViewBuilder
    private func orderedDashboardCards(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        compact: Bool
    ) -> some View {
        ForEach(visibleDashboardCards, id: \.self) { card in
            dashboardCardView(
                card,
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem,
                todayCommitments: todayCommitments,
                compact: compact
            )
            .id(card)
        }
    }

    private var visibleDashboardCards: [TodayDashboardCard] {
        dashboardCardOrder.filter { card in
            guard !hiddenDashboardCards.contains(card) else { return false }
            if card == .endOfDay {
                return showEndOfDayWrapUp
            }
            return true
        }
    }

    @ViewBuilder
    private func dashboardCardView(
        _ card: TodayDashboardCard,
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        compact: Bool
    ) -> some View {
        switch card {
        case .teacherContext:
            teacherContextRibbon(
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem,
                compact: compact
            )
            .padding(.top, 6)
        case .currentClass:
            classSectionCard(activeItem: activeItem, nextItem: nextItem, schedule: schedule, now: now, compact: compact)
        case .attendance:
            attendanceDashboardCard(schedule: schedule, now: now, activeItem: activeItem, compact: compact)
        case .commitments:
            commitmentsCard(todayCommitments: todayCommitments, compact: compact)
        case .upcoming:
            upcomingStrip(schedule: schedule, now: now, nextItem: nextItem, compact: compact)
        case .tasks:
            topTasksCard(now: now, compact: compact)
        case .support:
            studentSupportCard(activeItem: activeItem, nextItem: nextItem, compact: compact)
        case .notes:
            notesSnapshotCard(compact: compact)
        case .endOfDay:
            if showEndOfDayWrapUp {
                endOfDayCard(now: now, schedule: schedule, compact: compact)
            }
        case .subPlan:
            subPlanCard(schedule: schedule, compact: compact)
        }
    }

    @ViewBuilder
    private func classSectionCard(activeItem: AlarmItem?, nextItem: AlarmItem?, schedule: [AlarmItem], now: Date, compact: Bool) -> some View {
        let completedItem = schedule.last(where: {
            endDateToday(for: $0, now: now) < now
        })

        if let item = activeItem ?? nextItem ?? completedItem {
            let linkedTasks = todos.filter {
                !$0.isCompleted &&
                $0.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(item.className.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            }
            let roster = rosterStudents(for: item)
            let sectionTitle: String = {
                if activeItem?.id == item.id {
                    return "Current Class"
                }
                if nextItem?.id == item.id {
                    return "Next Class"
                }
                return "Last Class"
            }()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(
                        sectionTitle,
                        systemImage: activeItem?.id == item.id
                            ? "studentdesk"
                            : (nextItem?.id == item.id ? "calendar.badge.clock" : "clock.arrow.circlepath")
                    )
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()
                }

                Button {
                    openBlock(item)
                } label: {
                    Text(item.className)
                        .font((compact ? Font.caption : .subheadline).weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                let meta = [item.gradeLevel, item.location]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                if !meta.isEmpty {
                    Text(meta)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    if !linkedTasks.isEmpty {
                        Label("\(linkedTasks.count) task\(linkedTasks.count == 1 ? "" : "s")", systemImage: "checklist")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }

                    if let completionText = attendanceCompletionText(for: item, now: now) {
                        Label(completionText, systemImage: "checkmark.circle")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Live Controls")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            presentAttendance(for: item, now: now, schedule: schedule)
                        } label: {
                            Label("Attendance", systemImage: "checklist.checked")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(roster.isEmpty)

                        Button {
                            rosterItem = item
                        } label: {
                            Label("Roster", systemImage: "person.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 10) {
                        Button {
                            homeworkCaptureSession = HomeworkCaptureSession(item: item, date: now)
                        } label: {
                            Label("Homework", systemImage: "text.book.closed")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Menu {
                            Button("Sub Plan", systemImage: "doc.text") {
                                subPlanItem = item
                            }

                            Button("Class Controls", systemImage: "ellipsis.circle") {
                                showingSessionActions = true
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

            }
            .modifier(DashboardCardStyle(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor, compact: compact))
        }
    }

    @ViewBuilder
    private func attendanceDashboardCard(
        schedule: [AlarmItem],
        now: Date,
        activeItem: AlarmItem?,
        compact: Bool
    ) -> some View {
        let currentAttendanceTarget = activeItem ?? schedule.first {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }
        let previousAttendanceItems = schedule
            .filter {
                endDateToday(for: $0, now: now) < now &&
                !rosterStudents(for: $0).isEmpty
            }
            .sorted {
                endDateToday(for: $0, now: now) > endDateToday(for: $1, now: now)
            }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Attendance", systemImage: "checklist.checked")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()
            }

            if let currentAttendanceTarget {
                Button {
                    openBlock(currentAttendanceTarget)
                } label: {
                    Text(currentAttendanceTarget.className)
                        .font((compact ? Font.caption : .subheadline).weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if let completionText = attendanceCompletionText(for: currentAttendanceTarget, now: now) {
                    Text(completionText)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }

                Text("Open the current block quickly or catch up on an earlier class from one place.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)

                Button {
                    presentAttendance(for: currentAttendanceTarget, now: now, schedule: schedule)
                } label: {
                    Label("Open Current Attendance", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(rosterStudents(for: currentAttendanceTarget).isEmpty)
            } else {
                Text("No active class right now.")
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                Text("Use the most recent class below if you need to catch up on attendance.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }

            if !previousAttendanceItems.isEmpty {
                Menu {
                    ForEach(previousAttendanceItems) { previousItem in
                        Button {
                            presentAttendance(for: previousItem, now: now, schedule: schedule)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(previousItem.className)
                                Text(
                                    "\(previousItem.startTime.formatted(date: .omitted, time: .shortened)) - \(previousItem.endTime.formatted(date: .omitted, time: .shortened))"
                                )
                            }
                        }
                    }
                } label: {
                    Label("Catch Up Previous Attendance (\(previousAttendanceItems.count))", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            Button {
                homeworkReviewDate = now
                showingHomeworkReview = true
            } label: {
                Label("Review Homework", systemImage: "text.book.closed")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(attendanceRecordsForToday(now: now).allSatisfy {
                $0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })

            Menu {
                Button("Attendance Summary (.txt)", systemImage: "doc.text") {
                    exportTodayAttendance(as: .text, schedule: schedule, now: now)
                }

                Button("Attendance Summary (.csv)", systemImage: "tablecells") {
                    exportTodayAttendance(as: .csv, schedule: schedule, now: now)
                }

                Button("Attendance Summary (.pdf)", systemImage: "doc.richtext") {
                    exportTodayAttendance(as: .pdf, schedule: schedule, now: now)
                }
            } label: {
                Label("Export Attendance", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .disabled(attendanceRecordsForToday(now: now).isEmpty)
        }
        .modifier(DashboardCardStyle(accent: .blue, compact: compact))
    }

    @ViewBuilder
    private func subPlanCard(schedule: [AlarmItem], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sub Plan", systemImage: "doc.text")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))
                Spacer()
            }

            Text("Choose a plan date, then build the substitute packet with the correct schedule, roster, supports, notes, and attendance for that day.")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)

            DatePicker(
                "Plan Date",
                selection: $dailySubPlanDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            Button {
                showingDailySubPlan = true
            } label: {
                Label(
                    "Open \(dailySubPlanDate.formatted(date: .abbreviated, time: .omitted)) Sub Plan",
                    systemImage: "square.and.pencil"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }

    @ViewBuilder
    private func studentSupportCard(activeItem: AlarmItem?, nextItem: AlarmItem?, compact: Bool) -> some View {
        let activeSupports = activeItem.map(rosterStudents(for:)) ?? []
        let nextSupports = nextItem.map(rosterStudents(for:)) ?? []
        let relevantTasks = topTasks(for: Date()).filter {
            let key = $0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            return !key.isEmpty && studentSupportsByName[key] != nil
        }

        if let activeItem, !activeSupports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Class Support", systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        rosterItem = activeItem
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(activeItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryView(
                    students: activeSupports,
                    compact: compact,
                    fallback: "Student details stay private until you open the roster."
                )
            }
            .modifier(DashboardCardStyle(accent: activeItem.type.themeColor == .clear ? .blue : activeItem.type.themeColor, compact: compact))
        } else if let nextItem, !nextSupports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Next Class Support", systemImage: "person.2.wave.2.fill")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        rosterItem = nextItem
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(nextItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryView(
                    students: nextSupports,
                    compact: compact,
                    fallback: "Open the class to review roster details when you need them."
                )
            }
            .modifier(DashboardCardStyle(accent: nextItem.type.themeColor == .clear ? .blue : nextItem.type.themeColor, compact: compact))
        } else if relevantTasks.compactMap({ task in
            studentSupportsByName[task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)]
        }).first != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Student Support", systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        openStudentsTab()
                    }
                    .font(.caption.weight(.semibold))
                }

                Text("Confidential student support item")
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                Text("Open the linked class or student record to review details.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
            .modifier(DashboardCardStyle(accent: .mint, compact: compact))
        }
    }

    @ViewBuilder
    private func supportSummaryView(
        students: [StudentSupportProfile],
        compact: Bool,
        fallback: String
    ) -> some View {
        let accommodationsCount = students.filter {
            !$0.accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let promptCount = students.filter {
            !$0.prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let firstPrompt = students
            .map { $0.prompts.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        let summaryParts = [
            students.isEmpty ? nil : "\(students.count) student\(students.count == 1 ? "" : "s")",
            accommodationsCount == 0 ? nil : "\(accommodationsCount) with accommodations",
            promptCount == 0 ? nil : "\(promptCount) with prompts"
        ].compactMap { $0 }

        Text(summaryParts.isEmpty ? fallback : summaryParts.joined(separator: " • "))
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(.secondary)

        if let firstPrompt {
            Text(firstPrompt)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }

    private func rosterStudents(for item: AlarmItem) -> [StudentSupportProfile] {
        if !item.linkedStudentIDs.isEmpty {
            let linkedIDs = Set(item.linkedStudentIDs)
            let linkedProfiles = studentSupportProfiles
                .filter { linkedIDs.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            if !linkedProfiles.isEmpty {
                return linkedProfiles
            }
        }

        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return studentSupportProfiles
            .filter { profile in
                if let classDefinitionID = item.classDefinitionID {
                    guard profileMatches(classDefinitionID: classDefinitionID, profile: profile) else { return false }
                    if gradeKey.isEmpty {
                        return true
                    }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }

                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                if gradeKey.isEmpty || profileGradeKey.isEmpty {
                    return true
                }
                return profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func presentAttendance(for item: AlarmItem, now: Date, schedule: [AlarmItem]) {
        attendanceSession = AttendanceSession(
            item: item,
            date: now,
            schedule: schedule,
            students: rosterStudents(for: item)
        )
    }

    private func dayStatusCard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let remainingCount = schedule.filter { endDateToday(for: $0, now: now) > now }.count
        let finalBlock = schedule.max { startDateToday(for: $0, now: now) < startDateToday(for: $1, now: now) }
        let statusTitle: String
        let statusDetail: String
        let tint: Color

        if let ignoreDate, ignoreDate > now {
            statusTitle = "Alerts Snoozed"
            statusDetail = "Notifications are snoozed until \(ignoreDate.formatted(date: .abbreviated, time: .shortened))."
            tint = .orange
        } else if let activeItem {
            statusTitle = "School Day In Motion"
            statusDetail = "\(remainingCount) block\(remainingCount == 1 ? "" : "s") left today"
            tint = activeItem.accentColor == .clear ? .blue : activeItem.accentColor
        } else if let next = schedule.first(where: { startDateToday(for: $0, now: now) > now }) {
            statusTitle = "Next Block Ahead"
            statusDetail = "\(next.className) starts at \(startDateToday(for: next, now: now).formatted(date: .omitted, time: .shortened))"
            tint = next.accentColor == .clear ? .blue : next.accentColor
        } else {
            statusTitle = "School Day Wrapped"
            statusDetail = "No more scheduled blocks today."
            tint = .indigo
        }

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: ignoreDate != nil && (ignoreDate ?? now) > now ? "bell.slash.fill" : "sparkles")
                    .foregroundStyle(tint)
                    .font(compact ? .headline : .title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Text(statusDetail)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: compact ? 8 : 10) {
                statusPill(
                    title: "Blocks Left",
                    value: "\(remainingCount)",
                    compact: compact
                )

                if let finalBlock {
                    statusPill(
                        title: "Dismissal",
                        value: endDateToday(for: finalBlock, now: now).formatted(date: .omitted, time: .shortened),
                        compact: compact
                    )
                }
            }

            Button {
                openScheduleTab()
            } label: {
                Label("Open Schedule", systemImage: "calendar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .modifier(DashboardCardStyle(accent: tint, compact: compact))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func teacherContextRibbon(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let remainingCount = schedule.filter { endDateToday(for: $0, now: now) > now }.count
        let label: String
        let detail: String
        let tint: Color

        if let nextItem {
            label = "Next"
            detail = "\(nextItem.className) at \(startDateToday(for: nextItem, now: now).formatted(date: .omitted, time: .shortened))"
            tint = nextItem.accentColor == .clear ? .orange : nextItem.accentColor
        } else if let activeItem {
            label = "Now"
            detail = activeItem.className
            tint = activeItem.accentColor == .clear ? .blue : activeItem.accentColor
        } else if schedule.isEmpty {
            label = "Today"
            detail = "No scheduled blocks"
            tint = .secondary
        } else {
            label = "Today"
            detail = "Day is wrapped"
            tint = .indigo
        }

        return Group {
            if let editableItem = nextItem ?? activeItem {
                Button {
                    editingAlarm = editableItem
                } label: {
                    teacherContextRibbonContent(
                        label: label,
                        detail: detail,
                        remainingCount: remainingCount,
                        tint: tint,
                        compact: compact,
                        isInteractive: true
                    )
                }
                .buttonStyle(.plain)
            } else {
                teacherContextRibbonContent(
                    label: label,
                    detail: detail,
                    remainingCount: remainingCount,
                    tint: tint,
                    compact: compact,
                    isInteractive: false
                )
            }
        }
    }

    private func teacherContextRibbonContent(
        label: String,
        detail: String,
        remainingCount: Int,
        tint: Color,
        compact: Bool,
        isInteractive: Bool
    ) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            Label(label, systemImage: label == "Next" ? "calendar.badge.clock" : "play.circle.fill")
                .font((compact ? Font.caption : .subheadline).weight(.bold))
                .foregroundStyle(tint)

            Text(detail)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isInteractive {
                Image(systemName: "pencil")
                    .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            Text("\(remainingCount) left")
                .font((compact ? Font.caption2 : .caption).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 5 : 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.92))
                )
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.10),
                            Color(.secondarySystemBackground).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func statusPill(title: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font((compact ? Font.caption : .subheadline).weight(.bold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }

    private func commitmentsCard(todayCommitments: [CommitmentItem], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Today's Commitments", systemImage: "person.3.sequence.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(todayCommitments.isEmpty ? "Add" : "Manage") {
                    if todayCommitments.isEmpty {
                        showingAddCommitment = true
                    } else {
                        showingCommitmentsManager = true
                    }
                }
                .font(.caption.weight(.semibold))

                if !todayCommitments.isEmpty {
                    Button {
                        showingAddCommitment = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.headline)
                }
            }

            if todayCommitments.isEmpty {
                Text("Add duties, meetings, conferences, or coverage blocks so Today shows the full shape of your school day.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayCommitments.prefix(compact ? 3 : 4)) { commitment in
                        Button {
                            editingCommitment = commitment
                        } label: {
                            commitmentRow(for: commitment, compact: compact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }

    private func commitmentRow(for commitment: CommitmentItem, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: commitment.kind.systemImage)
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(commitment.kind.tint)
                .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                .background(
                    Circle()
                        .fill(commitment.kind.tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(commitmentTimeText(for: commitment))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)

                if !commitment.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(commitment.location)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            commitment.kind.tint.opacity(0.12),
                            Color(.secondarySystemBackground).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(commitment.kind.tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func floatingActionMenu(activeItem: AlarmItem?, now: Date) -> some View {
        return Menu {
            Button("Quick Add", systemImage: "plus.bubble") {
                showingQuickCapture = true
            }

            Button("Tasks", systemImage: "checklist") {
                openTodoTab()
            }

            Button("Notes", systemImage: "square.and.pencil") {
                openNotesTab()
            }

            Button("Homework Review", systemImage: "text.book.closed") {
                homeworkReviewDate = now
                showingHomeworkReview = true
            }

            Divider()

            Button("Schedule", systemImage: "calendar") {
                openScheduleTab()
            }

            Button("Class List", systemImage: "person.3") {
                openStudentsTab()
            }

            Button("Refresh", systemImage: "arrow.clockwise") {
                onRefresh()
            }

            Button("Settings", systemImage: "gearshape") {
                openSettingsTab()
            }
        } label: {
            Label("Actions", systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.18, green: 0.42, blue: 0.72), Color(red: 0.23, green: 0.52, blue: 0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
        }
    }

    private func upcomingStrip(
        schedule: [AlarmItem],
        now: Date,
        nextItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let upcomingItems = laterTodayItems(from: schedule, now: now, nextItem: nextItem)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Coming Later Today", systemImage: "calendar.badge.clock")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if !upcomingItems.isEmpty {
                    Button {
                        openScheduleTab()
                    } label: {
                        cardActionLabel("Schedule", accent: .blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            if upcomingItems.isEmpty {
                Text("No more scheduled blocks after next up.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(upcomingItems) { item in
                            upcomingChip(for: item, compact: compact)
                        }
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .blue, compact: compact))
    }

    private func upcomingChip(for item: AlarmItem, compact: Bool) -> some View {
        Button {
            openBlock(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.accentColor == .clear ? Color.gray.opacity(0.2) : item.accentColor)
                        .frame(width: 8, height: 8)

                    Text(item.className)
                        .font((compact ? Font.caption : .subheadline).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(item.location, systemImage: "mappin.and.ellipse")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: compact ? 140 : 168, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.08),
                                Color(.secondarySystemBackground).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func openBlock(_ item: AlarmItem) {
        editingAlarm = item
    }

    private func topTasksCard(now: Date, compact: Bool = false) -> some View {
        let tasks = topTasks(for: now)
        let highPriorityCount = tasks.filter { $0.priority == .high }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Top Tasks", systemImage: "checklist")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if !tasks.isEmpty {
                    cardMetricLabel(
                        "\(highPriorityCount) high",
                        accent: .orange
                    )
                }

                Button {
                    openTodoTab()
                } label: {
                    cardActionLabel(tasks.isEmpty ? "Add" : "Open", accent: .orange)
                }
                .buttonStyle(.plain)
            }

            if tasks.isEmpty {
                Text("No active school tasks. Add a few to make Today your command center.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        let linkedStudent = savedStudentProfile(for: task.studentOrGroup)
                        taskSummaryRow(task: task, linkedStudent: linkedStudent, compact: compact)
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .orange, compact: compact))
    }

    private func notesSnapshotCard(compact: Bool) -> some View {
        let snapshot = notesSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Notes Snapshot", systemImage: "square.and.pencil")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if snapshot != nil {
                    cardMetricLabel("Live", accent: .teal)
                }

                Button {
                    openNotesTab()
                } label: {
                    cardActionLabel(snapshot == nil ? "Add" : "Open", accent: .teal)
                }
                .buttonStyle(.plain)
            }

            if let snapshot {
                Text(snapshot)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 3 : 4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.teal.opacity(0.08))
                    )
            } else {
                Text("No school notes yet. Keep a running note here for duties, reminders, and meeting details.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Quick school note", text: $quickSchoolNoteText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitQuickSchoolNote()
                    }

                Button("Submit") {
                    submitQuickSchoolNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(quickSchoolNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .modifier(DashboardCardStyle(accent: .teal, compact: compact))
    }

    private func submitQuickSchoolNote() {
        let trimmed = quickSchoolNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        todayQuickNoteDraft = trimmed
        todayQuickNoteDraftToken = Date().timeIntervalSince1970
        quickSchoolNoteText = ""
        openNotesTab()
    }

    private func taskSummaryRow(
        task: TodoItem,
        linkedStudent: StudentSupportProfile?,
        compact: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.task)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                    .lineLimit(2)

                if let linkedStudent {
                    HStack(spacing: 8) {
                        Text(linkedStudent.name)
                            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        studentGradePill(linkedStudent.gradeLevel)
                    }
                }

                Text(taskSubtitle(for: task))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(task.priority.rawValue.capitalized)
                .font(.caption2.weight(.bold))
                .foregroundStyle(task.priority.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(task.priority.color.opacity(0.12))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.10), lineWidth: 1)
        )
    }

    private func cardActionLabel(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
    }

    private func cardMetricLabel(_ value: String, accent: Color) -> some View {
        Text(value)
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
    }

    private func schoolBoundaryCard(
        now: Date,
        schedule: [AlarmItem],
        compact: Bool = false
    ) -> some View {
        let afterHours = isAfterSchoolQuietStart(now)
        let quietStart = schoolQuietStart(on: now)
        let unfinishedSchoolTasks = todos.filter { !$0.isCompleted && $0.workspace == .school }.count
        let unfinishedPersonalTasks = todos.filter { !$0.isCompleted && $0.workspace == .personal }.count
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }.count

        let title: String
        let message: String
        let tint: Color

        if schoolQuietHoursEnabled && afterHours {
            title = hideSchoolDashboardAfterHours ? "School Day Closed" : "After Hours Boundary"
            message = "School alerts are quiet after \(quietStart.formatted(date: .omitted, time: .shortened)). \(unfinishedSchoolTasks) school task\(unfinishedSchoolTasks == 1 ? "" : "s") are paused, and \(unfinishedPersonalTasks) personal task\(unfinishedPersonalTasks == 1 ? "" : "s") remain visible."
            tint = .indigo
        } else if schoolQuietHoursEnabled {
            title = "School Boundary Set"
            message = "Routine school alerts quiet at \(quietStart.formatted(date: .omitted, time: .shortened)). \(remainingBlocks) block\(remainingBlocks == 1 ? "" : "s") remain in today's school flow."
            tint = .teal
        } else {
            title = "After Hours Boundary"
            message = "Set an after-hours quiet time so school reminders stop following you home."
            tint = .secondary
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: afterHours ? "moon.stars.fill" : "lock.shield.fill")
                    .font(compact ? .headline : .title3)
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Text(message)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Settings") {
                    openSettingsTab()
                }
                .font(.caption.weight(.bold))
            }
        }
        .modifier(DashboardCardStyle(accent: tint, compact: compact))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func personalFocusCard(now: Date, compact: Bool = false) -> some View {
        let tasks = topTasks(for: now, workspace: .personal)
        let personalNotePreview = personalNotesText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Personal Focus", systemImage: "house.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(tasks.isEmpty ? "Add" : "Open") {
                    openTodoTab()
                }
                .font(.caption.weight(.semibold))
            }

            if tasks.isEmpty {
                Text("No personal tasks queued. Add a few personal reminders so after-hours mode has a clean landing zone.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(task.priority.color)
                                .frame(width: 9, height: 9)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.task)
                                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                                    .lineLimit(2)

                                Text(taskSubtitle(for: task))
                                    .font(compact ? .caption2 : .caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if !personalNotePreview.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Personal Notes", systemImage: "square.and.pencil")
                            .font((compact ? Font.caption : .subheadline).weight(.semibold))

                        Spacer()

                        Button("Open") {
                            openNotesTab()
                        }
                        .font(.caption.weight(.semibold))
                    }

                    Text(personalNotePreview)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 2 : 3)
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .green, compact: compact))
    }

    private func endOfDayCard(now: Date, schedule: [AlarmItem], compact: Bool = false) -> some View {
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }
        let unfinishedTasks = todos.filter { !$0.isCompleted && $0.workspace == .school }.count
        let dismissal = remainingBlocks.last.map { endDateToday(for: $0, now: now) }
        let carryoverTasks = todos.filter { !$0.isCompleted && $0.bucket == .today && $0.workspace == .school }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("End of Day", systemImage: "sunset.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()
            }

            if remainingBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The teaching day is wrapped. \(unfinishedTasks) task\(unfinishedTasks == 1 ? "" : "s") still open.")
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)

                    if !carryoverTasks.isEmpty {
                        Text("\(carryoverTasks.count) task\(carryoverTasks.count == 1 ? "" : "s") are still marked for today.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)

                        if !compact {
                            ForEach(carryoverTasks.prefix(3)) { task in
                                Text("• \(task.task)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if offerTaskCarryover {
                            Button("Roll Today's Tasks to Tomorrow") {
                                rollTodayTasksToTomorrow()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(remainingBlocks.count) block\(remainingBlocks.count == 1 ? "" : "s") remain, with dismissal around \(dismissal?.formatted(date: .omitted, time: .shortened) ?? "later").")
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(unfinishedTasks) open task\(unfinishedTasks == 1 ? "" : "s") still need attention.")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                openTodoTab()
            } label: {
                Label("Open To Do", systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }

    private func overrideBanner(name: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: "wand.and.stars")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Schedule Override")
                    .font(.subheadline.weight(.bold))

                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Class Trax is running today from the override schedule.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Manage") {
                openScheduleTab()
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.14),
                            Color.cyan.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    private func adjustedTodaySchedule(for now: Date) -> [AlarmItem] {

        let weekday = Calendar.current.component(.weekday, from: now)

        let todaysItems = (overrideSchedule ?? alarms)
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }

        var cumulativeOffset: TimeInterval = 0
        var adjustedItems: [AlarmItem] = []

        for item in todaysItems {
            var adjusted = item

            adjusted.start = item.start.addingTimeInterval(cumulativeOffset)

            let liveHold = liveHoldDuration(for: item, now: now)
            let extra = (extraTimeByItemID[item.id] ?? 0) + liveHold

            adjusted.end = item.end
                .addingTimeInterval(cumulativeOffset)
                .addingTimeInterval(extra)

            adjustedItems.append(adjusted)
            cumulativeOffset += extra
        }

        return adjustedItems
    }

    private func laterTodayItems(
        from schedule: [AlarmItem],
        now: Date,
        nextItem: AlarmItem?
    ) -> [AlarmItem] {
        let nextID = nextItem?.id

        return schedule
            .filter { startDateToday(for: $0, now: now) > now && $0.id != nextID }
            .prefix(3)
            .map { $0 }
    }

    private func displayableNextItem(_ item: AlarmItem?, now: Date) -> AlarmItem? {
        guard let item else { return nil }
        guard startDateToday(for: item, now: now).timeIntervalSince(now) <= 7200 else { return nil }
        return item
    }

    private func commitmentsForToday(now: Date) -> [CommitmentItem] {
        resolvedCommitments(for: now, from: commitments)
    }

    private func loadDashboardCardOrderIfNeeded() {
        let stored = decodeDashboardCardOrder(from: storedDashboardCardOrder)
        dashboardCardOrder = stored.isEmpty ? TodayDashboardCard.defaultOrder : stored
        hiddenDashboardCards = decodeHiddenDashboardCards(from: storedHiddenDashboardCards)
    }

    private func persistDashboardCardOrder(_ cards: [TodayDashboardCard]) {
        storedDashboardCardOrder = cards.map(\.rawValue).joined(separator: ",")
    }

    private func persistHiddenDashboardCards(_ cards: Set<TodayDashboardCard>) {
        storedHiddenDashboardCards = cards.map(\.rawValue).sorted().joined(separator: ",")
    }

    private func decodeDashboardCardOrder(from string: String) -> [TodayDashboardCard] {
        let keys = string
            .split(separator: ",")
            .map(String.init)

        guard !keys.isEmpty else {
            return TodayDashboardCard.defaultOrder
        }

        var seen = Set<TodayDashboardCard>()
        var resolved: [TodayDashboardCard] = []

        for key in keys {
            guard let card = TodayDashboardCard(rawValue: key), !seen.contains(card) else { continue }
            resolved.append(card)
            seen.insert(card)
        }

        for card in TodayDashboardCard.defaultOrder where !seen.contains(card) {
            resolved.append(card)
        }

        return resolved
    }

    private func decodeHiddenDashboardCards(from string: String) -> Set<TodayDashboardCard> {
        Set(
            string
                .split(separator: ",")
                .compactMap { TodayDashboardCard(rawValue: String($0)) }
        )
    }

    private func resetDashboardLayout() {
        dashboardCardOrder = TodayDashboardCard.defaultOrder
        hiddenDashboardCards.removeAll()
    }

    private func topTasks(for now: Date, workspace: TodoItem.Workspace = .school) -> [TodoItem] {
        todos
            .filter { !$0.isCompleted && $0.workspace == workspace }
            .sorted { lhs, rhs in
                let lhsBucket = bucketRank(lhs.bucket)
                let rhsBucket = bucketRank(rhs.bucket)

                if lhsBucket != rhsBucket {
                    return lhsBucket < rhsBucket
                }

                let lhsRank = priorityRank(lhs.priority)
                let rhsRank = priorityRank(rhs.priority)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?):
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.task.localizedCaseInsensitiveCompare(rhs.task) == .orderedAscending
                }
            }
            .prefix(3)
            .map { $0 }
    }

    private func taskSubtitle(for task: TodoItem) -> String {
        var parts = [task.workspace.displayName, task.category.displayName, task.bucket.displayName]

        if let due = task.dueDate {
            parts.append("Due \(due.formatted(date: .abbreviated, time: .omitted))")
        }

        if !task.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.linkedContext)
        }

        if !task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.studentOrGroup)
        }

        if task.reminder != .none {
            parts.append(task.reminder.displayName)
        }

        if !task.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.followUpNote)
        }

        if task.priority != .none {
            parts.append("\(task.priority.rawValue) Priority")
        }

        return parts.joined(separator: " • ")
    }

    private func savedStudentProfile(for name: String) -> StudentSupportProfile? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return studentSupportsByName[key]
    }

    @ViewBuilder
    private func studentGradePill(_ gradeLevel: String) -> some View {
        let color = GradeLevelOption.color(for: gradeLevel)
        let label = GradeLevelOption.pillLabel(for: gradeLevel)

        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(color == .yellow ? Color.black.opacity(0.8) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    private func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high: return 0
        case .med: return 1
        case .low: return 2
        case .none: return 3
        }
    }

    private func bucketRank(_ bucket: TodoItem.Bucket) -> Int {
        switch bucket {
        case .today: return 0
        case .tomorrow: return 1
        case .thisWeek: return 2
        case .later: return 3
        }
    }

    private func shouldShowDayStatus(now: Date, schedule: [AlarmItem], activeItem: AlarmItem?) -> Bool {
        if let ignoreDate, ignoreDate > now {
            return true
        }

        if activeItem != nil {
            return false
        }

        return schedule.isEmpty || schedule.contains { startDateToday(for: $0, now: now) > now }
    }

    private var notesSnapshot: String? {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " • ")

        return normalized.isEmpty ? nil : normalized
    }

    private var suggestedTaskContexts: [String] {
        let classContexts = (overrideSchedule ?? alarms)
            .map(\.className)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let commitmentContexts = commitments
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Array(Set((classContexts + commitmentContexts).filter { !$0.isEmpty }))
            .sorted()
    }

    private func preferredCaptureContext(for schedule: [AlarmItem]) -> String? {
        let now = Date()
        if let active = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }) {
            return active.className
        }

        return schedule.first(where: {
            startDateToday(for: $0, now: now) > now
        })?.className
    }

    private func preferredCaptureCategory(for schedule: [AlarmItem], now: Date) -> TodoItem.Category? {
        let item = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }) ?? schedule.first(where: {
            startDateToday(for: $0, now: now) > now
        })

        guard let item else { return nil }

        switch item.type {
        case .math, .ela, .science, .socialStudies:
            return .prep
        case .assembly:
            return .meetingFollowUp
        case .prep:
            return .admin
        case .studyTime:
            return .prep
        case .recess, .lunch, .transition:
            return .classroom
        case .other, .blank:
            return .other
        }
    }

    private func rollTodayTasksToTomorrow() {
        for index in todos.indices {
            if !todos[index].isCompleted && todos[index].bucket == .today && todos[index].workspace == .school {
                todos[index].bucket = .tomorrow
            }
        }
    }

    private func commitmentTimeText(for commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    private func schoolQuietStart(on date: Date) -> Date {
        Calendar.current.date(
            bySettingHour: schoolQuietHour,
            minute: schoolQuietMinute,
            second: 0,
            of: date
        ) ?? date
    }

    private func isAfterSchoolQuietStart(_ now: Date) -> Bool {
        guard schoolQuietHoursEnabled else { return false }
        return now >= schoolQuietStart(on: now)
    }

    private func shouldShowAfterHoursPersonalMode(now: Date, schedule: [AlarmItem]) -> Bool {
        guard hideSchoolDashboardAfterHours else { return false }
        guard isAfterSchoolQuietStart(now) else { return false }
        return !schedule.contains { endDateToday(for: $0, now: now) > now }
    }

    private func anchoredDate(for date: Date, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
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

    private func warningForUpcomingBlock(_ item: AlarmItem?, now: Date) -> InAppWarning? {

        guard let item else { return nil }
        guard item.type != .blank else { return nil }

        let start = startDateToday(for: item, now: now)
        let secondsRemaining = Int(start.timeIntervalSince(now))
        let matchingWarning = item.warningLeadTimes.first { secondsRemaining == $0 * 60 }
        return matchingWarning.map { InAppWarning(item: item, minutesRemaining: $0) }
    }

    private func secondaryBackgroundColor(for item: AlarmItem?) -> Color {

        guard let item else { return Color.cyan }

        switch item.type {
        case .math:
            return .orange
        case .ela:
            return .yellow
        case .science:
            return .green
        case .socialStudies:
            return .mint
        case .assembly:
            return .pink
        case .prep:
            return .cyan
        case .studyTime:
            return .blue
        case .recess:
            return .teal
        case .lunch:
            return .pink
        case .transition:
            return Color(.systemGray5)
        case .other:
            return Color(.systemGray3)
        case .blank:
            return Color(.systemBackground)
        }
    }

    private func handleWarningTrigger(_ warning: InAppWarning?, key: String?) {

        guard let warning, let key else { return }
        guard lastWarningKey != key else { return }

        lastWarningKey = key
        warningDismissTask?.cancel()

        BellFeedbackManager.shared.playSelectedBellFeedback()

        withAnimation {
            activeWarning = warning
        }

        warningDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation {
                    activeWarning = nil
                }
            }
        }
    }

    private func extend(_ item: AlarmItem, byMinutes minutes: Int) {
        SessionControlStore.extend(itemID: item.id, byMinutes: minutes)
    }

    private func toggleHold(for item: AlarmItem, now: Date) {
        SessionControlStore.toggleHold(itemID: item.id, now: now)
    }

    private func skipBell(for item: AlarmItem) {
        SessionControlStore.skipBell(itemID: item.id)
        BellCountdownEngine.shared.reset()
    }

    private func isHeld(_ item: AlarmItem) -> Bool {
        SessionControlStore.isHeld(itemID: item.id)
    }

    private func liveHoldDuration(for item: AlarmItem, now: Date) -> TimeInterval {
        SessionControlStore.liveHoldDuration(for: item.id, now: now)
    }

    private func handleActiveItemChange(_ newValue: UUID?) {
        if lastActiveItemID != newValue {
            BellCountdownEngine.shared.reset()
            lastActiveItemID = newValue
        }

        SessionControlStore.clearHoldIfNeeded(activeItemID: newValue)
    }

    private func processBellIfNeeded(_ activeItem: AlarmItem?, now: Date) {
        guard let activeItem else {
            BellCountdownEngine.shared.reset()
            return
        }

        guard !skippedBellItemIDs.contains(activeItem.id) else { return }

        let secondsRemaining = Int(ceil(endDateToday(for: activeItem, now: now).timeIntervalSince(now)))
        BellCountdownEngine.shared.process(secondsRemaining: secondsRemaining)
    }

    private func liveActivityState(for activeItem: AlarmItem?, now: Date) -> LiveActivitySnapshot? {
        guard liveActivitiesEnabled else { return nil }
        guard let activeItem else { return nil }

        let nextItem = displayableNextItem(adjustedTodaySchedule(for: now).first {
            startDateToday(for: $0, now: now) > now
        }, now: now)

        let room = activeItem.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let liveHold = liveHoldDuration(for: activeItem, now: now)
        let stableEndTime = endDateToday(for: activeItem, now: now).addingTimeInterval(-liveHold)

        return LiveActivitySnapshot(
            className: activeItem.className,
            room: room,
            endTime: stableEndTime,
            isHeld: isHeld(activeItem),
            iconName: activeItem.scheduleType.symbolName,
            nextClassName: nextItem?.className ?? "",
            nextIconName: nextItem?.scheduleType.symbolName ?? ""
        )
    }

    private func syncLiveActivity(with snapshot: LiveActivitySnapshot?) {
        pendingLiveActivityStopTask?.cancel()

        guard liveActivitiesEnabled else {
            LiveActivityManager.stop()
            return
        }

        guard let snapshot else {
            pendingLiveActivityStopTask = Task {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                LiveActivityManager.stop()
            }
            return
        }

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

    private func widgetSnapshot(activeItem: AlarmItem?, nextItem: AlarmItem?, now: Date) -> ClassTraxWidgetSnapshot {
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
                isHeld: isHeld(item)
            )
        }

        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: activeItem.map(summary),
            next: displayableNextItem(nextItem, now: now).map(summary)
        )
    }

    private func syncWidgetSnapshot(_ snapshot: ClassTraxWidgetSnapshot) {
#if canImport(WidgetKit)
        WidgetSnapshotStore.save(snapshot)
        WatchSessionSyncManager.shared.sync(snapshot: snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassTraxHomeWidget")
#else
        WidgetSnapshotStore.save(snapshot)
        WatchSessionSyncManager.shared.sync(snapshot: snapshot)
#endif
    }

    private func landscapeHeader(now: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(headerStatusText(for: now), systemImage: currentHeaderSymbol(now: now))
                .font(.caption.weight(.semibold))
                .foregroundStyle(currentHeaderAccent(now: now))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(currentHeaderAccent(now: now).opacity(0.12))
                )

            if let ignoreDate, ignoreDate > now {
                notificationPauseBadge(until: ignoreDate, compact: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notificationPauseBadge(until date: Date, compact: Bool = false) -> some View {
        Label(
            compact
                ? "Snoozed Until \(date.formatted(date: .omitted, time: .shortened))"
                : "Alerts Snoozed Until \(date.formatted(date: .abbreviated, time: .shortened))",
            systemImage: "bell.slash.fill"
        )
        .font((compact ? Font.caption2 : .caption).weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
    }

    private func headerStatusText(for now: Date) -> String {
        if let ignoreDate, ignoreDate > now {
            return "Alerts snoozed while you pause the school-day flow."
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return "After-hours mode is active and the dashboard is shifting personal."
        }

        let remainingBlocks = adjustedTodaySchedule(for: now).filter { endDateToday(for: $0, now: now) > now }.count
        if remainingBlocks == 0 {
            return "The schedule is clear for the rest of today."
        }

        return "\(remainingBlocks) block\(remainingBlocks == 1 ? "" : "s") remain in today's teaching flow."
    }

    private func currentHeaderSymbol(now: Date) -> String {
        if let ignoreDate, ignoreDate > now {
            return "bell.slash.fill"
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return "moon.stars.fill"
        }

        return "sun.max.fill"
    }

    private func currentHeaderAccent(now: Date) -> Color {
        if let ignoreDate, ignoreDate > now {
            return .orange
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return .indigo
        }

        return .blue
    }

    private func todaysBlockCount(for now: Date) -> Int {
        adjustedTodaySchedule(for: now).count
    }

    private func todayHeaderStat(title: String, value: String, accent: Color, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    todayHeaderStatContent(title: title, value: value, accent: accent)
                }
                .buttonStyle(.plain)
            } else {
                todayHeaderStatContent(title: title, value: value, accent: accent)
            }
        }
    }

    private func todayHeaderStatContent(title: String, value: String, accent: Color) -> some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func todayHeaderBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.16),
                        Color.white.opacity(0.45),
                        Color(.secondarySystemBackground).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func todayHeaderBorder(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(accent.opacity(0.14), lineWidth: 1)
    }

    private func mostRecentAttendanceItem(from schedule: [AlarmItem], now: Date) -> AlarmItem? {
        schedule
            .filter { block in
                endDateToday(for: block, now: now) < now &&
                !rosterStudents(for: block).isEmpty
            }
            .max { lhs, rhs in
                endDateToday(for: lhs, now: now) < endDateToday(for: rhs, now: now)
            }
    }

    private func attendanceRecordsForToday(now: Date) -> [AttendanceRecord] {
        let dateKey = AttendanceRecord.dateKey(for: now)
        return attendanceRecords.filter { $0.dateKey == dateKey }
    }

    private func classHomeworkText(for item: AlarmItem, now: Date) -> String {
        let dateKey = AttendanceRecord.dateKey(for: now)
        return attendanceRecords.first(where: {
            $0.dateKey == dateKey &&
            $0.isClassHomeworkNote &&
            attendanceRecordMatchesClass($0, item: item)
        })?.absentHomework ?? ""
    }

    private func saveClassHomework(_ text: String, for item: AlarmItem, now: Date) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateKey = AttendanceRecord.dateKey(for: now)
        let roster = rosterStudents(for: item)

        attendanceRecords.removeAll {
            $0.dateKey == dateKey &&
            ($0.isClassHomeworkNote || $0.isHomeworkAssignmentOnly) &&
            attendanceRecordMatchesClass($0, item: item)
        }

        guard !trimmed.isEmpty else { return }

        attendanceRecords.append(
            AttendanceRecord(
                dateKey: dateKey,
                className: item.className,
                gradeLevel: GradeLevelOption.normalized(item.gradeLevel),
                studentName: "",
                studentID: nil,
                classDefinitionID: item.classDefinitionID,
                blockID: item.id,
                blockStartTime: item.startTime,
                blockEndTime: item.endTime,
                status: .present,
                absentHomework: trimmed
            )
        )

        for student in roster {
            attendanceRecords.append(
                AttendanceRecord(
                    dateKey: dateKey,
                    className: item.className,
                    gradeLevel: GradeLevelOption.normalized(student.gradeLevel).isEmpty ? GradeLevelOption.normalized(item.gradeLevel) : GradeLevelOption.normalized(student.gradeLevel),
                    studentName: student.name,
                    studentID: student.id,
                    classDefinitionID: item.classDefinitionID,
                    blockID: item.id,
                    blockStartTime: item.startTime,
                    blockEndTime: item.endTime,
                    status: .present,
                    absentHomework: trimmed,
                    isHomeworkAssignmentOnly: true
                )
            )
        }
    }

    private func attendanceRecordMatchesClass(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        if let blockID = record.blockID {
            return blockID == item.id
        }

        if recordMatchesBlockTime(record, item: item) {
            return true
        }

        if let classDefinitionID = item.classDefinitionID, let recordClassDefinitionID = record.classDefinitionID {
            return classDefinitionID == recordClassDefinitionID
        }

        return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className) &&
            normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
    }

    private func recordMatchesBlockTime(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        guard
            let recordStartTime = record.blockStartTime,
            let recordEndTime = record.blockEndTime
        else {
            return false
        }

        return blockTimeSignature(start: recordStartTime, end: recordEndTime) ==
            blockTimeSignature(start: item.startTime, end: item.endTime)
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

    private func attendanceCompletionText(for item: AlarmItem, now: Date) -> String? {
        let roster = rosterStudents(for: item)
        guard !roster.isEmpty else { return nil }
        let dateKey = AttendanceRecord.dateKey(for: now)
        let markedKeys = Set(
            attendanceRecords
                .filter {
                    $0.isAttendanceEntry &&
                    $0.dateKey == dateKey &&
                    attendanceRecordMatchesClass($0, item: item)
                }
                .compactMap { record in
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName)
                }
        )
        let markedCount = roster.filter { student in
            guard let key = attendanceMatchKey(studentID: student.id, studentName: student.name) else { return false }
            return markedKeys.contains(key)
        }.count
        return markedCount >= roster.count
            ? "Attendance complete"
            : "Attendance \(markedCount)/\(roster.count)"
    }

    private enum TodayAttendanceExportFormat {
        case text
        case csv
        case pdf
    }

    private func exportTodayAttendance(as format: TodayAttendanceExportFormat, schedule: [AlarmItem], now: Date) {
        let records = attendanceRecordsForToday(now: now)
        guard !records.isEmpty else { return }

        let titleDate = now.formatted(date: .abbreviated, time: .omitted)
        let filenameDate = AttendanceRecord.dateKey(for: now)
        let title = "Attendance Summary - \(titleDate)"
        let body = todayAttendanceExportBody(records: records, schedule: schedule)

        let exportURL: URL?
        switch format {
        case .pdf:
            exportURL = makeSubPlanPDF(
                title: title,
                filename: "classtrax-attendance-summary-\(filenameDate)",
                body: body
            )
        case .text:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("classtrax-attendance-summary-\(filenameDate)-\(UUID().uuidString).txt")
            do {
                try "\(title)\n\n\(body)".write(to: url, atomically: true, encoding: .utf8)
                exportURL = url
            } catch {
                exportURL = nil
            }
        case .csv:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("classtrax-attendance-summary-\(filenameDate)-\(UUID().uuidString).csv")
            do {
                try todayAttendanceCSV(records: records, schedule: schedule).write(to: url, atomically: true, encoding: .utf8)
                exportURL = url
            } catch {
                exportURL = nil
            }
        }

        guard let exportURL else { return }
        todayAttendanceExportURL = exportURL
        showingTodayAttendanceShareSheet = true
    }

    private func todayAttendanceExportBody(records: [AttendanceRecord], schedule: [AlarmItem]) -> String {
        let classOrder = Dictionary(
            uniqueKeysWithValues: schedule.enumerated().map { index, block in
                (normalizedStudentKey(block.className), index)
            }
        )
        let classHomeworkNotes = records.filter(\.isClassHomeworkNote)
        let studentRecords = records.filter(\.isAttendanceEntry)

        let grouped = Dictionary(grouping: studentRecords) { record in
            if let studentID = record.studentID {
                return studentID.uuidString
            }
            return normalizedStudentKey(record.studentName)
        }

        var sections: [String] = grouped.values
            .sorted { lhs, rhs in
                let leftName = lhs.first?.studentName ?? ""
                let rightName = rhs.first?.studentName ?? ""
                return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
            }
            .compactMap { studentRecords in
                let sortedRecords = studentRecords.sorted { lhs, rhs in
                    let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: lhs))] ?? .max
                    let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: rhs))] ?? .max
                    if leftOrder == rightOrder {
                        return resolvedAttendanceClassName(for: lhs)
                            .localizedCaseInsensitiveCompare(resolvedAttendanceClassName(for: rhs)) == .orderedAscending
                    }
                    return leftOrder < rightOrder
                }

                let studentName = sortedRecords.first?.studentName ?? "Student"
                let gradeLevel = sortedRecords.first?.gradeLevel ?? ""
                let attendanceExceptions = sortedRecords.filter { $0.status != .present }
                let statusLines = attendanceExceptions.map {
                    "\(resolvedAttendanceClassName(for: $0)): \($0.status.rawValue)"
                }
                let homework = sortedRecords
                    .compactMap(\.absentHomework)
                    .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                let homeworkLines = formattedMissingWorkLines(from: homework)

                guard !statusLines.isEmpty || !homeworkLines.isEmpty else {
                    return nil
                }

                var sections = ["Student: \(studentName)"]
                if !gradeLevel.isEmpty {
                    sections.append("Grade: \(gradeLevel)")
                }
                if !statusLines.isEmpty {
                    sections.append("Attendance:")
                    sections.append(contentsOf: statusLines.map { "• \($0)" })
                }
                if !homeworkLines.isEmpty {
                    sections.append("Missing Work:")
                    sections.append(contentsOf: homeworkLines.map { "• \($0)" })
                }
                return sections.joined(separator: "\n")
            }
        if !classHomeworkNotes.isEmpty {
            let homeworkSection = classHomeworkNotes
                .sorted {
                    let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: $0))] ?? .max
                    let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: $1))] ?? .max
                    return leftOrder < rightOrder
                }
                .flatMap { record in
                    formattedMissingWorkLines(from: record.absentHomework).map {
                        "• \(resolvedAttendanceClassName(for: record)): \($0)"
                    }
                }

            if !homeworkSection.isEmpty {
                sections.append((["Class Homework:"] + homeworkSection).joined(separator: "\n"))
            }
        }

        return sections.isEmpty ? "All recorded students were marked present." : sections.joined(separator: "\n\n")
    }

    private func todayAttendanceCSV(records: [AttendanceRecord], schedule: [AlarmItem]) -> String {
        let classOrder = Dictionary(
            uniqueKeysWithValues: schedule.enumerated().map { index, block in
                (normalizedStudentKey(block.className), index)
            }
        )

        let sortedRecords = records
            .filter(\.isAttendanceEntry)
            .sorted { lhs, rhs in
            let leftName = lhs.studentName.localizedLowercase
            let rightName = rhs.studentName.localizedLowercase
            if leftName != rightName {
                return leftName < rightName
            }

            let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: lhs))] ?? .max
            let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: rhs))] ?? .max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }

            return resolvedAttendanceClassName(for: lhs)
                .localizedCaseInsensitiveCompare(resolvedAttendanceClassName(for: rhs)) == .orderedAscending
        }

        let header = [
            "date",
            "studentName",
            "gradeLevel",
            "className",
            "status",
            "missingWork"
        ].joined(separator: ",")

        let rows = sortedRecords.map { record in
            [
                record.dateKey,
                record.studentName,
                record.gradeLevel,
                resolvedAttendanceClassName(for: record),
                record.status.rawValue,
                record.absentHomework
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func resolvedAttendanceClassName(for record: AttendanceRecord) -> String {
        if let classDefinitionID = record.classDefinitionID,
           let definition = classDefinitions.first(where: { $0.id == classDefinitionID }) {
            let name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        let rawName = record.className.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawName.isEmpty || rawName.localizedCaseInsensitiveContains("managedobject") {
            return "Class Not Set"
        }
        return rawName
    }

    private func formattedMissingWorkLines(from homework: String?) -> [String] {
        guard let homework else { return [] }
        return homework
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct AttendanceSession: Identifiable {
    let item: AlarmItem
    let date: Date
    let schedule: [AlarmItem]
    let students: [StudentSupportProfile]

    var id: UUID { item.id }
}

private struct HomeworkCaptureSession: Identifiable {
    let item: AlarmItem
    let date: Date

    var id: UUID { item.id }
}

struct AttendanceEditorView: View {
    private enum StatusChoice: String, CaseIterable, Identifiable {
        case present = "Present"
        case absent = "Absent"
        case tardy = "Tardy"
        case excused = "Excused"

        var id: String { rawValue }

        var status: AttendanceRecord.Status {
            switch self {
            case .present: return .present
            case .absent: return .absent
            case .tardy: return .tardy
            case .excused: return .excused
            }
        }
    }

    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]
    let onCommit: ([AttendanceRecord]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var baseRecords: [AttendanceRecord]
    @State private var draftClassRecords: [AttendanceRecord]
    @State private var classMissingWork: String
    @State private var showingClassNoteEditor = false
    @State private var editingStudentHomework: StudentSupportProfile?
    @State private var applyMissingWorkFeedback: String?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var didCommit = false

    init(
        item: AlarmItem,
        date: Date,
        students: [StudentSupportProfile],
        records: [AttendanceRecord],
        onCommit: @escaping ([AttendanceRecord]) -> Void
    ) {
        self.item = item
        self.date = date
        self.students = students
        self.onCommit = onCommit
        let dateKey = AttendanceRecord.dateKey(for: date)
        let splitRecords = Self.splitRecords(records, for: item, dateKey: dateKey)
        _baseRecords = State(initialValue: splitRecords.base)
        _draftClassRecords = State(initialValue: splitRecords.currentClass)
        _classMissingWork = State(initialValue: Self.defaultMissingWork(from: splitRecords.currentClass))
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: date)
    }

    private var normalizedGrade: String {
        GradeLevelOption.normalized(item.gradeLevel)
    }

    private var currentClassRecords: [AttendanceRecord] {
        draftClassRecords.filter(\.isAttendanceEntry)
    }

    private var recordsByStudentID: [UUID: AttendanceRecord] {
        currentClassRecords.reduce(into: [UUID: AttendanceRecord]()) { partialResult, record in
            if let studentID = record.studentID {
                partialResult[studentID] = record
            }
        }
    }

    private var unmarkedCount: Int {
        students.filter { status(for: $0) == nil }.count
    }

    private var absentCount: Int {
        students.filter { status(for: $0) == .absent }.count
    }

    private var tardyCount: Int {
        students.filter { status(for: $0) == .tardy }.count
    }

    private var excusedCount: Int {
        students.filter { status(for: $0) == .excused }.count
    }

    private var earlierAbsentStudents: [StudentSupportProfile] {
        students.filter { student in
            status(for: student) == nil && earlierAbsentRecord(for: student) != nil
        }
    }

    private var markedStudentKeys: Set<String> {
        Set(
            currentClassRecords
                .compactMap { record in
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName)
                }
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.className)
                        .font(.headline)
                    Text("\(date.formatted(date: .abbreviated, time: .omitted)) • \(item.gradeLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Summary") {
                LabeledContent("Unmarked", value: "\(unmarkedCount)")
                LabeledContent("Absent", value: "\(absentCount)")
                LabeledContent("Tardy", value: "\(tardyCount)")
                LabeledContent("Excused", value: "\(excusedCount)")

                if !earlierAbsentStudents.isEmpty {
                    Button("Carry Forward Earlier Absences (\(earlierAbsentStudents.count))") {
                        carryForwardEarlierAbsences()
                    }
                }
            }

            Section("Class Missing Work") {
                Button(classMissingWork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Set Class Missing Work" : "Edit Class Missing Work") {
                    showingClassNoteEditor = true
                }

                if !classMissingWork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(classMissingWork)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Apply to \(absentCount) Absent Student\(absentCount == 1 ? "" : "s")") {
                        applyClassMissingWorkToAbsentStudents()
                    }
                    .disabled(absentCount == 0)

                    if let applyMissingWorkFeedback {
                        Text(applyMissingWorkFeedback)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Mark Remaining Present") {
                    markRemainingPresent()
                }
            }

            Section("Students") {
                ForEach(students) { student in
                    studentRow(student)
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    commit()
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    exportAttendance()
                }
                .disabled(students.isEmpty)
            }
        }
        .sheet(isPresented: $showingClassNoteEditor) {
            NavigationStack {
                AttendanceNoteEditorView(
                    title: item.className,
                    helperText: "This note auto-fills when you mark a student absent for this period.",
                    initialText: classMissingWork,
                    onSave: {
                        classMissingWork = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        upsertClassHomeworkRecord()
                    }
                )
            }
        }
        .sheet(item: $editingStudentHomework) { student in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: student.name,
                    helperText: "Edit the saved homework for this absent student.",
                    initialText: existingRecord(for: student)?.absentHomework ?? classMissingWork,
                    onSave: { updateHomework($0, for: student) }
                )
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .onDisappear {
            commit()
        }
    }

    private func studentRow(_ student: StudentSupportProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.name)
                        .font(.body.weight(.semibold))
                    if !student.accommodations.isEmpty {
                        Text(student.accommodations)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(statusLabel(for: student))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(StatusChoice.allCases) { choice in
                    Button(choice.rawValue) {
                        setStatus(choice.status, for: student)
                    }
                    .buttonStyle(.bordered)
                    .tint(status(for: student) == choice.status ? tint(for: choice.status) : .gray)
                }

                if status(for: student) != nil {
                    Button("Clear") {
                        clearStatus(for: student)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.caption)

            if status(for: student) == .absent,
               !classMissingWork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(existingRecord(for: student)?.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (existingRecord(for: student)?.absentHomework ?? classMissingWork)
                        : classMissingWork)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Spacer()

                    Button("Edit") {
                        editingStudentHomework = student
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func status(for student: StudentSupportProfile) -> AttendanceRecord.Status? {
        guard let existing = existingRecord(for: student) else { return nil }
        return existing.status
    }

    private func attendanceMatchKey(studentID: UUID?, studentName: String) -> String? {
        if let studentID {
            return studentID.uuidString.lowercased()
        }

        let normalizedName = normalizedStudentKey(studentName)
        return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
    }

    private func statusLabel(for student: StudentSupportProfile) -> String {
        status(for: student)?.rawValue ?? "Unmarked"
    }

    private func setStatus(_ status: AttendanceRecord.Status, for student: StudentSupportProfile) {
        if let index = recordIndex(for: student) {
            draftClassRecords[index].status = status
            if status != .absent {
                draftClassRecords[index].absentHomework = ""
            } else if draftClassRecords[index].absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftClassRecords[index].absentHomework = classMissingWork
            }
        } else {
            draftClassRecords.append(
                AttendanceRecord(
                    dateKey: dateKey,
                    className: item.className,
                    gradeLevel: normalizedGrade,
                    studentName: student.name,
                    studentID: student.id,
                    classDefinitionID: item.classDefinitionID,
                    blockID: item.id,
                    blockStartTime: item.startTime,
                    blockEndTime: item.endTime,
                    status: status,
                    absentHomework: status == .absent ? classMissingWork : ""
                )
            )
        }
    }

    private func clearStatus(for student: StudentSupportProfile) {
        guard let index = recordIndex(for: student) else { return }
        draftClassRecords.remove(at: index)
    }

    private func applyClassMissingWorkToAbsentStudents() {
        let trimmed = classMissingWork.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var appliedCount = 0
        for student in students where status(for: student) == .absent {
            if let index = recordIndex(for: student) {
                draftClassRecords[index].absentHomework = trimmed
                appliedCount += 1
            }
        }
        upsertClassHomeworkRecord()
        applyMissingWorkFeedback = appliedCount == 1
            ? "Applied to 1 absent student."
            : "Applied to \(appliedCount) absent students."
    }

    private func markRemainingPresent() {
        for student in students where status(for: student) == nil {
            setStatus(.present, for: student)
        }
    }

    private func updateHomework(_ text: String, for student: StudentSupportProfile) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = recordIndex(for: student) else { return }
        draftClassRecords[index].absentHomework = trimmed
    }

    private func carryForwardEarlierAbsences() {
        for student in earlierAbsentStudents {
            setStatus(.absent, for: student)
            guard let previousRecord = earlierAbsentRecord(for: student),
                  let index = recordIndex(for: student),
                  draftClassRecords[index].absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }
            draftClassRecords[index].absentHomework = previousRecord.absentHomework
        }
    }

    private func exportAttendance() {
        let header = "date,className,gradeLevel,studentName,status,absentHomework"
        let rows = students.map { student in
            let record = existingRecord(for: student)
            return [
                dateKey,
                item.className,
                normalizedGrade,
                student.name,
                record?.status.rawValue ?? "",
                record?.absentHomework ?? ""
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let filename = "classtrax-attendance-\(dateKey)-\(item.className.replacingOccurrences(of: " ", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func commit() {
        guard !didCommit else { return }
        didCommit = true
        upsertClassHomeworkRecord()
        onCommit(baseRecords + draftClassRecords)
    }

    private func upsertClassHomeworkRecord() {
        draftClassRecords.removeAll { $0.isClassHomeworkNote || $0.isHomeworkAssignmentOnly }

        let trimmed = classMissingWork.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftClassRecords.append(
            AttendanceRecord(
                dateKey: dateKey,
                className: item.className,
                gradeLevel: normalizedGrade,
                studentName: "",
                studentID: nil,
                classDefinitionID: item.classDefinitionID,
                blockID: item.id,
                blockStartTime: item.startTime,
                blockEndTime: item.endTime,
                status: .present,
                absentHomework: trimmed
            )
        )

        for student in students {
            draftClassRecords.append(
                AttendanceRecord(
                    dateKey: dateKey,
                    className: item.className,
                    gradeLevel: GradeLevelOption.normalized(student.gradeLevel).isEmpty ? normalizedGrade : GradeLevelOption.normalized(student.gradeLevel),
                    studentName: student.name,
                    studentID: student.id,
                    classDefinitionID: item.classDefinitionID,
                    blockID: item.id,
                    blockStartTime: item.startTime,
                    blockEndTime: item.endTime,
                    status: .present,
                    absentHomework: trimmed,
                    isHomeworkAssignmentOnly: true
                )
            )
        }
    }

    private func recordIndex(for student: StudentSupportProfile) -> Int? {
        draftClassRecords.firstIndex(where: { record in
            guard record.isAttendanceEntry else { return false }
            if let studentID = record.studentID, studentID == student.id {
                if let blockID = record.blockID {
                    return blockID == item.id
                }
                if Self.recordMatchesBlockTime(record, item: item) {
                    return true
                }
                if let classDefinitionID = item.classDefinitionID, let recordClassDefinitionID = record.classDefinitionID {
                    return classDefinitionID == recordClassDefinitionID
                }
                return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className)
            }
            return Self.recordMatchesCurrentClass(record, item: item) &&
                normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(normalizedGrade) &&
                normalizedStudentKey(record.studentName) == normalizedStudentKey(student.name)
        })
    }

    private func existingRecord(for student: StudentSupportProfile) -> AttendanceRecord? {
        if let record = recordsByStudentID[student.id] {
            return record
        }
        guard let index = recordIndex(for: student) else { return nil }
        return draftClassRecords[index]
    }

    private func tint(for status: AttendanceRecord.Status) -> Color {
        switch status {
        case .present: return .green
        case .absent: return .red
        case .tardy: return .orange
        case .excused: return .blue
        }
    }

    private static func defaultMissingWork(from records: [AttendanceRecord]) -> String {
        if let classNote = records.first(where: {
            $0.isClassHomeworkNote &&
            !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines),
           !classNote.isEmpty {
            return classNote
        }

        return records.first(where: {
            $0.status == .absent &&
            !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func earlierAbsentRecord(for student: StudentSupportProfile) -> AttendanceRecord? {
        let priorAbsences = (baseRecords + draftClassRecords)
            .filter { record in
                record.dateKey == dateKey &&
                    record.isAttendanceEntry &&
                    record.status == .absent &&
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName) ==
                        attendanceMatchKey(studentID: student.id, studentName: student.name) &&
                    Self.isEarlierBlockRecord(record, than: item)
            }

        return priorAbsences.max { lhs, rhs in
            Self.blockSortDate(for: lhs) < Self.blockSortDate(for: rhs)
        }
    }

    private static func splitRecords(
        _ records: [AttendanceRecord],
        for item: AlarmItem,
        dateKey: String
    ) -> (base: [AttendanceRecord], currentClass: [AttendanceRecord]) {
        var base: [AttendanceRecord] = []
        var currentClass: [AttendanceRecord] = []

        for record in records {
            if record.dateKey == dateKey && recordMatchesCurrentClass(record, item: item) {
                currentClass.append(record)
            } else {
                base.append(record)
            }
        }

        return (base, currentClass)
    }

    private static func recordMatchesCurrentClass(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        if let blockID = record.blockID {
            return blockID == item.id
        }
        if recordMatchesBlockTime(record, item: item) {
            return true
        }
        if let classDefinitionID = item.classDefinitionID, let recordClassDefinitionID = record.classDefinitionID {
            return classDefinitionID == recordClassDefinitionID
        }
        return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className)
    }

    private static func recordMatchesBlockTime(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        guard
            let recordStartTime = record.blockStartTime,
            let recordEndTime = record.blockEndTime
        else {
            return false
        }

        return blockTimeSignature(start: recordStartTime, end: recordEndTime) ==
            blockTimeSignature(start: item.startTime, end: item.endTime)
    }

    private static func blockTimeSignature(start: Date, end: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        return String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    private static func isEarlierBlockRecord(_ record: AttendanceRecord, than item: AlarmItem) -> Bool {
        guard let recordEndTime = record.blockEndTime else {
            return false
        }

        return blockSortDate(for: recordEndTime) <= blockSortDate(for: item.startTime)
    }

    private static func blockSortDate(for record: AttendanceRecord) -> Date {
        record.blockEndTime ?? record.blockStartTime ?? .distantPast
    }

    private static func blockSortDate(for date: Date) -> Date {
        date
    }
}

private struct AttendanceNoteEditorView: View {
    let title: String
    let helperText: String
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    @State private var draftText: String

    init(title: String, helperText: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.helperText = helperText
        self.initialText = initialText
        self.onSave = onSave
        _draftText = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                if !helperText.isEmpty {
                    Text(helperText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $draftText)
                .focused($isEditorFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Missing Work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(draftText)
                    dismiss()
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            isEditorFocused = true
        }
    }
}

private struct DailyHomeworkReviewView: View {
    enum BrowseMode: String, CaseIterable, Identifiable {
        case grade = "Grade"
        case className = "Class"
        case student = "Student"

        var id: String { rawValue }
    }

    @Binding var attendanceRecords: [AttendanceRecord]
    let classDefinitions: [ClassDefinitionItem]
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var browseMode: BrowseMode = .grade
    @State private var editingTarget: HomeworkReviewTarget?

    private var dateKey: String {
        AttendanceRecord.dateKey(for: date)
    }

    private var homeworkRecords: [AttendanceRecord] {
        attendanceRecords
            .filter {
                $0.dateKey == dateKey &&
                !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { lhs, rhs in
                if lhs.className.localizedCaseInsensitiveCompare(rhs.className) != .orderedSame {
                    return lhs.className.localizedCaseInsensitiveCompare(rhs.className) == .orderedAscending
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return lhs.gradeLevel.localizedCaseInsensitiveCompare(rhs.gradeLevel) == .orderedAscending
            }
    }

    private var classHomeworkRecords: [AttendanceRecord] {
        homeworkRecords.filter(\.isClassHomeworkNote)
    }

    private var studentHomeworkRecords: [AttendanceRecord] {
        let studentRecords = homeworkRecords.filter { !$0.isClassHomeworkNote }
        let grouped = Dictionary(grouping: studentRecords) { record in
            homeworkGroupingKey(for: record)
        }

        return grouped.values.compactMap { records in
            records.sorted { lhs, rhs in
                if lhs.isHomeworkAssignmentOnly != rhs.isHomeworkAssignmentOnly {
                    return !lhs.isHomeworkAssignmentOnly && rhs.isHomeworkAssignmentOnly
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
            }.first
        }
    }

    private var gradeGroups: [HomeworkReviewGroup] {
        groupedRecords {
            let normalized = GradeLevelOption.normalized($0.gradeLevel)
            return normalized.isEmpty ? "No Grade" : normalized
        }
    }

    private var classGroups: [HomeworkReviewGroup] {
        groupedRecords {
            resolvedClassName(for: $0)
        }
    }

    private var studentGroups: [HomeworkReviewGroup] {
        let grouped = Dictionary(grouping: studentHomeworkRecords) { record in
            let trimmed = record.studentName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unnamed Student" : trimmed
        }

        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { key in
            let records = (grouped[key] ?? []).sorted { lhs, rhs in
                if lhs.className.localizedCaseInsensitiveCompare(rhs.className) != .orderedSame {
                    return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
                }

                return lhs.gradeLevel.localizedCaseInsensitiveCompare(rhs.gradeLevel) == .orderedAscending
            }

            return HomeworkReviewGroup(title: key, records: records)
        }
    }

    private var activeGroups: [HomeworkReviewGroup] {
        switch browseMode {
        case .grade:
            return gradeGroups
        case .className:
            return classGroups
        case .student:
            return studentGroups
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Browse By", selection: $browseMode) {
                    ForEach(BrowseMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if homeworkRecords.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Homework Saved",
                        systemImage: "text.book.closed",
                        description: Text("Class homework and absent-student missing work for \(date.formatted(date: .abbreviated, time: .omitted)) will appear here.")
                    )
                }
            } else {
                Section("Summary") {
                    LabeledContent("Class Homework Notes", value: "\(classHomeworkRecords.count)")
                    LabeledContent("Student Missing Work", value: "\(studentHomeworkRecords.count)")
                }

                ForEach(activeGroups) { group in
                    Section(group.title) {
                        let classRecords = group.records.filter(\.isClassHomeworkNote)
                        let studentRecords = group.records.filter { !$0.isClassHomeworkNote }

                        if !classRecords.isEmpty {
                            ForEach(classRecords) { record in
                                Button {
                                    openEditor(for: record)
                                } label: {
                                    HomeworkReviewRow(
                                        title: browseMode == .className ? "Class Homework" : displayClassName(for: record),
                                        subtitle: record.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Class note" : "\(record.gradeLevel) • Class note",
                                        detail: record.absentHomework
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !studentRecords.isEmpty {
                            ForEach(studentRecords) { record in
                                Button {
                                    openEditor(for: record)
                                } label: {
                                    HomeworkReviewRow(
                                        title: browseMode == .student ? displayClassName(for: record) : record.studentName,
                                        subtitle: studentSubtitle(for: record),
                                        detail: record.absentHomework
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Homework Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $editingTarget) { target in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: target.title,
                    helperText: target.helperText,
                    initialText: target.initialText,
                    onSave: { saveHomework($0, recordID: target.id) }
                )
            }
        }
    }

    private func groupedRecords(key: (AttendanceRecord) -> String) -> [HomeworkReviewGroup] {
        let grouped = Dictionary(grouping: classHomeworkRecords + studentHomeworkRecords, by: key)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { groupKey in
            let records = (grouped[groupKey] ?? []).sorted { lhs, rhs in
                if lhs.isClassHomeworkNote != rhs.isClassHomeworkNote {
                    return lhs.isClassHomeworkNote && !rhs.isClassHomeworkNote
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
            }

            return HomeworkReviewGroup(title: groupKey, records: records)
        }
    }

    private func openEditor(for record: AttendanceRecord) {
        let title: String
        let helperText: String

        if record.isClassHomeworkNote {
            title = displayClassName(for: record)
            helperText = "Edit the class-level homework note for this block."
        } else {
            title = record.studentName
            helperText = "Edit the saved missing work for this student."
        }

        editingTarget = HomeworkReviewTarget(
            id: record.id,
            title: title,
            helperText: helperText,
            initialText: record.absentHomework
        )
    }

    private func saveHomework(_ text: String, recordID: UUID) {
        guard let index = attendanceRecords.firstIndex(where: { $0.id == recordID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if attendanceRecords[index].isClassHomeworkNote && trimmed.isEmpty {
            attendanceRecords.remove(at: index)
            return
        }

        attendanceRecords[index].absentHomework = trimmed
    }

    private func displayClassName(for record: AttendanceRecord) -> String {
        resolvedClassName(for: record)
    }

    private func studentSubtitle(for record: AttendanceRecord) -> String {
        let parts = [displayClassName(for: record), record.gradeLevel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Student homework" : parts.joined(separator: " • ")
    }

    private func homeworkGroupingKey(for record: AttendanceRecord) -> String {
        let studentKey = record.studentID?.uuidString.lowercased() ?? normalizedStudentKey(record.studentName)
        let blockKey: String
        if let blockID = record.blockID {
            blockKey = blockID.uuidString.lowercased()
        } else if let classDefinitionID = record.classDefinitionID {
            blockKey = classDefinitionID.uuidString.lowercased()
        } else {
            blockKey = normalizedStudentKey(resolvedClassName(for: record))
        }

        return "\(studentKey)|\(blockKey)|\(record.dateKey)"
    }

    private func resolvedClassName(for record: AttendanceRecord) -> String {
        if let classDefinitionID = record.classDefinitionID,
           let definition = classDefinitions.first(where: { $0.id == classDefinitionID }) {
            let name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        let rawName = record.className.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawName.isEmpty || rawName.localizedCaseInsensitiveContains("managedobject") {
            return "Class Not Set"
        }

        return rawName
    }
}

private struct HomeworkReviewGroup: Identifiable {
    let title: String
    let records: [AttendanceRecord]

    var id: String { title }
}

private struct HomeworkReviewTarget: Identifiable {
    let id: UUID
    let title: String
    let helperText: String
    let initialText: String
}

private struct HomeworkReviewRow: View {
    let title: String
    let subtitle: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct InAppWarning: Identifiable, Equatable {
    let item: AlarmItem
    let minutesRemaining: Int

    var id: String {
        "\(item.id.uuidString)-\(minutesRemaining)"
    }

    var title: String {
        switch minutesRemaining {
        case 5:
            return "5 Minute Warning"
        case 2:
            return "2 Minute Warning"
        default:
            return "1 Minute Warning"
        }
    }

    var accentColor: Color {
        switch minutesRemaining {
        case 5:
            return .yellow
        case 2:
            return .orange
        default:
            return .red
        }
    }

    var roomText: String {
        let trimmed = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Room not set" : trimmed
    }

    var timeText: String {
        "\(item.start.formatted(date: .omitted, time: .shortened)) - \(item.end.formatted(date: .omitted, time: .shortened))"
    }
}

private struct LiveActivitySnapshot: Equatable {
    let className: String
    let room: String
    let endTime: Date
    let isHeld: Bool
    let iconName: String
    let nextClassName: String
    let nextIconName: String
}

private struct TodayClassRosterView: View {
    let item: AlarmItem
    @Binding var alarms: [AlarmItem]
    @Binding var profiles: [StudentSupportProfile]
    let classDefinitions: [ClassDefinitionItem]

    @Environment(\.dismiss) private var dismiss
    @State private var showingAddExisting = false
    @State private var showingAddNew = false
    @State private var showingLinkClassSheet = false
    @State private var editingStudent: StudentSupportProfile?
    @State private var editingClassContextStudent: StudentSupportProfile?

    private var students: [StudentSupportProfile] {
        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return profiles
            .filter { profile in
                if let classDefinitionID = item.classDefinitionID {
                    guard profileMatches(classDefinitionID: classDefinitionID, profile: profile) else { return false }
                } else {
                    guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                }

                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                if gradeKey.isEmpty || profileGradeKey.isEmpty {
                    return true
                }
                return profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableProfilesToAdd: [StudentSupportProfile] {
        let rosterIDs = Set(students.map(\.id))
        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return profiles
            .filter { !rosterIDs.contains($0.id) }
            .filter { profile in
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                return gradeKey.isEmpty || profileGradeKey.isEmpty || profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var linkedClassDefinition: ClassDefinitionItem? {
        guard let classDefinitionID = item.classDefinitionID else { return nil }
        return classDefinitions.first { $0.id == classDefinitionID }
    }

    private var rosterLinkSummary: String {
        if let linkedClassDefinition {
            return "This roster is linked to the saved class \(linkedClassDefinition.displayName). Student links, class-specific notes, and roster edits will stay attached to that saved class."
        }

        return "This block is using text and grade matching only. Students added here will attach to the class name shown on this block, but class-specific notes work best after linking the block to a saved class."
    }

    private var suggestedClassDefinitions: [ClassDefinitionItem] {
        classDefinitionCandidates(
            name: item.className,
            gradeLevel: item.gradeLevel,
            in: classDefinitions
        )
    }

    private var remainingClassDefinitions: [ClassDefinitionItem] {
        let suggestedIDs = Set(suggestedClassDefinitions.map(\.id))
        return classDefinitions
            .filter { !suggestedIDs.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.className)
                        .font(.headline.weight(.bold))

                    let meta = [item.gradeLevel, item.location]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")

                    if !meta.isEmpty {
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(rosterCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
            }

            Section("Link Status") {
                if let linkedClassDefinition {
                    LabeledContent("Class Roster") {
                        Text(linkedClassDefinition.displayName)
                            .foregroundStyle(.primary)
                    }
                } else {
                    LabeledContent("Class Roster") {
                        Text("Not linked")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(rosterLinkSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if !classDefinitions.isEmpty {
                    Button(linkedClassDefinition == nil ? "Link Class Roster" : "Change Class Roster") {
                        showingLinkClassSheet = true
                    }
                }
            }

            Section("Roster") {
                if students.isEmpty {
                    Text("No students linked to this class and grade yet.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(rosterCardBackground(accent: .secondary))
                } else {
                    ForEach(students) { student in
                        Button {
                            editingStudent = student
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(student.name)
                                        .fontWeight(.semibold)

                                    gradePill(student.gradeLevel)
                                }

                                let info = classSummary(for: student, in: classDefinitions)
                                if !info.isEmpty {
                                    Text(info)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !student.accommodations.isEmpty {
                                    Text(student.accommodations)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !student.prompts.isEmpty {
                                    Text(student.prompts)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if let classDefinitionID = item.classDefinitionID,
                                   let context = classContext(for: student, classDefinitionID: classDefinitionID) {
                                    let classDetail = [context.behaviorNotes, context.effortNotes, context.classNotes]
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " • ")

                                    if !classDetail.isEmpty {
                                        Text(classDetail)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(item.type.themeColor == .clear ? .blue : item.type.themeColor)
                                            .lineLimit(3)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(rosterCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if item.classDefinitionID != nil {
                                Button("Class Notes") {
                                    editingClassContextStudent = student
                                }
                                .tint(item.type.themeColor == .clear ? .blue : item.type.themeColor)
                            }

                            Button("Remove", role: .destructive) {
                                removeStudentFromClass(student)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Class Roster")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    (item.type.themeColor == .clear ? Color.blue : item.type.themeColor).opacity(0.06),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddExisting = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }

                Button {
                    showingAddNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExisting) {
            NavigationStack {
                rosterAddSheet
            }
        }
        .sheet(isPresented: $showingLinkClassSheet) {
            NavigationStack {
                linkClassSheet
            }
        }
        .sheet(isPresented: $showingAddNew) {
            EditStudentSupportView(
                profiles: $profiles,
                classDefinitions: classDefinitions,
                existing: nil,
                initialLinkedClassDefinitionIDs: item.classDefinitionID.map { [$0] } ?? [],
                initialClassName: item.className,
                initialGradeLevel: item.gradeLevel
            )
        }
        .sheet(item: $editingStudent) { student in
            EditStudentSupportView(
                profiles: $profiles,
                classDefinitions: classDefinitions,
                existing: student
            )
        }
        .sheet(item: $editingClassContextStudent) { student in
            if let classDefinitionID = item.classDefinitionID {
                NavigationStack {
                    TodayStudentClassContextView(
                        item: item,
                        student: student,
                        classDefinitionID: classDefinitionID,
                        profiles: $profiles
                    )
                }
            }
        }
    }

    private var rosterAddSheet: some View {
        List {
            Section {
                Text("Add existing students to \(item.className) without creating duplicate student records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(rosterLinkSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Available Students") {
                if availableProfilesToAdd.isEmpty {
                    Text("No additional students match this class or grade right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableProfilesToAdd) { student in
                        Button {
                            addStudentToClass(student)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(student.name)
                                    .foregroundStyle(.primary)
                                Text(classSummary(for: student, in: classDefinitions))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add to Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    showingAddExisting = false
                }
            }
        }
    }

    private var linkClassSheet: some View {
        List {
            Section {
                Text("Link this schedule block to a saved class so roster edits, class-specific notes, and supports all attach to the same class definition.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Class Rosters") {
                ForEach(classDefinitions.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) { definition in
                    Button {
                        applyClassDefinitionLink(definition)
                    } label: {
                        classDefinitionRow(definition)
                    }
                }
            }
        }
        .navigationTitle("Class Roster")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showingLinkClassSheet = false
                }
            }
        }
    }

    @ViewBuilder
    private func classDefinitionRow(_ definition: ClassDefinitionItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(definition.displayName)
                .foregroundStyle(.primary)

            let detail = [definition.typeDisplayName, definition.defaultLocation]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")

            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addStudentToClass(_ student: StudentSupportProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else { return }

        if let classDefinitionID = item.classDefinitionID {
            let currentIDs = linkedClassDefinitionIDs(for: profiles[index])
            let updatedIDs = currentIDs + [classDefinitionID]
            profiles[index] = updatingProfile(profiles[index], linkedTo: updatedIDs, definitions: classDefinitions)
        } else {
            var updated = profiles[index]
            updated.className = mergedClassSummary(current: updated.className, adding: item.className)
            if updated.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.gradeLevel = GradeLevelOption.normalized(item.gradeLevel)
            }
            profiles[index] = updated
        }
    }

    private func removeStudentFromClass(_ student: StudentSupportProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else { return }

        if let classDefinitionID = item.classDefinitionID {
            let updatedIDs = linkedClassDefinitionIDs(for: profiles[index]).filter { $0 != classDefinitionID }
            profiles[index] = updatingProfile(profiles[index], linkedTo: updatedIDs, definitions: classDefinitions)
        } else {
            var updated = profiles[index]
            updated.className = removingClassSummary(current: updated.className, removing: item.className)
            profiles[index] = updated
        }
    }

    private func applyClassDefinitionLink(_ definition: ClassDefinitionItem) {
        guard let index = alarms.firstIndex(where: { $0.id == item.id }) else { return }

        alarms[index].classDefinitionID = definition.id

        let normalizedGrade = GradeLevelOption.normalized(definition.gradeLevel)
        if !normalizedGrade.isEmpty {
            alarms[index].gradeLevelValue = normalizedGrade
        }

        if alarms[index].location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alarms[index].location = definition.defaultLocation
        }

        showingLinkClassSheet = false
        dismiss()
    }

    private func rosterCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.10),
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func gradePill(_ gradeLevel: String) -> some View {
        let color = GradeLevelOption.color(for: gradeLevel)
        let label = GradeLevelOption.pillLabel(for: gradeLevel)

        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(color == .yellow ? Color.black.opacity(0.8) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct TodayStudentClassContextView: View {
    let item: AlarmItem
    let student: StudentSupportProfile
    let classDefinitionID: UUID
    @Binding var profiles: [StudentSupportProfile]

    @Environment(\.dismiss) private var dismiss

    @State private var behaviorNotes = ""
    @State private var effortNotes = ""
    @State private var classNotes = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.headline.weight(.bold))
                    Text(item.className)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Behavior / Support") {
                TextField("Behavior notes", text: $behaviorNotes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Effort / participation", text: $effortNotes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Class-specific notes", text: $classNotes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle("Class Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    save()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if let existingContext = classContext(for: student, classDefinitionID: classDefinitionID) {
                behaviorNotes = existingContext.behaviorNotes
                effortNotes = existingContext.effortNotes
                classNotes = existingContext.classNotes
            }
        }
    }

    private func save() {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else {
            dismiss()
            return
        }

        let context = StudentSupportProfile.ClassContext(
            classDefinitionID: classDefinitionID,
            behaviorNotes: behaviorNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            effortNotes: effortNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            classNotes: classNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        profiles[index] = updatingProfile(profiles[index], classContext: context)
        dismiss()
    }
}

private struct TodayClassSubPlanView: View {
    private enum Field: Hashable {
        case overview
        case lessonPlan
        case materials
        case subNotes
        case returnNotes
    }

    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]
    let alarms: [AlarmItem]
    let commitments: [CommitmentItem]
    let activeOverrideName: String?
    let attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]

    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) private var dismiss
    @State private var overview = ""
    @State private var lessonPlan = ""
    @State private var materials = ""
    @State private var subNotes = ""
    @State private var returnNotes = ""
    @State private var includeRoster = true
    @State private var includeSupports = true
    @State private var includeAttendance = true
    @State private var includeCommitments = true
    @State private var includeDaySchedule = true
    @State private var includeSubProfile = true
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var selectedDate: Date
    @State private var feedbackMessage: String?
    @FocusState private var focusedField: Field?

    init(
        item: AlarmItem,
        date: Date,
        students: [StudentSupportProfile],
        alarms: [AlarmItem],
        commitments: [CommitmentItem],
        activeOverrideName: String?,
        attendanceRecords: [AttendanceRecord],
        subPlans: Binding<[SubPlanItem]>
    ) {
        self.item = item
        self.date = date
        self.students = students
        self.alarms = alarms
        self.commitments = commitments
        self.activeOverrideName = activeOverrideName
        self.attendanceRecords = attendanceRecords
        _subPlans = subPlans
        _selectedDate = State(initialValue: date)
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: selectedDate)
    }

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var schedule: [AlarmItem] {
        alarms
            .filter { $0.dayOfWeek == selectedWeekday }
            .sorted {
                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }
                return $0.endTime < $1.endTime
            }
    }

    private var commitmentsForSelectedDate: [CommitmentItem] {
        resolvedCommitments(for: selectedDate, from: commitments)
    }

    private var displayedOverrideName: String? {
        Calendar.current.isDate(selectedDate, inSameDayAs: date) ? activeOverrideName : nil
    }

    private var linkedAlarmForSelectedDate: AlarmItem? {
        schedule.first { block in
            if let classDefinitionID = item.classDefinitionID, block.classDefinitionID == classDefinitionID {
                return true
            }

            return classNamesMatch(scheduleClassName: block.className, profileClassName: item.className) &&
                normalizedStudentKey(GradeLevelOption.normalized(block.gradeLevel)) ==
                normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
        }
    }

    private var existingPlan: SubPlanItem? {
        subPlans.first {
            $0.dateKey == dateKey &&
            ($0.linkedAlarmID == (linkedAlarmForSelectedDate?.id ?? item.id) || (
                classNamesMatch(scheduleClassName: $0.className, profileClassName: item.className) &&
                normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
            ))
        }
    }

    private var followUpNotes: [FollowUpNoteItem] {
        decodeFollowUpNotesFromDefaults()
    }

    private var subPlanProfile: SubPlanProfile {
        ClassTraxPersistence.loadSubPlanProfile(from: modelContext)
    }

    private var relevantClassNotes: [FollowUpNoteItem] {
        followUpNotes.filter {
            $0.kind == .classNote &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: $0.context)
        }
    }

    private var relevantStudentNotes: [FollowUpNoteItem] {
        let studentKeys = Set(students.map { normalizedStudentKey($0.name) })
        return followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            studentKeys.contains(normalizedStudentKey($0.studentOrGroup))
        }
    }

    private var attendanceSummary: [AttendanceRecord.Status: Int] {
        var summary: [AttendanceRecord.Status: Int] = [:]
        for record in attendanceRows {
            summary[record.status, default: 0] += 1
        }
        return summary
    }

    private var attendanceRows: [AttendanceRecord] {
        attendanceRecords.filter {
            $0.dateKey == dateKey &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: $0.className) &&
            normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
        }
        .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.className)
                        .font(.headline.weight(.bold))

                    let meta = [
                        selectedDate.formatted(date: .abbreviated, time: .omitted),
                        item.gradeLevel,
                        item.location
                    ]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                    if !meta.isEmpty {
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(displayedOverrideName ?? "Regular Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 2)

                    infoRow(
                        title: "Selected Date",
                        value: selectedDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )

                    infoRow(
                        title: "Linked Block",
                        value: linkedBlockSummaryText,
                        systemImage: linkedAlarmForSelectedDate == nil ? "exclamationmark.triangle" : "checkmark.circle"
                    )

                    infoRow(
                        title: "Saved Draft",
                        value: existingPlan == nil ? "No saved class packet yet" : "Existing class packet found",
                        systemImage: existingPlan == nil ? "tray" : "tray.full"
                    )

                    infoRow(
                        title: "Workflow Role",
                        value: "Secondary packet for one class block",
                        systemImage: "square.stack.3d.down.right"
                    )
                }
                .padding(.vertical, 8)
                .listRowBackground(subPlanCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
            }

            if let feedbackMessage {
                Section {
                    feedbackRow(message: feedbackMessage, accent: .green)
                }
                .listRowBackground(subPlanCardBackground(accent: .green))
            }

            Section("Plan Date") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )

                Text(
                    linkedAlarmForSelectedDate == nil
                    ? "No matching class block is scheduled on that date yet. You can still prep the packet now and link it to the saved class when that block exists."
                    : "Choose the day first so this class sub plan saves against the correct class block."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Sub Overview") {
                TextField("Quick summary for the substitute", text: $overview, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .overview)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .lessonPlan
                    }
                TextField("Lesson plan or class flow", text: $lessonPlan, axis: .vertical)
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .lessonPlan)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .materials
                    }
            }

            Section("Materials & Notes") {
                TextField("Materials, copies, links, devices", text: $materials, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .materials)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .subNotes
                    }
                TextField("Sub notes, routines, dismissal reminders", text: $subNotes, axis: .vertical)
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .subNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .returnNotes
                    }
                TextField("Notes the substitute can leave for you", text: $returnNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .returnNotes)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            Section("Include in Export") {
                Toggle("Include roster", isOn: $includeRoster)
                Toggle("Include accommodations and prompts", isOn: $includeSupports)
                Toggle("Include attendance snapshot", isOn: $includeAttendance)
                Toggle("Include commitments", isOn: $includeCommitments)
                Toggle("Include day schedule", isOn: $includeDaySchedule)
                Toggle("Include Sub Plan Profile", isOn: $includeSubProfile)
            }

            Section("Packet Preview") {
                Label("\(students.count) linked student\(students.count == 1 ? "" : "s")", systemImage: "person.3.sequence.fill")
                Label("\(relevantClassNotes.count) class note\(relevantClassNotes.count == 1 ? "" : "s")", systemImage: "note.text")
                Label("\(relevantStudentNotes.count) student note\(relevantStudentNotes.count == 1 ? "" : "s")", systemImage: "person.text.rectangle")
                Label("\(schedule.count) block\(schedule.count == 1 ? "" : "s") in day schedule", systemImage: "calendar")
                Label("\(attendanceRows.count) attendance record\(attendanceRows.count == 1 ? "" : "s")", systemImage: "checklist.checked")
                Label("\(relevantCommitments.count) commitment\(relevantCommitments.count == 1 ? "" : "s")", systemImage: "briefcase")
            }
            .listRowBackground(subPlanCardBackground(accent: .indigo))

            if includeDaySchedule {
                Section("Day Schedule Snapshot") {
                    ForEach(schedule) { block in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.className)
                                    .fontWeight(.semibold)

                                let meta = [block.gradeLevel, block.location]
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " • ")

                                if !meta.isEmpty {
                                    Text(meta)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if includeAttendance {
                Section("Attendance Snapshot") {
                    if attendanceRows.isEmpty {
                        Text("No attendance has been taken for this class yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            ForEach(AttendanceRecord.Status.allCases) { status in
                                if let count = attendanceSummary[status], count > 0 {
                                    Text("\(status.rawValue): \(count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        ForEach(attendanceRows) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.studentName)
                                    Spacer()
                                    Text(record.status.rawValue)
                                        .foregroundStyle(.secondary)
                                }

                                if record.status == .absent && !record.absentHomework.isEmpty {
                                    Text("Homework: \(record.absentHomework)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !missingWorkRows.isEmpty {
                Section("Missing Work for Absent Students") {
                    ForEach(missingWorkRows) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.studentName)
                                .fontWeight(.semibold)
                            Text(record.absentHomework)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if includeCommitments {
                Section("Commitments Snapshot") {
                    if relevantCommitments.isEmpty {
                        Text("No commitments overlap with this class block.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(relevantCommitments) { commitment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commitment.title)
                                    .fontWeight(.semibold)
                                Text(commitmentTimeText(commitment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sub Plan")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    (item.type.themeColor == .clear ? Color.blue : item.type.themeColor).opacity(0.06),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Share Text") {
                    focusedField = nil
                    save()
                    exportTextPlan()
                }

                Menu {
                    Button("PDF Packet") {
                        focusedField = nil
                        save()
                        exportPDFPlan()
                    }

                    Divider()

                    Button("Save Packet") {
                        focusedField = nil
                        save()
                        dismiss()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .onChange(of: selectedDate) { _, _ in
            focusedField = nil
            loadExisting()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func loadExisting() {
        overview = ""
        lessonPlan = ""
        materials = ""
        subNotes = ""
        returnNotes = ""
        includeRoster = true
        includeSupports = true
        includeAttendance = true
        includeCommitments = true
        includeDaySchedule = true
        includeSubProfile = true

        if let existingPlan {
            overview = existingPlan.overview
            lessonPlan = existingPlan.lessonPlan
            materials = existingPlan.materials
            subNotes = existingPlan.subNotes
            returnNotes = existingPlan.returnNotes
            includeRoster = existingPlan.includeRoster
            includeSupports = existingPlan.includeSupports
            includeAttendance = existingPlan.includeAttendance
            includeCommitments = existingPlan.includeCommitments
            includeDaySchedule = existingPlan.includeDaySchedule
            includeSubProfile = existingPlan.includeSubProfile
        }
    }

    private func save() {
        let updated = SubPlanItem(
            id: existingPlan?.id ?? UUID(),
            dateKey: dateKey,
            linkedAlarmID: linkedAlarmForSelectedDate?.id ?? item.id,
            className: item.className,
            gradeLevel: GradeLevelOption.normalized(item.gradeLevel),
            location: item.location,
            overview: overview.trimmingCharacters(in: .whitespacesAndNewlines),
            lessonPlan: lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines),
            materials: materials.trimmingCharacters(in: .whitespacesAndNewlines),
            subNotes: subNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeAttendance: includeAttendance,
            includeCommitments: includeCommitments,
            includeDaySchedule: includeDaySchedule,
            includeSubProfile: includeSubProfile,
            createdAt: existingPlan?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if let index = subPlans.firstIndex(where: { $0.id == updated.id }) {
            subPlans[index] = updated
        } else {
            subPlans.insert(updated, at: 0)
        }

        feedbackMessage = "Saved \(item.className) for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private func exportTextPlan() {
        let filename = "classtrax-sub-plan-\(dateKey)-\(item.className.replacingOccurrences(of: " ", with: "-")).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? exportText().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Text packet is ready to share."
    }

    private func exportPDFPlan() {
        let safeName = item.className.replacingOccurrences(of: " ", with: "-")
        let title = "ClassTrax Sub Plan"
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName)"
        if let url = makeSubPlanPDF(title: title, filename: filename, body: exportText()) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "PDF packet is ready to share."
        } else {
            exportTextPlan()
        }
    }

    private func exportText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let profileText = includeSubProfile ? """
        Teacher Contact
        \(teacherContactBlock())

        Emergency / Drill
        \(emergencyDrillBlock())

        Classroom Access
        \(classroomAccessBlock())

        Static Notes
        \(staticNotesBlock())
        """ : ""

        let classNotesText = relevantClassNotes.isEmpty ? "None" : relevantClassNotes.map {
            "- \($0.note)"
        }.joined(separator: "\n")

        let studentNotesText = relevantStudentNotes.isEmpty ? "None" : relevantStudentNotes.map { note in
            if let student = students.first(where: {
                normalizedStudentKey($0.name) == normalizedStudentKey(note.studentOrGroup)
            }) {
                return "- \(note.studentOrGroup) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]: \(note.note)"
            }
            return "- \(note.studentOrGroup): \(note.note)"
        }.joined(separator: "\n")

        let dayScheduleText: String = {
            guard includeDaySchedule else { return "Not included" }
            return schedule.map { block in
                let timeRange = "\(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))"
                let meta = [block.gradeLevel, block.location]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")
                if meta.isEmpty {
                    return "- \(timeRange): \(block.className)"
                }
                return "- \(timeRange): \(block.className) (\(meta))"
            }
            .joined(separator: "\n")
        }()

        let attendanceText: String = {
            guard includeAttendance else { return "Not included" }
            guard !attendanceRows.isEmpty else { return "No attendance taken yet" }
            return attendanceRows.map {
                let homework = $0.status == .absent && !$0.absentHomework.isEmpty
                    ? " — Homework: \($0.absentHomework)"
                    : ""
                return "- \($0.studentName): \($0.status.rawValue)\(homework)"
            }.joined(separator: "\n")
        }()

        let commitmentsText: String = {
            guard includeCommitments else { return "Not included" }
            guard !relevantCommitments.isEmpty else { return "No overlapping commitments" }
            return relevantCommitments.map {
                "- \($0.title): \(commitmentTimeText($0))"
            }.joined(separator: "\n")
        }()

        let rosterText: String = {
            guard includeRoster, !students.isEmpty else { return "Not included" }
            return students.map { student in
                var lines = ["- \(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"]
                if includeSupports {
                    let supportParts = [student.accommodations, student.prompts]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if !supportParts.isEmpty {
                        lines.append("  Supports: \(supportParts.joined(separator: " • "))")
                    }
                }
                return lines.joined(separator: "\n")
            }
            .joined(separator: "\n")
        }()

        return """
        ClassTrax Sub Plan
        \(selectedDate.formatted(date: .complete, time: .omitted))

        Active Schedule
        \(displayedOverrideName ?? "Regular Day")

        \(profileText)

        Class
        \(item.className)
        \(GradeLevelOption.normalized(item.gradeLevel)) • \(resolvedRoomText())
        \(timeRangeText(using: timeFormatter))

        Overview
        \(overview.isEmpty ? "None added" : overview)

        Lesson Plan
        \(lessonPlan.isEmpty ? "None added" : lessonPlan)

        Materials
        \(materials.isEmpty ? "None added" : materials)

        Sub Notes
        \(subNotes.isEmpty ? "None added" : subNotes)

        Return Notes
        \(returnNotes.isEmpty ? "None added" : returnNotes)

        Roster
        \(rosterText)

        Class Notes
        \(classNotesText)

        Student Notes
        \(studentNotesText)

        Commitments
        \(commitmentsText)

        Day Schedule
        \(dayScheduleText)

        Attendance Snapshot
        \(attendanceText)
        """
    }

    private func resolvedRoomText() -> String {
        let room = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty { return room }
        let fallback = subPlanProfile.room.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "Room not set" : fallback
    }

    private var linkedBlockSummaryText: String {
        guard let block = linkedAlarmForSelectedDate else {
            return "No matching block scheduled"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: block.startTime)) - \(formatter.string(from: block.endTime))"
    }

    private var missingWorkRows: [AttendanceRecord] {
        attendanceRows.filter {
            $0.status == .absent &&
            !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func feedbackRow(message: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func timeRangeText(using formatter: DateFormatter) -> String {
        let block = linkedAlarmForSelectedDate ?? item
        return "\(formatter.string(from: block.startTime)) - \(formatter.string(from: block.endTime))"
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func teacherContactBlock() -> String {
        let lines = [
            labeledLine("Teacher", subPlanProfile.teacherName),
            labeledLine("Room", resolvedRoomText()),
            labeledLine("Email", subPlanProfile.contactEmail),
            labeledLine("Phone", subPlanProfile.contactPhone),
            labeledLine("Front Office", subPlanProfile.schoolFrontOfficeContact),
            labeledLine("Neighboring Teacher", subPlanProfile.neighboringTeacher)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func emergencyDrillBlock() -> String {
        let lines = [
            blockText(subPlanProfile.emergencyDrillProcedures),
            labeledLine("File Link", subPlanProfile.emergencyDrillFileLink)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func classroomAccessBlock() -> String {
        let credentialText = subPlanProfile.appCredentials
            .filter(\.hasContent)
            .map { credential in
                [
                    labeledLine("App", credential.applicationName),
                    labeledLine("Link", credential.applicationLink),
                    labeledLine("Username", credential.username),
                    labeledLine("Password", credential.password)
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let lines = [
            labeledLine("Extensions", subPlanProfile.phoneExtensions),
            blockText(subPlanProfile.passwordsAccessNotes),
            credentialText.isEmpty ? nil : credentialText
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func staticNotesBlock() -> String {
        blockText(subPlanProfile.staticNotes) ?? "Not added yet"
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func blockText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var relevantCommitments: [CommitmentItem] {
        let block = linkedAlarmForSelectedDate ?? item
        return commitmentsForSelectedDate.filter { commitment in
            let start = anchoredDate(commitment.startTime, on: selectedDate)
            let end = anchoredDate(commitment.endTime, on: selectedDate)
            let classStart = anchoredDate(block.startTime, on: selectedDate)
            let classEnd = anchoredDate(block.endTime, on: selectedDate)
            return start < classEnd && end > classStart
        }
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

    private func commitmentTimeText(_ commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    private func subPlanCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.10),
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }
}

private struct TodayDailySubPlanView: View {
    private enum Field: Hashable {
        case morningNotes
        case sharedMaterials
        case dismissalNotes
        case emergencyNotes
        case returnNotes
    }

    let date: Date
    let alarms: [AlarmItem]
    let commitments: [CommitmentItem]
    let activeOverrideName: String?
    let students: [StudentSupportProfile]
    let attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]
    @Binding var dailySubPlans: [DailySubPlanItem]

    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) private var dismiss
    @State private var morningNotes = ""
    @State private var sharedMaterials = ""
    @State private var dismissalNotes = ""
    @State private var emergencyNotes = ""
    @State private var returnNotes = ""
    @State private var includeAttendance = true
    @State private var includeRoster = true
    @State private var includeSupports = true
    @State private var includeCommitments = true
    @State private var includeSubProfile = true
    @State private var blockPlans: [UUID: BlockSubPlanDraft] = [:]
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var selectedDate: Date
    @State private var feedbackMessage: String?
    @FocusState private var focusedField: Field?

    private struct BlockSubPlanDraft {
        var overview: String = ""
        var lessonPlan: String = ""
        var materials: String = ""
        var subNotes: String = ""
    }

    init(
        date: Date,
        alarms: [AlarmItem],
        commitments: [CommitmentItem],
        activeOverrideName: String?,
        students: [StudentSupportProfile],
        attendanceRecords: [AttendanceRecord],
        subPlans: Binding<[SubPlanItem]>,
        dailySubPlans: Binding<[DailySubPlanItem]>
    ) {
        self.date = date
        self.alarms = alarms
        self.commitments = commitments
        self.activeOverrideName = activeOverrideName
        self.students = students
        self.attendanceRecords = attendanceRecords
        _subPlans = subPlans
        _dailySubPlans = dailySubPlans
        _selectedDate = State(initialValue: date)
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: selectedDate)
    }

    private var existingDailyPlan: DailySubPlanItem? {
        dailySubPlans.first { $0.dateKey == dateKey }
    }

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var schedule: [AlarmItem] {
        alarms
            .filter { $0.dayOfWeek == selectedWeekday }
            .sorted {
                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }
                return $0.endTime < $1.endTime
            }
    }

    private var commitmentsForSelectedDate: [CommitmentItem] {
        resolvedCommitments(for: selectedDate, from: commitments)
    }

    private var displayedOverrideName: String? {
        Calendar.current.isDate(selectedDate, inSameDayAs: date) ? activeOverrideName : nil
    }

    private var followUpNotes: [FollowUpNoteItem] {
        decodeFollowUpNotesFromDefaults()
    }

    private var subPlanProfile: SubPlanProfile {
        ClassTraxPersistence.loadSubPlanProfile(from: modelContext)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline.weight(.bold))
                    Text("\(schedule.count) block\(schedule.count == 1 ? "" : "s") prepared for the day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(displayedOverrideName ?? "Regular Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 2)

                    dailyInfoRow(
                        title: "Selected Date",
                        value: selectedDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )

                    dailyInfoRow(
                        title: "Saved Draft",
                        value: existingDailyPlan == nil ? "No saved daily packet yet" : "Existing daily packet found",
                        systemImage: existingDailyPlan == nil ? "tray" : "tray.full"
                    )

                    dailyInfoRow(
                        title: "Class Blocks",
                        value: "\(schedule.count) total • \(savedBlockCount) saved • \(draftBlockCount) draft",
                        systemImage: "square.stack.3d.up"
                    )

                    dailyInfoRow(
                        title: "Workflow Role",
                        value: "Primary substitute packet",
                        systemImage: "star.circle"
                    )
                }
                .padding(.vertical, 8)
                .listRowBackground(dailySubPlanCardBackground(accent: .blue))
            }

            if let feedbackMessage {
                Section {
                    dailyFeedbackRow(message: feedbackMessage, accent: .green)
                }
                .listRowBackground(dailySubPlanCardBackground(accent: .green))
            }

            Section("Plan Date") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )

                Text("Choose the day first so the correct class blocks load into this sub plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    SubPlanProfileSettingsView()
                } label: {
                    Label("Review Sub Plan Profile", systemImage: "person.text.rectangle")
                }

                Text("Check your reusable teacher contact, emergency, access, and static note details before exporting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Day-Wide Notes") {
                TextField("Morning notes for the substitute", text: $morningNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .morningNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .sharedMaterials
                    }
                TextField("Shared materials, links, copies, devices", text: $sharedMaterials, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .sharedMaterials)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .dismissalNotes
                    }
                TextField("Dismissal notes and end-of-day reminders", text: $dismissalNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .dismissalNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .emergencyNotes
                    }
                TextField("Emergency / important alerts", text: $emergencyNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .emergencyNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .returnNotes
                    }
                TextField("Notes the substitute can leave for you", text: $returnNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .returnNotes)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            Section("Include in Export") {
                Toggle("Include attendance snapshots", isOn: $includeAttendance)
                Toggle("Include rosters", isOn: $includeRoster)
                Toggle("Include accommodations and prompts", isOn: $includeSupports)
                Toggle("Include commitments", isOn: $includeCommitments)
                Toggle("Include Sub Plan Profile", isOn: $includeSubProfile)
            }

            Section("Class Blocks") {
                if schedule.isEmpty {
                    ContentUnavailableView(
                        "No Class Blocks for This Date",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pick another day or add schedule blocks for this weekday to prepare a full daily sub plan.")
                    )
                } else {
                    ForEach(schedule) { block in
                        let draft = binding(for: block)
                        DisclosureGroup {
                            VStack(spacing: 10) {
                                TextField("Overview", text: draft.overview, axis: .vertical)
                                    .lineLimit(2...4)
                                TextField("Lesson plan", text: draft.lessonPlan, axis: .vertical)
                                    .lineLimit(3...6)
                                TextField("Materials", text: draft.materials, axis: .vertical)
                                    .lineLimit(2...4)
                                TextField("Sub notes", text: draft.subNotes, axis: .vertical)
                                    .lineLimit(3...6)
                            }
                            .padding(.top, 6)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(block.className)
                                            .fontWeight(.semibold)
                                        Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    Text(blockDraftStatus(for: block))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(blockHasSavedDraft(block) ? .green : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill((blockHasSavedDraft(block) ? Color.green : Color.secondary).opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                }
            }

            if !missingWorkRows.isEmpty {
                Section("Missing Work for Absent Students") {
                    ForEach(missingWorkRows) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.studentName)
                                .fontWeight(.semibold)
                            Text("\(record.className) • \(record.absentHomework)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Daily Sub Plan")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
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
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Share Text") {
                    focusedField = nil
                    save()
                    exportTextPlan()
                }

                Menu {
                    Menu("Whole Day") {
                        Button("Text Packet") {
                            focusedField = nil
                            save()
                            exportTextPlan()
                        }

                        Button("PDF Packet") {
                            focusedField = nil
                            save()
                            exportPDFPlan()
                        }
                    }

                    Menu("Specific Class") {
                        if schedule.isEmpty {
                            Text("No Class Blocks")
                        } else {
                            ForEach(schedule) { block in
                                Menu(block.className) {
                                    Button("Class Packet (Text)") {
                                        focusedField = nil
                                        save()
                                        exportSingleBlockTextPlan(for: block)
                                    }

                                    Button("Class Packet (PDF)") {
                                        focusedField = nil
                                        save()
                                        exportSingleBlockPDFPlan(for: block)
                                    }
                                }
                            }
                        }
                    }

                    Button("Missing Work (CSV)") {
                        focusedField = nil
                        exportMissingWork()
                    }
                    
                    Divider()

                    Button("Save Packet") {
                        focusedField = nil
                        save()
                        dismiss()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .onChange(of: selectedDate) { _, _ in
            focusedField = nil
            loadExisting()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func loadExisting() {
        morningNotes = ""
        sharedMaterials = ""
        dismissalNotes = ""
        emergencyNotes = ""
        returnNotes = ""
        includeAttendance = true
        includeRoster = true
        includeSupports = true
        includeCommitments = true
        includeSubProfile = true
        blockPlans = [:]

        if let existingDailyPlan {
            morningNotes = existingDailyPlan.morningNotes
            sharedMaterials = existingDailyPlan.sharedMaterials
            dismissalNotes = existingDailyPlan.dismissalNotes
            emergencyNotes = existingDailyPlan.emergencyNotes
            returnNotes = existingDailyPlan.returnNotes
            includeAttendance = existingDailyPlan.includeAttendance
            includeRoster = existingDailyPlan.includeRoster
            includeSupports = existingDailyPlan.includeSupports
            includeCommitments = existingDailyPlan.includeCommitments
            includeSubProfile = existingDailyPlan.includeSubProfile
        }

        for block in schedule {
            if let existing = subPlans.first(where: { $0.dateKey == dateKey && $0.linkedAlarmID == block.id }) {
                blockPlans[block.id] = BlockSubPlanDraft(
                    overview: existing.overview,
                    lessonPlan: existing.lessonPlan,
                    materials: existing.materials,
                    subNotes: existing.subNotes
                )
            } else {
                blockPlans[block.id] = blockPlans[block.id] ?? BlockSubPlanDraft()
            }
        }
    }

    private func binding(for block: AlarmItem) -> (
        overview: Binding<String>,
        lessonPlan: Binding<String>,
        materials: Binding<String>,
        subNotes: Binding<String>
    ) {
        (
            overview: Binding(
                get: { blockPlans[block.id]?.overview ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].overview = $0 }
            ),
            lessonPlan: Binding(
                get: { blockPlans[block.id]?.lessonPlan ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].lessonPlan = $0 }
            ),
            materials: Binding(
                get: { blockPlans[block.id]?.materials ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].materials = $0 }
            ),
            subNotes: Binding(
                get: { blockPlans[block.id]?.subNotes ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].subNotes = $0 }
            )
        )
    }

    private func blockHasSavedDraft(_ block: AlarmItem) -> Bool {
        subPlans.contains { $0.dateKey == dateKey && $0.linkedAlarmID == block.id }
    }

    private var savedBlockCount: Int {
        schedule.filter(blockHasSavedDraft).count
    }

    private var draftBlockCount: Int {
        schedule.filter { block in
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let hasTypedContent = !draft.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasTypedContent && !blockHasSavedDraft(block)
        }.count
    }

    private func blockDraftStatus(for block: AlarmItem) -> String {
        let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
        let hasTypedContent = !draft.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasTypedContent {
            return blockHasSavedDraft(block) ? "Saved" : "Draft"
        }

        return blockHasSavedDraft(block) ? "Saved" : "Empty"
    }

    private func save() {
        let updatedDaily = DailySubPlanItem(
            id: existingDailyPlan?.id ?? UUID(),
            dateKey: dateKey,
            morningNotes: morningNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            sharedMaterials: sharedMaterials.trimmingCharacters(in: .whitespacesAndNewlines),
            dismissalNotes: dismissalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyNotes: emergencyNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            includeAttendance: includeAttendance,
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeCommitments: includeCommitments,
            includeSubProfile: includeSubProfile,
            createdAt: existingDailyPlan?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if let index = dailySubPlans.firstIndex(where: { $0.id == updatedDaily.id }) {
            dailySubPlans[index] = updatedDaily
        } else {
            dailySubPlans.insert(updatedDaily, at: 0)
        }

        for block in schedule {
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let existing = subPlans.first(where: { $0.dateKey == dateKey && $0.linkedAlarmID == block.id })
            let updated = SubPlanItem(
                id: existing?.id ?? UUID(),
                dateKey: dateKey,
                linkedAlarmID: block.id,
                className: block.className,
                gradeLevel: GradeLevelOption.normalized(block.gradeLevel),
                location: block.location,
                overview: draft.overview.trimmingCharacters(in: .whitespacesAndNewlines),
                lessonPlan: draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines),
                materials: draft.materials.trimmingCharacters(in: .whitespacesAndNewlines),
                subNotes: draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                includeRoster: includeRoster,
                includeSupports: includeSupports,
                includeAttendance: includeAttendance,
                includeCommitments: includeCommitments,
                includeDaySchedule: true,
                includeSubProfile: includeSubProfile,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )

            if let index = subPlans.firstIndex(where: { $0.id == updated.id }) {
                subPlans[index] = updated
            } else {
                subPlans.append(updated)
            }
        }

        feedbackMessage = "Saved daily plan for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private func exportTextPlan() {
        let filename = "classtrax-daily-sub-plan-\(dateKey).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? exportText().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Whole-day packet is ready to share."
    }

    private func exportPDFPlan() {
        let filename = "classtrax-daily-sub-plan-\(dateKey)"
        if let url = makeSubPlanPDF(title: "ClassTrax Daily Sub Plan", filename: filename, body: exportText()) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "Whole-day PDF packet is ready to share."
        } else {
            exportTextPlan()
        }
    }

    private func exportSingleBlockTextPlan(for block: AlarmItem) {
        let safeName = block.className.replacingOccurrences(of: " ", with: "-")
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? singleBlockExportText(for: block).write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "\(block.className) packet is ready to share."
    }

    private func exportSingleBlockPDFPlan(for block: AlarmItem) {
        let safeName = block.className.replacingOccurrences(of: " ", with: "-")
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName)"
        if let url = makeSubPlanPDF(
            title: "ClassTrax Sub Plan",
            filename: filename,
            body: singleBlockExportText(for: block)
        ) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "\(block.className) PDF packet is ready to share."
        } else {
            exportSingleBlockTextPlan(for: block)
        }
    }

    private func exportMissingWork() {
        let filename = "classtrax-missing-work-\(dateKey).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? missingWorkCSV().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Missing-work CSV is ready to share."
    }

    private func exportText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let profileText = includeSubProfile ? """
        Teacher Contact
        \(teacherContactBlock())

        Emergency / Drill
        \(emergencyDrillBlock())

        Classroom Access
        \(classroomAccessBlock())

        Static Notes
        \(staticNotesBlock())
        """ : ""

        let blockText = schedule.map { block in
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let roster = rosterForBlock(block)
            let attendance = attendanceForBlock(block)
            let classNotes = classNotesForBlock(block)
            let studentNotes = studentNotesForBlock(block, roster: roster)
            let blockCommitments = commitmentsForBlock(block)

            let rosterText = includeRoster
                ? (roster.isEmpty ? "None" : roster.map { student in
                    var lines = ["- \(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"]
                    if includeSupports {
                        let supports = [student.accommodations, student.prompts]
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        if !supports.isEmpty {
                            lines.append("  Supports: \(supports.joined(separator: " • "))")
                        }
                    }
                    return lines.joined(separator: "\n")
                }.joined(separator: "\n"))
                : "Not included"

            let attendanceText = includeAttendance
                ? (
                    attendance.isEmpty
                    ? "No attendance taken yet"
                    : attendance.map {
                        let homework = $0.status == .absent && !$0.absentHomework.isEmpty
                            ? " — Homework: \($0.absentHomework)"
                            : ""
                        return "- \($0.studentName): \($0.status.rawValue)\(homework)"
                    }.joined(separator: "\n")
                )
                : "Not included"

            let commitmentsText = includeCommitments
                ? (blockCommitments.isEmpty ? "No overlapping commitments" : blockCommitments.map { "- \($0.title): \(commitmentTimeText($0))" }.joined(separator: "\n"))
                : "Not included"

            let classNotesText = classNotes.isEmpty ? "None" : classNotes.map { "- \($0.note)" }.joined(separator: "\n")
            let studentNotesText = studentNotes.isEmpty ? "None" : studentNotes.map { note in
                if let student = roster.first(where: {
                    normalizedStudentKey($0.name) == normalizedStudentKey(note.studentOrGroup)
                }) {
                    return "- \(note.studentOrGroup) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]: \(note.note)"
                }
                return "- \(note.studentOrGroup): \(note.note)"
            }.joined(separator: "\n")

            return """
            \(block.className)
            \(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))
            \(block.gradeLevel) • \(block.location)

            Overview
            \(draft.overview.isEmpty ? "None added" : draft.overview)

            Lesson Plan
            \(draft.lessonPlan.isEmpty ? "None added" : draft.lessonPlan)

            Materials
            \(draft.materials.isEmpty ? "None added" : draft.materials)

            Sub Notes
            \(draft.subNotes.isEmpty ? "None added" : draft.subNotes)

            Roster
            \(rosterText)

            Attendance
            \(attendanceText)

            Class Notes
            \(classNotesText)

            Student Notes
            \(studentNotesText)

            Commitments
            \(commitmentsText)
            """
        }.joined(separator: "\n\n--------------------\n\n")

        let renderedBlockText = blockText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No class blocks are scheduled for this date."
            : blockText

        return """
        ClassTrax Daily Sub Plan
        \(selectedDate.formatted(date: .complete, time: .omitted))

        Active Schedule
        \(displayedOverrideName ?? "Regular Day")

        \(profileText)

        Morning Notes
        \(morningNotes.isEmpty ? "None added" : morningNotes)

        Shared Materials
        \(sharedMaterials.isEmpty ? "None added" : sharedMaterials)

        Dismissal Notes
        \(dismissalNotes.isEmpty ? "None added" : dismissalNotes)

        Emergency Notes
        \(emergencyNotes.isEmpty ? "None added" : emergencyNotes)

        Return Notes
        \(returnNotes.isEmpty ? "None added" : returnNotes)

        Day Schedule and Block Plans
        \(renderedBlockText)
        """
    }

    private var missingWorkRows: [AttendanceRecord] {
        attendanceRecords
            .filter {
                $0.dateKey == dateKey &&
                $0.status == .absent &&
                !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { first, second in
                if first.className.localizedCaseInsensitiveCompare(second.className) != .orderedSame {
                    return first.className.localizedCaseInsensitiveCompare(second.className) == .orderedAscending
                }
                return first.studentName.localizedCaseInsensitiveCompare(second.studentName) == .orderedAscending
            }
    }

    private func dailyFeedbackRow(message: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func missingWorkCSV() -> String {
        let header = "date,className,gradeLevel,studentName,status,absentHomework"
        let rows = schedule.flatMap { block in
            attendanceForBlock(block)
                .filter { $0.status == .absent && !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { record in
                    [
                        dateKey,
                        block.className,
                        GradeLevelOption.normalized(block.gradeLevel),
                        record.studentName,
                        record.status.rawValue,
                        record.absentHomework
                    ]
                    .map(csvEscape)
                    .joined(separator: ",")
                }
        }

        if rows.isEmpty {
            let fallbackRow = [
                dateKey,
                "No absent work recorded",
                "",
                "",
                "",
                ""
            ]
            .map(csvEscape)
            .joined(separator: ",")

            return ([header, fallbackRow]).joined(separator: "\n")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private func singleBlockExportText(for block: AlarmItem) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
        let roster = rosterForBlock(block)
        let attendance = attendanceForBlock(block)
        let classNotes = classNotesForBlock(block)
        let studentNotes = studentNotesForBlock(block, roster: roster)
        let blockCommitments = commitmentsForBlock(block)

        let profileText = includeSubProfile ? """
        Teacher Contact
        \(teacherContactBlock())

        Emergency / Drill
        \(emergencyDrillBlock())

        Classroom Access
        \(classroomAccessBlock())

        Static Notes
        \(staticNotesBlock())
        """ : ""

        let rosterText = includeRoster
            ? (roster.isEmpty ? "None" : roster.map { student in
                var lines = ["- \(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"]
                if includeSupports {
                    let supports = [student.accommodations, student.prompts]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if !supports.isEmpty {
                        lines.append("  Supports: \(supports.joined(separator: "; "))")
                    }
                }
                return lines.joined(separator: "\n")
            }.joined(separator: "\n"))
            : "Not included"

        let attendanceText = includeAttendance
            ? (attendance.isEmpty ? "None" : attendance.map {
                "- \($0.studentName): \($0.status.rawValue)\($0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " | Missing work: \($0.absentHomework)")"
            }.joined(separator: "\n"))
            : "Not included"

        let classNotesText = classNotes.isEmpty ? "None" : classNotes.map { "- \($0.note)" }.joined(separator: "\n")
        let studentNotesText = studentNotes.isEmpty ? "None" : studentNotes.map { note in
            "- \(note.studentOrGroup): \(note.note)"
        }.joined(separator: "\n")
        let commitmentsText = includeCommitments
            ? (blockCommitments.isEmpty ? "None" : blockCommitments.map { commitment in
                let start = anchoredDate(commitment.startTime, on: selectedDate)
                let end = anchoredDate(commitment.endTime, on: selectedDate)
                return "- \(commitment.title) (\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end)))"
            }.joined(separator: "\n"))
            : "Not included"

        return """
        ClassTrax Sub Plan
        \(selectedDate.formatted(date: .complete, time: .omitted))

        Class
        \(block.className)

        Time
        \(timeFormatter.string(from: anchoredDate(block.startTime, on: selectedDate))) - \(timeFormatter.string(from: anchoredDate(block.endTime, on: selectedDate)))

        Active Schedule
        \(displayedOverrideName ?? "Regular Day")

        \(profileText)

        Shared Materials
        \(sharedMaterials.isEmpty ? "None added" : sharedMaterials)

        Overview
        \(draft.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None added" : draft.overview)

        Lesson Plan
        \(draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None added" : draft.lessonPlan)

        Materials
        \(draft.materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None added" : draft.materials)

        Sub Notes
        \(draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None added" : draft.subNotes)

        Return Notes
        \(returnNotes.isEmpty ? "None added" : returnNotes)

        Roster
        \(rosterText)

        Attendance
        \(attendanceText)

        Class Notes
        \(classNotesText)

        Student Notes
        \(studentNotesText)

        Commitments
        \(commitmentsText)
        """
    }

    private func teacherContactBlock() -> String {
        let lines = [
            labeledLine("Teacher", subPlanProfile.teacherName),
            labeledLine("Room", subPlanProfile.room),
            labeledLine("Email", subPlanProfile.contactEmail),
            labeledLine("Phone", subPlanProfile.contactPhone),
            labeledLine("Front Office", subPlanProfile.schoolFrontOfficeContact),
            labeledLine("Neighboring Teacher", subPlanProfile.neighboringTeacher)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func emergencyDrillBlock() -> String {
        let lines = [
            blockText(subPlanProfile.emergencyDrillProcedures),
            labeledLine("File Link", subPlanProfile.emergencyDrillFileLink)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func classroomAccessBlock() -> String {
        let credentialText = subPlanProfile.appCredentials
            .filter(\.hasContent)
            .map { credential in
                [
                    labeledLine("App", credential.applicationName),
                    labeledLine("Link", credential.applicationLink),
                    labeledLine("Username", credential.username),
                    labeledLine("Password", credential.password)
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let lines = [
            labeledLine("Extensions", subPlanProfile.phoneExtensions),
            blockText(subPlanProfile.passwordsAccessNotes),
            credentialText.isEmpty ? nil : credentialText
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func staticNotesBlock() -> String {
        blockText(subPlanProfile.staticNotes) ?? "Not added yet"
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func blockText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rosterForBlock(_ block: AlarmItem) -> [StudentSupportProfile] {
        let linkedIDs = Set(block.linkedStudentIDs)
        if !linkedIDs.isEmpty {
            return students.filter { linkedIDs.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        let normalizedGrade = GradeLevelOption.normalized(block.gradeLevel)
        return students.filter { profile in
            classNamesMatch(scheduleClassName: block.className, profileClassName: profile.className) &&
            (
                normalizedGrade.isEmpty ||
                profile.gradeLevel.isEmpty ||
                normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel)) == normalizedStudentKey(normalizedGrade)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func attendanceForBlock(_ block: AlarmItem) -> [AttendanceRecord] {
        attendanceRecords.filter {
            $0.dateKey == dateKey &&
            $0.isAttendanceEntry &&
            classNamesMatch(scheduleClassName: block.className, profileClassName: $0.className) &&
            normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(block.gradeLevel))
        }
        .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func classNotesForBlock(_ block: AlarmItem) -> [FollowUpNoteItem] {
        followUpNotes.filter {
            $0.kind == .classNote &&
            classNamesMatch(scheduleClassName: block.className, profileClassName: $0.context)
        }
    }

    private func studentNotesForBlock(_ block: AlarmItem, roster: [StudentSupportProfile]) -> [FollowUpNoteItem] {
        let studentKeys = Set(roster.map { normalizedStudentKey($0.name) })
        return followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            studentKeys.contains(normalizedStudentKey($0.studentOrGroup))
        }
    }

    private func commitmentsForBlock(_ block: AlarmItem) -> [CommitmentItem] {
        commitmentsForSelectedDate.filter { commitment in
            let start = anchoredDate(commitment.startTime, on: selectedDate)
            let end = anchoredDate(commitment.endTime, on: selectedDate)
            let blockStart = anchoredDate(block.startTime, on: selectedDate)
            let blockEnd = anchoredDate(block.endTime, on: selectedDate)
            return start < blockEnd && end > blockStart
        }
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

    private func commitmentTimeText(_ commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    private func dailySubPlanCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.10),
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }

    private func dailyInfoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private func makeSubPlanPDF(title: String, filename: String, body: String) -> URL? {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(filename)-\(UUID().uuidString).pdf")

    let text = "\(title)\n\n\(body)"
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 14),
        .paragraphStyle: paragraph
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let printableRect = CGRect(x: 36, y: 36, width: 540, height: 720)

    do {
        try renderer.writePDF(to: url) { context in
            var range = NSRange(location: 0, length: attributed.length)

            while range.location < attributed.length {
                context.beginPage()
                range = drawSubPlanAttributedString(attributed, in: printableRect, range: range)
            }
        }
        return url
    } catch {
        return nil
    }
}

private func drawSubPlanAttributedString(_ string: NSAttributedString, in rect: CGRect, range: NSRange) -> NSRange {
    let framesetter = CTFramesetterCreateWithAttributedString(string)
    guard let context = UIGraphicsGetCurrentContext() else {
        return range
    }

    let pageBounds = UIGraphicsGetPDFContextBounds()
    let coreTextRect = CGRect(
        x: rect.minX,
        y: pageBounds.height - rect.maxY,
        width: rect.width,
        height: rect.height
    )
    let path = CGPath(rect: coreTextRect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(range.location, range.length), path, nil)

    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: 0, y: pageBounds.height)
    context.scaleBy(x: 1, y: -1)
    CTFrameDraw(frame, context)
    context.restoreGState()

    let visibleRange = CTFrameGetVisibleStringRange(frame)
    return NSRange(location: range.location + visibleRange.length, length: string.length - range.location - visibleRange.length)
}

private func makeStyledSubPlanAttributedString(title: String, body: String) -> NSAttributedString {
    let result = NSMutableAttributedString()

    let titleParagraph = NSMutableParagraphStyle()
    titleParagraph.alignment = .left
    titleParagraph.lineBreakMode = .byWordWrapping
    titleParagraph.paragraphSpacing = 10

    let headingParagraph = NSMutableParagraphStyle()
    headingParagraph.alignment = .left
    headingParagraph.lineBreakMode = .byWordWrapping
    headingParagraph.paragraphSpacing = 6
    headingParagraph.paragraphSpacingBefore = 10

    let bodyParagraph = NSMutableParagraphStyle()
    bodyParagraph.alignment = .left
    bodyParagraph.lineBreakMode = .byWordWrapping
    bodyParagraph.lineSpacing = 3
    bodyParagraph.paragraphSpacing = 8

    let bulletParagraph = NSMutableParagraphStyle()
    bulletParagraph.alignment = .left
    bulletParagraph.lineBreakMode = .byWordWrapping
    bulletParagraph.lineSpacing = 2
    bulletParagraph.paragraphSpacing = 4
    bulletParagraph.headIndent = 16
    bulletParagraph.firstLineHeadIndent = 0

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: UIColor.label,
        .paragraphStyle: titleParagraph
    ]

    let headingAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: UIColor.label,
        .paragraphStyle: headingParagraph
    ]

    let bodyAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12.5, weight: .regular),
        .foregroundColor: UIColor.label,
        .paragraphStyle: bodyParagraph
    ]

    let bulletAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: UIColor.label,
        .paragraphStyle: bulletParagraph
    ]

    result.append(NSAttributedString(string: "\(title)\n", attributes: titleAttributes))

    let blocks = body
        .components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    for block in blocks {
        let lines = block.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { continue }
        let remainingLines = Array(lines.dropFirst())

        if !remainingLines.isEmpty {
            result.append(NSAttributedString(string: "\(firstLine)\n", attributes: headingAttributes))
            appendSubPlanBodyLines(remainingLines, to: result, bodyAttributes: bodyAttributes, bulletAttributes: bulletAttributes)
        } else {
            let isBullet = firstLine.trimmingCharacters(in: .whitespaces).hasPrefix("-")
            let attributes = isBullet ? bulletAttributes : bodyAttributes
            result.append(NSAttributedString(string: "\(firstLine)\n", attributes: attributes))
        }

        result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
    }

    return result
}

private func appendSubPlanBodyLines(
    _ lines: [String],
    to result: NSMutableAttributedString,
    bodyAttributes: [NSAttributedString.Key: Any],
    bulletAttributes: [NSAttributedString.Key: Any]
) {
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let isBullet = trimmedLine.hasPrefix("-")
        let isIndented = line.hasPrefix("  ")
        let attributes = (isBullet || isIndented) ? bulletAttributes : bodyAttributes
        result.append(NSAttributedString(string: "\(line)\n", attributes: attributes))
    }
}

private func drawSubPlanPageHeader(title: String, pageNumber: Int, in rect: CGRect) {
    let headerText = "\(title)    Page \(pageNumber)"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .right

    let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 9, weight: .medium),
        .foregroundColor: UIColor.secondaryLabel,
        .paragraphStyle: paragraph
    ]

    let headerRect = CGRect(x: rect.minX, y: 18, width: rect.width, height: 16)
    headerText.draw(in: headerRect, withAttributes: attributes)
}

private func exportContextPill(title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
}

struct TodayLayoutCustomizationView: View {
    @Binding var cards: [TodayView.TodayDashboardCard]
    @Binding var hiddenCards: Set<TodayView.TodayDashboardCard>
    @Environment(\.dismiss) private var dismiss

    private var orderedCards: [TodayView.TodayDashboardCard] {
        cards
    }

    var body: some View {
        List {
            Section {
                Text("Current Block and Next Up stay fixed at the top. Choose which cards appear below, then drag them into the order that fits your routine.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Shown on Today") {
                ForEach(orderedCards, id: \.id) { card in
                    visibilityRow(for: card)
                }
            }

            Section("Card Order") {
                ForEach(orderedCards, id: \.id) { card in
                    orderingRow(for: card)
                }
                .onMove(perform: moveCards)
            }
        }
        .navigationTitle("Customize Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Reset") {
                    cards = TodayView.TodayDashboardCard.defaultOrder
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }

    private func visibilityBinding(for card: TodayView.TodayDashboardCard) -> Binding<Bool> {
        Binding(
            get: { !hiddenCards.contains(card) },
            set: { isVisible in
                if isVisible {
                    hiddenCards.remove(card)
                } else {
                    hiddenCards.insert(card)
                }
            }
        )
    }

    private func visibilityRow(for card: TodayView.TodayDashboardCard) -> some View {
        let isHidden = hiddenCards.contains(card)

        return Toggle(isOn: visibilityBinding(for: card)) {
            HStack {
                Label(card.title, systemImage: card.systemImage)

                Spacer()

                Text(isHidden ? "Hidden" : "Shown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHidden ? Color.secondary : Color.green)
            }
            .opacity(isHidden ? 0.62 : 1.0)
        }
    }

    private func orderingRow(for card: TodayView.TodayDashboardCard) -> some View {
        let isHidden = hiddenCards.contains(card)

        return HStack {
            Label(card.title, systemImage: card.systemImage)
                .opacity(isHidden ? 0.62 : 1.0)

            Spacer()

            if isHidden {
                Text("Hidden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct TodayCommitmentsManagerView: View {
    @Binding var commitments: [CommitmentItem]
    let onAdd: () -> Void
    let onEdit: (CommitmentItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private var groupedCommitments: [(day: WeekdayTab, items: [CommitmentItem])] {
        WeekdayTab.allCases.compactMap { day in
            let items = commitments
                .filter { $0.dayOfWeek == day.rawValue }
                .sorted {
                    if $0.startTime == $1.startTime {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return $0.startTime < $1.startTime
                }

            guard !items.isEmpty else { return nil }
            return (day, items)
        }
    }

    var body: some View {
        List {
            Section {
                Text("Commitments can repeat weekly or be saved as one-time events for a specific date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if groupedCommitments.isEmpty {
                Section("No Commitments Yet") {
                    Text("Add duties, meetings, conferences, or coverage blocks so they stay attached to the correct weekday.")
                        .foregroundStyle(.secondary)

                    Button("Add Commitment", systemImage: "plus.circle.fill") {
                        onAdd()
                    }
                }
            } else {
                ForEach(groupedCommitments, id: \.day) { section in
                    Section(section.day.title) {
                        ForEach(section.items) { commitment in
                            Button {
                                onEdit(commitment)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(commitment.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(
                                        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    Text(commitment.recurrence == .oneTime
                                        ? "One Time • \((commitment.specificDate ?? Date()).formatted(date: .abbreviated, time: .omitted))"
                                        : "Recurring Weekly")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if !commitment.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(commitment.location)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Commitments")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
}

private struct InAppWarningBanner: View {
    let warning: InAppWarning

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(warning.accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 0.15 : 0.45)

                Image(systemName: "bell.badge.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(warning.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(warning.accentColor)

                Text(warning.item.className)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Text("\(warning.timeText) • \(warning.roomText)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(warning.accentColor.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: warning.accentColor.opacity(0.18), radius: 18, y: 8)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct DashboardCardStyle: ViewModifier {
    let accent: Color
    let compact: Bool

    func body(content: Content) -> some View {
        content
            .padding(compact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.10),
                                Color(.secondarySystemBackground).opacity(0.90),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.08), radius: 16, y: 8)
    }
}
