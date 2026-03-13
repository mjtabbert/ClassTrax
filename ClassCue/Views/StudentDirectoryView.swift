//
//  StudentDirectoryView.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct StudentDirectoryView: View {
    @Binding var profiles: [StudentSupportProfile]

    private enum GroupingMode: String, CaseIterable, Identifiable {
        case none = "All"
        case className = "Class"
        case gradeLevel = "Grade"

        var id: String { rawValue }
    }

    @State private var showingAdd = false
    @State private var editingProfile: StudentSupportProfile?
    @State private var showingFileImporter = false
    @State private var showingTemplateShareSheet = false
    @State private var pastedCSVText = ""
    @State private var showingPasteImporter = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
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

    var body: some View {
        List(selection: $selection) {
            Section {
                Text("Add students or groups here, then save their class, grade, accommodations, and instructional reminders. You can also import them from a Google Sheet as CSV.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
            }

            if filteredProfiles.isEmpty {
                Section("Saved Supports") {
                    Text("No student supports saved yet.")
                        .foregroundColor(.secondary)
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
        .navigationTitle("Student Directory")
        .environment(\.editMode, .constant(selection.isEmpty ? .inactive : .active))
        .searchable(text: $searchText, prompt: "Search students, class, grade, or contact")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Import CSV File") {
                        showingFileImporter = true
                    }

                    Button("Paste CSV Text") {
                        showingPasteImporter = true
                    }

                    Button("Get Google Sheets Template") {
                        showingTemplateShareSheet = true
                    }

                    Divider()

                    Button("Export Students") {
                        showingExportOptions = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EditStudentSupportView(profiles: $profiles, existing: nil)
        }
        .sheet(item: $editingProfile) { profile in
            EditStudentSupportView(profiles: $profiles, existing: profile)
        }
        .sheet(isPresented: $showingTemplateShareSheet) {
            StudentDirectoryShareSheet(activityItems: [makeTemplateFileURL()])
        }
        .sheet(isPresented: $showingExportShareSheet) {
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
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .confirmationDialog(
            "Export Student Directory",
            isPresented: $showingExportOptions,
            titleVisibility: .visible
        ) {
            if !selection.isEmpty {
                Button("Export Selected Students") {
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
    }

    @ViewBuilder
    private func profileRow(_ profile: StudentSupportProfile) -> some View {
        Button {
            editingProfile = profile
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .fontWeight(.semibold)

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
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(selection.contains(profile.id) ? "Deselect" : "Select") {
                toggleSelection(for: profile)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Edit") {
                editingProfile = profile
            }
            .tint(.orange)

            Button("Delete", role: .destructive) {
                deleteProfile(profile)
            }
        }
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
                        isPasteEditorFocused = false
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
                    isPasteEditorFocused = false
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

    private func parseCSV(_ csv: String) throws -> [StudentSupportProfile] {
        let rows = csv
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var imported: [StudentSupportProfile] = []

        for (index, row) in rows.enumerated() {
            let parts = row
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if index == 0, isHeaderRow(parts) {
                continue
            }

            guard parts.count >= 1 else {
                throw StudentImportError.invalidColumnCount(rowNumber: index + 1)
            }

            guard !parts[0].isEmpty else {
                throw StudentImportError.missingName(rowNumber: index + 1)
            }

            imported.append(
                StudentSupportProfile(
                    name: parts[0],
                    className: parts.count >= 2 ? parts[1] : "",
                    gradeLevel: parts.count >= 3 ? GradeLevelOption.normalized(parts[2]) : "",
                    graduationYear: parts.count >= 6 ? parts[5] : "",
                    parentNames: parts.count >= 7 ? parts[6] : "",
                    parentPhoneNumbers: parts.count >= 8 ? parts[7] : "",
                    parentEmails: parts.count >= 9 ? parts[8] : "",
                    studentEmail: parts.count >= 10 ? parts[9] : "",
                    accommodations: parts.count >= 4 ? parts[3] : "",
                    prompts: parts.count >= 5 ? parts[4] : ""
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

        profiles = merged.map {
            StudentSupportProfile(
                id: $0.id,
                name: $0.name,
                className: $0.className,
                gradeLevel: GradeLevelOption.normalized($0.gradeLevel),
                graduationYear: $0.graduationYear,
                parentNames: $0.parentNames,
                parentPhoneNumbers: $0.parentPhoneNumbers,
                parentEmails: $0.parentEmails,
                studentEmail: $0.studentEmail,
                accommodations: $0.accommodations,
                prompts: $0.prompts
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isHeaderRow(_ parts: [String]) -> Bool {
        guard let first = parts.first?.lowercased() else { return false }
        return first == "name" || first == "student"
    }

    private func makeTemplateFileURL() -> URL {
        let template = """
        name,className,gradeLevel,accommodations,prompts,graduationYear,parentNames,parentPhoneNumbers,parentEmails,studentEmail
        Ava Johnson,Math,5th Grade,Prefer front seating and extra wait time,Check for understanding before independent work,2033,Monica Johnson,555-123-4567,monica@example.com,ava@example.com
        Reading Group A,ELA,5th Grade,Chunk directions and provide sentence starters,Preview key vocabulary before discussion,,,,,
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classcue-student-directory-template.csv")
        try? template.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func profileSummary(_ profile: StudentSupportProfile) -> String {
        [profile.className, profile.gradeLevel, profile.graduationYear.isEmpty ? "" : "Class of \(profile.graduationYear)"]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private var availableClasses: [String] {
        profiles
            .map(\.className)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .removingDuplicates()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selection.subtract(duplicateIDs)
    }

    private func exportAllProfiles() {
        export(profiles, filename: "classcue-students-all.csv")
    }

    private func exportSelectedProfiles() {
        let selected = profiles.filter { selection.contains($0.id) }
        export(selected, filename: "classcue-students-selected.csv")
    }

    private enum ExportMode {
        case className
        case gradeLevel
    }

    private func exportProfiles(named value: String, mode: ExportMode) {
        let filtered: [StudentSupportProfile]
        let safeValue = value.replacingOccurrences(of: " ", with: "-")

        switch mode {
        case .className:
            filtered = profiles.filter {
                $0.className.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(value) == .orderedSame
            }
            export(filtered, filename: "classcue-class-\(safeValue).csv")
        case .gradeLevel:
            filtered = profiles.filter {
                $0.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(value) == .orderedSame
            }
            export(filtered, filename: "classcue-grade-\(safeValue).csv")
        }
    }

    private func export(_ profiles: [StudentSupportProfile], filename: String) {
        guard !profiles.isEmpty else { return }

        let header = "name,className,gradeLevel,accommodations,prompts,graduationYear,parentNames,parentPhoneNumbers,parentEmails,studentEmail"
        let rows = profiles.map { profile in
            [
                profile.name,
                profile.className,
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
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportFileURL = url
        showingExportShareSheet = true
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    @ViewBuilder
    private func exportScopePickerView(
        title: String,
        values: [String],
        selection: Binding<String>,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Form {
            Section(title) {
                Picker(title, selection: selection) {
                    ForEach(values, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
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
        guard !query.isEmpty else { return profiles }

        return profiles.filter { profile in
            [
                profile.name,
                profile.className,
                profile.gradeLevel,
                profile.parentNames,
                profile.parentEmails,
                profile.studentEmail
            ]
            .contains { value in
                value.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var groupedProfiles: [StudentProfileSection] {
        switch groupingMode {
        case .none:
            return [StudentProfileSection(title: "Saved Supports", profiles: filteredProfiles)]
        case .className:
            return groupedSections(
                from: filteredProfiles,
                using: { profile in
                    let value = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? "Unassigned Class" : value
                }
            )
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
                    profiles: value.sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
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
