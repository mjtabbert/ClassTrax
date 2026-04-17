//
//  ImportView.swift
//  ClassTrax
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {

    @Binding var alarms: [AlarmItem]
    @Environment(\.dismiss) private var dismiss

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingFileImporter = false
    @State private var showingTemplateShareSheet = false
    @State private var pastedCSVText = ""
    @State private var showingPasteImporter = false
    @FocusState private var isPasteEditorFocused: Bool
    @State private var pendingImportedItems: [AlarmItem] = []
    @State private var showingImportModeDialog = false

    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                importOverviewCard

                actionCard(
                    title: "Import CSV File",
                    subtitle: "Choose a CSV from Files, Downloads, Drive, or another document provider.",
                    systemImage: "square.and.arrow.down",
                    accent: ClassTraxSemanticColor.primaryAction
                ) {
                    showingFileImporter = true
                }

                actionCard(
                    title: "Paste CSV Text",
                    subtitle: "Copy CSV rows from Google Sheets, Excel, or another source and paste them directly into Class Trax.",
                    systemImage: "doc.on.clipboard",
                    accent: ClassTraxSemanticColor.secondaryAction
                ) {
                    showingPasteImporter = true
                }

                actionCard(
                    title: "Get Google Sheets Template",
                    subtitle: "Exports a fillable Class Trax CSV template you can open in Google Sheets and complete.",
                    systemImage: "doc.text.magnifyingglass",
                    accent: ClassTraxSemanticColor.reviewWarning
                ) {
                    showingTemplateShareSheet = true
                }

                templateGuide
            }
            .padding()
        }
        .navigationTitle("Import CSV")
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(isPresented: $showingTemplateShareSheet) {
            ShareSheet(activityItems: [makeTemplateFileURL()])
        }
        .sheet(isPresented: $showingPasteImporter) {
            NavigationStack {
                pasteImportView
            }
        }
        .alert("Import Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "How should this import be applied?",
            isPresented: $showingImportModeDialog,
            titleVisibility: .visible
        ) {
            Button("Replace Entire Schedule") {
                applyImport(mode: .replaceAll)
            }

            Button("Replace Matching Days") {
                applyImport(mode: .replaceMatchingDays)
            }

            Button("Add / Merge Imported Blocks") {
                applyImport(mode: .merge)
            }

            Button("Cancel", role: .cancel) {
                pendingImportedItems = []
            }
        } message: {
            Text("Imported rows can replace everything, replace only the weekdays included in the CSV, or merge into the current schedule.")
        }
    }

    private var importOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bring your schedule in cleanly.")
                .font(.headline.weight(.semibold))

            Text("Import from a CSV file, paste rows directly, or start from a template when you are building a schedule outside the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                importMetric(title: "Sources", value: "Files, Paste, Template", accent: ClassTraxSemanticColor.primaryAction)
                importMetric(title: "Modes", value: "Replace or Merge", accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func importMetric(title: String, value: String, accent: Color) -> some View {
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

    private var templateGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Template Format")
                .font(.headline)

            Text("Columns: `dayOfWeek,className,gradeLevel,location,startTime,endTime,type`")
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)

            Text("Example: `2,Math,5th Grade,Room 201,08:00,08:45,Math`")
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)

            Text("Weekday values use iOS weekday numbering: 1 = Sunday, 2 = Monday, ... 7 = Saturday.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 18)
    }

    private var pasteImportView: some View {
        Form {
            Section {
                Text("Paste the CSV header and rows here. This works well with copied data from Google Sheets or Excel.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 16)
            }

            Section("CSV Input") {
                TextEditor(text: $pastedCSVText)
                    .font(.body.monospaced())
                    .focused($isPasteEditorFocused)
                    .frame(minHeight: 280)
                    .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 12)
            }

            Section {
                Button {
                    importPastedCSV()
                } label: {
                    Label("Import Pasted CSV", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ClassTraxSemanticColor.primaryAction)
                .disabled(pastedCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Paste CSV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isPasteEditorFocused ? "Hide Keyboard" : "Close") {
                    if isPasteEditorFocused {
                        isPasteEditorFocused = false
                    } else {
                        dismiss()
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

                Button("Hide Keyboard") {
                    isPasteEditorFocused = false
                }
            }
        }
    }

    private func actionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding()
            .classTraxCardChrome(accent: accent, cornerRadius: 18)
        }
        .buttonStyle(.plain)
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
            let importedItems = try parseCSV(csvString)
            queueImport(importedItems)
        } catch let error as CSVImportError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to read CSV: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func importPastedCSV() {
        do {
            let importedItems = try parseCSV(pastedCSVText)
            pastedCSVText = ""
            showingPasteImporter = false
            queueImport(importedItems)
        } catch let error as CSVImportError {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        } catch {
            errorMessage = "Failed to import pasted CSV: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func parseCSV(_ csv: String) throws -> [AlarmItem] {
        let rows = csv
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var newItems: [AlarmItem] = []

        for (index, row) in rows.enumerated() {
            let parts = row
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if index == 0, isHeaderRow(parts) {
                continue
            }

            guard parts.count >= 6 else {
                throw CSVImportError.invalidColumnCount(rowNumber: index + 1)
            }

            guard let dayOfWeek = Int(parts[0]), (1...7).contains(dayOfWeek) else {
                throw CSVImportError.invalidDay(rowNumber: index + 1)
            }

            guard let startTime = parseTime(parts[4]) else {
                throw CSVImportError.invalidTime(rowNumber: index + 1, value: parts[4])
            }

            guard let endTime = parseTime(parts[5]) else {
                throw CSVImportError.invalidTime(rowNumber: index + 1, value: parts[5])
            }

            let type = inferredType(
                typeString: parts.count >= 7 ? parts[6] : "",
                className: parts[1]
            )

            let item = AlarmItem(
                dayOfWeek: dayOfWeek,
                className: parts[1],
                location: parts[3],
                gradeLevel: GradeLevelOption.normalized(parts[2]),
                startTime: startTime,
                endTime: endTime,
                type: type
            )

            newItems.append(item)
        }

        return newItems.sorted { lhs, rhs in
            if lhs.dayOfWeek == rhs.dayOfWeek {
                return lhs.startTime < rhs.startTime
            }
            return lhs.dayOfWeek < rhs.dayOfWeek
        }
    }

    private func queueImport(_ importedItems: [AlarmItem]) {
        pendingImportedItems = importedItems
        showingImportModeDialog = true
    }

    private func applyImport(mode: ImportMode) {
        let importedItems = pendingImportedItems
        guard !importedItems.isEmpty else { return }

        switch mode {
        case .replaceAll:
            alarms = importedItems
        case .replaceMatchingDays:
            let importedDays = Set(importedItems.map(\.dayOfWeek))
            let retained = alarms.filter { !importedDays.contains($0.dayOfWeek) }
            alarms = sortSchedule(retained + importedItems)
        case .merge:
            alarms = mergeSchedule(existing: alarms, imported: importedItems)
        }

        pendingImportedItems = []
        dismiss()
    }

    private func mergeSchedule(existing: [AlarmItem], imported: [AlarmItem]) -> [AlarmItem] {
        var merged = existing

        for item in imported {
            if let index = merged.firstIndex(where: { existingItem in
                existingItem.dayOfWeek == item.dayOfWeek &&
                existingItem.className.caseInsensitiveCompare(item.className) == .orderedSame &&
                existingItem.startTime == item.startTime &&
                existingItem.endTime == item.endTime
            }) {
                merged[index] = item
            } else {
                merged.append(item)
            }
        }

        return sortSchedule(merged)
    }

    private func sortSchedule(_ items: [AlarmItem]) -> [AlarmItem] {
        items.sorted { lhs, rhs in
            if lhs.dayOfWeek == rhs.dayOfWeek {
                return lhs.startTime < rhs.startTime
            }
            return lhs.dayOfWeek < rhs.dayOfWeek
        }
    }

    private func isHeaderRow(_ parts: [String]) -> Bool {
        guard let first = parts.first?.lowercased() else { return false }
        return first == "dayofweek" || first == "day"
    }

    private func parseTime(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["H:mm", "HH:mm", "h:mm a"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }

    private func inferredType(typeString: String, className: String) -> AlarmItem.ScheduleType {
        let parsedType = parseType(typeString)
        if parsedType != .other || normalizedTypeKey(typeString).isEmpty == false {
            return parsedType
        }

        return parseType(className)
    }

    private func parseType(_ string: String) -> AlarmItem.ScheduleType {
        switch normalizedTypeKey(string) {
        case "math":
            return .math
        case "reading", "ela", "englishlanguagearts", "languagearts":
            return .ela
        case "science":
            return .science
        case "socialstudies", "socialstudy", "socialscience":
            return .socialStudies
        case "prep", "planning", "plan", "plannning":
            return .prep
        case "recess":
            return .recess
        case "lunch":
            return .lunch
        case "transition", "passing", "passingperiod":
            return .transition
        case "assembly":
            return .assembly
        case "studytime", "studyhall", "study":
            return .studyTime
        case "blank", "none", "clear":
            return .blank
        case "other", "":
            return .other
        default:
            return .other
        }
    }

    private func normalizedTypeKey(_ string: String) -> String {
        string
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func makeTemplateFileURL() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClassTrax Schedule Template.csv")
        try? templateCSV.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private var templateCSV: String {
        [
            "dayOfWeek,className,gradeLevel,location,startTime,endTime,type",
            "2,Math,5th Grade,Room 201,08:00,08:45,Math",
            "2,Reading,5th Grade,Room 201,08:50,09:35,ELA",
            "2,Science,5th Grade,Lab,09:40,10:25,Science",
            "2,Recess,5th Grade,Playground,10:25,10:40,Recess",
            "2,Lunch,5th Grade,Cafeteria,10:45,11:15,Lunch"
        ]
        .joined(separator: "\n")
    }
}

private enum CSVImportError: LocalizedError {
    case invalidColumnCount(rowNumber: Int)
    case invalidDay(rowNumber: Int)
    case invalidTime(rowNumber: Int, value: String)

    var errorDescription: String? {
        switch self {
        case .invalidColumnCount(let rowNumber):
            return "Row \(rowNumber) does not have enough columns."
        case .invalidDay(let rowNumber):
            return "Row \(rowNumber) has an invalid day value. Use 1 through 7."
        case .invalidTime(let rowNumber, let value):
            return "Row \(rowNumber) has an invalid time: \(value). Use formats like 08:30 or 8:30 AM."
        }
    }
}

private enum ImportMode {
    case replaceAll
    case replaceMatchingDays
    case merge

    func successMessage(count: Int) -> String {
        switch self {
        case .replaceAll:
            return "Imported \(count) schedule block(s) and replaced the full schedule."
        case .replaceMatchingDays:
            return "Imported \(count) schedule block(s) and replaced the matching day schedules."
        case .merge:
            return "Imported \(count) schedule block(s) and merged them into the existing schedule."
        }
    }
}
