//
//  DayOverridesView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 5:05 PM
//  Version: ClassTrax Dev Build 18
//

import SwiftUI

struct DayOverridesView: View {
    
    @Binding var overrides: [DayOverride]
    @Binding var profiles: [ScheduleProfile]
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedProfileID: UUID?
    @State private var selectedKind: DayOverride.OverrideKind = .custom
    @State private var overrideToDelete: DayOverride?
    @State private var feedbackMessage = ""

    private var todayOverride: DayOverride? {
        overrides.first {
            Calendar.current.isDateInToday($0.date)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    overridesOverviewCard
                }

                if let todayOverride {
                    Section("Today's Override") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(todayOverride.kind.displayName)
                                .font(.headline)

                            Text(profileName(for: todayOverride.profileID))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button("Load Into Editor") {
                            loadOverride(todayOverride)
                        }
                        .tint(ClassTraxSemanticColor.primaryAction)

                        Button("Clear Today's Override", role: .destructive) {
                            overrides.removeAll { $0.id == todayOverride.id }
                        }
                    }
                }

                Section("Override Setup") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                    if !presetKinds.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetKinds, id: \.self) { kind in
                                    Button(kind.displayName) {
                                        selectedKind = kind
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(selectedKind == kind ? ClassTraxSemanticColor.primaryAction : .secondary.opacity(0.3))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Picker("Override Type", selection: $selectedKind) {
                        ForEach(DayOverride.OverrideKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }

                    Picker("Profile", selection: $selectedProfileID) {
                        Text("Select a Profile").tag(nil as UUID?)
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(profile.id as UUID?)
                        }
                    }

                    if let suggestedProfile {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Suggested Profile", systemImage: "calendar.badge.clock")
                                .font(.subheadline.weight(.semibold))

                            Text(suggestedProfileSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(selectedProfileID == suggestedProfile.id ? "Suggested Profile Selected" : "Use \(suggestedProfile.name)") {
                                selectedProfileID = suggestedProfile.id
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedProfileID == suggestedProfile.id)
                        }
                    }

                    Button("Save Override") {
                        saveOverride()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClassTraxSemanticColor.primaryAction)
                    .disabled(selectedProfileID == nil || profiles.isEmpty)
                }

                if !feedbackMessage.isEmpty {
                    Section {
                        Label(feedbackMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Section("Saved Overrides") {
                    if overrides.isEmpty {
                        Text("No day overrides yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sortedOverrides) { override in
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    loadOverride(override)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(formattedDate(override.date))
                                            .font(.headline)

                                        Text(override.kind.displayName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.blue)

                                        Text(profileName(for: override.profileID))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                HStack {
                                    Button("Use Today") {
                                        selectedDate = Date()
                                        selectedKind = override.kind
                                        selectedProfileID = override.profileID
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Copy +1 Week") {
                                        duplicateOverrideToNextWeek(override)
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Delete", role: .destructive) {
                                        overrideToDelete = override
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Day Overrides")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                applySuggestedProfileIfNeeded()
            }
            .onChange(of: selectedKind) { _, _ in
                applySuggestedProfileIfNeeded()
            }
            .alert("Delete Override?", isPresented: Binding(
                get: { overrideToDelete != nil },
                set: { _ in overrideToDelete = nil }
            ), presenting: overrideToDelete) { item in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    overrides.removeAll { $0.id == item.id }
                }
            } message: { item in
                Text("Delete override for \(formattedDate(item.date))?")
            }
        }
    }

    private var overridesOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust a single day without rebuilding the week.")
                .font(.headline.weight(.semibold))

            Text("Use overrides for assemblies, testing, late starts, field trips, or any one-day schedule shift that should temporarily replace the normal plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                overridesMetric(title: "Saved", value: "\(overrides.count)", accent: ClassTraxSemanticColor.primaryAction)
                overridesMetric(title: "Profiles", value: "\(profiles.count)", accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func overridesMetric(title: String, value: String, accent: Color) -> some View {
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
    }
    
    private var sortedOverrides: [DayOverride] {
        overrides.sorted { $0.date < $1.date }
    }

    private var presetKinds: [DayOverride.OverrideKind] {
        DayOverride.OverrideKind.allCases.filter { $0 != .custom }
    }

    private var suggestedProfile: ScheduleProfile? {
        let preferredKeywords = selectedKind.profileKeywords

        if let keywordMatch = profiles.first(where: { profile in
            let normalizedName = profile.name.lowercased()
            return preferredKeywords.contains(where: { normalizedName.contains($0) })
        }) {
            return keywordMatch
        }

        return profiles.first
    }

    private var suggestedProfileSummary: String {
        guard let suggestedProfile else { return "No profile suggestion available." }
        return "\(selectedKind.displayName) works best with \(suggestedProfile.name)."
    }
    
    private func saveOverride() {
        guard let selectedProfileID else { return }
        
        let normalizedDate = Calendar.current.startOfDay(for: selectedDate)
        
        if let existingIndex = overrides.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: normalizedDate)
        }) {
            overrides[existingIndex].profileID = selectedProfileID
            overrides[existingIndex].kind = selectedKind
        } else {
            overrides.append(
                DayOverride(
                    date: normalizedDate,
                    profileID: selectedProfileID,
                    kind: selectedKind
                )
            )
        }

        feedbackMessage = "\(selectedKind.displayName) saved for \(formattedDate(normalizedDate))."
    }

    private func loadOverride(_ override: DayOverride) {
        selectedDate = override.date
        selectedKind = override.kind
        selectedProfileID = override.profileID
    }

    private func duplicateOverrideToNextWeek(_ override: DayOverride) {
        guard let nextWeekDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: override.date)) else {
            return
        }

        if let existingIndex = overrides.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: nextWeekDate)
        }) {
            overrides[existingIndex].profileID = override.profileID
            overrides[existingIndex].kind = override.kind
            feedbackMessage = "\(override.kind.displayName) replaced the override on \(formattedDate(nextWeekDate))."
        } else {
            overrides.append(
                DayOverride(
                    date: nextWeekDate,
                    profileID: override.profileID,
                    kind: override.kind
                )
            )
            feedbackMessage = "\(override.kind.displayName) copied to \(formattedDate(nextWeekDate))."
        }

        selectedDate = nextWeekDate
        selectedKind = override.kind
        selectedProfileID = override.profileID
    }

    private func applySuggestedProfileIfNeeded() {
        guard let suggestedProfile else { return }
        guard selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) else { return }
        selectedProfileID = suggestedProfile.id
    }
    
    private func profileName(for id: UUID) -> String {
        profiles.first(where: { $0.id == id })?.name ?? "Unknown Profile"
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

private extension DayOverride.OverrideKind {
    var profileKeywords: [String] {
        switch self {
        case .custom:
            return []
        case .earlyRelease, .minimumDay:
            return ["early", "minimum", "short"]
        case .lateStart:
            return ["late", "delay"]
        case .assemblyDay:
            return ["assembly"]
        case .testingDay:
            return ["testing", "test"]
        }
    }
}

#Preview {
    DayOverridesView(
        overrides: .constant([]),
        profiles: .constant([
            ScheduleProfile(name: "Regular Day", alarms: []),
            ScheduleProfile(name: "Assembly Day", alarms: [])
        ])
    )
}
