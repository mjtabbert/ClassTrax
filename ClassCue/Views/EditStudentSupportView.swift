//
//  EditStudentSupportView.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import SwiftUI

struct EditStudentSupportView: View {
    @Binding var profiles: [StudentSupportProfile]
    let existing: StudentSupportProfile?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var className = ""
    @State private var gradeLevel = ""
    @State private var graduationYear = ""
    @State private var parentNames = ""
    @State private var parentPhoneNumbers = ""
    @State private var parentEmails = ""
    @State private var studentEmail = ""
    @State private var accommodations = ""
    @State private var prompts = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Student or Group") {
                    TextField("Name", text: $name)
                    TextField("Class", text: $className)
                    Picker("Grade", selection: $gradeLevel) {
                        Text("None").tag("")
                        ForEach(GradeLevelOption.optionsForPicker(), id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Graduation Year", text: $graduationYear)
                }

                Section("Contacts") {
                    TextField("Parent / Guardian Names", text: $parentNames)
                    TextField("Parent Phone Numbers", text: $parentPhoneNumbers)
                    TextField("Parent Emails", text: $parentEmails)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("Student Email", text: $studentEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }

                Section("Accommodations") {
                    TextField("Supports, accommodations, or reminders", text: $accommodations, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Instructional Prompts") {
                    TextField("What to remember during class", text: $prompts, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(existing == nil ? "Add Student Support" : "Edit Support")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard let existing else { return }
                name = existing.name
                className = existing.className
                gradeLevel = GradeLevelOption.normalized(existing.gradeLevel)
                graduationYear = existing.graduationYear
                parentNames = existing.parentNames
                parentPhoneNumbers = existing.parentPhoneNumbers
                parentEmails = existing.parentEmails
                studentEmail = existing.studentEmail
                accommodations = existing.accommodations
                prompts = existing.prompts
            }
        }
    }

    private func save() {
        let item = StudentSupportProfile(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            className: className.trimmingCharacters(in: .whitespacesAndNewlines),
            gradeLevel: GradeLevelOption.normalized(gradeLevel),
            graduationYear: graduationYear.trimmingCharacters(in: .whitespacesAndNewlines),
            parentNames: parentNames.trimmingCharacters(in: .whitespacesAndNewlines),
            parentPhoneNumbers: parentPhoneNumbers.trimmingCharacters(in: .whitespacesAndNewlines),
            parentEmails: parentEmails.trimmingCharacters(in: .whitespacesAndNewlines),
            studentEmail: studentEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            accommodations: accommodations.trimmingCharacters(in: .whitespacesAndNewlines),
            prompts: prompts.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let existing, let index = profiles.firstIndex(where: { $0.id == existing.id }) {
            profiles[index] = item
        } else {
            profiles.append(item)
        }

        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        dismiss()
    }
}
