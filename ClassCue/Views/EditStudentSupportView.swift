//
//  EditStudentSupportView.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import SwiftUI

struct EditStudentSupportView: View {
    @Binding var profiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    let existing: StudentSupportProfile?
    let initialLinkedClassDefinitionIDs: [UUID]
    let initialClassName: String
    let initialGradeLevel: String

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var className = ""
    @State private var gradeLevel = ""
    @State private var selectedClassDefinitionIDs: Set<UUID> = []
    @State private var graduationYear = ""
    @State private var parentNames = ""
    @State private var parentPhoneNumbers = ""
    @State private var parentEmails = ""
    @State private var studentEmail = ""
    @State private var isSped = false
    @State private var selectedSupportTeacherIDs = Set<UUID>()
    @State private var selectedSupportParaIDs = Set<UUID>()
    @State private var supportRooms = ""
    @State private var supportScheduleNotes = ""
    @State private var accommodations = ""
    @State private var prompts = ""

    init(
        profiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>,
        existing: StudentSupportProfile?,
        initialLinkedClassDefinitionIDs: [UUID] = [],
        initialClassName: String = "",
        initialGradeLevel: String = ""
    ) {
        _profiles = profiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
        self.existing = existing
        self.initialLinkedClassDefinitionIDs = initialLinkedClassDefinitionIDs
        self.initialClassName = initialClassName
        self.initialGradeLevel = initialGradeLevel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Student or Group") {
                    TextField("Name", text: $name)

                    TextField("Class", text: $className)

                    if !classDefinitions.isEmpty {
                        DisclosureGroup("Linked Saved Classes") {
                            if !candidateClassDefinitions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Suggested matches")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    ForEach(candidateClassDefinitions) { definition in
                                        linkedClassToggleRow(definition)
                                    }
                                }
                                .padding(.bottom, 8)
                            }

