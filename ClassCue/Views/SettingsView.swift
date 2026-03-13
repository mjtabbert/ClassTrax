//
//  SettingsView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI
import ActivityKit

struct SettingsView: View {
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = HapticPattern.doubleThump.rawValue
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = SoundPattern.classicAlarm.rawValue
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()
    @AppStorage("day_overrides_v1_data") private var savedOverrides: Data = Data()
    @AppStorage("student_support_profiles_v1_data") private var savedStudentProfiles: Data = Data()
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0

    @State private var holidayModeEnabled = false
    @State private var holidayResumeDate = Date().addingTimeInterval(60 * 60 * 24)
    @State private var schoolQuietStart = Calendar.current.date(
        bySettingHour: 16,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()

    @State private var alarms: [AlarmItem] = []
    @State private var profiles: [ScheduleProfile] = []
    @State private var overrides: [DayOverride] = []
    @State private var studentProfiles: [StudentSupportProfile] = []

    var body: some View {
        NavigationStack {
            Form {
                alertsSection
                liveActivityStatusSection
                holidaySection
                schoolBoundariesSection
                studentContextSection
                scheduleToolsSection
                appToolsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                loadData()
                configureHolidayMode()
            }
            .onChange(of: alarms) { _, newValue in
                saveAlarms(newValue)
            }
            .onChange(of: profiles) { _, newValue in
                saveProfiles(newValue)
            }
            .onChange(of: overrides) { _, newValue in
                saveOverrides(newValue)
            }
            .onChange(of: studentProfiles) { _, newValue in
                savedStudentProfiles = (try? JSONEncoder().encode(newValue.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })) ?? Data()
            }
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
        }
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

            if let selectedHaptic = HapticPattern(rawValue: selectedHapticRawValue) {
                LabeledContent("Haptic Source", value: selectedHaptic.sourceGroup.rawValue)
                    .font(.footnote)
            }

            if let selectedSound = SoundPattern(rawValue: selectedSoundRawValue) {
                LabeledContent("Sound Source", value: selectedSound.sourceGroup.rawValue)
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
        Section("Holiday Mode") {
            Toggle("Pause Schedule", isOn: $holidayModeEnabled)

            if holidayModeEnabled {
                DatePicker(
                    "Resume On",
                    selection: $holidayResumeDate,
                    displayedComponents: [.date, .hourAndMinute]
                )

                Button("Save Holiday Mode") {
                    ignoreUntil = holidayResumeDate.timeIntervalSince1970
                }

                Button("Turn Off Holiday Mode", role: .destructive) {
                    ignoreUntil = 0
                    holidayModeEnabled = false
                }
            } else {
                holidayStatusText
            }
        }
    }

    private var liveActivityStatusSection: some View {
        Section("Live Activity Status") {
            LabeledContent("iPhone Allows Live Activities") {
                Text(liveActivitiesEnabled ? "On" : "Off")
                    .foregroundColor(liveActivitiesEnabled ? .green : .red)
            }

            LabeledContent("ClassCue Activity Running") {
                Text(activeLiveActivityCount > 0 ? "Yes" : "No")
                    .foregroundColor(activeLiveActivityCount > 0 ? .green : .secondary)
            }

            if activeLiveActivityCount > 0 {
                Text("ClassCue currently has \(activeLiveActivityCount) active Live Activit\(activeLiveActivityCount == 1 ? "y" : "ies").")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("If this says \"No\" during an active class, the app is not successfully starting the lock screen activity yet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var holidayStatusText: some View {
        if ignoreUntil > Date().timeIntervalSince1970 {
            Text("Schedule paused until \(Date(timeIntervalSince1970: ignoreUntil).formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else {
            Text("Schedule is active.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var schoolBoundariesSection: some View {
        Section("School Boundaries") {
            Toggle("Quiet School Alerts After Hours", isOn: $schoolQuietHoursEnabled)

            if schoolQuietHoursEnabled {
                DatePicker(
                    "Quiet Starting At",
                    selection: $schoolQuietStart,
                    displayedComponents: .hourAndMinute
                )

                Text("This applies every day. ClassCue quiets routine school alerts after this time and resumes them again the next day before your first scheduled alert.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Use after-hours quieting to keep school notifications from following you into personal time.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var scheduleToolsSection: some View {
        Section("Schedule Tools") {
            NavigationLink("Schedule Profiles") {
                ProfilesView(alarms: $alarms, profiles: $profiles)
            }

            NavigationLink("Day Overrides") {
                DayOverridesView(overrides: $overrides, profiles: $profiles)
            }
        }
    }

    private var studentContextSection: some View {
        Section("Class / Student Context") {
            NavigationLink {
                StudentDirectoryView(profiles: $studentProfiles)
            } label: {
                LabeledContent("Student Directory") {
                    Text(studentProfiles.isEmpty ? "Not Set" : "\(studentProfiles.count)")
                        .foregroundColor(studentProfiles.isEmpty ? .secondary : .primary)
                }
            }

            if studentProfiles.isEmpty {
                Text("Open Student Directory to add names, accommodations, and prompts once, then reuse them in tasks and quick capture.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Saved student supports now power the student picker and accommodation previews in the task and capture workflows.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var appToolsSection: some View {
        Section("App Tools") {
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
            NavigationLink("About Class Cue") {
                AboutView()
            }
        }
    }

    private func testBell() {
        let haptic = HapticPattern(rawValue: selectedHapticRawValue) ?? .doubleThump
        let sound = BellSound.fromStoredPreference(selectedSoundRawValue)
        BellFeedbackManager.shared.play(haptic: haptic, bellSound: sound)
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
        if let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) {
            alarms = decodedAlarms
        } else {
            alarms = []
        }

        if let decodedProfiles = try? JSONDecoder().decode([ScheduleProfile].self, from: savedProfiles) {
            profiles = decodedProfiles
        } else {
            profiles = []
        }

        if let decodedProfiles = try? JSONDecoder().decode([StudentSupportProfile].self, from: savedStudentProfiles) {
            studentProfiles = decodedProfiles.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } else {
            studentProfiles = []
        }

        if let decodedOverrides = try? JSONDecoder().decode([DayOverride].self, from: savedOverrides) {
            overrides = decodedOverrides
        } else {
            overrides = []
        }
    }

    private func saveAlarms(_ alarms: [AlarmItem]) {
        if let encoded = try? JSONEncoder().encode(alarms) {
            savedAlarms = encoded
        }
    }

    private func saveProfiles(_ profiles: [ScheduleProfile]) {
        if let encoded = try? JSONEncoder().encode(profiles) {
            savedProfiles = encoded
        }
    }

    private func saveOverrides(_ overrides: [DayOverride]) {
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
            activeOverrideDate: activeOverride?.date
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
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var activeLiveActivityCount: Int {
        Activity<ClassCueActivityAttributes>.activities.count
    }
}
