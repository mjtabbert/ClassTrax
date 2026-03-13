//
//  TodayView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 25
//

import SwiftUI
import WidgetKit

struct TodayView: View {

    @Binding var alarms: [AlarmItem]
    @Binding var todos: [TodoItem]
    @Binding var commitments: [CommitmentItem]
    @Binding var studentSupportProfiles: [StudentSupportProfile]
    @Binding var attendanceRecords: [AttendanceRecord]
    let suggestedStudents: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    let activeOverrideName: String?
    let overrideSchedule: [AlarmItem]?
    let ignoreDate: Date?
    let openScheduleTab: () -> Void
    let openTodoTab: () -> Void
    let openNotesTab: () -> Void
    let openSettingsTab: () -> Void

    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0

    @State private var activeWarning: InAppWarning?
    @State private var lastWarningKey: String?
    @State private var warningDismissTask: Task<Void, Never>?
    @State private var extraTimeByItemID: [UUID: TimeInterval] = [:]
    @State private var heldItemID: UUID?
    @State private var holdStartedAt: Date?
    @State private var skippedBellItemIDs: Set<UUID> = []
    @State private var lastActiveItemID: UUID?
    @State private var showingSessionActions = false
    @State private var showingAddCommitment = false
    @State private var editingCommitment: CommitmentItem?
    @State private var showingQuickCapture = false
    @State private var editingAlarm: AlarmItem?
    @State private var showingStudentDirectory = false
    @State private var rosterItem: AlarmItem?
    @State private var attendanceItem: AlarmItem?