                            ForEach(classDefinitions) { definition in
                                linkedClassToggleRow(definition)
                            }
                        }
                    }

                    if !selectedClassDefinitions.isEmpty {
                        Text(selectedClassDefinitions.map(\.displayName).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Grade", selection: $gradeLevel) {
                        Text("None").tag("")
                        ForEach(GradeLevelOption.optionsForPicker(), id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Graduation Year", text: $graduationYear)
                    Toggle("Additional Supports", isOn: $isSped)
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

                if isSped {
                    Section("Supports") {
                        if availableTeacherContacts.isEmpty && availableParaContacts.isEmpty {
                            Text("Add teachers or paras in the Students support lists to assign classroom supports here.")
                                .foregroundStyle(.secondary)
                        }

                        if !availableTeacherContacts.isEmpty {
                            DisclosureGroup("Classroom Teachers") {
                                ForEach(availableTeacherContacts) { contact in
                                    supportAssignmentRow(
                                        contact: contact,
                                        selectedIDs: $selectedSupportTeacherIDs,
                                        tint: .blue
                                    )
                                }
                            }
                        }

                        if !availableParaContacts.isEmpty {
                            DisclosureGroup("Paras") {
                                ForEach(availableParaContacts) { contact in
                                    supportAssignmentRow(
                                        contact: contact,
                                        selectedIDs: $selectedSupportParaIDs,
                                        tint: .orange
                                    )
                                }
                            }
                        }

                        TextField("Support Rooms", text: $supportRooms)
                        TextField("Support Schedule Notes", text: $supportScheduleNotes, axis: .vertical)
                            .lineLimit(2...6)
                    }
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
                configureInitialValues()
            }
            .onChange(of: selectedClassDefinitionIDs) { _, _ in
                applySelectedClassDefinitions()
                reconcileSupportAssignments()
            }
        }
    }

    private func save() {
        let item = StudentSupportProfile(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            className: resolvedClassSummary(),
            gradeLevel: GradeLevelOption.normalized(gradeLevel),
            classDefinitionID: selectedClassDefinitionIDs.sorted { $0.uuidString < $1.uuidString }.first,
            classDefinitionIDs: selectedClassDefinitionIDs.sorted { $0.uuidString < $1.uuidString },
            graduationYear: graduationYear.trimmingCharacters(in: .whitespacesAndNewlines),
            parentNames: parentNames.trimmingCharacters(in: .whitespacesAndNewlines),
            parentPhoneNumbers: parentPhoneNumbers.trimmingCharacters(in: .whitespacesAndNewlines),
            parentEmails: parentEmails.trimmingCharacters(in: .whitespacesAndNewlines),
            studentEmail: studentEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            isSped: isSped,
            supportTeacherIDs: Array(selectedSupportTeacherIDs).sorted { $0.uuidString < $1.uuidString },
            supportParaIDs: Array(selectedSupportParaIDs).sorted { $0.uuidString < $1.uuidString },
            supportRooms: supportRooms.trimmingCharacters(in: .whitespacesAndNewlines),
            supportScheduleNotes: supportScheduleNotes.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func configureInitialValues() {
        if let existing {
            name = existing.name
            className = existing.className
            gradeLevel = GradeLevelOption.normalized(existing.gradeLevel)
            selectedClassDefinitionIDs = Set(linkedClassDefinitionIDs(for: existing))
            if selectedClassDefinitionIDs.isEmpty,
               let matchedID = exactClassDefinitionMatch(
                    name: existing.className,
                    gradeLevel: existing.gradeLevel,
                    in: classDefinitions
               )?.id {
                selectedClassDefinitionIDs = [matchedID]
            }
            graduationYear = existing.graduationYear
            parentNames = existing.parentNames
            parentPhoneNumbers = existing.parentPhoneNumbers
            parentEmails = existing.parentEmails
            studentEmail = existing.studentEmail
            isSped = existing.isSped
            selectedSupportTeacherIDs = Set(existing.supportTeacherIDs)
            selectedSupportParaIDs = Set(existing.supportParaIDs)
            supportRooms = existing.supportRooms
            supportScheduleNotes = existing.supportScheduleNotes
            accommodations = existing.accommodations
            prompts = existing.prompts
            return
        }

        className = initialClassName
        gradeLevel = GradeLevelOption.normalized(initialGradeLevel)
        selectedClassDefinitionIDs = Set(initialLinkedClassDefinitionIDs)
        reconcileSupportAssignments()
    }

    private func applySelectedClassDefinitions() {
        guard let primaryDefinition = selectedClassDefinitions.first else { return }
        className = selectedClassDefinitions.map(\.name).joined(separator: ", ")

        if gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let grades = selectedClassDefinitions
                .map(\.gradeLevel)
                .map(GradeLevelOption.normalized)
                .filter { !$0.isEmpty }

            if let singleGrade = Set(grades).first, Set(grades).count == 1 {
                gradeLevel = singleGrade
            } else if grades.isEmpty {
                gradeLevel = GradeLevelOption.normalized(primaryDefinition.gradeLevel)
            }
        }
    }

    private var candidateClassDefinitions: [ClassDefinitionItem] {
        return classDefinitionCandidates(
            name: className.trimmingCharacters(in: .whitespacesAndNewlines),
            gradeLevel: gradeLevel,
            in: classDefinitions
        )
    }

    private var selectedClassDefinitions: [ClassDefinitionItem] {
        classDefinitions
            .filter { selectedClassDefinitionIDs.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var profileDraft: StudentSupportProfile {
        StudentSupportProfile(
            id: existing?.id ?? UUID(),
            name: name,
            className: className,
            gradeLevel: gradeLevel,
            classDefinitionID: selectedClassDefinitionIDs.sorted { $0.uuidString < $1.uuidString }.first,
            classDefinitionIDs: Array(selectedClassDefinitionIDs),
            graduationYear: graduationYear,
            parentNames: parentNames,
            parentPhoneNumbers: parentPhoneNumbers,
            parentEmails: parentEmails,
            studentEmail: studentEmail,
            isSped: isSped,
            supportTeacherIDs: Array(selectedSupportTeacherIDs),
            supportParaIDs: Array(selectedSupportParaIDs),
            supportRooms: supportRooms,
            supportScheduleNotes: supportScheduleNotes,
            accommodations: accommodations,
            prompts: prompts
        )
    }

    private var availableTeacherContacts: [ClassStaffContact] {
        allTeacherContacts(in: teacherContacts)
    }

    private var availableParaContacts: [ClassStaffContact] {
        allParaContacts(in: paraContacts)
    }

    private func reconcileSupportAssignments() {
        let validTeacherIDs = Set(availableTeacherContacts.map(\.id))
        let validParaIDs = Set(availableParaContacts.map(\.id))
        selectedSupportTeacherIDs = selectedSupportTeacherIDs.intersection(validTeacherIDs)
        selectedSupportParaIDs = selectedSupportParaIDs.intersection(validParaIDs)
    }

    @ViewBuilder
    private func linkedClassToggleRow(_ definition: ClassDefinitionItem) -> some View {
        let isSelected = selectedClassDefinitionIDs.contains(definition.id)

        Button {
            if isSelected {
                selectedClassDefinitionIDs.remove(definition.id)
            } else {
                selectedClassDefinitionIDs.insert(definition.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? definition.themeColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.displayName)
                        .foregroundStyle(.primary)

                    let detail = [definition.typeDisplayName, definition.defaultLocation]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")

                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func supportAssignmentRow(
        contact: ClassStaffContact,
        selectedIDs: Binding<Set<UUID>>,
        tint: Color
    ) -> some View {
        let isSelected = selectedIDs.wrappedValue.contains(contact.id)

        Button {
            if isSelected {
                selectedIDs.wrappedValue.remove(contact.id)
            } else {
                selectedIDs.wrappedValue.insert(contact.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? tint : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.trimmedName.isEmpty ? "Unnamed" : contact.trimmedName)
                        .foregroundStyle(.primary)

                    let details = [
                        contact.subject.trimmingCharacters(in: .whitespacesAndNewlines),
                        contact.room.trimmingCharacters(in: .whitespacesAndNewlines),
                        contact.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                    if !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resolvedClassSummary() -> String {
        if !selectedClassDefinitions.isEmpty {
            return selectedClassDefinitions.map(\.name).joined(separator: ", ")
        }

        return className.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
