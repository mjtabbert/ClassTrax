import SwiftUI

struct EditClassDefinitionView: View {
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    let existing: ClassDefinitionItem?
    let onSaveChanges: (([ClassDefinitionItem], [StudentSupportProfile]) -> Void)?
    @AppStorage("teacher_workflow_mode_v1") private var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var scheduleType: ClassDefinitionItem.ScheduleKind = .other
    @State private var gradeLevel = ""
    @State private var defaultLocation = ""
    @State private var selectedStudentIDs = Set<UUID>()
    @State private var showLinkedStudents = false

    init(
        classDefinitions: Binding<[ClassDefinitionItem]>,
        studentProfiles: Binding<[StudentSupportProfile]>,
        existing: ClassDefinitionItem?,
        onSaveChanges: (([ClassDefinitionItem], [StudentSupportProfile]) -> Void)? = nil
    ) {
        _classDefinitions = classDefinitions
        _studentProfiles = studentProfiles
        self.existing = existing
        self.onSaveChanges = onSaveChanges
    }

    private var teacherWorkflowMode: TeacherWorkflowMode {
        TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom
    }

    private var detailsSectionTitle: String {
        teacherWorkflowMode == .classroom ? "Class Setup" : "Group Setup"
    }

    private var namePlaceholder: String {
        teacherWorkflowMode == .classroom ? "Class Name" : "Group Name"
    }

    private var editorTitle: String {
        if existing == nil {
            return teacherWorkflowMode == .classroom ? "Add Class" : "Add Group"
        }
        return teacherWorkflowMode == .classroom ? "Edit Class" : "Edit Group"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    editorOverviewCard
                }

                Section(detailsSectionTitle) {
                    TextField(namePlaceholder, text: $name)

                    Picker("Type", selection: $scheduleType) {
                        ForEach(ClassDefinitionItem.ScheduleKind.alphabetizedCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Picker("Grade Level", selection: $gradeLevel) {
                        Text("None").tag("")
                        ForEach(GradeLevelOption.optionsForPicker(), id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    TextField("Default Room / Location", text: $defaultLocation)
                }
                Section("Student Links") {
                    DisclosureGroup(isExpanded: $showLinkedStudents) {
                        if sortedStudentProfiles.isEmpty {
                            Text("No students saved yet. Add students in Class List, then link them here.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(sortedStudentProfiles) { profile in
                                linkedStudentRow(profile)
                            }
                        }
                    } label: {
                        LabeledContent("Link Students Now") {
                            Text("\(selectedStudentIDs.count)")
                                .foregroundStyle(selectedStudentIDs.isEmpty ? .secondary : .primary)
                        }
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
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
                guard let existing else { return }
                name = existing.name
                scheduleType = existing.scheduleKind
                gradeLevel = GradeLevelOption.normalized(existing.gradeLevel)
                defaultLocation = existing.defaultLocation
                showLinkedStudents = true
                selectedStudentIDs = Set(
                    studentProfiles
                        .filter {
                            if profileMatches(classDefinitionID: existing.id, profile: $0) {
                                return true
                            }

                            return linkedClassDefinitionIDs(for: $0).isEmpty &&
                                classNamesMatch(scheduleClassName: existing.name, profileClassName: $0.className)
                        }
                        .map(\.id)
                )
            }
        }
    }

    private var editorOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "Create a reusable class or group." : "Update this saved class or group.")
                .font(.headline.weight(.semibold))

            Text(existing == nil
                ? "Save the basics first, then connect students when you are ready."
                : "Student links are optional and can be changed anytime without rebuilding your schedule.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                editorMetric(
                    title: teacherWorkflowMode == .classroom ? "Mode" : "Workflow",
                    value: teacherWorkflowMode.shortLabel,
                    accent: ClassTraxSemanticColor.primaryAction
                )
                editorMetric(
                    title: "Linked",
                    value: "\(selectedStudentIDs.count)",
                    accent: ClassTraxSemanticColor.success
                )
            }
        }
        .padding(16)
        .classTraxCardChrome(accent: ClassTraxSemanticColor.primaryAction, cornerRadius: 20)
    }

    private func editorMetric(title: String, value: String, accent: Color) -> some View {
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

    private func save() {
        let item = ClassDefinitionItem(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduleType: scheduleType,
            gradeLevel: GradeLevelOption.normalized(gradeLevel),
            defaultLocation: defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let existing, let index = classDefinitions.firstIndex(where: { $0.id == existing.id }) {
            classDefinitions[index] = item
        } else {
            classDefinitions.append(item)
        }

        classDefinitions.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        syncLinkedStudents(for: item)
        onSaveChanges?(classDefinitions, studentProfiles)
        dismiss()
    }

    private var sortedStudentProfiles: [StudentSupportProfile] {
        studentProfiles.sorted { lhs, rhs in
            let lhsSelected = selectedStudentIDs.contains(lhs.id)
            let rhsSelected = selectedStudentIDs.contains(rhs.id)
            if lhsSelected != rhsSelected {
                return lhsSelected && !rhsSelected
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    @ViewBuilder
    private func linkedStudentRow(_ profile: StudentSupportProfile) -> some View {
        let isSelected = selectedStudentIDs.contains(profile.id)

        Button {
            if isSelected {
                selectedStudentIDs.remove(profile.id)
            } else {
                selectedStudentIDs.insert(profile.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .foregroundStyle(.primary)

                    let detail = [profile.gradeLevel, classSummary(for: profile, in: classDefinitions)]
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

    private func syncLinkedStudents(for definition: ClassDefinitionItem) {
        let updatedDefinitions = classDefinitions

        for index in studentProfiles.indices {
            let isSelected = selectedStudentIDs.contains(studentProfiles[index].id)
            let linkedIDs = linkedClassDefinitionIDs(for: studentProfiles[index])
            let alreadyLinked = linkedIDs.contains(definition.id)

            if isSelected && !alreadyLinked {
                studentProfiles[index] = updatingProfile(
                    studentProfiles[index],
                    linkedTo: linkedIDs + [definition.id],
                    definitions: updatedDefinitions
                )
            } else if isSelected && alreadyLinked {
                studentProfiles[index] = updatingProfile(
                    studentProfiles[index],
                    linkedTo: linkedIDs,
                    definitions: updatedDefinitions
                )
            } else if !isSelected && alreadyLinked {
                studentProfiles[index] = updatingProfile(
                    studentProfiles[index],
                    linkedTo: linkedIDs.filter { $0 != definition.id },
                    definitions: updatedDefinitions
                )
            }
        }
    }

}
