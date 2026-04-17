import SwiftUI

struct ClassDefinitionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var profiles: [StudentSupportProfile]
    var onCommitChanges: (([ClassDefinitionItem], [StudentSupportProfile]) -> Void)? = nil
    var onDeleteDefinition: ((ClassDefinitionItem) -> Void)? = nil
    @AppStorage("teacher_workflow_mode_v1") private var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue

    @State private var showingAdd = false
    @State private var editingDefinition: ClassDefinitionItem?
    @State private var showingBulkEntry = false

    private var teacherWorkflowMode: TeacherWorkflowMode {
        TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom
    }

    private var definitionsTitle: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Saved Classes"
        case .resourceSped:
            return "Saved Groups"
        case .hybrid:
            return "Saved Classes & Groups"
        }
    }

    private var addDefinitionTitle: String {
        teacherWorkflowMode == .classroom ? "Add Class" : "Add Group"
    }

    var body: some View {
        List {
            Section {
                classDefinitionsOverviewCard
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if classDefinitions.isEmpty {
                Section(definitionsTitle) {
                    ContentUnavailableView(
                        teacherWorkflowMode == .classroom ? "No Saved Classes Yet" : "No Saved Groups Yet",
                        systemImage: "books.vertical",
                        description: Text(
                            teacherWorkflowMode == .classroom
                                ? "Add your classes once, then reuse them in schedules and student supports."
                                : "Add reusable teaching groups once, then reuse them in schedules, supports, and service workflows."
                        )
                    )
                    .listRowBackground(sectionCardBackground(accent: .blue))
                }
            } else {
                Section(definitionsTitle) {
                    ForEach(classDefinitions) { definition in
                        classDefinitionRow(definition)
                            .listRowBackground(sectionCardBackground(accent: rowAccent(for: definition)))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(definitionsTitle)
        .scrollContentBackground(.hidden)
        .background(classDefinitionsBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    ToolbarMenuLabel(title: addDefinitionTitle, systemImage: "plus", expanded: false)
                }
            }

            if supportsBulkEntry {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingBulkEntry = true
                    } label: {
                        Image(systemName: "square.grid.3x2")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EditClassDefinitionView(
                classDefinitions: $classDefinitions,
                studentProfiles: $profiles,
                existing: nil,
                onSaveChanges: { updatedDefinitions, updatedProfiles in
                    onCommitChanges?(updatedDefinitions, updatedProfiles)
                }
            )
        }
        .sheet(item: $editingDefinition) { definition in
            EditClassDefinitionView(
                classDefinitions: $classDefinitions,
                studentProfiles: $profiles,
                existing: definition,
                onSaveChanges: { updatedDefinitions, updatedProfiles in
                    onCommitChanges?(updatedDefinitions, updatedProfiles)
                }
            )
        }
        .sheet(isPresented: $showingBulkEntry) {
            ClassBulkEntryView(classDefinitions: $classDefinitions)
        }
    }

    private func deleteDefinition(_ definition: ClassDefinitionItem) {
        if let onDeleteDefinition {
            onDeleteDefinition(definition)
            return
        }

        let updatedProfiles = profiles.map { profile in
            let linkedIDs = linkedClassDefinitionIDs(for: profile)
            guard linkedIDs.contains(definition.id) else { return profile }
            return updatingProfile(
                profile,
                linkedTo: linkedIDs.filter { $0 != definition.id },
                definitions: classDefinitions.filter { $0.id != definition.id }
            )
        }
        let updatedDefinitions = classDefinitions.filter { $0.id != definition.id }
        profiles = updatedProfiles
        classDefinitions = updatedDefinitions
        onCommitChanges?(updatedDefinitions, updatedProfiles)
    }

    private var linkedStudentCount: Int {
        profiles.filter { profile in
            !profile.className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private var unlinkedClassCount: Int {
        classDefinitions.filter { studentsLinked(to: $0) == 0 }.count
    }

    private func studentsLinked(to definition: ClassDefinitionItem) -> Int {
        return profiles.filter {
            if profileMatches(classDefinitionID: definition.id, profile: $0) {
                return true
            }

            return classNamesMatch(scheduleClassName: definition.name, profileClassName: $0.className)
        }.count
    }

    private func classDefinitionRow(_ definition: ClassDefinitionItem) -> some View {
        let accent = rowAccent(for: definition)
        let detail = [
            definition.typeDisplayName,
            definition.gradeLevel,
            definition.defaultLocation
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
        let linkedCount = studentsLinked(to: definition)
        let relinkCount = relinkCandidateCount(for: definition)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: definition.symbolName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(definition.name)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(definition.instructionalContextKind(for: teacherWorkflowMode).displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.10))
                        )

                    Text("\(linkedCount) linked")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.12))
                        )

                    if relinkCount > 0 {
                        Text("\(relinkCount) to relink")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.blue.opacity(0.12))
                            )
                    }
                }

                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Button {
                deleteDefinition(definition)
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.red.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)

            Menu {
                if relinkCount > 0 {
                    Button("Relink Students") {
                        relinkStudents(to: definition)
                    }
                }

                Button("Edit") {
                    editingDefinition = definition
                }

                Button("Delete", role: .destructive) {
                    deleteDefinition(definition)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var classDefinitionsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(definitionsTitle)
                        .font(.headline.weight(.semibold))

                    Text(
                        teacherWorkflowMode == .classroom
                            ? "Reusable class definitions keep schedules and student links aligned without extra setup."
                            : "Reusable class and group definitions keep schedules and student links aligned without extra setup."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Button {
                    showingAdd = true
                } label: {
                    Label(addDefinitionTitle, systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if supportsBulkEntry {
                    Button {
                        showingBulkEntry = true
                    } label: {
                        Label("Grid Entry", systemImage: "square.grid.3x2")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(ClassTraxSemanticColor.secondaryAction)
                }
            }

            HStack(spacing: 12) {
                summaryPill(
                    title: teacherWorkflowMode == .classroom ? "Classes" : "Groups",
                    value: "\(classDefinitions.count)",
                    accent: .blue
                )
                summaryPill(
                    title: "Linked Students",
                    value: "\(linkedStudentCount)",
                    accent: .green
                )
                summaryPill(
                    title: "Unlinked",
                    value: "\(unlinkedClassCount)",
                    accent: .orange
                )
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func rowAccent(for definition: ClassDefinitionItem) -> Color {
        definition.themeColor == .clear ? .blue : definition.themeColor
    }

    private func relinkCandidateCount(for definition: ClassDefinitionItem) -> Int {
        profiles.filter {
            !profileMatches(classDefinitionID: definition.id, profile: $0) &&
            classNamesMatch(scheduleClassName: definition.name, profileClassName: $0.className)
        }.count
    }

    private func relinkStudents(to definition: ClassDefinitionItem) {
        let updatedProfiles = profiles.map { profile in
            guard
                !profileMatches(classDefinitionID: definition.id, profile: profile),
                classNamesMatch(scheduleClassName: definition.name, profileClassName: profile.className)
            else {
                return profile
            }

            return updatingProfile(
                profile,
                linkedTo: linkedClassDefinitionIDs(for: profile) + [definition.id],
                definitions: classDefinitions
            )
        }
        profiles = updatedProfiles
        onCommitChanges?(classDefinitions, updatedProfiles)
    }

    private func summaryPill(title: String, value: String, accent: Color) -> some View {
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
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.10), lineWidth: 0.9)
        )
    }

    private func sectionCardBackground(accent: Color) -> some View {
        ClassTraxCardBackground(accent: accent)
    }

    private var classDefinitionsBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.05),
                Color.green.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var supportsBulkEntry: Bool {
        horizontalSizeClass != .compact
    }
}
