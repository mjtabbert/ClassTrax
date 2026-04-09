//
//  ScheduleView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//  Build: ClassTrax Dev Build 26
//

import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var selectedDay: WeekdayTab
    @Binding var alarms: [AlarmItem]
    @Binding var todos: [TodoItem]
    @Binding var subPlans: [SubPlanItem]
    @Binding var dailySubPlans: [DailySubPlanItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    @Binding var commitments: [CommitmentItem]
    var activeOverrideName: String? = nil
    var overrideSchedule: [AlarmItem]? = nil
    let onRefresh: @MainActor () -> Void
    let openTodayTab: () -> Void
    let openTodoTab: () -> Void
    let openNotesTab: () -> Void

    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()
    @AppStorage("teacher_workflow_mode_v1") private var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue

    @State private var showingAddSheet = false
    @State private var editingItem: AlarmItem?
    @State private var profiles: [ScheduleProfile] = []
    @State private var showingCopyWholeDaySheet = false
    @State private var showingEraseDayDialog = false
    @State private var showingSaveDayProfileAlert = false
    @State private var showingSaveWeekProfileAlert = false
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false
    @State private var showingOverridesSheet = false
    @State private var showingStudentDirectory = false
    @State private var pendingDeleteItem: AlarmItem?
    @State private var profileName = ""
    @State private var overrides: [DayOverride] = []
    @State private var showPastBlocks = false

    private var filteredSchedule: [AlarmItem] {
        if isViewingActiveOverride, let overrideSchedule {
            return overrideSchedule.sorted { $0.startTime < $1.startTime }
        }

        let dayItems = alarms.filter { $0.dayOfWeek == selectedDay.rawValue }
        return dayItems.sorted { $0.startTime < $1.startTime }
    }

    private var isViewingActiveOverride: Bool {
        selectedDay == .today && activeOverrideName != nil
    }

    private var hasAnySchedule: Bool {
        !alarms.isEmpty
    }

    private var availableCopyDays: [WeekdayTab] {
        WeekdayTab.allCases.filter { day in
            day != selectedDay && alarms.contains(where: { $0.dayOfWeek == day.rawValue })
        }
    }

    private var isSelectedDayToday: Bool {
        selectedDay.rawValue == Calendar.current.component(.weekday, from: Date())
    }

    private var teacherWorkflowMode: TeacherWorkflowMode {
        TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom
    }

    var body: some View {

        NavigationStack {

            TimelineView(.periodic(from: .now, by: 30)) { context in
                scheduleScrollContent(now: context.date)
                .refreshable {
                    onRefresh()
                }
                .background(scheduleBackground)
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        ToolbarMenuLabel(
                            title: "Add",
                            systemImage: "plus",
                            expanded: prefersExpandedToolbar
                        )
                    }
                    .disabled(isViewingActiveOverride)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Block", systemImage: "plus") {
                            showingAddSheet = true
                        }
                        .disabled(isViewingActiveOverride)

                        Divider()

                        Button("Copy Whole Day", systemImage: "doc.on.doc") {
                            showingCopyWholeDaySheet = true
                        }
                        .disabled(filteredSchedule.isEmpty || isViewingActiveOverride)

                        Button("Save Day as Profile", systemImage: "square.and.arrow.down") {
                            profileName = defaultDayProfileName
                            showingSaveDayProfileAlert = true
                        }
                        .disabled(filteredSchedule.isEmpty)

                        Button("Save Week as Profile", systemImage: "tray.and.arrow.down") {
                            profileName = defaultWeekProfileName
                            showingSaveWeekProfileAlert = true
                        }
                        .disabled(alarms.isEmpty)

                        Divider()

                        Button("Day Overrides", systemImage: "calendar.badge.clock") {
                            showingOverridesSheet = true
                        }

                        Button("Export Schedule CSV", systemImage: "square.and.arrow.up") {
                            showingExportSheet = true
                        }
                        .disabled(alarms.isEmpty)

                        Button("Import Schedule CSV", systemImage: "square.and.arrow.down") {
                            showingImportSheet = true
                        }

                        Divider()

                        Button("Students", systemImage: "person.3") {
                            showingStudentDirectory = true
                        }

                        Button("Refresh", systemImage: "arrow.clockwise") {
                            onRefresh()
                        }

                        Button("Prep & Handoff", systemImage: "doc.text") {
                            selectedDay = .today
                            openTodayTab()
                        }

                        Divider()

                        Button("Erase Day", systemImage: "trash", role: .destructive) {
                            showingEraseDayDialog = true
                        }
                        .disabled(filteredSchedule.isEmpty || isViewingActiveOverride)
                    } label: {
                        ToolbarMenuLabel(
                            title: "More",
                            systemImage: "ellipsis",
                            expanded: prefersExpandedToolbar
                        )
                    }
                }
            }
            .onAppear {
                loadProfiles()
                loadOverrides()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditView(
                    alarms: $alarms,
                    studentProfiles: studentProfiles,
                    classDefinitions: classDefinitions,
                    day: selectedDay.rawValue
                )
            }
            .sheet(item: $editingItem) { item in
                AddEditView(
                    alarms: $alarms,
                    studentProfiles: studentProfiles,
                    classDefinitions: classDefinitions,
                    day: item.dayOfWeek,
                    existing: item
                )
            }
            .sheet(isPresented: $showingImportSheet) {
                NavigationStack {
                    ImportView(alarms: $alarms)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                NavigationStack {
                    ExportView(alarms: $alarms)
                }
            }
            .sheet(isPresented: $showingOverridesSheet) {
                DayOverridesView(
                    overrides: $overrides,
                    profiles: $profiles
                )
            }
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(
                        profiles: $studentProfiles,
                        classDefinitions: $classDefinitions,
                        teacherContacts: $teacherContacts,
                        paraContacts: $paraContacts
                    )
                }
            }
            .sheet(isPresented: $showingCopyWholeDaySheet) {
                NavigationStack {
                    CopyWholeDaySheet(
                        sourceDay: selectedDay,
                        availableDays: WeekdayTab.allCases.filter { $0 != selectedDay },
                        onCopy: { destinations in
                            copySchedule(from: selectedDay, to: destinations)
                        }
                    )
                }
            }
            .alert("Delete Block?", isPresented: isShowingDeleteBlockAlert) {
                Button("Delete", role: .destructive) {
                    if let pendingDeleteItem {
                        deleteBlock(pendingDeleteItem)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteItem = nil
                }
            } message: {
                Text("This block will be removed from the schedule.")
            }
            .onChange(of: overrides) { _, newValue in
                saveOverrides(newValue)
            }
            .confirmationDialog(
                "Erase \(selectedDay.title)?",
                isPresented: $showingEraseDayDialog,
                titleVisibility: .visible
            ) {
                Button("Erase Day", role: .destructive) {
                    eraseSelectedDay()
                }
            } message: {
                Text("This removes all blocks for \(selectedDay.title).")
            }
            .alert("Save Day as Profile", isPresented: $showingSaveDayProfileAlert) {
                TextField("Profile Name", text: $profileName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    saveProfile(named: profileName, alarms: filteredSchedule)
                }
            } message: {
                Text("Save \(selectedDay.title) as a reusable profile.")
            }
            .alert("Save Week as Profile", isPresented: $showingSaveWeekProfileAlert) {
                TextField("Profile Name", text: $profileName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    saveProfile(named: profileName, alarms: alarms)
                }
            } message: {
                Text("Save the full week as a reusable profile.")
            }
        }
    }

    private func scheduleScrollContent(now: Date) -> some View {
        ScrollView {
            HStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 16) {
                    dayPicker
                    planningOverviewCard(now: now)

                    if let activeOverrideName, isViewingActiveOverride {
                        overrideBanner(name: activeOverrideName)
                    }

                    if filteredSchedule.isEmpty {
                        emptyState
                    } else if isSelectedDayToday {
                        todayScheduleLayout(now: now)
                    } else {
                        standardScheduleLayout
                    }
                }
                .frame(maxWidth: 1100, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    private var dayPicker: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {

                ForEach(WeekdayTab.allCases, id: \.self) { day in

                    Button {
                        selectedDay = day
                    } label: {
                        Text(day.shortTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedDay == day ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedDay == day ? Color.blue : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var prefersExpandedToolbar: Bool {
        horizontalSizeClass != .compact
    }

    private var scheduleBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                selectedDay == .today ? Color.blue.opacity(0.05) : Color.pink.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var emptyState: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(hasAnySchedule ? "No blocks for \(selectedDay.title)." : "No schedule yet.")
                .font(.headline)

            Text(
                isViewingActiveOverride
                ? "The active override is replacing your normal \(selectedDay.title) schedule."
                : hasAnySchedule
                ? "Choose another day or tap + to add a block for \(selectedDay.title)."
                : "Tap + to add your first block for \(selectedDay.title)."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            VStack(spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label(hasAnySchedule ? "Add Block for \(selectedDay.title)" : "Add First Block", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isViewingActiveOverride)

                HStack(spacing: 10) {
                    Button {
                        openTodoTab()
                    } label: {
                        Label("Planner", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openNotesTab()
                    } label: {
                        Label("Notes", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.08),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var standardScheduleLayout: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredSchedule) { item in
                scheduleRow(for: item)
            }
        }
    }

    private func planningOverviewCard(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDay == .today ? "Planning for Today" : "Planning for \(selectedDay.title)")
                        .font(.headline.weight(.bold))

                    Text(planningSummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(isViewingActiveOverride ? "Override" : "Base Plan")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(isViewingActiveOverride ? .blue : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill((isViewingActiveOverride ? Color.blue : Color.secondary).opacity(0.12))
                    )
            }

            HStack(spacing: 10) {
                planningStatPill(title: "Blocks", value: "\(filteredSchedule.count)", accent: .blue)
                planningStatPill(title: "Tasks", value: "\(linkedTaskCount)", accent: .orange)
                planningStatPill(title: "Plans", value: "\(selectedDayPlanCount)", accent: .indigo)
                planningStatPill(title: "Meetings", value: "\(selectedDayCommitmentCount)", accent: .green)
            }

            VStack(spacing: 10) {
                Button {
                    openTodayTab()
                } label: {
                    Label("Prep & Handoff", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 10) {
                    Button {
                        openTodoTab()
                    } label: {
                        Label("Planner", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openNotesTab()
                    } label: {
                        Label("Notes", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.12),
                            Color.indigo.opacity(0.06),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    private func todayScheduleLayout(now: Date) -> some View {
        let pastItems = filteredSchedule.filter { isPast($0, now: now) }
        let currentAndUpcoming = filteredSchedule.filter { !isPast($0, now: now) }

        return VStack(alignment: .leading, spacing: 14) {
            if !currentAndUpcoming.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schedule for Today")
                        .font(.headline)

                    Text("Current and upcoming blocks stay at the top.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            if currentAndUpcoming.isEmpty {
                Text("No more blocks remain today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(currentAndUpcoming) { item in
                        scheduleRow(for: item)
                    }
                }
                .padding(.bottom, pastItems.isEmpty ? 0 : 6)
            }

            if !pastItems.isEmpty {
                DisclosureGroup(isExpanded: $showPastBlocks) {
                    VStack(spacing: 12) {
                        ForEach(pastItems) { item in
                            scheduleRow(for: item)
                                .opacity(0.84)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    HStack {
                        Text("Earlier Today")
                            .font(.headline)

                        Spacer()

                        Text("\(pastItems.count)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.indigo.opacity(0.06),
                                    Color(.tertiarySystemBackground)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
        }
    }

    private func overrideBanner(name: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Override Active for Today")
                    .font(.subheadline.weight(.bold))

                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Edits are locked here because today's schedule is coming from an override.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Manage") {
                showingOverridesSheet = true
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
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
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }

    private func planningStatPill(title: String, value: String, accent: Color) -> some View {
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

    @ViewBuilder
    private func scheduleRow(for item: AlarmItem) -> some View {
        if isViewingActiveOverride {
            TimelineRow(
                item: item,
                classDefinitions: classDefinitions,
                workflowMode: teacherWorkflowMode,
                now: Date(),
                isHero: false
            )
        } else {
            Button {
                editingItem = item
            } label: {
                TimelineRow(
                    item: item,
                    classDefinitions: classDefinitions,
                    workflowMode: teacherWorkflowMode,
                    now: Date(),
                    isHero: false
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                    pendingDeleteItem = item
                }
            }
        }
    }

    private func deleteBlock(_ item: AlarmItem) {
        alarms.removeAll { $0.id == item.id }
        pendingDeleteItem = nil
    }

    private var isShowingDeleteBlockAlert: Binding<Bool> {
        Binding(
            get: { pendingDeleteItem != nil },
            set: { if !$0 { pendingDeleteItem = nil } }
        )
    }

    private func isPast(_ item: AlarmItem, now: Date) -> Bool {
        anchoredDate(for: item.endTime, now: now) < now
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

    private var defaultDayProfileName: String {
        "\(selectedDay.title) Schedule"
    }

    private var selectedDayContexts: Set<String> {
        Set(
            filteredSchedule
                .map(\.className)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private var linkedTaskCount: Int {
        todos.filter { todo in
            let context = todo.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
            return !todo.isCompleted && !context.isEmpty && selectedDayContexts.contains(context)
        }.count
    }

    private var selectedDayPlanCount: Int {
        if selectedDay == .today {
            let dateKey = AttendanceRecord.dateKey(for: Date())
            let hasDailyPlan = dailySubPlans.contains { $0.dateKey == dateKey }
            let classPlans = subPlans.filter { $0.dateKey == dateKey }.count
            return classPlans + (hasDailyPlan ? 1 : 0)
        }

        return filteredSchedule.isEmpty ? 0 : subPlans.filter { plan in
            selectedDayContexts.contains(plan.className.trimmingCharacters(in: .whitespacesAndNewlines))
        }.count
    }

    private var selectedDayCommitmentCount: Int {
        commitments.filter { $0.dayOfWeek == selectedDay.rawValue }.count
    }

    private var planningSummaryText: String {
        if filteredSchedule.isEmpty {
            return "No schedule blocks yet. Add your first block, then keep planning and notes tied to the same day."
        }

        let classCount = selectedDayContexts.count
        return "\(classCount) class\(classCount == 1 ? "" : "es") / group\(classCount == 1 ? "" : "s"), \(linkedTaskCount) planner item\(linkedTaskCount == 1 ? "" : "s"), \(selectedDayPlanCount) prep item\(selectedDayPlanCount == 1 ? "" : "s"), and \(selectedDayCommitmentCount) scheduled commitment\(selectedDayCommitmentCount == 1 ? "" : "s")."
    }

    private var defaultWeekProfileName: String {
        "Weekly Schedule"
    }

    private func copySchedule(from sourceDay: WeekdayTab, to targetDays: [WeekdayTab]) {
        for targetDay in targetDays {
            copySchedule(from: sourceDay, to: targetDay)
        }
    }

    private func copySchedule(from sourceDay: WeekdayTab, to targetDay: WeekdayTab) {
        let sourceItems = alarms
            .filter { $0.dayOfWeek == sourceDay.rawValue }
            .sorted { $0.startTime < $1.startTime }

        let copiedItems = sourceItems.map { item in
            AlarmItem(
                id: UUID(),
                dayOfWeek: targetDay.rawValue,
                className: item.className,
                location: item.location,
                gradeLevel: item.gradeLevel,
                startTime: item.startTime,
                endTime: item.endTime,
                type: item.type,
                classDefinitionID: item.classDefinitionID,
                linkedStudentIDs: item.linkedStudentIDs
            )
        }

        alarms.removeAll { $0.dayOfWeek == targetDay.rawValue }
        alarms.append(contentsOf: copiedItems)
        sortAlarms()
    }

    private func eraseSelectedDay() {
        alarms.removeAll { $0.dayOfWeek == selectedDay.rawValue }
    }

    private func saveProfile(named name: String, alarms profileAlarms: [AlarmItem]) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let existingIndex = profiles.firstIndex(where: { $0.name == trimmedName }) {
            profiles[existingIndex].alarms = profileAlarms
        } else {
            profiles.append(
                ScheduleProfile(
                    name: trimmedName,
                    alarms: profileAlarms
                )
            )
        }

        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveProfiles()
        profileName = ""
    }

    private func loadProfiles() {
        profiles = ClassTraxPersistence.loadThirdSlice(from: modelContext).profiles
    }

    private func loadOverrides() {
        overrides = ClassTraxPersistence.loadThirdSlice(from: modelContext).overrides
    }

    private func saveProfiles() {
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

    private func sortAlarms() {
        alarms.sort { lhs, rhs in
            if lhs.dayOfWeek == rhs.dayOfWeek {
                return lhs.startTime < rhs.startTime
            }
            return lhs.dayOfWeek < rhs.dayOfWeek
        }
    }
}

private struct CopyWholeDaySheet: View {
    let sourceDay: WeekdayTab
    let availableDays: [WeekdayTab]
    let onCopy: ([WeekdayTab]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDays: Set<WeekdayTab> = []

    var body: some View {
        Form {
            Section("Copy \(sourceDay.title) To") {
                ForEach(availableDays, id: \.self) { day in
                    Toggle(day.title, isOn: binding(for: day))
                }
            }

            Section {
                Text("This replaces each destination day with \(sourceDay.title)’s full schedule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Copy Whole Day")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Copy") {
                    onCopy(selectedDays.sorted { $0.rawValue < $1.rawValue })
                    dismiss()
                }
                .disabled(selectedDays.isEmpty)
                .fontWeight(.semibold)
            }
        }
    }

    private func binding(for day: WeekdayTab) -> Binding<Bool> {
        Binding(
            get: { selectedDays.contains(day) },
            set: { isSelected in
                if isSelected {
                    selectedDays.insert(day)
                } else {
                    selectedDays.remove(day)
                }
            }
        )
    }
}
