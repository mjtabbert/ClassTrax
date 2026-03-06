//
//  DayOverridesView.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 5:05 PM
//  Version: ClassCue Dev Build 18
//

import SwiftUI

struct DayOverridesView: View {
    
    @Binding var overrides: [DayOverride]
    @Binding var profiles: [ScheduleProfile]
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedProfileID: UUID?
    @State private var overrideToDelete: DayOverride?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Add Day Override") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
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
                
                Section("Saved Overrides") {
                    if overrides.isEmpty {
                        Text("No day overrides yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sortedOverrides) { override in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(formattedDate(override.date))
                                    .font(.headline)
                                
                                Text(profileName(for: override.profileID))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Delete", role: .destructive) {
                                    overrideToDelete = override
                                }
                                .buttonStyle(.bordered)
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
    
    private func saveOverride() {
        guard let selectedProfileID else { return }
        
        let normalizedDate = Calendar.current.startOfDay(for: selectedDate)
        
        if let existingIndex = overrides.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: normalizedDate)
        }) {
            overrides[existingIndex].profileID = selectedProfileID
        } else {
            overrides.append(
                DayOverride(
                    date: normalizedDate,
                    profileID: selectedProfileID
                )
            )
        }
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