    var body: some View {

        TimelineView(.periodic(from: .now, by: 0.2)) { context in

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
            .onChange(of: liveActivityState(for: activeItem, now: now)) { _, newValue in
                syncLiveActivity(with: newValue)
            }
            .onChange(of: widgetSnapshot(activeItem: activeItem, nextItem: nextItem, now: now)) { _, newValue in
                syncWidgetSnapshot(newValue)
            }
            .task {
                syncLiveActivity(with: liveActivityState(for: activeItem, now: now))
                syncWidgetSnapshot(widgetSnapshot(activeItem: activeItem, nextItem: nextItem, now: now))
            }
            .confirmationDialog(
                activeItem == nil ? "Class Controls" : "\(activeItem?.className ?? "Class") Controls",
                isPresented: $showingSessionActions,
                titleVisibility: .visible
            ) {
                if let activeItem {
                    Button(isHeld(activeItem) ? "Resume Class" : "Hold Class") {
                        toggleHold(for: activeItem, now: now)
                    }

                    Button("Extend 1 Minute") {
                        extend(activeItem, byMinutes: 1)
                    }

                    Button("Extend 2 Minutes") {
                        extend(activeItem, byMinutes: 2)
                    }

                    Button("Extend 5 Minutes") {
                        extend(activeItem, byMinutes: 5)
                    }

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
                    day: item.dayOfWeek,
                    existing: item
                )
            }
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(profiles: $studentSupportProfiles)
                }
            }
            .sheet(item: $rosterItem) { item in
                NavigationStack {
                    TodayClassRosterView(item: item, students: rosterStudents(for: item))
                }
            }
            .sheet(item: $attendanceItem) { item in
                NavigationStack {
                    TodayClassAttendanceView(
                        item: item,
                        date: now,
                        students: rosterStudents(for: item),
                        records: $attendanceRecords
                    )
                }
            }
        }
    }

    // MARK: Header

    func header(now: Date) -> some View {

        VStack(spacing: 4) {

            Text(now.formatted(.dateTime.weekday(.wide)))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .tracking(4)

            Text(now.formatted(.dateTime.month().day()))
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding(.top)
    }

    private func holidayModeBanner(until date: Date) -> some View {

        HStack(spacing: 10) {
            Image(systemName: "bell.slash.fill")
                .foregroundColor(.orange)

            Text("Holiday mode is on until \(date.formatted(date: .abbreviated, time: .shortened)).")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.12))
        )
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

        ScrollView {
            VStack(spacing: 16) {

                header(now: now)

                if let ignoreDate, ignoreDate > now {
                    holidayModeBanner(until: ignoreDate)
                        .padding(.horizontal)
                }

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
            .padding(.bottom, 96)
        }
    }

    @ViewBuilder
    private func landscapeDashboard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {

        VStack(spacing: 12) {

            landscapeHeader(now: now)

            if let ignoreDate, ignoreDate > now {
                holidayModeBanner(until: ignoreDate)
            }

            if let activeOverrideName {
                overrideBanner(name: activeOverrideName)
            }

            HStack(alignment: .top, spacing: 16) {

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
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
            teacherContextRibbon(
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem
            )
            .padding(.top, 6)
            classSectionCard(activeItem: activeItem, nextItem: nextItem, compact: false)
            commitmentsCard(todayCommitments: todayCommitments, compact: false)
            upcomingStrip(schedule: schedule, now: now, nextItem: nextItem)
            topTasksCard(now: now)
            studentSupportCard(activeItem: activeItem, nextItem: nextItem, compact: false)
            notesSnapshotCard(compact: false)
            schoolBoundaryCard(now: now, schedule: schedule)
            endOfDayCard(now: now, schedule: schedule)
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
            if shouldShowDayStatus(now: now, schedule: schedule, activeItem: schedule.first(where: {
                now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
            })) {
                dayStatusCard(now: now, schedule: schedule, activeItem: schedule.first(where: {
                    now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
                }), compact: true)
            }

            teacherContextRibbon(
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem,
                compact: true
            )
            .padding(.top, 6)
            classSectionCard(activeItem: activeItem, nextItem: nextItem, compact: true)
            commitmentsCard(todayCommitments: todayCommitments, compact: true)
            upcomingStrip(schedule: schedule, now: now, nextItem: nextItem, compact: true)
            topTasksCard(now: now, compact: true)
            studentSupportCard(activeItem: activeItem, nextItem: nextItem, compact: true)
            notesSnapshotCard(compact: true)
            schoolBoundaryCard(now: now, schedule: schedule, compact: true)
            endOfDayCard(now: now, schedule: schedule, compact: true)
        }
    }

    @ViewBuilder
    private func classSectionCard(activeItem: AlarmItem?, nextItem: AlarmItem?, compact: Bool) -> some View {
        if let item = activeItem ?? nextItem {
            let linkedTasks = todos.filter {
                !$0.isCompleted &&
                $0.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(item.className.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            }
            let roster = rosterStudents(for: item)
            let supportCount = roster.count

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(activeItem != nil ? "Current Class" : "Next Class", systemImage: activeItem != nil ? "studentdesk" : "calendar.badge.clock")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()
                }

                Text(item.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

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
                    if !roster.isEmpty {
                        Label("\(roster.count) student\(roster.count == 1 ? "" : "s")", systemImage: "person.3.sequence.fill")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }

                    if !linkedTasks.isEmpty {
                        Label("\(linkedTasks.count) task\(linkedTasks.count == 1 ? "" : "s")", systemImage: "checklist")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }

                    if supportCount > 0 {
                        Label("\(supportCount) support\(supportCount == 1 ? "" : "s")", systemImage: "person.crop.circle.badge.checkmark")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        rosterItem = item
                    } label: {
                        Label("Roster", systemImage: "person.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        attendanceItem = item
                    } label: {
                        Label("Attendance", systemImage: "checklist.checked")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(roster.isEmpty)
                }
            }
            .padding(compact ? 12 : 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
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
                    Label("Current Class Support", systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        openTodoTab()
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(activeItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryList(activeSupports, compact: compact)
            }
            .padding(compact ? 12 : 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else if let nextItem, !nextSupports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Next Class Support", systemImage: "person.2.wave.2.fill")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()
                }

                Text(nextItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryList(nextSupports, compact: compact)
            }
            .padding(compact ? 12 : 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else if let support = relevantTasks.compactMap({ task in
            studentSupportsByName[task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)]
        }).first {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Student Support", systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        openTodoTab()
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(support.name)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                if !support.accommodations.isEmpty {
                    Text(support.accommodations)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 3 : 4)
                }

                if !support.prompts.isEmpty {
                    Text(support.prompts)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 2 : 3)
                }
            }
            .padding(compact ? 12 : 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func rosterStudents(for item: AlarmItem) -> [StudentSupportProfile] {
        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return studentSupportProfiles
            .filter { profile in
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                if gradeKey.isEmpty || profileGradeKey.isEmpty {
                    return true
                }
                return profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @ViewBuilder
    private func supportSummaryList(_ supports: [StudentSupportProfile], compact: Bool) -> some View {
        ForEach(Array(supports.prefix(compact ? 2 : 3))) { support in
            VStack(alignment: .leading, spacing: 2) {
                Text(support.name)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                let detail = [support.gradeLevel, support.accommodations, support.prompts]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                if !detail.isEmpty {
                    Text(detail)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 3 : 4)
                }
            }
        }
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
            statusTitle = "Holiday Mode Active"
            statusDetail = "Notifications are paused until \(ignoreDate.formatted(date: .abbreviated, time: .shortened))."
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
        }
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
            if let nextItem {
                Button {
                    editingAlarm = nextItem
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    if let first = todayCommitments.first {
                        editingCommitment = first
                    } else {
                        showingAddCommitment = true
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
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
    }

    private func floatingActionMenu(activeItem: AlarmItem?, now: Date) -> some View {
        Menu {
            Button("Schedule", systemImage: "calendar") {
                openScheduleTab()
            }

            Button("Tasks", systemImage: "checklist") {
                openTodoTab()
            }

            Button("Notes", systemImage: "note.text") {
                openNotesTab()
            }

            Button("Students", systemImage: "person.3") {
                showingStudentDirectory = true
            }

            Button("Settings", systemImage: "gearshape") {
                openSettingsTab()
            }

            Divider()

            Button("Quick Add", systemImage: "square.and.pencil") {
                showingQuickCapture = true
            }

            if let activeItem {
                Divider()

                Button(isHeld(activeItem) ? "Resume Class" : "Hold Class", systemImage: isHeld(activeItem) ? "play.fill" : "pause.fill") {
                    toggleHold(for: activeItem, now: now)
                }

                Button("Extend 1 Minute", systemImage: "plus") {
                    extend(activeItem, byMinutes: 1)
                }

                Button("Extend 2 Minutes", systemImage: "plus") {
                    extend(activeItem, byMinutes: 2)
                }

                Button("Extend 5 Minutes", systemImage: "plus") {
                    extend(activeItem, byMinutes: 5)
                }

                Button(
                    skippedBellItemIDs.contains(activeItem.id) ? "Bell Already Skipped" : "Skip Bell",
                    systemImage: skippedBellItemIDs.contains(activeItem.id) ? "bell.slash.fill" : "bell.slash"
                ) {
                    if !skippedBellItemIDs.contains(activeItem.id) {
                        skipBell(for: activeItem)
                    }
                }
                .disabled(skippedBellItemIDs.contains(activeItem.id))
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
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.28), radius: 12, y: 6)
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
                    Button("Schedule") {
                        openScheduleTab()
                    }
                    .font(.caption.weight(.semibold))
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
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func upcomingChip(for item: AlarmItem, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(item.accentColor == .clear ? Color.gray.opacity(0.2) : item.accentColor)
                    .frame(width: 8, height: 8)

                Text(item.className)
                    .font((compact ? Font.caption : .subheadline).weight(.bold))
                    .lineLimit(1)
            }

            Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: compact ? 140 : 168, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
    }

    private func topTasksCard(now: Date, compact: Bool = false) -> some View {
        let tasks = topTasks(for: now)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Top Tasks", systemImage: "checklist")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(tasks.isEmpty ? "Add" : "Open") {
                    openTodoTab()
                }
                .font(.caption.weight(.semibold))
            }

            if tasks.isEmpty {
                Text("No active school tasks. Add a few to make Today your command center.")
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
        }
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func notesSnapshotCard(compact: Bool) -> some View {
        let snapshot = notesSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Notes Snapshot", systemImage: "note.text")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(snapshot == nil ? "Add" : "Open") {
                    openNotesTab()
                }
                .font(.caption.weight(.semibold))
            }

            if let snapshot {
                Text(snapshot)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 3 : 4)
            } else {
                Text("No school notes yet. Keep a running note here for duties, reminders, and meeting details.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func schoolBoundaryCard(
        now: Date,
        schedule: [AlarmItem],
        compact: Bool = false
    ) -> some View {
        let afterHours = isAfterSchoolQuietStart(now)
        let quietStart = schoolQuietStart(on: now)
        let unfinishedTasks = todos.filter { !$0.isCompleted }.count
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }.count

        let title: String
        let message: String
        let tint: Color

        if schoolQuietHoursEnabled && afterHours {
            title = "After Hours Boundary"
            message = "School alerts are quiet after \(quietStart.formatted(date: .omitted, time: .shortened)). \(unfinishedTasks) task\(unfinishedTasks == 1 ? "" : "s") can wait until tomorrow unless you choose otherwise."
            tint = .indigo
        } else if schoolQuietHoursEnabled {
            title = "School Boundary Set"
            message = "Routine school alerts quiet at \(quietStart.formatted(date: .omitted, time: .shortened)). \(remainingBlocks) block\(remainingBlocks == 1 ? "" : "s") remain in today's school flow."
            tint = .teal
        } else {
            title = "Protect Personal Time"
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
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private func endOfDayCard(now: Date, schedule: [AlarmItem], compact: Bool = false) -> some View {
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }
        let unfinishedTasks = todos.filter { !$0.isCompleted }.count
        let dismissal = remainingBlocks.last.map { endDateToday(for: $0, now: now) }
        let carryoverTasks = todos.filter { !$0.isCompleted && $0.bucket == .today }

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

                        Button("Roll Today's Tasks to Tomorrow") {
                            rollTodayTasksToTomorrow()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
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
        }
        .padding(compact ? 12 : 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

                Text("ClassCue is running today from the override schedule.")
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

    private func commitmentsForToday(now: Date) -> [CommitmentItem] {
        let weekday = Calendar.current.component(.weekday, from: now)

        return commitments
            .filter { $0.dayOfWeek == weekday }
            .sorted { lhs, rhs in
                let lhsStart = anchoredDate(for: lhs.startTime, now: now)
                let rhsStart = anchoredDate(for: rhs.startTime, now: now)
                return lhsStart < rhsStart
            }
    }

    private func topTasks(for now: Date) -> [TodoItem] {
        todos
            .filter { !$0.isCompleted }
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
        var parts = [task.category.displayName, task.bucket.displayName]

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
        case .prep:
            return .admin
        case .recess, .lunch, .transition:
            return .classroom
        case .other, .blank:
            return .other
        }
    }

    private func rollTodayTasksToTomorrow() {
        for index in todos.indices {
            if !todos[index].isCompleted && todos[index].bucket == .today {
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

        switch secondsRemaining {
        case 300:
            return InAppWarning(item: item, minutesRemaining: 5)
        case 120:
            return InAppWarning(item: item, minutesRemaining: 2)
        case 60:
            return InAppWarning(item: item, minutesRemaining: 1)
        default:
            return nil
        }
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
        case .prep:
            return .cyan
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
        extraTimeByItemID[item.id, default: 0] += TimeInterval(minutes * 60)
        skippedBellItemIDs.remove(item.id)
    }

    private func toggleHold(for item: AlarmItem, now: Date) {
        if heldItemID == item.id {
            let additionalHold = liveHoldDuration(for: item, now: now)
            extraTimeByItemID[item.id, default: 0] += additionalHold
            heldItemID = nil
            holdStartedAt = nil
        } else {
            heldItemID = item.id
            holdStartedAt = now
        }
    }

    private func skipBell(for item: AlarmItem) {
        skippedBellItemIDs.insert(item.id)
        BellCountdownEngine.shared.reset()
    }

    private func isHeld(_ item: AlarmItem) -> Bool {
        heldItemID == item.id
    }

    private func liveHoldDuration(for item: AlarmItem, now: Date) -> TimeInterval {
        guard heldItemID == item.id, let holdStartedAt else { return 0 }
        return max(now.timeIntervalSince(holdStartedAt), 0)
    }

    private func handleActiveItemChange(_ newValue: UUID?) {
        if lastActiveItemID != newValue {
            BellCountdownEngine.shared.reset()
            lastActiveItemID = newValue
        }

        if let heldItemID, heldItemID != newValue {
            self.heldItemID = nil
            holdStartedAt = nil
        }
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
        guard let activeItem else { return nil }

        let nextItem = adjustedTodaySchedule(for: now).first {
            startDateToday(for: $0, now: now) > now
        }

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
        guard let snapshot else {
            LiveActivityManager.stop()
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

    private func widgetSnapshot(activeItem: AlarmItem?, nextItem: AlarmItem?, now: Date) -> ClassCueWidgetSnapshot {
        func summary(for item: AlarmItem) -> ClassCueWidgetSnapshot.BlockSummary {
            ClassCueWidgetSnapshot.BlockSummary(
                className: item.className,
                room: item.location.trimmingCharacters(in: .whitespacesAndNewlines),
                gradeLevel: item.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                symbolName: item.scheduleType.symbolName,
                startTime: startDateToday(for: item, now: now),
                endTime: endDateToday(for: item, now: now),
                typeName: item.typeLabel
            )
        }

        return ClassCueWidgetSnapshot(
            updatedAt: now,
            current: activeItem.map(summary),
            next: nextItem.map(summary)
        )
    }

    private func syncWidgetSnapshot(_ snapshot: ClassCueWidgetSnapshot) {
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassCueHomeWidget")
    }

    private func landscapeHeader(now: Date) -> some View {

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(2.4)
                    .foregroundStyle(.orange)

                Text(now.formatted(.dateTime.month().day()))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }

            Spacer()

            Text(now.formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
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
    let students: [StudentSupportProfile]

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
            }

            Section("Roster") {
                if students.isEmpty {
                    Text("No students linked to this class and grade yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(students) { student in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(student.name)
                                .fontWeight(.semibold)

                            let info = [student.gradeLevel, student.className]
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                                .joined(separator: " • ")

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
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Class Roster")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TodayClassAttendanceView: View {
    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]
    @Binding var records: [AttendanceRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var showingShareSheet = false

    private var dateKey: String {
        AttendanceRecord.dateKey(for: date)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.className)
                        .font(.headline.weight(.bold))
                    Text("\(date.formatted(date: .abbreviated, time: .omitted)) • \(item.gradeLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Attendance") {
                if students.isEmpty {
                    Text("No linked students were found for this class and grade.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(students) { student in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(student.name)
                                    .fontWeight(.semibold)
                                if !student.accommodations.isEmpty {
                                    Text(student.accommodations)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Picker(
                                "Status",
                                selection: Binding(
                                    get: { status(for: student) },
                                    set: { setStatus($0, for: student) }
                                )
                            ) {
                                ForEach(AttendanceRecord.Status.allCases) { status in
                                    Text(status.rawValue).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Export") {
                    exportAttendance()
                }
                .disabled(students.isEmpty)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func status(for student: StudentSupportProfile) -> AttendanceRecord.Status {
        records.first(where: {
            $0.dateKey == dateKey &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: $0.className) &&
            normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel)) &&
            normalizedStudentKey($0.studentName) == normalizedStudentKey(student.name)
        })?.status ?? .present
    }

    private func setStatus(_ status: AttendanceRecord.Status, for student: StudentSupportProfile) {
        let normalizedGrade = GradeLevelOption.normalized(item.gradeLevel)
        if let index = records.firstIndex(where: {
            $0.dateKey == dateKey &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: $0.className) &&
            normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(normalizedGrade) &&
            normalizedStudentKey($0.studentName) == normalizedStudentKey(student.name)
        }) {
            records[index].status = status
        } else {
            records.append(
                AttendanceRecord(
                    dateKey: dateKey,
                    className: item.className,
                    gradeLevel: normalizedGrade,
                    studentName: student.name,
                    status: status
                )
            )
        }
    }

    private func exportAttendance() {
        let header = "date,className,gradeLevel,studentName,status"
        let rows = students.map { student in
            [
                dateKey,
                item.className,
                GradeLevelOption.normalized(item.gradeLevel),
                student.name,
                status(for: student).rawValue
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }
        let csv = ([header] + rows).joined(separator: "\n")
        let filename = "classcue-attendance-\(dateKey)-\(item.className.replacingOccurrences(of: " ", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
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
