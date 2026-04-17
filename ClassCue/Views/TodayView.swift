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

// TodayView now acts as the screen shell: state, modal wiring, and composition.
struct TodayView: View {
    // RuntimeState keeps the coarse dashboard refresh path centralized.
    struct RuntimeState {
        let now: Date
        let schedule: [AlarmItem]
        let activeItem: AlarmItem?
        let nextItem: AlarmItem?
        let warning: InAppWarning?
        let todayCommitments: [CommitmentItem]

        var highlightItem: AlarmItem? {
            activeItem ?? nextItem
        }
    }

    @Binding var alarms: [AlarmItem]
    @Binding var todos: [TodoItem]
    @Binding var commitments: [CommitmentItem]
    @Binding var studentSupportProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    @Binding var attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]
    @Binding var dailySubPlans: [DailySubPlanItem]
    let suggestedStudents: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    let activeOverrideName: String?
    let overrideSchedule: [AlarmItem]?
    let ignoreDate: Date?
    let isAttendanceEnabled: Bool
    let isScheduleEnabled: Bool
    let isHomeworkEnabled: Bool
    let isBehaviorEnabled: Bool
    let onRefresh: @MainActor () -> Void
    let onRefreshNotifications: () -> Void
    let openAttendanceTab: () -> Void
    let openScheduleTab: () -> Void
    let openScheduleBlock: (AlarmItem) -> Void
    let openStudentsTab: () -> Void
    let openTodoTab: () -> Void
    let openTodoItem: (TodoItem) -> Void
    let openNotesTab: () -> Void
    let openSettingsTab: () -> Void
    let behaviorLogs: [BehaviorLogItem]
    let behaviorLogsForStudent: (StudentSupportProfile) -> [BehaviorLogItem]
    let behaviorSegmentsForStudent: (StudentSupportProfile) -> [BehaviorSegmentOption]
    let preferredBehaviorSegmentID: (StudentSupportProfile) -> UUID?
    let preferredBehaviorSegmentTitle: (StudentSupportProfile) -> String
    let onLogBehavior: (StudentSupportProfile, BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?) -> Void
    let onLogBehaviorWithNote: (StudentSupportProfile, BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?, String, Date) -> Void

    @AppStorage("notes_v1") var notesText: String = ""
    @AppStorage("personal_notes_v1") var personalNotesText: String = ""
    @AppStorage("today_quick_note_draft_v1") var todayQuickNoteDraft = ""
    @AppStorage("today_quick_note_draft_token_v1") var todayQuickNoteDraftToken: Double = 0
    @AppStorage("school_quiet_hours_enabled") var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") var schoolQuietMinute = 0
    @AppStorage("school_show_end_of_day_wrap_up") var showEndOfDayWrapUp = true
    @AppStorage("school_offer_task_carryover") var offerTaskCarryover = true
    @AppStorage("school_hide_dashboard_after_hours") var hideSchoolDashboardAfterHours = true
    @AppStorage("school_show_personal_focus_card") var showPersonalFocusCard = true
    @AppStorage("live_activities_enabled") var liveActivitiesEnabled = true
    @AppStorage("today_dashboard_card_order_v1") var storedDashboardCardOrder = ""
    @AppStorage("today_dashboard_hidden_cards_v1") var storedHiddenDashboardCards = ""
    @AppStorage("teacher_workflow_mode_v1") var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue
    @AppStorage("classtrax_sounds_muted_v1") var soundsMuted = false

    @State var activeWarning: InAppWarning?
    @State var lastWarningKey: String?
    @State var warningDismissTask: Task<Void, Never>?
    @AppStorage("classtrax_extra_time_by_item_v1") private var storedExtraTimeByItemID: Data = Data()
    @AppStorage("classtrax_held_item_id_v1") private var storedHeldItemID: String = ""
    @AppStorage("classtrax_hold_started_at_v1") private var storedHoldStartedAt: Double = 0
    @AppStorage("classtrax_skipped_bell_item_ids_v1") private var storedSkippedBellItemIDs: Data = Data()
    @State var lastActiveItemID: UUID?
    @State var showingSessionActions = false
    @State var sessionActionItem: AlarmItem?
    @State var showingAddCommitment = false
    @State var showingCommitmentsManager = false
    @State var editingCommitment: CommitmentItem?
    @State var showingQuickCapture = false
    @State var editingAlarm: AlarmItem?
    @State var showingStudentDirectory = false
    @State var studentLookupSession: TodayStudentLookupSession?
    @State var groupActionSession: TodayGroupActionSession?
    @State var quickViewStudent: StudentSupportProfile?
    @State var editingStudentSupportProfile: StudentSupportProfile?
    @State var rosterItem: AlarmItem?
    @State var attendanceSession: AttendanceSession?
    @State var homeworkCaptureSession: HomeworkCaptureSession?
    @State var classBehaviorNoteItem: AlarmItem?
    @State var showingHomeworkReview = false
    @State var homeworkReviewDate = Date()
    @State var subPlanItem: AlarmItem?
    @State var showingDailyExport = false
    @State var showingDailySubPlan = false
    @State var dailySubPlanDate = Date()
    @State var todayAttendanceExportURL: URL?
    @State var showingTodayAttendanceShareSheet = false
    @State var quickSchoolNoteText = ""
    @State var pendingLiveActivityStopTask: Task<Void, Never>?
    @State var dashboardCardOrder = TodayDashboardCard.defaultOrder
    @State var hiddenDashboardCards = Set<TodayDashboardCard>()
    @State var scrollTargetCard: TodayDashboardCard?
    @State var showingLayoutCustomization = false
    @State var dashboardNow = Date()
    @State var lastDashboardRefreshBucket = 0
    @State var lastRenderedActiveItemID: UUID?
    @State var lastRenderedNextItemID: UUID?

    let dashboardPrimaryTint = ClassTraxSemanticColor.primaryAction
    let dashboardSecondaryTint = ClassTraxSemanticColor.secondaryAction

    var extraTimeByItemID: [UUID: TimeInterval] {
        SessionControlStore.extraTimeByItemID()
    }

    var skippedBellItemIDs: Set<UUID> {
        SessionControlStore.skippedBellItemIDs()
    }

    var body: some View {
        let runtime = makeRuntimeState(for: dashboardNow)

        return ZStack(alignment: .top) {
            todayBackground(for: runtime.highlightItem)
                .ignoresSafeArea()

            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height

                Group {
                    if isLandscape {
                        landscapeDashboard(
                            availableSize: geo.size,
                            now: runtime.now,
                            schedule: runtime.schedule,
                            activeItem: runtime.activeItem,
                            nextItem: runtime.nextItem,
                            todayCommitments: runtime.todayCommitments
                        )
                    } else {
                        portraitDashboard(
                            now: runtime.now,
                            schedule: runtime.schedule,
                            activeItem: runtime.activeItem,
                            nextItem: runtime.nextItem,
                            todayCommitments: runtime.todayCommitments
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

            floatingActionMenu(activeItem: runtime.activeItem, now: runtime.now)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .zIndex(1)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: activeWarning?.id)
        .confirmationDialog(
            sessionActionItem == nil ? "Class Controls" : "\(sessionActionItem?.className ?? "Class") Controls",
            isPresented: $showingSessionActions,
            titleVisibility: .visible
        ) {
            if let sessionActionItem {
                Button(
                    skippedBellItemIDs.contains(sessionActionItem.id) ? "Bell Already Skipped" : "Skip Bell",
                    role: skippedBellItemIDs.contains(sessionActionItem.id) ? .cancel : nil
                ) {
                    if !skippedBellItemIDs.contains(sessionActionItem.id) {
                        skipBell(for: sessionActionItem)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCommitment) {
            AddCommitmentView(
                commitments: $commitments,
                defaultDay: Calendar.current.component(.weekday, from: runtime.now)
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
                suggestedStudentGroups: classDefinitions.map(\.name),
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
                StudentDirectoryView(
                    profiles: $studentSupportProfiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts
                )
            }
        }
        .sheet(item: $studentLookupSession) { session in
            studentLookupSheet(for: session)
        }
        .sheet(item: $groupActionSession) { session in
            NavigationStack {
                TodayGroupActionPickerView(
                    session: session,
                    onChoose: { selection in
                        groupActionSession = nil
                        handleGroupActionSelection(selection, now: runtime.now, schedule: runtime.schedule)
                    }
                )
            }
        }
        .sheet(item: $quickViewStudent) { profile in
            NavigationStack {
                StudentQuickView(
                    profile: latestStudentProfile(for: profile),
                    classDefinitions: classDefinitions,
                    teacherContacts: teacherContacts,
                    paraContacts: paraContacts,
                    attendanceRecords: attendanceRecords,
                    behaviorLogs: behaviorLogsForStudent(profile),
                    behaviorSegments: behaviorSegmentsForStudent(latestStudentProfile(for: profile)),
                    preferredBehaviorSegmentID: preferredBehaviorSegmentID(latestStudentProfile(for: profile)),
                    preferredBehaviorSegmentTitle: preferredBehaviorSegmentTitle(latestStudentProfile(for: profile)),
                    onEdit: {
                        quickViewStudent = nil
                        editingStudentSupportProfile = latestStudentProfile(for: profile)
                    },
                    onOpenStudents: {
                        quickViewStudent = nil
                        openStudentsTab()
                    },
                    onOpenRecord: {
                        quickViewStudent = nil
                        openNotesTab()
                    },
                    onLogBehavior: { behavior, rating, segmentID in
                        onLogBehavior(latestStudentProfile(for: profile), behavior, rating, segmentID)
                    },
                    onLogBehaviorWithNote: { behavior, rating, segmentID, note, timestamp in
                        onLogBehaviorWithNote(latestStudentProfile(for: profile), behavior, rating, segmentID, note, timestamp)
                    },
                    onSaveBehaviorQuickNote: { segmentID, behavior, note in
                        saveBehaviorQuickNote(for: latestStudentProfile(for: profile), segmentID: segmentID, behavior: behavior, note: note)
                    }
                )
            }
        }
        .sheet(item: $editingStudentSupportProfile) { profile in
            EditStudentSupportView(
                profiles: $studentSupportProfiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
                existing: profile
            )
        }
        .sheet(item: $rosterItem) { item in
            NavigationStack {
                TodayClassRosterView(
                    item: item,
                    alarms: $alarms,
                    profiles: $studentSupportProfiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts
                )
            }
        }
        .sheet(item: $subPlanItem) { item in
            NavigationStack {
                TodayClassSubPlanView(
                    item: item,
                    date: runtime.now,
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
        .sheet(isPresented: $showingDailyExport) {
            DailyExportView(
                attendanceRecords: attendanceRecords,
                behaviorLogs: behaviorLogs,
                todos: todos,
                commitments: commitments,
                followUpNotes: decodeFollowUpNotesFromDefaults(),
                classDefinitions: classDefinitions,
                studentProfiles: studentSupportProfiles
            )
        }
        .sheet(isPresented: $showingTodayAttendanceShareSheet) {
            if let todayAttendanceExportURL {
                ShareSheet(activityItems: [todayAttendanceExportURL])
            }
        }
        .sheet(item: $attendanceSession) { session in
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
        .sheet(item: $homeworkCaptureSession) { session in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: session.targetTitle ?? session.item.className,
                    helperText: "This homework note is saved with today's class and included in attendance exports.",
                    initialText: classHomeworkText(for: session.item, now: session.date, targetClassDefinitionID: session.targetClassDefinitionID),
                    onSave: { saveClassHomework($0, for: session.item, now: session.date, targetClassDefinitionID: session.targetClassDefinitionID, targetTitle: session.targetTitle) }
                )
            }
        }
        .sheet(item: $classBehaviorNoteItem) { item in
            let initialNote = latestClassBehaviorNote(for: item)?.note ?? ""
            NavigationStack {
                AttendanceNoteEditorView(
                    title: "\(item.className) Class Note",
                    helperText: "Keep one class-level note for behavior or anything you need to remember in this block.",
                    initialText: initialNote,
                    onSave: { text in
                        saveClassBehaviorNote(text, for: item)
                    }
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
        .sheet(isPresented: $showingLayoutCustomization) {
            NavigationStack {
                TodayLayoutCustomizationView(
                    cards: $dashboardCardOrder,
                    hiddenCards: $hiddenDashboardCards
                )
            }
        }
        .onAppear {
            let initialNow = Date()
            dashboardNow = initialNow
            lastDashboardRefreshBucket = refreshBucket(for: initialNow)
            loadDashboardCardOrderIfNeeded()
        }
        .onChange(of: dashboardCardOrder) { _, newValue in
            persistDashboardCardOrder(newValue)
        }
        .onChange(of: hiddenDashboardCards) { _, newValue in
            persistHiddenDashboardCards(newValue)
        }
        .task {
            await runDashboardRefreshLoop()
        }
    }

    private func openStudentQuickView(_ profile: StudentSupportProfile) {
        studentLookupSession = nil
        quickViewStudent = profile
    }

    private func saveBehaviorQuickNote(
        for profile: StudentSupportProfile,
        segmentID: UUID?,
        behavior: BehaviorLogItem.BehaviorKind,
        note: String
    ) {
        guard let index = studentSupportProfiles.firstIndex(where: { $0.id == profile.id }) else { return }
        studentSupportProfiles[index] = updatingProfile(
            studentSupportProfiles[index],
            behaviorQuickNote: note,
            for: behavior,
            classDefinitionID: segmentID
        )
        quickViewStudent = studentSupportProfiles[index]
    }

    @ViewBuilder
    private func studentLookupSheet(for session: TodayStudentLookupSession) -> some View {
        NavigationStack {
            TodayStudentLookupView(
                session: session,
                onSelect: openStudentQuickView,
                behaviorLogsForStudent: behaviorLogsForStudent,
                onBehaviorLog: { profile, behavior, rating, segmentID, note, timestamp in
                    onLogBehaviorWithNote(profile, behavior, rating, segmentID, note, timestamp)
                }
            )
        }
    }
    // MARK: Header

}
