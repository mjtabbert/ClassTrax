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
                
                Section("Save Current Schedule") {
                    
                    TextField("Profile Name", text: $newProfileName)
                    
                    Button("Save Profile") {
                        saveProfile()
                    }
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
                                    
                                    Button("Duplicate") {
                                        duplicateProfile(profile)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Rename") {
                                        profileToRename = profile
                                        renameText = profile.name
                                    }
                                    .buttonStyle(.bordered)
                                    
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
                ToolbarItem(placement: .navigationBarLeading) {
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
