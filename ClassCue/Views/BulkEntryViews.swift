import SwiftUI

private struct StudentBulkEntryRow: Identifiable {
    let id: UUID
    var name: String
    var className: String
    var linkedClassDefinitionID: UUID?
    var gradeLevel: String
    var parentNames: String
    var studentEmail: String

    nonisolated init(profile: StudentSupportProfile? = nil) {
        id = profile?.id ?? UUID()
        name = profile?.name ?? ""
        className = profile?.className ?? ""
        linkedClassDefinitionID = profile?.classDefinitionIDs.first ?? profile?.classDefinitionID
        gradeLevel = profile?.gradeLevel ?? ""
        parentNames = profile?.parentNames ?? ""
        studentEmail = profile?.studentEmail ?? ""
    }

    var isBlank: Bool {
        [
            name,
            className,
            gradeLevel,
            parentNames,
            studentEmail
        ]
        .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private struct ClassBulkEntryRow: Identifiable {
    let id: UUID
    var name: String
    var scheduleKind: ClassDefinitionItem.ScheduleKind
    var gradeLevel: String
    var defaultLocation: String

    nonisolated init(definition: ClassDefinitionItem? = nil) {
        id = definition?.id ?? UUID()
        name = definition?.name ?? ""
        scheduleKind = definition?.scheduleKind ?? .other
        gradeLevel = definition?.gradeLevel ?? ""
        defaultLocation = definition?.defaultLocation ?? ""
    }

    var isBlank: Bool {
        [
            name,
            gradeLevel,
            defaultLocation
        ]
        .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private struct StaffBulkEntryRow: Identifiable {
    let id: UUID
    var name: String
    var room: String
    var subject: String
    var tags: String
    var emailAddress: String

    nonisolated init(contact: ClassStaffContact? = nil) {
        id = contact?.id ?? UUID()
        name = contact?.name ?? ""
        room = contact?.room ?? ""
        subject = contact?.subject ?? ""
        tags = contact?.tags ?? ""
        emailAddress = contact?.emailAddress ?? ""
    }

    var isBlank: Bool {
        [
            name,
            room,
            subject,
            tags,
            emailAddress
        ]
        .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct StudentBulkEntryView: View {
    @Binding var profiles: [StudentSupportProfile]
    let classDefinitions: [ClassDefinitionItem]
    let onSaveProfiles: (([StudentSupportProfile]) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftRows: [StudentBulkEntryRow]

    init(
        profiles: Binding<[StudentSupportProfile]>,
        classDefinitions: [ClassDefinitionItem],
        onSaveProfiles: (([StudentSupportProfile]) -> Void)? = nil
    ) {
        _profiles = profiles
        self.classDefinitions = classDefinitions
        self.onSaveProfiles = onSaveProfiles
        _draftRows = State(initialValue: profiles.wrappedValue.map(StudentBulkEntryRow.init(profile:)) + [StudentBulkEntryRow()])
    }

    var body: some View {
        bulkEntryScaffold(
            title: "Student Grid Entry",
            description: "Use this on iPad or Mac to enter several students at once. Pick a saved roster when you want direct class linking, or leave it blank and use the class label only.",
            addLabel: "Add Student Row",
            saveAction: save
        ) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                gridHeader(["Student", "Roster", "Class / Group", "Grade", "Parents", "Email", ""])

                ForEach($draftRows) { $row in
                    GridRow {
                        bulkField("Student", text: $row.name)
                        bulkRosterPicker(
                            selection: $row.linkedClassDefinitionID,
                            classDefinitions: classDefinitions
                        )
                        bulkField("Class / Group", text: $row.className)
                        bulkField("Grade", text: $row.gradeLevel)
                        bulkField("Parents", text: $row.parentNames)
                        bulkField("Email", text: $row.studentEmail)
                        bulkDeleteButton {
                            removeRow(id: row.id)
                        }
                    }
                }
            }
        } onAddRow: {
            draftRows.append(StudentBulkEntryRow())
        }
    }

    private func save() {
        let trimmedRows = draftRows.filter { !$0.isBlank }
        var updatedProfiles = profiles

        for row in trimmedRows {
            let selectedDefinition = classDefinitions.first(where: { $0.id == row.linkedClassDefinitionID })
            let typedClassName = row.className.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedClassName = typedClassName.isEmpty ? (selectedDefinition?.name ?? "") : typedClassName
            let matchedDefinitions = if let selectedDefinition {
                [selectedDefinition]
            } else {
                classDefinitions.filter {
                    classNamesMatch(scheduleClassName: $0.name, profileClassName: normalizedClassName)
                }
            }
            let linkedIDs = matchedDefinitions.map(\.id).sorted { $0.uuidString < $1.uuidString }
            let normalizedGrade = GradeLevelOption.normalized(
                row.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (selectedDefinition?.gradeLevel ?? "")
                    : row.gradeLevel
            )
            let profile = StudentSupportProfile(
                id: row.id,
                name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                className: normalizedClassName,
                gradeLevel: normalizedGrade,
                classDefinitionID: linkedIDs.first,
                classDefinitionIDs: linkedIDs,
                parentNames: row.parentNames.trimmingCharacters(in: .whitespacesAndNewlines),
                studentEmail: row.studentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if let index = updatedProfiles.firstIndex(where: { $0.id == row.id }) {
                let existing = updatedProfiles[index]
                updatedProfiles[index] = StudentSupportProfile(
                    id: existing.id,
                    name: profile.name,
                    className: profile.className,
                    gradeLevel: profile.gradeLevel,
                    classDefinitionID: profile.classDefinitionID,
                    classDefinitionIDs: profile.classDefinitionIDs,
                    classContexts: existing.classContexts,
                    graduationYear: existing.graduationYear,
                    parentNames: profile.parentNames,
                    parentPhoneNumbers: existing.parentPhoneNumbers,
                    parentEmails: existing.parentEmails,
                    studentEmail: profile.studentEmail,
                    isSped: existing.isSped,
                    supportTeacherIDs: existing.supportTeacherIDs,
                    supportParaIDs: existing.supportParaIDs,
                    supportRooms: existing.supportRooms,
                    supportScheduleNotes: existing.supportScheduleNotes,
                    accommodations: existing.accommodations,
                    prompts: existing.prompts
                )
            } else {
                updatedProfiles.append(profile)
            }
        }

        profiles = updatedProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        onSaveProfiles?(profiles)
        dismiss()
    }

    private func removeRow(id: UUID) {
        guard draftRows.count > 1 else { return }
        draftRows.removeAll { $0.id == id }
    }
}

struct ClassBulkEntryView: View {
    @Binding var classDefinitions: [ClassDefinitionItem]

    @Environment(\.dismiss) private var dismiss
    @State private var draftRows: [ClassBulkEntryRow]

    init(classDefinitions: Binding<[ClassDefinitionItem]>) {
        _classDefinitions = classDefinitions
        _draftRows = State(initialValue: classDefinitions.wrappedValue.map(ClassBulkEntryRow.init(definition:)) + [ClassBulkEntryRow()])
    }

    var body: some View {
        bulkEntryScaffold(
            title: "Class Grid Entry",
            description: "Add or revise saved classes and groups in one table instead of opening each record individually.",
            addLabel: "Add Class Row",
            saveAction: save
        ) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                gridHeader(["Name", "Type", "Grade", "Location", ""])

                ForEach($draftRows) { $row in
                    GridRow {
                        bulkField("Name", text: $row.name)
                        Picker("Type", selection: $row.scheduleKind) {
                            ForEach(ClassDefinitionItem.ScheduleKind.alphabetizedCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minWidth: 140, alignment: .leading)
                        bulkField("Grade", text: $row.gradeLevel)
                        bulkField("Location", text: $row.defaultLocation)
                        bulkDeleteButton {
                            removeRow(id: row.id)
                        }
                    }
                }
            }
        } onAddRow: {
            draftRows.append(ClassBulkEntryRow())
        }
    }

    private func save() {
        let rows = draftRows.filter { !$0.isBlank }
        classDefinitions = rows.map { row in
            ClassDefinitionItem(
                id: row.id,
                name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                scheduleType: row.scheduleKind,
                gradeLevel: GradeLevelOption.normalized(row.gradeLevel),
                defaultLocation: row.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        dismiss()
    }

    private func removeRow(id: UUID) {
        guard draftRows.count > 1 else { return }
        draftRows.removeAll { $0.id == id }
    }
}

struct SupportStaffBulkEntryView: View {
    let title: String
    let role: SupportStaffRole
    @Binding var contacts: [ClassStaffContact]
    let onSaveContacts: (([ClassStaffContact]) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftRows: [StaffBulkEntryRow]

    init(
        title: String,
        role: SupportStaffRole,
        contacts: Binding<[ClassStaffContact]>,
        onSaveContacts: (([ClassStaffContact]) -> Void)? = nil
    ) {
        self.title = title
        self.role = role
        _contacts = contacts
        self.onSaveContacts = onSaveContacts
        _draftRows = State(initialValue: contacts.wrappedValue.map(StaffBulkEntryRow.init(contact:)) + [StaffBulkEntryRow()])
    }

    var body: some View {
        bulkEntryScaffold(
            title: "\(title) Grid Entry",
            description: "Capture \(role.pluralTitle.lowercased()) in a single pass, including optional tags for responsibilities or service areas.",
            addLabel: "Add \(role.title) Row",
            saveAction: save
        ) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                gridHeader(["Name", "Room", "Subject", "Tags", "Email", ""])

                ForEach($draftRows) { $row in
                    GridRow {
                        bulkField("Name", text: $row.name)
                        bulkField("Room", text: $row.room)
                        bulkField("Subject", text: $row.subject)
                        bulkField("Tags", text: $row.tags)
                        bulkField("Email", text: $row.emailAddress)
                        bulkDeleteButton {
                            removeRow(id: row.id)
                        }
                    }
                }
            }
        } onAddRow: {
            draftRows.append(StaffBulkEntryRow())
        }
    }

    private func save() {
        contacts = draftRows
            .filter { !$0.isBlank }
            .map { row in
                ClassStaffContact(
                    id: row.id,
                    name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    room: row.room.trimmingCharacters(in: .whitespacesAndNewlines),
                    emailAddress: row.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                    subject: row.subject.trimmingCharacters(in: .whitespacesAndNewlines),
                    tags: row.tags.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
        onSaveContacts?(contacts)
        dismiss()
    }

    private func removeRow(id: UUID) {
        guard draftRows.count > 1 else { return }
        draftRows.removeAll { $0.id == id }
    }
}

private func bulkEntryScaffold<Content: View>(
    title: String,
    description: String,
    addLabel: String,
    saveAction: @escaping () -> Void,
    @ViewBuilder content: () -> Content,
    onAddRow: @escaping () -> Void
) -> some View {
    NavigationStack {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .classTraxCardChrome(accent: ClassTraxSemanticColor.primaryAction, cornerRadius: 20)

                content()
                    .padding(18)
                    .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 20)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(addLabel, action: onAddRow)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save", action: saveAction)
                    .fontWeight(.semibold)
            }
        }
    }
}

private func gridHeader(_ titles: [String]) -> some View {
    GridRow {
        ForEach(titles, id: \.self) { title in
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func bulkField(_ title: String, text: Binding<String>) -> some View {
    TextField(title, text: text)
        .textFieldStyle(.roundedBorder)
        .frame(minWidth: 140)
}

private func bulkRosterPicker(
    selection: Binding<UUID?>,
    classDefinitions: [ClassDefinitionItem]
) -> some View {
    Picker("Roster", selection: selection) {
        Text("None").tag(nil as UUID?)
        ForEach(classDefinitions) { definition in
            Text(definition.displayName).tag(Optional(definition.id))
        }
    }
    .pickerStyle(.menu)
    .frame(minWidth: 160, alignment: .leading)
}

private func bulkDeleteButton(action: @escaping () -> Void) -> some View {
    Button(role: .destructive, action: action) {
        Image(systemName: "trash")
    }
    .buttonStyle(.borderless)
    .frame(width: 36)
}
