//
//  StudentDirectoryView.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct StudentDirectoryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var profiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    let showsRosterDataTools: Bool

    private enum GroupingMode: String, CaseIterable, Identifiable {
        case none = "All"
        case className = "Class"
        case gradeLevel = "Grade"

        var id: String { rawValue }
    }

    private enum NameSortMode: String, CaseIterable, Identifiable {
        case firstName = "First"
        case lastName = "Last"

        var id: String { rawValue }
    }

    private struct HomeworkSession: Identifiable {
        let kind: FollowUpNoteItem.Kind
        let context: String
        let studentOrGroup: String

        var id: String {
            "\(kind.rawValue)-\(context)-\(studentOrGroup)"
        }
    }

    @State private var showingAdd = false
    @State private var showingSavedClasses = false
    @State private var editingProfile: StudentSupportProfile?
    @State private var showingFileImporter = false
    @State private var showingTemplateShareSheet = false
    @State private var pastedCSVText = ""
    @State private var showingPasteImporter = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showImportSuccessAlert = false
    @State private var importSuccessMessage = ""
    @FocusState private var isPasteEditorFocused: Bool
    @State private var selection = Set<UUID>()
    @State private var showingExportOptions = false
    @State private var showingClassExportPicker = false
    @State private var showingGradeExportPicker = false
    @State private var exportClassSelection = ""
    @State private var exportGradeSelection = ""
    @State private var exportFileURL: URL?
    @State private var showingExportShareSheet = false
    @State private var searchText = ""
    @State private var groupingMode: GroupingMode = .none
    @State private var nameSortMode: NameSortMode = .firstName
    @State private var expandedClassSections = Set<String>()
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()
    @State private var followUpNotes: [FollowUpNoteItem] = []
    @State private var homeworkSession: HomeworkSession?
    @State private var showingHomeworkClassPicker = false
    @State private var selectedHomeworkClass = ""

    init(
        profiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        showsRosterDataTools: Bool = false
    ) {
        _profiles = profiles
        _classDefinitions = classDefinitions
        self.showsRosterDataTools = showsRosterDataTools
    }

    var body: some View {
        directoryList
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
            .navigationTitle("Class List")
            .environment(\.editMode, .constant(selection.isEmpty ? .inactive : .active))
            .searchable(text: $searchText, prompt: "Search students, class, grade, or contact")
            .scrollContentBackground(.hidden)
            .background(directoryBackground)
            .listStyle(.insetGrouped)
            .onChange(of: groupingMode) { _, newValue in
                if newValue != .className {
                    expandedClassSections.removeAll()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Manage Saved Classes") {
                            showingSavedClasses = true
                        }

                        Divider()

                        Button("Import Roster CSV") {
                            showingFileImporter = true
                        }

                        Button("Paste Roster CSV") {
                            showingPasteImporter = true
                        }

                        Button("Share Roster Template") {
                            showingTemplateShareSheet = true
                        }

                        Divider()

                        Button("Export Roster CSV") {
                            showingExportOptions = true
                        }
                    } label: {
                        toolbarActionButton()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        toolbarMenuLabel(title: "New Student", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                EditStudentSupportView(profiles: $profiles, classDefinitions: classDefinitions, existing: nil)
            }
            .sheet(isPresented: $showingSavedClasses) {
                NavigationStack {
                    ClassDefinitionsView(classDefinitions: $classDefinitions, profiles: $profiles)
                }
            }
            .sheet(item: $editingProfile) { profile in
                EditStudentSupportView(profiles: $profiles, classDefinitions: classDefinitions, existing: profile)
            }
            .sheet(isPresented: $showingTemplateShareSheet) {
                StudentDirectoryShareSheet(activityItems: [makeTemplateFileURL()])
            }
            .sheet(isPresented: $showingExportShareSheet, onDismiss: {
                exportFileURL = nil
            }) {
                if let exportFileURL {
                    StudentDirectoryShareSheet(activityItems: [exportFileURL])
                }
            }
            .sheet(isPresented: $showingPasteImporter) {
                NavigationStack {
                    pasteImportView
                }
            }
            .sheet(isPresented: $showingClassExportPicker) {
                NavigationStack {
                    exportScopePickerView(
                        title: "Export Class",
                        values: availableClasses,
                        selection: $exportClassSelection,
                        buttonTitle: "Export Class"
                    ) {
                        exportProfiles(named: exportClassSelection, mode: .className)
                    }
                }
            }
            .sheet(isPresented: $showingGradeExportPicker) {
                NavigationStack {
                    exportScopePickerView(
                        title: "Export Grade",
                        values: availableGrades,
                        selection: $exportGradeSelection,
                        buttonTitle: "Export Grade"
                    ) {
                        exportProfiles(named: exportGradeSelection, mode: .gradeLevel)
                    }
                }
            }
            .sheet(isPresented: $showingHomeworkClassPicker) {
                NavigationStack {
                    exportScopePickerView(
                        title: "Missing Homework",
                        values: availableClasses,
                        selection: $selectedHomeworkClass,
                        buttonTitle: "Continue",
                        mode: .className
                    ) {
                        homeworkSession = HomeworkSession(
                            kind: .classNote,
                            context: selectedHomeworkClass,
                            studentOrGroup: ""
                        )
                        showingHomeworkClassPicker = false
                    }
                }
            }
            .sheet(item: $homeworkSession) { session in
                AddFollowUpNoteView(
                    notes: $followUpNotes,
                    suggestedContexts: availableClasses,
                    suggestedStudents: normalizedStudentDirectory(profiles.map(\.name)),
                    preferredKind: session.kind,
                    initialContext: session.context,
                    initialStudentOrGroup: session.studentOrGroup
                )
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .onAppear {
                loadFollowUpNotesIfNeeded()
            }
            .onChange(of: followUpNotes) { _, _ in
                persistFollowUpNotes()
            }
            .confirmationDialog(
                "Export Student Roster",
                isPresented: $showingExportOptions,
                titleVisibility: .visible
            ) {
                if !selection.isEmpty {
                    Button("Export Selected Students (\(selectedProfilesForExport.count))") {
                        exportSelectedProfiles()
                    }
                }

                if !availableClasses.isEmpty {
                    Button("Export Whole Class") {
                        exportClassSelection = availableClasses.first ?? ""
                        showingClassExportPicker = true
                    }
                }

                if !availableGrades.isEmpty {
                    Button("Export Grade Level") {
                        exportGradeSelection = availableGrades.first ?? ""
                        showingGradeExportPicker = true
                    }
                }

                Button("Export All Students") {
                    exportAllProfiles()
                }

                Button("Cancel", role: .cancel) { }
            }
            .alert("Import Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Import Complete", isPresented: $showImportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importSuccessMessage)
            }
    }

    @ViewBuilder
    private func toolbarMenuLabel(title: String, systemImage: String) -> some View {
        if prefersExpandedToolbar {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func toolbarActionButton() -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 32, height: 32)

            Image(systemName: "ellipsis")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel("Actions")
    }

    private var prefersExpandedToolbar: Bool {
        horizontalSizeClass != .compact
    }

    private var directoryList: some View {
        List(selection: $selection) {
            Section {
                Text(
                    showsRosterDataTools
                        ? "Use this screen for roster CSV import and export. Student editing and saved class management still live in Class List."
                        : "Manage your class list here, then save each student's class, grade, accommodations, and instructional reminders. Use Settings > Data Management for roster CSV import and export."
                )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .listRowBackground(sectionCardBackground(accent: .blue))
            }

            Section(showsRosterDataTools ? "Roster Data Tools" : "Quick Actions") {
                Button {
                    showingSavedClasses = true
                } label: {
                    actionRowLabel(
                        title: "Manage Saved Classes",
                        detail: "Add or remove reusable class names and linked class definitions",
                        systemImage: "books.vertical"
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(sectionCardBackground(accent: .indigo))

                if !availableClasses.isEmpty {
                    Button {
                        selectedHomeworkClass = availableClasses.first ?? ""
                        showingHomeworkClassPicker = true
                    } label: {
                        actionRowLabel(
                            title: "Log Class Missing Homework",
                            detail: "Report homework for one class, then keep it tied to that class in Notes",
                            systemImage: "text.book.closed"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionCardBackground(accent: .orange))
                }

                if showsRosterDataTools {
                    Button {
                        showingFileImporter = true
                    } label: {
                        actionRowLabel(
                            title: "Import Roster CSV",
                            detail: "Bring in students from a saved file",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionCardBackground(accent: .green))

                    Button {
                        showingPasteImporter = true
                    } label: {
                        actionRowLabel(
                            title: "Paste Roster CSV",
                            detail: "Paste rows directly from a spreadsheet",
                            systemImage: "doc.on.clipboard"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionCardBackground(accent: .mint))

                    Button {
                        showingExportOptions = true
                    } label: {
                        actionRowLabel(
                            title: "Export Roster CSV",
                            detail: exportSummaryText,
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionCardBackground(accent: .orange))

                    Button {
                        showingTemplateShareSheet = true
                    } label: {
                        actionRowLabel(
                            title: "Share Roster Template",
                            detail: "Send a blank CSV template for roster setup",
                            systemImage: "square.and.arrow.up.on.square"
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(sectionCardBackground(accent: .blue))
                }
            }

            Section("Roster Snapshot") {
                LabeledContent("Students") {
                    Text("\(profiles.count)")
                        .font(.headline)
                }

                LabeledContent("Classes") {
                    Text("\(availableClasses.count)")
                        .font(.headline)
                }

                LabeledContent("Grades") {
                    Text("\(availableGrades.count)")
                        .font(.headline)
                }

                if !selection.isEmpty {
                    LabeledContent("Selected") {
                        Text("\(selectedProfilesForExport.count)")
                            .font(.headline)
                    }
                }

                if let largestClass = groupedProfiles.max(by: { $0.profiles.count < $1.profiles.count }), !largestClass.title.isEmpty {
                    LabeledContent("Largest Group") {
                        Text("\(largestClass.title) (\(largestClass.profiles.count))")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Search Results") {
                        Text("\(filteredProfiles.count)")
                            .font(.headline)
                    }
                }

                if !showsRosterDataTools {
                    Button("Add New Student") {
                        showingAdd = true
                    }
                }
            }

            Section("Class Context") {
                LabeledContent("Linked to Saved Class") {
                    Text("\(linkedSavedClassCount)")
                        .font(.headline)
                }

                LabeledContent("Multi-Class Students") {
                    Text("\(multiClassStudentCount)")
                        .font(.headline)
                }

                LabeledContent("Needs Class Review") {
                    Text("\(needsClassReviewCount)")
                        .font(.headline)
                }

                Text("Saved class links determine whether student supports, notes, and class-specific context stay attached across the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Edit Saved Classes") {
                    showingSavedClasses = true
                }
            }

            if !duplicateGroups.isEmpty {
                Section("Duplicate Review") {
                    ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.first?.name ?? "Duplicate")
                                .fontWeight(.semibold)

                            Text("\(group.count) entries found. Merge duplicates to keep one complete record.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Merge Duplicates") {
                                mergeDuplicates(group)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(sectionCardBackground(accent: .orange))
                    }
                }
            }

            Section("Roster View") {
                Picker("Group By", selection: $groupingMode) {
                    ForEach(GroupingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(sectionCardBackground(accent: .indigo))

                Picker("Sort Names", selection: $nameSortMode) {
                    ForEach(NameSortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(sectionCardBackground(accent: .blue))
            }

            if filteredProfiles.isEmpty {
                Section("Saved Supports") {
                    Text("No student supports saved yet.")
                        .foregroundColor(.secondary)
                        .listRowBackground(sectionCardBackground(accent: .secondary))
                }
            } else {
                if groupingMode == .className {
                    ForEach(groupedProfiles, id: \.title) { section in
                        Section {
                            DisclosureGroup(
                                isExpanded: classSectionBinding(for: section.title)
                            ) {
                                ForEach(section.profiles) { profile in
                                    profileRow(profile)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(section.title)
                                            .fontWeight(.semibold)

                                        Spacer()

                                        Text("\(section.profiles.count)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(section.profiles.prefix(3).map(\.name).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .listRowBackground(sectionCardBackground(accent: .indigo))
                        }
                    }
                } else {
                    ForEach(groupedProfiles, id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.profiles) { profile in
                                profileRow(profile)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: StudentSupportProfile) -> some View {
        Button {
            editingProfile = profile
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile.name)
                        .fontWeight(.semibold)

                    gradePill(profile.gradeLevel)
                }

                let summary = profileSummary(profile)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !profile.accommodations.isEmpty {
                    Text(profile.accommodations)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if !profile.prompts.isEmpty {
                    Text(profile.prompts)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No accommodations or prompts saved yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sectionCardBackground(accent: accent(for: profile)))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(selection.contains(profile.id) ? "Deselect" : "Select") {
                toggleSelection(for: profile)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Homework") {
                homeworkSession = HomeworkSession(
                    kind: .studentNote,
                    context: firstClassContext(for: profile),
                    studentOrGroup: profile.name
                )
            }
            .tint(.blue)

            Button("Edit") {
                editingProfile = profile
            }
            .tint(.orange)

            Button("Delete", role: .destructive) {
                deleteProfile(profile)
            }
        }
    }

    private var directoryBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.05),
                Color.pink.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var exportSummaryText: String {
        if !selection.isEmpty {
            let count = selectedProfilesForExport.count
            return "\(count) selected student\(count == 1 ? "" : "s") ready to export"
        }

        return "\(profiles.count) total student\(profiles.count == 1 ? "" : "s") across \(availableClasses.count) class\(availableClasses.count == 1 ? "" : "es")"
    }

    private var linkedSavedClassCount: Int {
        profiles.filter {
            $0.classDefinitionID != nil || !$0.classDefinitionIDs.isEmpty
        }.count
    }

    private var multiClassStudentCount: Int {
        profiles.filter {
            Set($0.classDefinitionIDs).count > 1
        }.count
    }

    private var needsClassReviewCount: Int {
        profiles.filter { profile in
            let hasSavedClassLink = profile.classDefinitionID != nil || !profile.classDefinitionIDs.isEmpty
            let hasTypedClassName = !classSummary(for: profile, in: classDefinitions).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return !hasSavedClassLink && hasTypedClassName
        }.count
    }

    private func actionRowLabel(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func accent(for profile: StudentSupportProfile) -> Color {
        let grade = normalizedStudentKey(profile.gradeLevel)
        if grade.contains("prek") || grade == "k" {
            return .pink
        }
        if grade.contains("1") || grade.contains("2") || grade.contains("3") {
            return .orange
        }
        if grade.contains("4") || grade.contains("5") {
            return .green
        }
        if grade.contains("6") || grade.contains("7") || grade.contains("8") {
            return .blue
        }
        return .indigo
    }

    private func sectionCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.10),
                        Color(.secondarySystemBackground).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }

    private func classSectionBinding(for title: String) -> Binding<Bool> {
        Binding(
            get: { expandedClassSections.contains(title) },
            set: { isExpanded in
                if isExpanded {
                    expandedClassSections.insert(title)
                } else {
                    expandedClassSections.remove(title)
                }
            }
        )
    }

    @ViewBuilder
    private func gradePill(_ gradeLevel: String) -> some View {
        let color = GradeLevelOption.color(for: gradeLevel)
        let label = GradeLevelOption.pillLabel(for: gradeLevel)

        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(color == .yellow ? Color.black.opacity(0.8) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }

    private var pasteImportView: some View {
        Form {
            Section {
                Text("Paste CSV rows copied from Google Sheets. Expected columns: `name,className,gradeLevel,accommodations,prompts`.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Additional optional columns: `graduationYear,parentNames,parentPhoneNumbers,parentEmails,studentEmail`.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("This imports students and class links only. It does not modify the schedule.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section("CSV Text") {
                TextEditor(text: $pastedCSVText)
                    .font(.body.monospaced())
                    .focused($isPasteEditorFocused)
                    .frame(minHeight: 260)
            }

            Section {
                Button {
                    importPastedCSV()
                } label: {
                    Label("Import Students", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Paste Student CSV")
        .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isPasteEditorFocused {
                        Button("Done") {
                            handlePasteImportDone()
                        }
                    }
                }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear") {
                    pastedCSVText = ""
                }
                .disabled(pastedCSVText.isEmpty)
            }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        handlePasteImportDone()
                    }
                }
            }
        }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importCSV(from: url)
        case .failure(let error):
            errorMessage = "Unable to open the selected file: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func importCSV(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()

        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            let imported = try parseCSV(csvString)
            mergeImportedProfiles(imported)
        } catch let error as StudentImportError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to read CSV: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func importPastedCSV() {
        do {
            let imported = try parseCSV(pastedCSVText)
            pastedCSVText = ""
            showingPasteImporter = false
            mergeImportedProfiles(imported)
        } catch let error as StudentImportError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to import pasted CSV: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func handlePasteImportDone() {
        let trimmed = pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isPasteEditorFocused = false
            return
        }

        importPastedCSV()
    }

    private func parseCSV(_ csv: String) throws -> [StudentSupportProfile] {
        let rows = csv
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let parsedRows = rows.map(parseCSVColumns)
        let headerLookup = parsedRows.first.flatMap { isHeaderRow($0) ? columnIndexLookup(for: $0) : nil }
        var imported: [StudentSupportProfile] = []

        for (index, parts) in parsedRows.enumerated() {
            let trimmedParts = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if index == 0, isHeaderRow(trimmedParts) {
                continue
            }

            guard !trimmedParts.isEmpty else {
                throw StudentImportError.invalidColumnCount(rowNumber: index + 1)
            }

            let name = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["name", "student", "studentname"], fallbackIndex: 0)
            let className = sanitizedImportedClassName(
                csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["classname", "class", "savedclass"], fallbackIndex: 1)
            )
            let gradeLevel = GradeLevelOption.normalized(
                csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["gradelevel", "grade"], fallbackIndex: 2)
            )
            let accommodations = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["accommodations", "supports"], fallbackIndex: 3)
            let prompts = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["prompts", "reminders", "notes"], fallbackIndex: 4)
            let graduationYear = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["graduationyear", "classof"], fallbackIndex: 5)
            let parentNames = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["parentnames", "parents"], fallbackIndex: 6)
            let parentPhoneNumbers = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["parentphonenumbers", "parentphone", "phonenumber"], fallbackIndex: 7)
            let parentEmails = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["parentemails", "parentemail"], fallbackIndex: 8)
            let studentEmail = csvValue(in: trimmedParts, headerLookup: headerLookup, keys: ["studentemail", "email"], fallbackIndex: 9)

            guard !name.isEmpty else {
                throw StudentImportError.missingName(rowNumber: index + 1)
            }

            imported.append(
                StudentSupportProfile(
                    name: name,
                    className: className,
                    gradeLevel: gradeLevel,
                    classDefinitionID: exactClassDefinitionMatch(
                        name: className,
                        gradeLevel: gradeLevel,
                        in: classDefinitions
                    )?.id,
                    classDefinitionIDs: exactClassDefinitionMatch(
                        name: className,
                        gradeLevel: gradeLevel,
                        in: classDefinitions
                    ).map { [$0.id] } ?? [],
                    graduationYear: graduationYear,
                    parentNames: parentNames,
                    parentPhoneNumbers: parentPhoneNumbers,
                    parentEmails: parentEmails,
                    studentEmail: studentEmail,
                    accommodations: accommodations,
                    prompts: prompts
                )
            )
        }

        return imported
    }

    private func mergeImportedProfiles(_ imported: [StudentSupportProfile]) {
        var merged = profiles

        for profile in imported {
            if let index = merged.firstIndex(where: {
                normalizedStudentKey($0.name) == normalizedStudentKey(profile.name)
            }) {
                merged[index] = mergedStudentProfile(existing: merged[index], incoming: profile)
            } else {
                merged.append(profile)
            }
        }

        profiles = sortProfiles(merged.map {
            StudentSupportProfile(
                id: $0.id,
                name: $0.name,
                className: $0.className,
                gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                classDefinitionID: $0.classDefinitionID,
                classDefinitionIDs: linkedClassDefinitionIDs(for: $0),
                classContexts: $0.classContexts,
                graduationYear: $0.graduationYear,
                parentNames: $0.parentNames,
                parentPhoneNumbers: $0.parentPhoneNumbers,
                parentEmails: $0.parentEmails,
                studentEmail: $0.studentEmail,
                accommodations: $0.accommodations,
                prompts: $0.prompts
            )
        })

        searchText = ""
        groupingMode = .none
        selection.removeAll()
        expandedClassSections.removeAll()
        importSuccessMessage = "Imported \(imported.count) student\(imported.count == 1 ? "" : "s"). They are now listed under All."
        showImportSuccessAlert = true
    }

    private func isHeaderRow(_ parts: [String]) -> Bool {
        guard let first = parts.first?.lowercased() else { return false }
        return first == "name" || first == "student"
    }

    private func parseCSVColumns(_ row: String) -> [String] {
        var values: [String] = []
        var current = ""
        var isInsideQuotes = false

        for character in row {
            switch character {
            case "\"":
                isInsideQuotes.toggle()
            case "," where !isInsideQuotes:
                values.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            default:
                current.append(character)
            }
        }

        values.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return values.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }

    private func columnIndexLookup(for header: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: header.enumerated().map { index, value in
            (
                value
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "_", with: ""),
                index
            )
        })
    }

    private func csvValue(
        in parts: [String],
        headerLookup: [String: Int]?,
        keys: [String],
        fallbackIndex: Int
    ) -> String {
        if let headerLookup {
            for key in keys {
                if let index = headerLookup[key], parts.indices.contains(index) {
                    return parts[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        guard parts.indices.contains(fallbackIndex) else { return "" }
        return parts[fallbackIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedImportedClassName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized == "nsmanagedobject" || normalized == "managedobject" {
            return ""
        }

        return trimmed
    }

    private func makeTemplateFileURL() -> URL {
        let template = """
        name,className,gradeLevel,accommodations,prompts,graduationYear,parentNames,parentPhoneNumbers,parentEmails,studentEmail
        Ava Johnson,Math,5th Grade,Prefer front seating and extra wait time,Check for understanding before independent work,2033,Monica Johnson,555-123-4567,monica@example.com,ava@example.com
        Reading Group A,ELA,5th Grade,Chunk directions and provide sentence starters,Preview key vocabulary before discussion,,,,,
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classtrax-student-directory-template.csv")
        try? template.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func loadFollowUpNotesIfNeeded() {
        guard followUpNotes.isEmpty else { return }
        followUpNotes = (try? JSONDecoder().decode([FollowUpNoteItem].self, from: savedFollowUpNotes)) ?? []
    }

    private func persistFollowUpNotes() {
        savedFollowUpNotes = (try? JSONEncoder().encode(followUpNotes)) ?? Data()
    }

    private func profileSummary(_ profile: StudentSupportProfile) -> String {
        let summary = classSummary(for: profile, in: classDefinitions)
        return [summary, profile.gradeLevel, profile.graduationYear.isEmpty ? "" : "Class of \(profile.graduationYear)"]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var availableClasses: [String] {
        profiles
            .flatMap { profile in
                classSummary(for: profile, in: classDefinitions)
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicates()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func firstClassContext(for profile: StudentSupportProfile) -> String {
        let linkedNames = linkedClassNames(for: profile, in: classDefinitions)
        if let first = linkedNames.first {
            return first
        }

        return classSummary(for: profile, in: classDefinitions)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    private var availableGrades: [String] {
        profiles
            .map(\.gradeLevel)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicates()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func toggleSelection(for profile: StudentSupportProfile) {
        if selection.contains(profile.id) {
            selection.remove(profile.id)
        } else {
            selection.insert(profile.id)
        }
    }

    private func deleteProfile(_ profile: StudentSupportProfile) {
        profiles.removeAll { $0.id == profile.id }
        selection.remove(profile.id)
    }

    private func mergeDuplicates(_ group: [StudentSupportProfile]) {
        guard let mergedProfile = mergedStudentProfile(from: group) else { return }
        let duplicateIDs = Set(group.map(\.id))
        profiles.removeAll { duplicateIDs.contains($0.id) }
        profiles.append(mergedProfile)
        profiles = sortProfiles(profiles)
        selection.subtract(duplicateIDs)
    }

    private func exportAllProfiles() {
        export(sortProfiles(profiles), filename: "classtrax-students-all.csv")
    }

    private func exportSelectedProfiles() {
        let selected = selectedProfilesForExport
        export(selected, filename: "classtrax-students-selected.csv")
    }

    private enum ExportMode {
        case className
        case gradeLevel
    }

    private func exportProfiles(named value: String, mode: ExportMode) {
        let safeValue = value.replacingOccurrences(of: " ", with: "-")
        let filtered = filteredProfilesForExport(named: value, mode: mode)

        switch mode {
        case .className:
            export(filtered, filename: "classtrax-class-\(safeValue).csv")
        case .gradeLevel:
            export(filtered, filename: "classtrax-grade-\(safeValue).csv")
        }
    }

    private func export(_ profiles: [StudentSupportProfile], filename: String) {
        guard !profiles.isEmpty else {
            errorMessage = "There are no student records in that export scope yet."
            showErrorAlert = true
            return
        }

        let header = "name,className,gradeLevel,accommodations,prompts,graduationYear,parentNames,parentPhoneNumbers,parentEmails,studentEmail"
        let rows = profiles.map { profile in
            [
                profile.name,
                exportClassNames(for: profile),
                profile.gradeLevel,
                profile.accommodations,
                profile.prompts,
                profile.graduationYear,
                profile.parentNames,
                profile.parentPhoneNumbers,
                profile.parentEmails,
                profile.studentEmail
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = "Could not create the export file: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        exportFileURL = url
        showingExportShareSheet = true
    }

    private func exportClassNames(for profile: StudentSupportProfile) -> String {
        let linkedNames = linkedClassNames(for: profile, in: classDefinitions)
        if !linkedNames.isEmpty {
            return linkedNames.joined(separator: "; ")
        }

        return classSummary(for: profile, in: classDefinitions).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private var selectedProfilesForExport: [StudentSupportProfile] {
        sortProfiles(profiles.filter { selection.contains($0.id) })
    }

    private func filteredProfilesForExport(named value: String, mode: ExportMode) -> [StudentSupportProfile] {
        switch mode {
        case .className:
            return profiles.filter {
                linkedClassNames(for: $0, in: classDefinitions).contains(where: {
                    $0.localizedCaseInsensitiveCompare(value) == .orderedSame
                }) || classSummary(for: $0, in: classDefinitions).trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(value) == .orderedSame
            }
        case .gradeLevel:
            return profiles.filter {
                $0.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(value) == .orderedSame
            }
        }
    }

    @ViewBuilder
    private func exportScopePickerView(
        title: String,
        values: [String],
        selection: Binding<String>,
        buttonTitle: String,
        mode: ExportMode? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let exportMode = mode ?? (title == "Export Class" ? .className : .gradeLevel)
        let valueCounts = values.map { value in
            (value: value, count: filteredProfilesForExport(named: value, mode: exportMode).count)
        }
        let matchingCount = filteredProfilesForExport(named: selection.wrappedValue, mode: exportMode).count

        Form {
            Section(title) {
                Picker(title, selection: selection) {
                    ForEach(valueCounts, id: \.value) { item in
                        HStack {
                            Text(item.value)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(.secondary)
                        }
                        .tag(item.value)
                    }
                }
            }

            Section("Summary") {
                LabeledContent("Students Included", value: "\(matchingCount)")
                    .foregroundStyle(matchingCount == 0 ? .orange : .primary)
            }

            Section {
                Button(buttonTitle) {
                    action()
                    if title == "Export Class" {
                        showingClassExportPicker = false
                    } else {
                        showingGradeExportPicker = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(matchingCount == 0)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension StudentDirectoryView {
    struct StudentProfileSection {
        let title: String
        let profiles: [StudentSupportProfile]
    }

    var filteredProfiles: [StudentSupportProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sortProfiles(profiles) }

        return sortProfiles(profiles.filter { profile in
            [
                profile.name,
                classSummary(for: profile, in: classDefinitions),
                linkedClassNames(for: profile, in: classDefinitions).joined(separator: ", "),
                profile.gradeLevel,
                profile.parentNames,
                profile.parentEmails,
                profile.studentEmail
            ]
            .contains { value in
                value.localizedCaseInsensitiveContains(query)
            }
        })
    }

    var groupedProfiles: [StudentProfileSection] {
        switch groupingMode {
        case .none:
            return [StudentProfileSection(title: "Saved Supports", profiles: sortProfiles(filteredProfiles))]
        case .className:
            return groupedClassSections(from: filteredProfiles)
        case .gradeLevel:
            return groupedSections(
                from: filteredProfiles,
                using: { profile in
                    let value = profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? "Unassigned Grade" : value
                }
            )
        }
    }

    var duplicateGroups: [[StudentSupportProfile]] {
        duplicateStudentProfileGroups(in: profiles)
    }

    func groupedSections(
        from profiles: [StudentSupportProfile],
        using title: (StudentSupportProfile) -> String
    ) -> [StudentProfileSection] {
        Dictionary(grouping: profiles, by: title)
            .map { key, value in
                StudentProfileSection(
                    title: key,
                    profiles: sortProfiles(value)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func groupedClassSections(from profiles: [StudentSupportProfile]) -> [StudentProfileSection] {
        var grouped: [String: [StudentSupportProfile]] = [:]

        for profile in profiles {
            let names = linkedClassNames(for: profile, in: classDefinitions)
            let classNames = names.isEmpty
                ? classSummary(for: profile, in: classDefinitions)
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                : names

            if classNames.isEmpty {
                grouped["Unassigned Class", default: []].append(profile)
            } else {
                for name in classNames {
                    grouped[name, default: []].append(profile)
                }
            }
        }

        return grouped.map { key, value in
            StudentProfileSection(
                title: key,
                profiles: sortProfiles(value)
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func sortProfiles(_ profiles: [StudentSupportProfile]) -> [StudentSupportProfile] {
        profiles.sorted { lhs, rhs in
            let lhsKey = sortKey(for: lhs)
            let rhsKey = sortKey(for: rhs)
            if lhsKey == rhsKey {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhsKey.localizedCaseInsensitiveCompare(rhsKey) == .orderedAscending
        }
    }

    private func sortKey(for profile: StudentSupportProfile) -> String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nameSortMode == .lastName else { return trimmed }
        let parts = trimmed.split(separator: " ").map(String.init)
        guard let last = parts.last, parts.count > 1 else { return trimmed }
        let first = parts.dropLast().joined(separator: " ")
        return "\(last), \(first)"
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private enum StudentImportError: LocalizedError {
    case invalidColumnCount(rowNumber: Int)
    case missingName(rowNumber: Int)

    var errorDescription: String? {
        switch self {
        case .invalidColumnCount(let rowNumber):
            return "Row \(rowNumber) is missing required student columns."
        case .missingName(let rowNumber):
            return "Row \(rowNumber) must include a student or group name."
        }
    }
}

private struct StudentDirectoryShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
