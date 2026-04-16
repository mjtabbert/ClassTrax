//
//  EditStudentSupportView.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import SwiftUI

struct EditStudentSupportView: View {
    private enum FormSection: String, Hashable {
        case student
        case classes
        case contacts
        case supports
        case accommodations
        case prompts
    }

    private enum QuickAddSupportRole: Identifiable {
        case teacher
        case para

        var id: String {
            switch self {
            case .teacher:
                return "teacher"
            case .para:
                return "para"
            }
        }

        var title: String {
            switch self {
            case .teacher:
                return "Teacher"
            case .para:
                return "Para"
            }
        }
    }

    @Binding var profiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    let existing: StudentSupportProfile?
    let initialLinkedClassDefinitionIDs: [UUID]
    let initialClassName: String
    let initialGradeLevel: String
    let onSaveProfiles: (([StudentSupportProfile]) -> Void)?

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
    @State private var expandedSections: Set<FormSection> = [.student]
    @State private var showOptionalDetails = false
    @State private var quickAddSupportRole: QuickAddSupportRole?

    init(
        profiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>,
        existing: StudentSupportProfile?,
        initialLinkedClassDefinitionIDs: [UUID] = [],
        initialClassName: String = "",
        initialGradeLevel: String = "",
        onSaveProfiles: (([StudentSupportProfile]) -> Void)? = nil
    ) {
        _profiles = profiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
        self.existing = existing
        self.initialLinkedClassDefinitionIDs = initialLinkedClassDefinitionIDs
        self.initialClassName = initialClassName
        self.initialGradeLevel = initialGradeLevel
        self.onSaveProfiles = onSaveProfiles
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    studentOverviewCard
                }

