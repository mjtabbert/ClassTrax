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
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    let showsRosterDataTools: Bool
    let onImportedStudents: (([StudentSupportProfile]) -> Void)?
    let onSavedProfiles: (([StudentSupportProfile]) -> Void)?
    let onSavedTeacherContacts: (([ClassStaffContact]) -> Void)?
    let onSavedParaContacts: (([ClassStaffContact]) -> Void)?
    let onPrepareStudentEditor: (() -> Void)?

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

    private struct DuplicateReviewSession: Identifiable {
        let profiles: [StudentSupportProfile]

        var id: String {
            profiles
                .map(\.id.uuidString)
                .sorted()
                .joined(separator: "-")
        }
    }

    private struct AddStudentSeed: Identifiable {
        let id = UUID()
        let linkedClassDefinitionIDs: [UUID]
        let className: String
        let gradeLevel: String

        static let blank = AddStudentSeed(
            linkedClassDefinitionIDs: [],
            className: "",
            gradeLevel: ""
        )
    }

    @State private var addStudentSeed: AddStudentSeed?
    @State private var showingSavedClasses = false
    @State private var showingTeacherList = false
    @State private var showingParaList = false
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
    @State private var duplicateReviewSession: DuplicateReviewSession?

    init(
        profiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>,
        showsRosterDataTools: Bool = false,
        onImportedStudents: (([StudentSupportProfile]) -> Void)? = nil,
        onSavedProfiles: (([StudentSupportProfile]) -> Void)? = nil,
        onSavedTeacherContacts: (([ClassStaffContact]) -> Void)? = nil,
        onSavedParaContacts: (([ClassStaffContact]) -> Void)? = nil,
        onPrepareStudentEditor: (() -> Void)? = nil
    ) {
        _profiles = profiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
        self.showsRosterDataTools = showsRosterDataTools
        self.onImportedStudents = onImportedStudents
        self.onSavedProfiles = onSavedProfiles
        self.onSavedTeacherContacts = onSavedTeacherContacts
        self.onSavedParaContacts = onSavedParaContacts
        self.onPrepareStudentEditor = onPrepareStudentEditor
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Student", systemImage: "plus") {
                            onPrepareStudentEditor?()
                            addStudentSeed = .blank
                        }

                        Divider()

                        Button("Manage Saved Classes") {
                            showingSavedClasses = true
                        }

                        Button("Teachers") {
                            showingTeacherList = true
                        }

                        Button("Paras") {
                            showingParaList = true
                        }

                        Divider()

                        Button("Import Student Roster CSV") {
                            showingFileImporter = true
                        }

                        Button("Paste Student Roster CSV") {
                            showingPasteImporter = true
                        }

                        Button("Share Student Roster Template") {
                            showingTemplateShareSheet = true
                        }

                        Divider()

                        Button("Export Student Roster CSV") {
                            showingExportOptions = true
                        }
                    } label: {
                        ToolbarMenuLabel(
                            title: "More",
                            systemImage: "ellipsis",
                            expanded: prefersExpandedToolbar
                        )
                    }
                }
            }
            .sheet(item: $addStudentSeed) { seed in
                EditStudentSupportView(
                    profiles: $profiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts,
                    existing: nil,
                    initialLinkedClassDefinitionIDs: seed.linkedClassDefinitionIDs,
                    initialClassName: seed.className,
                    initialGradeLevel: seed.gradeLevel,
                    onSaveProfiles: onSavedProfiles
                )
            }
            .sheet(isPresented: $showingSavedClasses) {
                NavigationStack {
                    ClassDefinitionsView(classDefinitions: $classDefinitions, profiles: $profiles)
                }
            }
            .sheet(item: $editingProfile) { profile in
                EditStudentSupportView(
                    profiles: $profiles,
                    classDefinitions: $classDefinitions,
                    teacherContacts: $teacherContacts,
                    paraContacts: $paraContacts,
                    existing: profile,
                    onSaveProfiles: onSavedProfiles
                )
            }
            .sheet(isPresented: $showingTeacherList) {
                NavigationStack {
                    SupportStaffDirectoryView(
                        title: "Teachers",
                        role: .teacher,
                        contacts: $teacherContacts,
                        onCommitContacts: { updatedContacts in
                            onSavedTeacherContacts?(updatedContacts)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingParaList) {
                NavigationStack {
                    SupportStaffDirectoryView(
                        title: "Paras",
                        role: .para,
                        contacts: $paraContacts,
                        onCommitContacts: { updatedContacts in
                            onSavedParaContacts?(updatedContacts)
                        }
                    )
                }
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
            .sheet(item: $duplicateReviewSession) { session in
                NavigationStack {
                    DuplicateStudentReviewView(
                        profiles: session.profiles,
                        classDefinitions: classDefinitions,
                        onMerge: {
                            mergeDuplicates(session.profiles)
                            duplicateReviewSession = nil
                        }
                    )
                }
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

    private var prefersExpandedToolbar: Bool {
        horizontalSizeClass != .compact
    }

    private var directoryList: some View {
        List(selection: $selection) {
            Section {
                directoryOverviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
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

                            HStack(spacing: 10) {
                                Button("Review") {
                                    duplicateReviewSession = DuplicateReviewSession(profiles: group)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button("Merge Duplicates") {
                                    mergeDuplicates(group)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(sectionCardBackground(accent: .orange))
                    }
                }
            }

            Section {
                HStack(spacing: 12) {
                    compactSelectionMenu(
                        title: "Group",
                        value: groupingMode.rawValue,
                        systemImage: "square.grid.2x2"
                    ) {
                        Picker("Group By", selection: $groupingMode) {
                            ForEach(GroupingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }

                    compactSelectionMenu(
                        title: "Sort",
                        value: nameSortMode.rawValue,
                        systemImage: "arrow.up.arrow.down"
                    ) {
                        Picker("Sort Names", selection: $nameSortMode) {
                            ForEach(NameSortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    }
                }
                .listRowBackground(sectionCardBackground(accent: .indigo))
            }

            if groupingMode == .className {
                if classRosterSections.isEmpty {
                    Section("Saved Supports") {
                        Text("No student supports saved yet.")
                            .foregroundColor(.secondary)
                            .listRowBackground(sectionCardBackground(accent: .secondary))
                    }
                } else {
                    ForEach(classRosterSections) { section in
                        Section {
                            DisclosureGroup(
                                isExpanded: classSectionBinding(for: section.id)
                            ) {
                                if let definition = section.definition {
                                    Button {
                                        openAddStudent(for: definition)
                                    } label: {
                                        Label("Add Student to \(definition.name)", systemImage: "plus.circle.fill")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 6)
                                }

                                if section.profiles.isEmpty {
                                    Text(section.definition == nil ? "No students in this group yet." : "No students linked to this saved class yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 6)
                                } else {
                                    ForEach(section.profiles) { profile in
                                        profileRow(profile)
                                    }
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

                                    if !section.summary.isEmpty {
                                        Text(section.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .listRowBackground(sectionCardBackground(accent: section.accent))
                        }
                    }
                }
            } else if filteredProfiles.isEmpty {
                Section("Saved Supports") {
                    Text("No student supports saved yet.")
                        .foregroundColor(.secondary)
                        .listRowBackground(sectionCardBackground(accent: .secondary))
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

    private var directoryOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(showsRosterDataTools ? "Student Rosters" : "Class List")
                    .font(.headline.weight(.semibold))

                Text(directoryOverviewSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !showsRosterDataTools {
                HStack(spacing: 10) {
                    overviewActionPill(title: "Student", systemImage: "plus", accent: .blue) {
                        onPrepareStudentEditor?()
                        addStudentSeed = .blank
                    }

                    overviewActionPill(title: "Teacher", systemImage: "person.badge.plus", accent: .teal) {
                        showingTeacherList = true
                    }

                    overviewActionPill(title: "Para", systemImage: "person.2.badge.plus", accent: .orange) {
                        showingParaList = true
                    }
                }
            }

            HStack(spacing: 8) {
                overviewMetricButton(title: "Students", value: "\(profiles.count)", accent: .blue) {
                    searchText = ""
                    groupingMode = .none
                }
                overviewMetricButton(title: "Classes", value: "\(classDefinitions.count)", accent: .indigo) {
                    searchText = ""
                    groupingMode = .className
                    expandedClassSections = Set(classRosterSections.map(\.id))
                }
                overviewMetricButton(title: "Teachers", value: "\(teacherContacts.count)", accent: .teal) {
                    showingTeacherList = true
                }
                overviewMetricButton(title: "Paras", value: "\(paraContacts.count)", accent: .orange) {
                    showingParaList = true
                }

                if !selection.isEmpty {
                    overviewMetric(title: "Selected", value: "\(selectedProfilesForExport.count)", accent: .green)
                }
            }

            if needsClassReviewCount > 0 || multiClassStudentCount > 0 || linkedSavedClassCount > 0 {
                HStack(spacing: 10) {
                    if linkedSavedClassCount > 0 {
                        overviewTag("\(linkedSavedClassCount) linked", accent: .indigo)
                    }
                    if multiClassStudentCount > 0 {
                        overviewTag("\(multiClassStudentCount) multi-class", accent: .orange)
                    }
                    if needsClassReviewCount > 0 {
                        Button {
                            openDuplicateReview()
                        } label: {
                            overviewTag(needsReviewTagText, accent: .red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(sectionCardBackground(accent: .blue))
    }

    private var directoryOverviewSubtitle: String {
        if let largestClass = classRosterSections
            .filter({ $0.definition != nil || !$0.profiles.isEmpty })
            .max(by: { $0.profiles.count < $1.profiles.count }), !largestClass.title.isEmpty {
            return "Largest group: \(largestClass.title) (\(largestClass.profiles.count))"
        }

        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(filteredProfiles.count) matching students"
        }

        return "Students, saved classes, and support details in one place."
    }

    @ViewBuilder
    private func overviewMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    @ViewBuilder
    private func overviewMetricButton(
        title: String,
        value: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            overviewMetric(title: title, value: value, accent: accent)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func overviewActionPill(
        title: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.16))
                    )

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func overviewTag(_ text: String, accent: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
    }

    @ViewBuilder
    private func compactSelectionMenu<Content: View>(
        title: String,
        value: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.55))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func profileRow(_ profile: StudentSupportProfile) -> some View {
        Button {
            onPrepareStudentEditor?()
            editingProfile = profile
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(profile.name)
                        .fontWeight(.semibold)

                    if profile.isSped {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Additional Supports")
                    }

                    gradePill(profile.gradeLevel)
                }

                let summary = profileSummary(profile)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                let supportLine = supportSummary(
                    for: profile,
                    teachers: teacherContacts,
                    paras: paraContacts
                )

                if !supportLine.isEmpty {
                    Text(supportLine)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else if !profile.accommodations.isEmpty {
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
                onPrepareStudentEditor?()
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

    private var needsReviewTagText: String {
        needsClassReviewCount == 1 ? "1 needs review" : "\(needsClassReviewCount) need review"
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
        GradeLevelOption.color(for: profile.gradeLevel)
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

    private func openAddStudent(for definition: ClassDefinitionItem) {
        onPrepareStudentEditor?()
        addStudentSeed = AddStudentSeed(
            linkedClassDefinitionIDs: [definition.id],
            className: definition.name,
            gradeLevel: definition.gradeLevel
        )
    }

    @ViewBuilder
    private func gradePill(_ gradeLevel: String) -> some View {
        let color = GradeLevelOption.color(for: gradeLevel)
        let label = GradeLevelOption.pillLabel(for: gradeLevel)

        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(GradeLevelOption.foregroundColor(for: gradeLevel))
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
                    isSped: false,
                    supportTeacherIDs: [],
                    supportParaIDs: [],
                    supportRooms: "",
                    supportScheduleNotes: "",
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
                isSped: $0.isSped,
                supportTeacherIDs: $0.supportTeacherIDs,
                supportParaIDs: $0.supportParaIDs,
                supportRooms: $0.supportRooms,
                supportScheduleNotes: $0.supportScheduleNotes,
                accommodations: $0.accommodations,
                prompts: $0.prompts
            )
        })

        searchText = ""
        groupingMode = .none
        selection.removeAll()
        expandedClassSections.removeAll()
        onImportedStudents?(profiles)
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

private struct DuplicateStudentReviewView: View {
    let profiles: [StudentSupportProfile]
    let classDefinitions: [ClassDefinitionItem]
    let onMerge: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var expandedProfileIDs: Set<UUID> = []

    private var mergedPreview: StudentSupportProfile? {
        mergedStudentProfile(from: profiles)
    }

    var body: some View {
        List {
            Section {
                Text("Review these student records before merging. The merged preview shows the single record that will be kept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Duplicate Records") {
                ForEach(profiles) { profile in
                    DisclosureGroup(
                        isExpanded: expandedBinding(for: profile.id)
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            duplicateFieldRow("Classes", value: classSummary(for: profile, in: classDefinitions))
                            duplicateFieldRow("Graduation Year", value: profile.graduationYear)
                            duplicateFieldRow("Parents", value: profile.parentNames)
                            duplicateFieldRow("Parent Phones", value: profile.parentPhoneNumbers)
                            duplicateFieldRow("Parent Emails", value: profile.parentEmails)
                            duplicateFieldRow("Student Email", value: profile.studentEmail)
                            duplicateFieldRow("Support Rooms", value: profile.supportRooms)
                            duplicateFieldRow("Support Schedule", value: profile.supportScheduleNotes)
                            duplicateFieldRow("Accommodations", value: profile.accommodations)
                            duplicateFieldRow("Prompts", value: profile.prompts)

                            if profile.isSped || !profile.supportTeacherIDs.isEmpty || !profile.supportParaIDs.isEmpty {
                                HStack(spacing: 8) {
                                    comparisonBadge(title: "Supports", value: profile.isSped ? "On" : "Off", accent: .green)
                                    if !profile.supportTeacherIDs.isEmpty {
                                        comparisonBadge(title: "Teachers", value: "\(profile.supportTeacherIDs.count)", accent: .blue)
                                    }
                                    if !profile.supportParaIDs.isEmpty {
                                        comparisonBadge(title: "Paras", value: "\(profile.supportParaIDs.count)", accent: .orange)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(profile.name)
                                    .font(.headline)
                                Spacer(minLength: 8)
                                gradePill(profile.gradeLevel)
                            }

                            let summary = duplicateSummaryLine(for: profile)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let mergedPreview {
                Section("Merged Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(mergedPreview.name)
                                .font(.headline)
                            Spacer(minLength: 8)
                            gradePill(mergedPreview.gradeLevel)
                        }

                        duplicateFieldRow("Classes", value: classSummary(for: mergedPreview, in: classDefinitions))
                        duplicateFieldRow("Accommodations", value: mergedPreview.accommodations)
                        duplicateFieldRow("Prompts", value: mergedPreview.prompts)
                        duplicateFieldRow("Parents", value: mergedPreview.parentNames)
                        duplicateFieldRow("Phone", value: mergedPreview.parentPhoneNumbers)
                        duplicateFieldRow("Email", value: mergedPreview.studentEmail)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Review Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            expandedProfileIDs = Set(profiles.map(\.id))
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Merge") {
                    onMerge()
                }
                .fontWeight(.semibold)
                .disabled(mergedPreview == nil)
            }
        }
    }

    @ViewBuilder
    private func duplicateFieldRow(_ title: String, value: String) -> some View {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(trimmed)
                    .font(.subheadline)
            }
        }
    }

    private func expandedBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedProfileIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedProfileIDs.insert(id)
                } else {
                    expandedProfileIDs.remove(id)
                }
            }
        )
    }

    private func duplicateSummaryLine(for profile: StudentSupportProfile) -> String {
        [
            classSummary(for: profile, in: classDefinitions),
            profile.parentNames.trimmingCharacters(in: .whitespacesAndNewlines),
            profile.studentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    @ViewBuilder
    private func comparisonBadge(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }

    @ViewBuilder
    private func gradePill(_ gradeLevel: String) -> some View {
        let normalized = GradeLevelOption.normalized(gradeLevel)
        if !normalized.isEmpty {
            Text(GradeLevelOption.pillLabel(for: normalized))
                .font(.caption2.weight(.bold))
                .foregroundStyle(GradeLevelOption.foregroundColor(for: normalized))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(GradeLevelOption.color(for: normalized), in: Capsule(style: .continuous))
        }
    }
}

struct SupportStaffDirectoryView: View {
    let title: String
    let role: SupportStaffRole
    @Binding var contacts: [ClassStaffContact]
    let onCommitContacts: (([ClassStaffContact]) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftContacts: [ClassStaffContact]
    @State private var editingContact: ClassStaffContact?
    @State private var showingAddContact = false

    init(
        title: String,
        role: SupportStaffRole,
        contacts: Binding<[ClassStaffContact]>,
        onCommitContacts: (([ClassStaffContact]) -> Void)? = nil
    ) {
        self.title = title
        self.role = role
        _contacts = contacts
        self.onCommitContacts = onCommitContacts
        let initialDrafts = contacts.wrappedValue
        _draftContacts = State(initialValue: initialDrafts)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: role == .teacher ? "person.text.rectangle" : "person.2.badge.gearshape")
                        .font(.headline)

                    Text("Manage your \(role.pluralTitle.lowercased()) here, then assign them to students with Additional Supports.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if draftContacts.isEmpty {
                Section {
                    Text("No \(role.pluralTitle.lowercased()) added yet.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)

                    addContactButton
                } header: {
                    Text(role.pluralTitle)
                } footer: {
                    Text("Add \(role.pluralTitle.lowercased()) here, then tap Done to save them for student supports.")
                }
            } else {
                Section(role.pluralTitle) {
                    ForEach(draftContacts) { contact in
                        Button {
                            editingContact = contact
                        } label: {
                            supportStaffRow(contact)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(supportStaffCardBackground(accent: role == .teacher ? .teal : .orange))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") {
                                editingContact = contact
                            }
                            .tint(.orange)

                            Button("Delete", role: .destructive) {
                                draftContacts.removeAll { $0.id == contact.id }
                            }
                        }
                    }
                }

                Section {
                    addContactButton
                } footer: {
                    Text("Tap Done to save your \(role.pluralTitle.lowercased()).")
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    commitDraftContacts()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            NavigationStack {
                SupportStaffEditorView(
                    role: role,
                    initialContact: ClassStaffContact(),
                    onSave: { contact in
                        upsertDraftContact(contact)
                        showingAddContact = false
                    },
                    onCancel: {
                        showingAddContact = false
                    }
                )
            }
        }
        .sheet(item: $editingContact) { contact in
            NavigationStack {
                SupportStaffEditorView(
                    role: role,
                    initialContact: contact,
                    onSave: { updatedContact in
                        upsertDraftContact(updatedContact)
                        editingContact = nil
                    },
                    onCancel: {
                        editingContact = nil
                    }
                )
            }
        }
    }

    private var addContactButton: some View {
        Button {
            showingAddContact = true
        } label: {
            Label("Add \(role.title)", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func commitDraftContacts() {
        let committedContacts = draftContacts
            .map(normalizedContact(_:))
            .filter {
                ![
                    $0.name,
                    $0.room,
                    $0.cell,
                    $0.extensionNumber,
                    $0.emailAddress,
                    $0.subject
                ].allSatisfy(\.isEmpty)
            }
            .sorted { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
        contacts = committedContacts
        onCommitContacts?(committedContacts)
    }

    private func upsertDraftContact(_ contact: ClassStaffContact) {
        let normalized = normalizedContact(contact)
        guard ![
            normalized.name,
            normalized.room,
            normalized.cell,
            normalized.extensionNumber,
            normalized.emailAddress,
            normalized.subject
        ].allSatisfy(\.isEmpty) else { return }

        if let index = draftContacts.firstIndex(where: { $0.id == normalized.id }) {
            draftContacts[index] = normalized
        } else {
            draftContacts.append(normalized)
        }

        draftContacts.sort { $0.trimmedName.localizedCaseInsensitiveCompare($1.trimmedName) == .orderedAscending }
    }

    private func normalizedContact(_ contact: ClassStaffContact) -> ClassStaffContact {
        ClassStaffContact(
            id: contact.id,
            name: contact.name.trimmingCharacters(in: .whitespacesAndNewlines),
            room: contact.room.trimmingCharacters(in: .whitespacesAndNewlines),
            cell: contact.cell.trimmingCharacters(in: .whitespacesAndNewlines),
            extensionNumber: contact.extensionNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            emailAddress: contact.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: contact.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func contactSummary(_ contact: ClassStaffContact) -> String {
        [
            contact.room.trimmingCharacters(in: .whitespacesAndNewlines),
            contact.subject.trimmingCharacters(in: .whitespacesAndNewlines),
            contact.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    private func supportStaffCardBackground(accent: Color) -> some View {
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

    @ViewBuilder
    private func supportStaffRow(_ contact: ClassStaffContact) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill((role == .teacher ? Color.teal : Color.orange).opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: role == .teacher ? "person.text.rectangle" : "person.2.badge.gearshape")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(role == .teacher ? Color.teal : Color.orange)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New \(role.title)" : contact.name)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                let summary = contactSummary(contact)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No room, subject, or email saved yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct SupportStaffEditorView: View {
    let role: SupportStaffRole
    let initialContact: ClassStaffContact
    let onSave: (ClassStaffContact) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var room: String
    @State private var cell: String
    @State private var extensionNumber: String
    @State private var emailAddress: String
    @State private var subject: String

    init(
        role: SupportStaffRole,
        initialContact: ClassStaffContact,
        onSave: @escaping (ClassStaffContact) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.role = role
        self.initialContact = initialContact
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initialContact.name)
        _room = State(initialValue: initialContact.room)
        _cell = State(initialValue: initialContact.cell)
        _extensionNumber = State(initialValue: initialContact.extensionNumber)
        _emailAddress = State(initialValue: initialContact.emailAddress)
        _subject = State(initialValue: initialContact.subject)
    }

    var body: some View {
        Form {
            Section("Contact") {
                TextField("Name", text: $name)
                TextField("Room", text: $room)
                TextField("Subject", text: $subject)
            }

            Section("Communication") {
                TextField("Cell", text: $cell)
                    .keyboardType(.phonePad)
                TextField("Extension", text: $extensionNumber)
                    .keyboardType(.numberPad)
                TextField("Email Address", text: $emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
            }
        }
        .navigationTitle(initialContact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add \(role.title)" : "Edit \(role.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave(
                        ClassStaffContact(
                            id: initialContact.id,
                            name: name,
                            room: room,
                            cell: cell,
                            extensionNumber: extensionNumber,
                            emailAddress: emailAddress,
                            subject: subject
                        )
                    )
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private extension StudentDirectoryView {
    struct StudentProfileSection {
        let title: String
        let profiles: [StudentSupportProfile]
    }

    struct ClassRosterSection: Identifiable {
        let id: String
        let title: String
        let summary: String
        let profiles: [StudentSupportProfile]
        let accent: Color
        let definition: ClassDefinitionItem?
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

    var classRosterSections: [ClassRosterSection] {
        var sections: [ClassRosterSection] = classDefinitions.map { definition in
            let linkedProfiles = filteredProfiles.filter { profile in
                if profileMatches(classDefinitionID: definition.id, profile: profile) {
                    return true
                }

                return linkedClassDefinitionIDs(for: profile).isEmpty &&
                    classNamesMatch(scheduleClassName: definition.name, profileClassName: profile.className)
            }

            return ClassRosterSection(
                id: definition.id.uuidString,
                title: definition.name,
                summary: rosterSectionSummary(
                    profiles: linkedProfiles,
                    emptyText: definition.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                profiles: sortProfiles(linkedProfiles),
                accent: definition.themeColor == .clear ? .indigo : definition.themeColor,
                definition: definition
            )
        }

        let linkedDefinitionIDs = Set(classDefinitions.map(\.id))
        let unsavedProfiles = filteredProfiles.filter { profile in
            Set(linkedClassDefinitionIDs(for: profile)).isDisjoint(with: linkedDefinitionIDs)
        }
        let unsavedSections = groupedClassSections(from: unsavedProfiles).map { section in
            ClassRosterSection(
                id: "custom-\(section.title)",
                title: section.title,
                summary: rosterSectionSummary(profiles: section.profiles),
                profiles: section.profiles,
                accent: .secondary,
                definition: nil
            )
        }

        sections.append(contentsOf: unsavedSections)
        return sections.sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
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

    func rosterSectionSummary(profiles: [StudentSupportProfile], emptyText: String = "Saved class") -> String {
        let names = profiles.prefix(3).map(\.name)
        if !names.isEmpty {
            return names.joined(separator: ", ")
        }

        let trimmedEmptyText = emptyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedEmptyText.isEmpty ? "No linked students yet." : trimmedEmptyText
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

    private func openDuplicateReview() {
        guard let firstGroup = duplicateGroups.first else { return }
        duplicateReviewSession = DuplicateReviewSession(profiles: firstGroup)
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
