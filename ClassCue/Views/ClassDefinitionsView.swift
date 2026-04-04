import SwiftUI

struct ClassDefinitionsView: View {
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var profiles: [StudentSupportProfile]

    @State private var showingAdd = false
    @State private var editingDefinition: ClassDefinitionItem?

    var body: some View {
        List {
            Section {
                classDefinitionsOverviewCard
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if classDefinitions.isEmpty {
                Section("Saved Classes") {
                    ContentUnavailableView(
                        "No Saved Classes Yet",
                        systemImage: "books.vertical",
                        description: Text("Add your classes once, then reuse them in schedules and student supports.")
                    )
                    .listRowBackground(sectionCardBackground(accent: .blue))
                }
            } else {
                Section("Saved Classes") {
                    ForEach(classDefinitions) { definition in
                        Button {
                            editingDefinition = definition
                        } label: {
                            classDefinitionRow(definition)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(sectionCardBackground(accent: rowAccent(for: definition)))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") {
                                editingDefinition = definition
                            }
                            .tint(.orange)

                            Button("Delete", role: .destructive) {
                                deleteDefinition(definition)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Saved Classes")
        .scrollContentBackground(.hidden)
        .background(classDefinitionsBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    ToolbarMenuLabel(title: "Add", systemImage: "plus", expanded: false)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EditClassDefinitionView(classDefinitions: $classDefinitions, studentProfiles: $profiles, existing: nil)
        }
        .sheet(item: $editingDefinition) { definition in
            EditClassDefinitionView(classDefinitions: $classDefinitions, studentProfiles: $profiles, existing: definition)
        }
    }

    private func deleteDefinition(_ definition: ClassDefinitionItem) {
        profiles = profiles.map { profile in
            let linkedIDs = linkedClassDefinitionIDs(for: profile)
            guard linkedIDs.contains(definition.id) else { return profile }
            return updatingProfile(
                profile,
                linkedTo: linkedIDs.filter { $0 != definition.id },
                definitions: classDefinitions.filter { $0.id != definition.id }
            )
        }
        classDefinitions.removeAll { $0.id == definition.id }
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

                    Text("\(linkedCount) linked")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                }

                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var classDefinitionsOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved Classes")
                        .font(.headline.weight(.semibold))

                    Text("Reusable class definitions keep schedules and student links aligned without extra setup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Button {
                    showingAdd = true
                } label: {
                    Label("Add Class", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                summaryPill(
                    title: "Classes",
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
        .background(sectionCardBackground(accent: .blue))
    }

    private func rowAccent(for definition: ClassDefinitionItem) -> Color {
        definition.themeColor == .clear ? .blue : definition.themeColor
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
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 1)
        )
    }

    private func sectionCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.08),
                        Color(.secondarySystemGroupedBackground).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
}