                collapsibleSection(.student, title: "Student Information", systemImage: "person.text.rectangle") {
                    labeledEntryField("Name", text: $name, tint: accent(for: .student))

                    labeledEntryPicker("Grade", tint: accent(for: .student)) {
                        Picker("Grade", selection: $gradeLevel) {
                            Text("None").tag("")
                            ForEach(GradeLevelOption.optionsForPicker(), id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    }

                    labeledEntryField("Graduation Year", text: $graduationYear, tint: accent(for: .student))
                        .keyboardType(.numberPad)
                    labeledToggle("Additional Supports / SPED", isOn: $isSped, tint: accent(for: .student))
                }

                collapsibleSection(.classes, title: "Classes & Groups", systemImage: "books.vertical") {
                    labeledEntryField("Custom Class / Group Label (Optional)", text: $className, tint: accent(for: .classes))

                    if !classDefinitions.isEmpty {
                        DisclosureGroup("Choose Saved Classes or Groups") {
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
                }

                if existing == nil && !hasOptionalDetails {
                    Section {
                        Button("Add Contact or Support Details") {
                            showOptionalDetails = true
                            expandedSections.formUnion([.contacts, .supports, .accommodations, .prompts])
                        }
                        .tint(ClassTraxSemanticColor.secondaryAction)
                    }
                }

                if showOptionalDetails || existing != nil || hasOptionalDetails {
                    collapsibleSection(.contacts, title: "Contacts & Family", systemImage: "person.crop.circle.badge") {
                        labeledEntryField("Parent / Guardian Names", text: $parentNames, tint: accent(for: .contacts))
                        labeledEntryField("Parent Phone Numbers", text: $parentPhoneNumbers, tint: accent(for: .contacts))
                        labeledEntryField("Parent Emails", text: $parentEmails, tint: accent(for: .contacts))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                        labeledEntryField("Student Email", text: $studentEmail, tint: accent(for: .contacts))
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }
                }

                if isSped && (showOptionalDetails || existing != nil || hasOptionalDetails) {
                    collapsibleSection(.supports, title: "Supports & Staffing", systemImage: "figure.2.and.child.holdinghands") {
                        Text("Assign classroom teachers and paras for this student’s additional supports.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button {
                                quickAddSupportRole = .teacher
                            } label: {
                                Label("Add Teacher", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .tint(.teal)

                            Button {
                                quickAddSupportRole = .para
                            } label: {
                                Label("Add Para", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }

                        if availableTeacherContacts.isEmpty {
                            Text("No teachers added yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            DisclosureGroup("Assign Teachers (\(selectedSupportTeacherIDs.count))") {
                                ForEach(availableTeacherContacts) { contact in
                                    supportAssignmentRow(
                                        contact: contact,
                                        selectedIDs: $selectedSupportTeacherIDs,
                                        tint: .blue
                                    )
                                }
                            }
                        }

                        if availableParaContacts.isEmpty {
                            Text("No paras added yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            DisclosureGroup("Assign Paras (\(selectedSupportParaIDs.count))") {
                                ForEach(availableParaContacts) { contact in
                                    supportAssignmentRow(
                                        contact: contact,
                                        selectedIDs: $selectedSupportParaIDs,
                                        tint: .orange
                                    )
                                }
                            }
                        }

                        labeledEntryField("Support Rooms", text: $supportRooms, tint: accent(for: .supports))
                        labeledEntryField("Support Schedule Notes", text: $supportScheduleNotes, tint: accent(for: .supports), axis: .vertical)
                            .lineLimit(2...6)
                    }
                }

                if showOptionalDetails || existing != nil || hasOptionalDetails {
                    collapsibleSection(.accommodations, title: "Accommodations", systemImage: "list.clipboard") {
                        labeledEntryField("Supports, accommodations, or reminders", text: $accommodations, tint: accent(for: .accommodations), axis: .vertical)
                            .lineLimit(3...8)
                    }

                    collapsibleSection(.prompts, title: "Instructional Prompts", systemImage: "lightbulb") {
                        labeledEntryField("What to remember during class", text: $prompts, tint: accent(for: .prompts), axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Student" : "Edit Student")
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .listSectionSpacing(.compact)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existing == nil ? "Add" : "Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                configureInitialValues()
                showOptionalDetails = existing != nil || hasOptionalDetails
                reconcileSupportAssignments()
            }
            .onChange(of: selectedClassDefinitionIDs) { _, _ in
                applySelectedClassDefinitions()
                reconcileSupportAssignments()
            }
            .sheet(item: $quickAddSupportRole) { role in
                NavigationStack {
                    QuickSupportStaffEditorView(
                        roleTitle: role.title,
                        accent: role == .teacher ? .teal : .orange,
                        onSave: { contact in
                            appendQuickSupport(contact, role: role)
                            quickAddSupportRole = nil
                        },
                        onCancel: {
                            quickAddSupportRole = nil
                        }
                    )
                }
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
        onSaveProfiles?(profiles)
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

    private var hasOptionalDetails: Bool {
        !graduationYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !parentNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !parentPhoneNumbers.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !parentEmails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !studentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        isSped ||
        !supportRooms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !supportScheduleNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !selectedSupportTeacherIDs.isEmpty ||
        !selectedSupportParaIDs.isEmpty
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

    private func appendQuickSupport(_ contact: ClassStaffContact, role: QuickAddSupportRole) {
        let trimmedName = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        switch role {
        case .teacher:
            teacherContacts.append(contact)
            teacherContacts.sort { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
            selectedSupportTeacherIDs.insert(contact.id)
        case .para:
            paraContacts.append(contact)
            paraContacts.sort { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
            selectedSupportParaIDs.insert(contact.id)
        }
    }

    private var studentOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(existing == nil ? "Build the student profile in layers." : "Update the student profile.")
                .font(.headline.weight(.semibold))

            Text(existing == nil
                ? "Start with the core student details here. Add classes, family, supports, and accommodations only where they belong."
                : "Keep the core student details current, then expand only the sections that need changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                profileMetric(title: "Grade", value: gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not Set" : GradeLevelOption.pillLabel(for: gradeLevel), accent: ClassTraxSemanticColor.primaryAction)
                profileMetric(title: "Supports", value: isSped ? "On" : "Off", accent: ClassTraxSemanticColor.secondaryAction)
                profileMetric(title: "Optional Info", value: hasOptionalDetails ? "Added" : "Basic", accent: ClassTraxSemanticColor.success)
            }
        }
        .padding(12)
        .classTraxCardChrome(accent: ClassTraxSemanticColor.primaryAction, cornerRadius: 20)
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
                .fill(Color(.systemBackground).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        )
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
            .padding(.vertical, 4)
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
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func collapsibleSection<Content: View>(
        _ section: FormSection,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Section {
            DisclosureGroup(isExpanded: expansionBinding(for: section)) {
                content()
            } label: {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent(for: section))
                    .padding(.vertical, 1)
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent(for: section).opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func expansionBinding(for section: FormSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section)
                } else {
                    expandedSections.remove(section)
                }
            }
        )
    }

    private func resolvedClassSummary() -> String {
        if !selectedClassDefinitions.isEmpty {
            return selectedClassDefinitions.map(\.name).joined(separator: ", ")
        }

        return className.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func accent(for section: FormSection) -> Color {
        switch section {
        case .student:
            return ClassTraxSemanticColor.primaryAction
        case .classes:
            return .indigo
        case .contacts:
            return ClassTraxSemanticColor.secondaryAction
        case .supports:
            return ClassTraxSemanticColor.reviewWarning
        case .accommodations:
            return ClassTraxSemanticColor.success
        case .prompts:
            return ClassTraxSemanticColor.attendance
        }
    }

    private func labeledEntryField(
        _ title: String,
        text: Binding<String>,
        tint: Color,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            TextField(title, text: text, axis: axis)
                .padding(.horizontal, 12)
                .padding(.vertical, axis == .horizontal ? 9 : 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(.vertical, 1)
    }

    private func labeledEntryPicker<Content: View>(
        _ title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(.vertical, 1)
    }

    private func labeledToggle(_ title: String, isOn: Binding<Bool>, tint: Color) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .padding(.vertical, 1)
    }
}

private struct QuickSupportStaffEditorView: View {
    let roleTitle: String
    let accent: Color
    let onSave: (ClassStaffContact) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var room = ""
    @State private var emailAddress = ""
    @State private var subject = ""

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Name", text: $name)
                TextField("Room", text: $room)
                TextField("Role / Subject", text: $subject)
                TextField("Email Address", text: $emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
        .navigationTitle("Add \(roleTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    onSave(
                        ClassStaffContact(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            room: room.trimmingCharacters(in: .whitespacesAndNewlines),
                            emailAddress: emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .tint(accent)
            }
        }
    }
}
