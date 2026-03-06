//
//  SettingsView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = HapticPattern.doubleThump.rawValue
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = SoundPattern.classicAlarm.rawValue
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("profiles_v1_data") private var savedProfiles: Data = Data()

    @State private var holidayModeEnabled = false
    @State private var holidayResumeDate = Date().addingTimeInterval(60 * 60 * 24)

    @State private var alarms: [AlarmItem] = []
    @State private var profiles: [ScheduleProfile] = []

    var body: some View {
        NavigationStack {
            Form {
                alertsSection
                holidaySection
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
        }
    }

    private var alertsSection: some View {
        Section("Alerts") {
            Picker("Haptic Pattern", selection: $selectedHapticRawValue) {
                ForEach(HapticPattern.allCases, id: \.rawValue) { pattern in
                    Text(pattern.rawValue).tag(pattern.rawValue)
                }
            }

            Picker("Sound Pattern", selection: $selectedSoundRawValue) {
                ForEach(SoundPattern.allCases, id: \.rawValue) { pattern in
                    Text(pattern.displayName).tag(pattern.rawValue)
                }
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

    private var scheduleToolsSection: some View {
        Section("Schedule Tools") {
            NavigationLink("Import Schedule from CSV") {
                ImportView(alarms: $alarms)
            }

            NavigationLink("Export Schedule to CSV") {
                ExportView(alarms: $alarms)
            }

            NavigationLink("Schedule Profiles") {
                ProfilesView(alarms: $alarms, profiles: $profiles)
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
}
