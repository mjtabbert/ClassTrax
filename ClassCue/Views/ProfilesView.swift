//
//  ProfilesView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 4:50 PM
//  Version: ClassTrax Dev Build 17
//

import SwiftUI

struct ProfilesView: View {
    
    @Binding var alarms: [AlarmItem]
    @Binding var profiles: [ScheduleProfile]
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var newProfileName = ""
    
    @State private var profileToDelete: ScheduleProfile?
    @State private var profileToLoad: ScheduleProfile?
    @State private var profileToRename: ScheduleProfile?
    
    @State private var renameText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    profilesOverviewCard
                }

                Section("Save Current Schedule") {
                    TextField("Profile Name", text: $newProfileName)

                    Button("Save Profile") {
                        saveProfile()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ClassTraxSemanticColor.primaryAction)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || alarms.isEmpty)
                }

                Section("Saved Profiles") {
                    if profiles.isEmpty {
                        Text("No saved profiles yet.")
                            .foregroundColor(.secondary)
                    } else {
                        
                        ForEach(profiles) { profile in
                            
                            VStack(alignment: .leading, spacing: 8) {
                                
                                Text(profile.name)
                                    .font(.headline)
                                
                                Text("\(profile.alarms.count) schedule item(s)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    
                                    Button("Load") {
                                        profileToLoad = profile
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(ClassTraxSemanticColor.primaryAction)
                                    
                                    Button("Duplicate") {
                                        duplicateProfile(profile)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(ClassTraxSemanticColor.secondaryAction)
                                    
                                    Button("Rename") {
                                        profileToRename = profile
                                        renameText = profile.name
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(ClassTraxSemanticColor.reviewWarning)
                                    
                                    Button("Delete", role: .destructive) {
                                        profileToDelete = profile
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            
            .alert("Load Profile?", isPresented: Binding(
                get: { profileToLoad != nil },
                set: { _ in profileToLoad = nil }
            ), presenting: profileToLoad) { profile in
                
                Button("Cancel", role: .cancel) { }
                
                Button("Load", role: .destructive) {
                    alarms = profile.alarms
                }
                
            } message: { profile in
                Text("Replace current schedule with \"\(profile.name)\"?")
            }
            
            .alert("Delete Profile?", isPresented: Binding(
                get: { profileToDelete != nil },
                set: { _ in profileToDelete = nil }
            ), presenting: profileToDelete) { profile in
                
                Button("Cancel", role: .cancel) { }
                
                Button("Delete", role: .destructive) {
                    profiles.removeAll { $0.id == profile.id }
                }
                
            } message: { profile in
                Text("Delete \"\(profile.name)\"?")
            }
            
            .alert("Rename Profile", isPresented: Binding(
                get: { profileToRename != nil },
                set: { _ in profileToRename = nil }
            )) {
                
                TextField("New Name", text: $renameText)
                
                Button("Cancel", role: .cancel) {}
                
                Button("Rename") {
                    renameProfile()
                }
                
            }
        }
    }

    private var profilesOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save complete schedule setups.")
                .font(.headline.weight(.semibold))

            Text("Profiles let you keep reusable versions of a full day so you can switch quickly between regular, delayed, testing, and event schedules.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                profileMetric(title: "Profiles", value: "\(profiles.count)", accent: ClassTraxSemanticColor.primaryAction)
                profileMetric(title: "Current Blocks", value: "\(alarms.count)", accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func profileMetric(title: String, value: String, accent: Color) -> some View {
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
    
    private func saveProfile() {
        
        let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existingIndex = profiles.firstIndex(where: { $0.name == trimmed }) {
            profiles[existingIndex].alarms = alarms
        } else {
            let newProfile = ScheduleProfile(
                name: trimmed,
                alarms: alarms
            )
            profiles.append(newProfile)
        }
        
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        newProfileName = ""
    }
    
    private func duplicateProfile(_ profile: ScheduleProfile) {
        
        let newProfile = ScheduleProfile(
            name: "\(profile.name) Copy",
            alarms: profile.alarms
        )
        
        profiles.append(newProfile)
    }
    
    private func renameProfile() {
        
        guard let profile = profileToRename else { return }
        
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        renameText = ""
    }
}

#Preview {
    ProfilesView(
        alarms: .constant([]),
        profiles: .constant([
            ScheduleProfile(name: "Regular Day", alarms: []),
            ScheduleProfile(name: "Late Start", alarms: [])
        ])
    )
}
