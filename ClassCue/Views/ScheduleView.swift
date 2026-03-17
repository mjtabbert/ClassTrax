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

    @Binding var selectedDay: WeekdayTab
    @Binding var alarms: [AlarmItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    var activeOverrideName: String? = nil
    var overrideSchedule: [AlarmItem]? = nil
    let onRefresh: @MainActor () -> Void
    let openTodayTab: () -> Void

    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()

    @State private var showingAddSheet = false
    @State private var editingItem: AlarmItem?
    @State private var profiles: [ScheduleProfile] = []
    @State private var showingCopyDayDialog = false
    @State private var showingEraseDayDialog = false
    @State private var showingSaveDayProfileAlert = false
    @State private var showingSaveWeekProfileAlert = false
    @State private var showingImportSheet = false
    @State private var showingExportSheet = false
    @State private var showingOverridesSheet = false
    @State private var showingStudentDirectory = false
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

    var body: some View {

        NavigationStack {

            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollView {

                    VStack(alignment: .leading, spacing: 16) {

                        dayPicker

                        if let activeOverrideName, isViewingActiveOverride {
                            overrideBanner(name: activeOverrideName)
                        }

                        if filteredSchedule.isEmpty {
                            emptyState
                        } else if isSelectedDayToday {
                            todayScheduleLayout(now: context.date)
                        } else {
                            standardScheduleLayout
                        }
                    }
                    .padding()
                }
                .refreshable {
                    onRefresh()
                }
                .background(scheduleBackground)
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button("Students", systemImage: "person.3") {
                                showingStudentDirectory = true
                            }

                            Button("Refresh", systemImage: "arrow.clockwise") {
                                onRefresh()
                            }

                            Button("Daily Sub Plan", systemImage: "doc.text") {
                                selectedDay = .today
                                openTodayTab()
                            }

                            Divider()

                            Button("Import CSV", systemImage: "square.and.arrow.down") {
                                showingImportSheet = true
                            }

                            Button("Export CSV", systemImage: "square.and.arrow.up") {
                                showingExportSheet = true
                            }
                            .disabled(alarms.isEmpty)

                            Button("Copy Day", systemImage: "doc.on.doc") {
                                showingCopyDayDialog = true
                            }
                            .disabled(availableCopyDays.isEmpty || isViewingActiveOverride)

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

                            Button("Erase Day", systemImage: "trash", role: .destructive) {
                                showingEraseDayDialog = true
                            }
                            .disabled(filteredSchedule.isEmpty || isViewingActiveOverride)

                            Button("Day Overrides", systemImage: "wand.and.stars") {
                                showingOverridesSheet = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }

                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("Add Block", systemImage: "plus")
                        }
                        .disabled(isViewingActiveOverride)
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
                    StudentDirectoryView(profiles: $studentProfiles, classDefinitions: $classDefinitions)
                }
            }
            .onChange(of: overrides) { _, newValue in
                saveOverrides(newValue)
            }
            .confirmationDialog(
                "Copy to \(selectedDay.title)",
                isPresented: $showingCopyDayDialog,
                titleVisibility: .visible
            ) {
                ForEach(availableCopyDays, id: \.self) { day in
                    Button(day.title) {
                        copySchedule(from: day, to: selectedDay)
                    }
                }
            } message: {
                Text("Replace \(selectedDay.title) with another day’s schedule.")
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
                : "Tap + to add your first class block for \(selectedDay.title)."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
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

                Image(systemName: "wand.and.stars")
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

    @ViewBuilder
    private func scheduleRow(for item: AlarmItem) -> some View {
        if isViewingActiveOverride {
            TimelineRow(
                item: item,
                now: Date(),
                isHero: false
            )
        } else {
            Button {
                editingItem = item
            } label: {
                TimelineRow(
                    item: item,
                    now: Date(),
                    isHero: false
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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

    private var defaultWeekProfileName: String {
        "Weekly Schedule"
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
