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

                        Button("Clear Today's Override", role: .destructive) {
                            overrides.removeAll { $0.id == todayOverride.id }
                        }
                    }
                }

                Section("Add Day Override") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)

                    if !presetKinds.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetKinds, id: \.self) { kind in
                                    Button(kind.displayName) {
                                        selectedKind = kind
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(selectedKind == kind ? .accentColor : .secondary.opacity(0.3))
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
                    
                    Button("Save Override") {
                        saveOverride()
                    }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
    
    private var sortedOverrides: [DayOverride] {
        overrides.sorted { $0.date < $1.date }
    }

    private var presetKinds: [DayOverride.OverrideKind] {
        DayOverride.OverrideKind.allCases.filter { $0 != .custom }
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
    
    private func profileName(for id: UUID) -> String {
        profiles.first(where: { $0.id == id })?.name ?? "Unknown Profile"
    }
    
    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
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
