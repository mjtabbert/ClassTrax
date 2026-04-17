import SwiftUI
import SwiftData
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// Support types, extracted views, and TodayView extensions live here so the main
// TodayView file stays focused on screen state and composition.

// MARK: - Dashboard Configuration

enum TodayDashboardCard: String, CaseIterable, Identifiable {
    case teacherContext
    case currentClass
    case attendance
    case commitments
    case upcoming
    case tasks
    case support
    case notes
    case endOfDay
    case subPlan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teacherContext:
            return "Now"
        case .currentClass:
            return "Now & Next"
        case .attendance:
            return "Attendance"
        case .commitments:
            return "Planner Schedule"
        case .upcoming:
            return "Next Up"
        case .tasks:
            return "Planner"
        case .support:
            return "Student Support"
        case .notes:
            return "Notes"
        case .endOfDay:
            return "Closeout"
        case .subPlan:
            return "Sub Plans"
        }
    }

    var systemImage: String {
        switch self {
        case .teacherContext:
            return "sparkles"
        case .currentClass:
            return "studentdesk"
        case .attendance:
            return "checklist.checked"
        case .commitments:
            return "briefcase"
        case .upcoming:
            return "calendar.badge.clock"
        case .tasks:
            return "checklist"
        case .support:
            return "person.crop.circle.badge.checkmark"
        case .notes:
            return "square.and.pencil"
        case .endOfDay:
            return "sun.max"
        case .subPlan:
            return "doc.text"
        }
    }

    static let defaultOrder: [TodayDashboardCard] = [
        .teacherContext,
        .currentClass,
        .upcoming,
        .attendance,
        .notes,
        .tasks,
        .commitments,
        .support,
        .endOfDay,
        .subPlan
    ]

    static let defaultHidden: Set<TodayDashboardCard> = Set(allCases)
}

struct DashboardCardStyle: ViewModifier {
    let accent: Color
    let compact: Bool

    func body(content: Content) -> some View {
        content
            .padding(compact ? 11 : 13)
            .classTraxCardChrome(accent: accent, cornerRadius: 22)
    }
}

// MARK: - Homework Review

struct AttendanceNoteEditorView: View {
    private enum DraftMode: String, CaseIterable, Identifiable {
        case append = "Append"
        case replace = "Replace"

        var id: String { rawValue }
    }

    let title: String
    let helperText: String
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool
    @State private var draftMode: DraftMode
    @State private var draftText: String
    @State private var appendedText: String

    init(title: String, helperText: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.helperText = helperText
        self.initialText = initialText
        self.onSave = onSave
        _draftText = State(initialValue: initialText)
        _appendedText = State(initialValue: "")
        _draftMode = State(initialValue: initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .replace : .append)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                if !helperText.isEmpty {
                    Text(helperText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if hasExistingText {
                Picker("Edit Mode", selection: $draftMode) {
                    ForEach(DraftMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Note")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(initialText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }

            Text(draftMode == .append && hasExistingText ? "Add More" : "Note")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: editorBinding)
                .focused($isEditorFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.sentences)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(resolvedText)
                    dismiss()
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            isEditorFocused = true
        }
    }

    private var hasExistingText: Bool {
        !initialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var editorBinding: Binding<String> {
        Binding(
            get: {
                draftMode == .append && hasExistingText ? appendedText : draftText
            },
            set: { newValue in
                if draftMode == .append && hasExistingText {
                    appendedText = newValue
                } else {
                    draftText = newValue
                }
            }
        )
    }

    private var resolvedText: String {
        if draftMode == .append && hasExistingText {
            let trimmedAppend = appendedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAppend.isEmpty else {
                return initialText
            }
            return [initialText.trimmingCharacters(in: .whitespacesAndNewlines), trimmedAppend]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        return draftText
    }
}

struct DailyHomeworkReviewView: View {
    enum BrowseMode: String, CaseIterable, Identifiable {
        case grade = "Grade"
        case className = "Class"
        case student = "Student"

        var id: String { rawValue }
    }

    @Binding var attendanceRecords: [AttendanceRecord]
    let classDefinitions: [ClassDefinitionItem]
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var browseMode: BrowseMode = .grade
    @State private var editingTarget: HomeworkReviewTarget?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false

    private var dateKey: String {
        AttendanceRecord.dateKey(for: date)
    }

    private var homeworkRecords: [AttendanceRecord] {
        attendanceRecords
            .filter {
                $0.dateKey == dateKey &&
                (
                    ($0.isClassHomeworkNote && !$0.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                    (!$0.isClassHomeworkNote && !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
            }
            .sorted { lhs, rhs in
                if lhs.className.localizedCaseInsensitiveCompare(rhs.className) != .orderedSame {
                    return lhs.className.localizedCaseInsensitiveCompare(rhs.className) == .orderedAscending
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return lhs.gradeLevel.localizedCaseInsensitiveCompare(rhs.gradeLevel) == .orderedAscending
            }
    }

    private var classHomeworkRecords: [AttendanceRecord] {
        homeworkRecords.filter(\.isClassHomeworkNote)
    }

    private var absentStudentRecords: [AttendanceRecord] {
        attendanceRecords
            .filter {
                $0.dateKey == dateKey &&
                $0.isAttendanceEntry &&
                $0.status == .absent
            }
            .sorted { lhs, rhs in
                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
            }
    }

    private var studentHomeworkRecords: [AttendanceRecord] {
        let studentRecords = absentStudentRecords.filter { !$0.isClassHomeworkNote }
        let grouped = Dictionary(grouping: studentRecords) { record in
            homeworkGroupingKey(for: record)
        }

        return grouped.values.compactMap { records in
            records.sorted { lhs, rhs in
                let lhsHasDetail = !lhs.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let rhsHasDetail = !rhs.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if lhsHasDetail != rhsHasDetail {
                    return lhsHasDetail && !rhsHasDetail
                }

                if lhs.isHomeworkAssignmentOnly != rhs.isHomeworkAssignmentOnly {
                    return !lhs.isHomeworkAssignmentOnly && rhs.isHomeworkAssignmentOnly
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
            }.first
        }
    }

    private var gradeGroups: [HomeworkReviewGroup] {
        groupedRecords {
            let normalized = GradeLevelOption.normalized($0.gradeLevel)
            return normalized.isEmpty ? "No Grade" : normalized
        }
    }

    private var classGroups: [HomeworkReviewGroup] {
        groupedRecords {
            resolvedClassName(for: $0)
        }
    }

    private var studentGroups: [HomeworkReviewGroup] {
        let grouped = Dictionary(grouping: studentHomeworkRecords) { record in
            let trimmed = record.studentName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Unnamed Student" : trimmed
        }

        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { key in
            let records = (grouped[key] ?? []).sorted { lhs, rhs in
                if lhs.className.localizedCaseInsensitiveCompare(rhs.className) != .orderedSame {
                    return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
                }

                return lhs.gradeLevel.localizedCaseInsensitiveCompare(rhs.gradeLevel) == .orderedAscending
            }

            return HomeworkReviewGroup(title: key, records: records)
        }
    }

    private var activeGroups: [HomeworkReviewGroup] {
        switch browseMode {
        case .grade:
            return gradeGroups
        case .className:
            return classGroups
        case .student:
            return studentGroups
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Browse By", selection: $browseMode) {
                    ForEach(BrowseMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if classHomeworkRecords.isEmpty && studentHomeworkRecords.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Assigned Work Saved",
                        systemImage: "text.book.closed",
                        description: Text("Class homework and absent-student missing work for \(date.formatted(date: .abbreviated, time: .omitted)) will appear here.")
                    )
                }
            } else {
                Section("Summary") {
                    HStack(spacing: 10) {
                        homeworkSummaryPill(
                            title: "Assigned Work",
                            value: "\(classHomeworkRecords.count)",
                            accent: ClassTraxSemanticColor.primaryAction
                        )
                        homeworkSummaryPill(
                            title: "Missing Work",
                            value: "\(studentHomeworkRecords.count)",
                            accent: ClassTraxSemanticColor.reviewWarning
                        )
                    }
                }

                ForEach(activeGroups) { group in
                    Section {
                        let classRecords = group.records.filter(\.isClassHomeworkNote)
                        let studentRecords = group.records.filter { !$0.isClassHomeworkNote }

                        if !classRecords.isEmpty {
                            ForEach(classRecords) { record in
                                Button {
                                    openEditor(for: record)
                                } label: {
                                    HomeworkReviewRow(
                                        title: browseMode == .className ? "Assigned Work" : displayClassName(for: record),
                                        subtitle: record.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Class-level assigned work" : "\(record.gradeLevel) • Class-level assigned work",
                                        detail: record.assignedHomework,
                                        accent: .blue
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !studentRecords.isEmpty {
                            ForEach(studentRecords) { record in
                                Button {
                                    openEditor(for: record)
                                } label: {
                                    HomeworkReviewRow(
                                        title: browseMode == .student ? displayClassName(for: record) : record.studentName,
                                        subtitle: studentSubtitle(for: record),
                                        detail: record.absentHomework,
                                        accent: .orange
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        homeworkReviewSectionHeader(for: group)
                    }
                }
            }
        }
        .navigationTitle("Assigned & Missing Work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export Day Review", systemImage: "square.and.arrow.up") {
                        exportDayReview()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $editingTarget) { target in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: target.title,
                    helperText: target.helperText,
                    initialText: target.initialText,
                    onSave: { saveHomework($0, recordID: target.id) }
                )
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                HomeworkReviewShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func homeworkSummaryPill(title: String, value: String, accent: Color) -> some View {
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
        .classTraxCardChrome(accent: accent, cornerRadius: 14)
    }

    @ViewBuilder
    private func homeworkReviewSectionHeader(for group: HomeworkReviewGroup) -> some View {
        HStack {
            Text(group.title)

            Spacer(minLength: 8)

            if browseMode == .className || browseMode == .student {
                Button {
                    exportGroup(group)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func groupedRecords(key: (AttendanceRecord) -> String) -> [HomeworkReviewGroup] {
        let grouped = Dictionary(grouping: classHomeworkRecords + studentHomeworkRecords, by: key)
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { groupKey in
            let records = (grouped[groupKey] ?? []).sorted { lhs, rhs in
                if lhs.isClassHomeworkNote != rhs.isClassHomeworkNote {
                    return lhs.isClassHomeworkNote && !rhs.isClassHomeworkNote
                }

                if lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) != .orderedSame {
                    return lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
                }

                return resolvedClassName(for: lhs).localizedCaseInsensitiveCompare(resolvedClassName(for: rhs)) == .orderedAscending
            }

            return HomeworkReviewGroup(title: groupKey, records: records)
        }
    }

    private func openEditor(for record: AttendanceRecord) {
        let title: String
        let helperText: String

        if record.isClassHomeworkNote {
            title = displayClassName(for: record)
            helperText = "Edit the class-level assigned work for this block."
        } else {
            title = record.studentName
            helperText = record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Add missing work for this absent student."
                : "Edit the saved missing work for this student."
        }

        editingTarget = HomeworkReviewTarget(
            id: record.id,
            title: title,
            helperText: helperText,
            initialText: record.isClassHomeworkNote ? record.assignedHomework : record.absentHomework
        )
    }

    private func saveHomework(_ text: String, recordID: UUID) {
        guard let index = attendanceRecords.firstIndex(where: { $0.id == recordID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if attendanceRecords[index].isClassHomeworkNote && trimmed.isEmpty {
            attendanceRecords.remove(at: index)
            return
        }

        if attendanceRecords[index].isClassHomeworkNote {
            attendanceRecords[index].assignedHomework = trimmed
        } else {
            attendanceRecords[index].absentHomework = trimmed
        }
    }

    private func displayClassName(for record: AttendanceRecord) -> String {
        resolvedClassName(for: record)
    }

    private func studentSubtitle(for record: AttendanceRecord) -> String {
        let parts = [displayClassName(for: record), record.gradeLevel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Student missing work" : parts.joined(separator: " • ")
    }

    private func homeworkGroupingKey(for record: AttendanceRecord) -> String {
        let studentKey = record.studentID?.uuidString.lowercased() ?? normalizedStudentKey(record.studentName)
        let blockKey: String
        if let blockID = record.blockID {
            blockKey = blockID.uuidString.lowercased()
        } else if let classDefinitionID = record.classDefinitionID {
            blockKey = classDefinitionID.uuidString.lowercased()
        } else {
            blockKey = normalizedStudentKey(resolvedClassName(for: record))
        }

        return "\(studentKey)|\(blockKey)|\(record.dateKey)"
    }

    private func resolvedClassName(for record: AttendanceRecord) -> String {
        if let classDefinitionID = record.classDefinitionID,
           let definition = classDefinitions.first(where: { $0.id == classDefinitionID }) {
            let name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        let rawName = record.className.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawName.isEmpty || rawName.localizedCaseInsensitiveContains("managedobject") {
            return "Class Not Set"
        }

        return rawName
    }

    private func exportDayReview() {
        let titleDate = date.formatted(date: .abbreviated, time: .omitted)
        let body = exportText(
            title: "Assigned & Missing Work - \(titleDate)",
            groups: activeGroups
        )
        let filename = "classtrax-homework-review-\(dateKey).txt"
        shareExportText(body, filename: filename)
    }

    private func exportGroup(_ group: HomeworkReviewGroup) {
        let slug = normalizedStudentKey(group.title)
        let label: String
        switch browseMode {
        case .grade:
            label = "Grade"
        case .className:
            label = "Class"
        case .student:
            label = "Student"
        }

        let body = exportText(
            title: "\(label) Assigned & Missing Work - \(group.title)",
            groups: [group]
        )
        let filename = "classtrax-homework-\(label.lowercased())-\(slug.isEmpty ? "review" : slug)-\(dateKey).txt"
        shareExportText(body, filename: filename)
    }

    private func exportText(title: String, groups: [HomeworkReviewGroup]) -> String {
        var lines: [String] = [
            title,
            date.formatted(date: .complete, time: .omitted),
            ""
        ]

        for group in groups {
            lines.append(group.title)
            lines.append(String(repeating: "-", count: max(group.title.count, 8)))

            let classRecords = group.records.filter(\.isClassHomeworkNote)
            let studentRecords = group.records.filter { !$0.isClassHomeworkNote }

            if !classRecords.isEmpty {
                lines.append("Assigned Work")
                for record in classRecords {
                    let detail = record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
                    lines.append("• \(displayClassName(for: record))")
                    lines.append(detail.isEmpty ? "  Add assigned homework" : "  \(detail)")
                }
                lines.append("")
            }

            if !studentRecords.isEmpty {
                lines.append("Absent Student Missing Work")
                for record in studentRecords {
                    let detail = record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines)
                    lines.append("• \(record.studentName) — \(studentSubtitle(for: record))")
                    lines.append(detail.isEmpty ? "  Add missing work" : "  \(detail)")
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shareExportText(_ text: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            showingShareSheet = true
        } catch {
            exportURL = nil
            showingShareSheet = false
        }
    }

    private func normalizedStudentKey(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let pieces = value
            .lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
        return pieces.joined(separator: "-")
    }
}

private struct HomeworkReviewGroup: Identifiable {
    let title: String
    let records: [AttendanceRecord]

    var id: String { title }
}

private struct HomeworkReviewTarget: Identifiable {
    let id: UUID
    let title: String
    let helperText: String
    let initialText: String
}

private struct HomeworkReviewRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if detailText.isEmpty {
                Label("Add missing work", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            } else {
                Text(detailText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .contentShape(Rectangle())
    }

    private var detailText: String {
        detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct HomeworkReviewShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

// MARK: - Layout Customization

struct TodayLayoutCustomizationView: View {
    private enum LayoutProfile: String, CaseIterable, Identifiable {
        case recommended
        case planner
        case support

        var id: String { rawValue }
    }

    @Binding var cards: [TodayDashboardCard]
    @Binding var hiddenCards: Set<TodayDashboardCard>
    @Environment(\.dismiss) private var dismiss
    @AppStorage("teacher_workflow_mode_v1") private var teacherWorkflowModeRawValue = TeacherWorkflowMode.classroom.rawValue
    @State private var showingAdvancedControls = false

    private var teacherWorkflowMode: TeacherWorkflowMode {
        TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom
    }

    private var orderedCards: [TodayDashboardCard] {
        cards
    }

    private var isUsingDefaultLayout: Bool {
        cards == TodayDashboardCard.defaultOrder &&
        hiddenCards == TodayDashboardCard.defaultHidden
    }

    private var visibleCardCount: Int {
        orderedCards.filter { !hiddenCards.contains($0) }.count
    }

    var body: some View {
        List {
            Section("Default Layout") {
                Text("Start with a strong default instead of tuning everything by hand. Now, Next Up, and the live class or group stay near the top.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                layoutProfileButton(
                    profile: .recommended,
                    title: recommendedLayoutTitle,
                    detail: recommendedLayoutSummary
                )

                layoutProfileButton(
                    profile: .planner,
                    title: "Planner Heavy",
                    detail: "Show more planning surfaces, including planner schedule and end-of-day wrap-up."
                )

                layoutProfileButton(
                    profile: .support,
                    title: "Support Heavy",
                    detail: "Keep student support, attendance, and notes surfaces closer to the top."
                )
            }

            Section("Layout Status") {
                HStack(spacing: 12) {
                    layoutMetric(title: "Visible", value: "\(visibleCardCount)", accent: .blue)
                    layoutMetric(title: "Hidden", value: "\(hiddenCards.count)", accent: .orange)
                    layoutMetric(title: "Mode", value: teacherWorkflowMode.shortLabel, accent: .purple)
                }

                Button(showingAdvancedControls ? "Hide Advanced Controls" : "Show Advanced Controls") {
                    showingAdvancedControls.toggle()
                }
            }

            if showingAdvancedControls {
                Section("Shown on Today") {
                    ForEach(orderedCards, id: \.id) { card in
                        visibilityRow(for: card)
                    }
                }

                Section("Card Order") {
                    ForEach(orderedCards, id: \.id) { card in
                        orderingRow(for: card)
                    }
                    .onMove(perform: moveCards)
                }
            }
        }
        .navigationTitle("Customize Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Reset") {
                    cards = TodayDashboardCard.defaultOrder
                    hiddenCards = TodayDashboardCard.defaultHidden
                }
                .disabled(isUsingDefaultLayout)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
    }

    private var recommendedLayoutTitle: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Recommended Classroom Layout"
        case .resourceSped:
            return "Recommended Support Layout"
        case .hybrid:
            return "Recommended Hybrid Layout"
        }
    }

    private var recommendedLayoutSummary: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Lead with the live context, next up, attendance, planner, and notes."
        case .resourceSped:
            return "Keep support, attendance, planner, and notes visible without dashboard clutter."
        case .hybrid:
            return "Balance class flow, student support, planner, and notes without overloading the screen."
        }
    }

    private func layoutProfileButton(profile: LayoutProfile, title: String, detail: String) -> some View {
        Button {
            applyLayoutProfile(profile)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func layoutMetric(title: String, value: String, accent: Color) -> some View {
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

    private func applyLayoutProfile(_ profile: LayoutProfile) {
        switch profile {
        case .recommended:
            switch teacherWorkflowMode {
            case .classroom:
                cards = [.teacherContext, .currentClass, .upcoming, .attendance, .notes, .tasks, .commitments, .support, .endOfDay, .subPlan]
                hiddenCards = [.support, .subPlan]
            case .resourceSped:
                cards = [.teacherContext, .currentClass, .support, .attendance, .notes, .upcoming, .tasks, .commitments, .endOfDay, .subPlan]
                hiddenCards = [.commitments, .subPlan]
            case .hybrid:
                cards = [.teacherContext, .currentClass, .attendance, .support, .upcoming, .notes, .tasks, .commitments, .endOfDay, .subPlan]
                hiddenCards = [.subPlan]
            }
        case .planner:
            cards = [.teacherContext, .currentClass, .upcoming, .tasks, .commitments, .notes, .attendance, .endOfDay, .support, .subPlan]
            hiddenCards = [.support]
        case .support:
            cards = [.teacherContext, .currentClass, .support, .attendance, .notes, .upcoming, .tasks, .subPlan, .commitments, .endOfDay]
            hiddenCards = [.commitments, .endOfDay]
        }
    }

    private func visibilityBinding(for card: TodayDashboardCard) -> Binding<Bool> {
        Binding(
            get: { !hiddenCards.contains(card) },
            set: { isVisible in
                if isVisible {
                    hiddenCards.remove(card)
                } else {
                    hiddenCards.insert(card)
                }
            }
        )
    }

    private func visibilityRow(for card: TodayDashboardCard) -> some View {
        let isHidden = hiddenCards.contains(card)

        return Toggle(isOn: visibilityBinding(for: card)) {
            HStack {
                Label(card.title, systemImage: card.systemImage)

                Spacer()

                Text(isHidden ? "Hidden" : "Shown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isHidden ? Color.secondary : Color.green)
            }
            .opacity(isHidden ? 0.62 : 1.0)
        }
    }

    private func orderingRow(for card: TodayDashboardCard) -> some View {
        let isHidden = hiddenCards.contains(card)

        return HStack {
            Label(card.title, systemImage: card.systemImage)
                .opacity(isHidden ? 0.62 : 1.0)

            Spacer()

            if isHidden {
                Text("Hidden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                    )
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Warnings and Live Activity

struct InAppWarning: Identifiable, Equatable {
    let item: AlarmItem
    let minutesRemaining: Int

    var id: String {
        "\(item.id.uuidString)-\(minutesRemaining)"
    }

    var title: String {
        switch minutesRemaining {
        case 5:
            return "5 Minute Warning"
        case 2:
            return "2 Minute Warning"
        default:
            return "1 Minute Warning"
        }
    }

    var accentColor: Color {
        switch minutesRemaining {
        case 5:
            return .yellow
        case 2:
            return .orange
        default:
            return .red
        }
    }

    var roomText: String {
        let trimmed = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Room not set" : trimmed
    }

    var timeText: String {
        "\(item.start.formatted(date: .omitted, time: .shortened)) - \(item.end.formatted(date: .omitted, time: .shortened))"
    }
}

struct LiveActivitySnapshot: Equatable {
    let className: String
    let room: String
    let endTime: Date
    let isHeld: Bool
    let iconName: String
    let nextClassName: String
    let nextIconName: String
}

struct InAppWarningBanner: View {
    let warning: InAppWarning

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(warning.accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(pulse ? 1.18 : 0.92)
                    .opacity(pulse ? 0.15 : 0.45)

                Image(systemName: "bell.badge.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(warning.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title.uppercased())
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(warning.accentColor)

                Text(warning.item.className)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Text("\(warning.timeText) • \(warning.roomText)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(warning.accentColor.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: warning.accentColor.opacity(0.18), radius: 18, y: 8)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Attendance and Homework Sessions

struct AttendanceSession: Identifiable {
    let item: AlarmItem
    let date: Date
    let schedule: [AlarmItem]
    let students: [StudentSupportProfile]
    let targetClassDefinitionID: UUID?
    let targetTitle: String?

    var id: String { "\(item.id.uuidString)-\(targetClassDefinitionID?.uuidString ?? "all")" }
}

struct HomeworkCaptureSession: Identifiable {
    let item: AlarmItem
    let date: Date
    let targetClassDefinitionID: UUID?
    let targetTitle: String?

    var id: String { "\(item.id.uuidString)-\(targetClassDefinitionID?.uuidString ?? "all")" }
}

struct AttendanceEditorView: View {
    private enum StatusChoice: String, CaseIterable, Identifiable {
        case present = "Present"
        case absent = "Absent"
        case tardy = "Tardy"
        case excused = "Excused"

        var id: String { rawValue }

        var status: AttendanceRecord.Status {
            switch self {
            case .present: return .present
            case .absent: return .absent
            case .tardy: return .tardy
            case .excused: return .excused
            }
        }
    }

    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]
    let targetClassDefinitionID: UUID?
    let targetTitle: String?
    let onCommit: ([AttendanceRecord]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var baseRecords: [AttendanceRecord]
    @State private var draftClassRecords: [AttendanceRecord]
    @State private var classAssignedHomework: String
    @State private var showingClassNoteEditor = false
    @State private var editingStudentHomework: StudentSupportProfile?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var didCommit = false

    init(
        item: AlarmItem,
        date: Date,
        students: [StudentSupportProfile],
        targetClassDefinitionID: UUID? = nil,
        targetTitle: String? = nil,
        records: [AttendanceRecord],
        onCommit: @escaping ([AttendanceRecord]) -> Void
    ) {
        self.item = item
        self.date = date
        self.students = students
        self.targetClassDefinitionID = targetClassDefinitionID
        self.targetTitle = targetTitle
        self.onCommit = onCommit
        let dateKey = AttendanceRecord.dateKey(for: date)
        let splitRecords = Self.splitRecords(records, for: item, dateKey: dateKey, targetClassDefinitionID: targetClassDefinitionID)
        _baseRecords = State(initialValue: splitRecords.base)
        _draftClassRecords = State(initialValue: splitRecords.currentClass)
        _classAssignedHomework = State(initialValue: Self.defaultAssignedHomework(from: splitRecords.currentClass))
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: date)
    }

    private var normalizedGrade: String {
        GradeLevelOption.normalized(item.gradeLevel)
    }

    private var currentClassRecords: [AttendanceRecord] {
        draftClassRecords.filter(\.isAttendanceEntry)
    }

    private var recordsByStudentID: [UUID: AttendanceRecord] {
        currentClassRecords.reduce(into: [UUID: AttendanceRecord]()) { partialResult, record in
            if let studentID = record.studentID {
                partialResult[studentID] = record
            }
        }
    }

    private var unmarkedCount: Int {
        students.filter { status(for: $0) == nil }.count
    }

    private var absentCount: Int {
        students.filter { status(for: $0) == .absent }.count
    }

    private var tardyCount: Int {
        students.filter { status(for: $0) == .tardy }.count
    }

    private var excusedCount: Int {
        students.filter { status(for: $0) == .excused }.count
    }

    private var earlierAbsentStudents: [StudentSupportProfile] {
        students.filter { student in
            status(for: student) == nil && earlierAbsentRecord(for: student) != nil
        }
    }

    private var markedStudentKeys: Set<String> {
        Set(
            currentClassRecords
                .compactMap { record in
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName)
                }
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetTitle ?? item.className)
                        .font(.headline)
                    Text("\(date.formatted(date: .abbreviated, time: .omitted)) • \(item.gradeLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                attendanceSummaryCard
            }

            Section("Assigned Homework") {
                Button(classAssignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Set Assigned Work" : "Edit Assigned Work") {
                    showingClassNoteEditor = true
                }
                .tint(ClassTraxSemanticColor.primaryAction)

                if !classAssignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(classAssignedHomework)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 16)
                }
            }

            Section {
                Button("Mark Unmarked Present") {
                    markRemainingPresent()
                }
                .tint(ClassTraxSemanticColor.success)
            }

            Section("Students") {
                ForEach(students) { student in
                    studentRow(student)
                }
            }
        }
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    exportAttendance()
                }
                .disabled(students.isEmpty)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    commit()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingClassNoteEditor) {
            NavigationStack {
                AttendanceNoteEditorView(
                    title: targetTitle ?? item.className,
                    helperText: "This is the class-level assigned homework for this block.",
                    initialText: classAssignedHomework,
                    onSave: {
                        classAssignedHomework = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        upsertClassHomeworkRecord()
                    }
                )
            }
        }
        .sheet(item: $editingStudentHomework) { student in
            NavigationStack {
                AttendanceNoteEditorView(
                    title: student.name,
                    helperText: "Edit the saved missing work for this absent student.",
                    initialText: existingRecord(for: student)?.absentHomework ?? "",
                    onSave: { updateHomework($0, for: student) }
                )
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .onDisappear {
            commit()
        }
    }

    private func studentRow(_ student: StudentSupportProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.name)
                        .font(.body.weight(.semibold))
                    if !student.accommodations.isEmpty {
                        Text(student.accommodations)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(statusLabel(for: student))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(StatusChoice.allCases) { choice in
                    Button {
                        setStatus(choice.status, for: student)
                    } label: {
                        Text(choice.rawValue)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(status(for: student) == choice.status ? tint(for: choice.status) : tint(for: choice.status).opacity(0.28))
                }
            }
            .font(.caption)

            if let studentStatus = status(for: student), studentStatus != .present {
                VStack(alignment: .leading, spacing: 6) {
                    if studentStatus == .absent && !classAssignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Assigned: \(classAssignedHomework)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text(
                            existingRecord(for: student)?.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                ? "Missing Work: \(existingRecord(for: student)?.absentHomework ?? "")"
                                : "Missing Work not added yet"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                        Spacer()

                        Button(existingRecord(for: student)?.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "Edit" : "Add") {
                            editingStudentHomework = student
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(14)
        .classTraxCardChrome(accent: statusAccent(for: student), cornerRadius: 16)
    }

    private func status(for student: StudentSupportProfile) -> AttendanceRecord.Status? {
        guard let existing = existingRecord(for: student) else { return nil }
        return existing.status
    }

    private func attendanceMatchKey(studentID: UUID?, studentName: String) -> String? {
        if let studentID {
            return studentID.uuidString.lowercased()
        }

        let normalizedName = normalizedStudentKey(studentName)
        return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
    }

    private func statusLabel(for student: StudentSupportProfile) -> String {
        status(for: student)?.rawValue ?? "Unmarked"
    }

    private func setStatus(_ newStatus: AttendanceRecord.Status, for student: StudentSupportProfile) {
        if status(for: student) == newStatus {
            clearStatus(for: student)
            return
        }

        if let index = recordIndex(for: student) {
            draftClassRecords[index].status = newStatus
            if newStatus == .present {
                draftClassRecords[index].absentHomework = ""
            }
        } else {
            draftClassRecords.append(
                AttendanceRecord(
                    dateKey: dateKey,
                    className: targetTitle ?? item.className,
                    gradeLevel: normalizedGrade,
                    studentName: student.name,
                    studentID: student.id,
                    classDefinitionID: targetClassDefinitionID ?? item.classDefinitionID,
                    blockID: item.id,
                    blockStartTime: item.startTime,
                    blockEndTime: item.endTime,
                    status: newStatus
                )
            )
        }
    }

    private func clearStatus(for student: StudentSupportProfile) {
        guard let index = recordIndex(for: student) else { return }
        draftClassRecords.remove(at: index)
    }

    private func markRemainingPresent() {
        for student in students where status(for: student) == nil {
            setStatus(.present, for: student)
        }
    }

    private func updateHomework(_ text: String, for student: StudentSupportProfile) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = recordIndex(for: student) else { return }
        draftClassRecords[index].absentHomework = trimmed
    }

    private func carryForwardEarlierAbsences() {
        for student in earlierAbsentStudents {
            setStatus(.absent, for: student)
            guard let previousRecord = earlierAbsentRecord(for: student),
                  let index = recordIndex(for: student),
                  draftClassRecords[index].absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }
            draftClassRecords[index].absentHomework = previousRecord.absentHomework
        }
    }

    private func exportAttendance() {
        let header = "date,className,gradeLevel,studentName,status,absentHomework"
        let rows = students.map { student in
            let record = existingRecord(for: student)
            return [
                dateKey,
                targetTitle ?? item.className,
                normalizedGrade,
                student.name,
                record?.status.rawValue ?? "",
                record?.absentHomework ?? ""
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        let exportName = (targetTitle ?? item.className).replacingOccurrences(of: " ", with: "-")
        let filename = "classtrax-attendance-\(dateKey)-\(exportName).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func commit() {
        guard !didCommit else { return }
        didCommit = true
        upsertClassHomeworkRecord()
        onCommit(Self.mergedAttendanceRecords(base: baseRecords, draft: draftClassRecords))
    }

    private func upsertClassHomeworkRecord() {
        draftClassRecords.removeAll { $0.isClassHomeworkNote || $0.isHomeworkAssignmentOnly }

        let trimmed = classAssignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftClassRecords.append(
            AttendanceRecord(
                dateKey: dateKey,
                className: targetTitle ?? item.className,
                gradeLevel: normalizedGrade,
                studentName: "",
                studentID: nil,
                classDefinitionID: targetClassDefinitionID ?? item.classDefinitionID,
                blockID: item.id,
                blockStartTime: item.startTime,
                blockEndTime: item.endTime,
                status: .present,
                assignedHomework: trimmed
            )
        )
    }

    private var attendanceSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance Overview")
                .font(.headline.weight(.semibold))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .leading), count: 4),
                alignment: .leading,
                spacing: 10
            ) {
                attendanceSummaryMetric(title: "Unmarked", value: unmarkedCount, accent: ClassTraxSemanticColor.neutral)
                attendanceSummaryMetric(title: "Absent", value: absentCount, accent: ClassTraxSemanticColor.reviewWarning)
                attendanceSummaryMetric(title: "Tardy", value: tardyCount, accent: ClassTraxSemanticColor.attendance)
                attendanceSummaryMetric(title: "Excused", value: excusedCount, accent: ClassTraxSemanticColor.secondaryAction)
            }

            if !earlierAbsentStudents.isEmpty {
                Button("Carry Forward Earlier Absences (\(earlierAbsentStudents.count))") {
                    carryForwardEarlierAbsences()
                }
                .buttonStyle(.bordered)
                .tint(ClassTraxSemanticColor.reviewWarning)
                .controlSize(.small)
            }
        }
        .padding(16)
        .classTraxCardChrome(accent: ClassTraxSemanticColor.attendance, cornerRadius: 18)
    }

    private func attendanceSummaryMetric(title: String, value: Int, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private func recordIndex(for student: StudentSupportProfile) -> Int? {
        draftClassRecords.firstIndex(where: { record in
            guard record.isAttendanceEntry else { return false }
            if let studentID = record.studentID, studentID == student.id {
                if let blockID = record.blockID {
                    if blockID != item.id { return false }
                    if let targetClassDefinitionID {
                        return record.classDefinitionID == targetClassDefinitionID
                    }
                    return true
                }
                if Self.recordMatchesBlockTime(record, item: item) {
                    if let targetClassDefinitionID {
                        return record.classDefinitionID == targetClassDefinitionID
                    }
                    return true
                }
                if let targetClassDefinitionID {
                    if record.classDefinitionID == targetClassDefinitionID {
                        return true
                    }
                } else if item.matchesLinkedClassDefinition(record.classDefinitionID) {
                    return true
                }
                return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className)
            }
            return Self.recordMatchesCurrentClass(record, item: item, targetClassDefinitionID: targetClassDefinitionID) &&
                normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(normalizedGrade) &&
                normalizedStudentKey(record.studentName) == normalizedStudentKey(student.name)
        })
    }

    private func existingRecord(for student: StudentSupportProfile) -> AttendanceRecord? {
        if let record = recordsByStudentID[student.id] {
            return record
        }
        guard let index = recordIndex(for: student) else { return nil }
        return draftClassRecords[index]
    }

    private func tint(for status: AttendanceRecord.Status) -> Color {
        switch status {
        case .present: return ClassTraxSemanticColor.success
        case .absent: return ClassTraxSemanticColor.reviewWarning
        case .tardy: return ClassTraxSemanticColor.attendance
        case .excused: return ClassTraxSemanticColor.secondaryAction
        }
    }

    private func statusAccent(for student: StudentSupportProfile) -> Color {
        guard let status = status(for: student) else {
            return ClassTraxSemanticColor.neutral
        }
        return tint(for: status)
    }

    private static func defaultAssignedHomework(from records: [AttendanceRecord]) -> String {
        if let classNote = records.first(where: {
            $0.isClassHomeworkNote &&
            !$0.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines),
           !classNote.isEmpty {
            return classNote
        }

        return ""
    }

    private func earlierAbsentRecord(for student: StudentSupportProfile) -> AttendanceRecord? {
        let priorAbsences = (baseRecords + draftClassRecords)
            .filter { record in
                record.dateKey == dateKey &&
                    record.isAttendanceEntry &&
                    record.status == .absent &&
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName) ==
                        attendanceMatchKey(studentID: student.id, studentName: student.name) &&
                    Self.isEarlierBlockRecord(record, than: item)
            }

        return priorAbsences.max { lhs, rhs in
            Self.blockSortDate(for: lhs) < Self.blockSortDate(for: rhs)
        }
    }

    private static func splitRecords(
        _ records: [AttendanceRecord],
        for item: AlarmItem,
        dateKey: String,
        targetClassDefinitionID: UUID?
    ) -> (base: [AttendanceRecord], currentClass: [AttendanceRecord]) {
        var base: [AttendanceRecord] = []
        var currentClass: [AttendanceRecord] = []

        for record in records {
            if record.dateKey == dateKey && recordMatchesCurrentClass(record, item: item, targetClassDefinitionID: targetClassDefinitionID) {
                currentClass.append(record)
            } else {
                base.append(record)
            }
        }

        return (base, currentClass)
    }

    private static func mergedAttendanceRecords(base: [AttendanceRecord], draft: [AttendanceRecord]) -> [AttendanceRecord] {
        var mergedByKey: [String: AttendanceRecord] = [:]
        var orderedKeys: [String] = []

        for record in base {
            let key = attendanceMergeKey(for: record)
            if mergedByKey[key] == nil {
                orderedKeys.append(key)
            }
            mergedByKey[key] = record
        }

        for record in draft {
            let key = attendanceMergeKey(for: record)
            if mergedByKey[key] == nil {
                orderedKeys.append(key)
            }
            // Draft values should always win over base values for the same logical record.
            mergedByKey[key] = record
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }

    private static func attendanceMergeKey(for record: AttendanceRecord) -> String {
        let recordType: String = {
            if record.isClassHomeworkNote { return "class-note" }
            if record.isHomeworkAssignmentOnly { return "assignment-only" }
            return "attendance"
        }()

        let blockIdentity: String = {
            if let blockID = record.blockID {
                return "block:\(blockID.uuidString.lowercased())"
            }
            if let start = record.blockStartTime, let end = record.blockEndTime {
                let cal = Calendar(identifier: .gregorian)
                return String(
                    format: "time:%02d:%02d-%02d:%02d",
                    cal.component(.hour, from: start),
                    cal.component(.minute, from: start),
                    cal.component(.hour, from: end),
                    cal.component(.minute, from: end)
                )
            }
            return "time:unspecified"
        }()

        let classIdentity: String = {
            if let classDefinitionID = record.classDefinitionID {
                return "class:\(classDefinitionID.uuidString.lowercased())"
            }
            let normalizedClass = normalizedStudentKey(record.className)
            return "class:\(normalizedClass)"
        }()

        let studentIdentity: String = {
            if let studentID = record.studentID {
                return "student:\(studentID.uuidString.lowercased())"
            }
            let normalizedName = normalizedStudentKey(record.studentName)
            return "student:name:\(normalizedName)"
        }()

        return [
            record.dateKey,
            recordType,
            blockIdentity,
            classIdentity,
            studentIdentity
        ].joined(separator: "|")
    }

    private static func recordMatchesCurrentClass(_ record: AttendanceRecord, item: AlarmItem, targetClassDefinitionID: UUID?) -> Bool {
        if let blockID = record.blockID {
            guard blockID == item.id else { return false }
            if let targetClassDefinitionID {
                return record.classDefinitionID == targetClassDefinitionID
            }
            return true
        }
        if recordMatchesBlockTime(record, item: item) {
            if let targetClassDefinitionID {
                return record.classDefinitionID == targetClassDefinitionID
            }
            return true
        }
        if let targetClassDefinitionID {
            if record.classDefinitionID == targetClassDefinitionID {
                return true
            }
        } else if item.matchesLinkedClassDefinition(record.classDefinitionID) {
            return true
        }
        return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className)
    }

    private static func recordMatchesBlockTime(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        guard
            let recordStartTime = record.blockStartTime,
            let recordEndTime = record.blockEndTime
        else {
            return false
        }

        return blockTimeSignature(start: recordStartTime, end: recordEndTime) ==
            blockTimeSignature(start: item.startTime, end: item.endTime)
    }

    private static func blockTimeSignature(start: Date, end: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        return String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    private static func isEarlierBlockRecord(_ record: AttendanceRecord, than item: AlarmItem) -> Bool {
        guard let recordEndTime = record.blockEndTime else {
            return false
        }

        return blockSortDate(for: recordEndTime) <= blockSortDate(for: item.startTime)
    }

    private static func blockSortDate(for record: AttendanceRecord) -> Date {
        record.blockEndTime ?? record.blockStartTime ?? .distantPast
    }

    private static func blockSortDate(for date: Date) -> Date {
        date
    }
}

// MARK: - Class Support Surfaces

struct TodayClassRosterView: View {
    let item: AlarmItem
    @Binding var alarms: [AlarmItem]
    @Binding var profiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]

    @Environment(\.dismiss) private var dismiss
    @State private var showingAddExisting = false
    @State private var showingAddNew = false
    @State private var showingLinkClassSheet = false
    @State private var draftLinkedClassDefinitionIDs: Set<UUID> = []
    @State private var editingStudent: StudentSupportProfile?
    @State private var editingClassContextStudent: StudentSupportProfile?

    private var students: [StudentSupportProfile] {
        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return profiles
            .filter { profile in
                let matchesSavedClassLink = item.linkedClassDefinitionIDs.contains { linkedID in
                    profileMatches(classDefinitionID: linkedID, profile: profile)
                }

                let matchesBlockName = classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className)
                guard matchesSavedClassLink || matchesBlockName else { return false }

                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                if gradeKey.isEmpty || profileGradeKey.isEmpty {
                    return true
                }
                return profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableProfilesToAdd: [StudentSupportProfile] {
        let rosterIDs = Set(students.map(\.id))
        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        return profiles
            .filter { !rosterIDs.contains($0.id) }
            .filter { profile in
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                return gradeKey.isEmpty || profileGradeKey.isEmpty || profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var linkedClassDefinitions: [ClassDefinitionItem] {
        item.linkedClassDefinitionIDs.compactMap { linkedID in
            classDefinitions.first { $0.id == linkedID }
        }
    }

    private var rosterLinkSummary: String {
        if let primaryDefinition = linkedClassDefinitions.first {
            if linkedClassDefinitions.count > 1 {
                let extraCount = linkedClassDefinitions.count - 1
                return "This roster is linked to \(primaryDefinition.displayName) plus \(extraCount) additional saved class / group\(extraCount == 1 ? "" : "s"). Student links and roster matching will use every linked class / group on this block."
            }
            return "This roster is linked to the saved class \(primaryDefinition.displayName). Student links, class-specific notes, and roster edits will stay attached to that saved class."
        }

        return "This block is using text and grade matching only. Students added here will attach to the class name shown on this block, but class-specific notes work best after linking the block to a saved class."
    }

    private var suggestedClassDefinitions: [ClassDefinitionItem] {
        classDefinitionCandidates(
            name: item.className,
            gradeLevel: item.gradeLevel,
            in: classDefinitions
        )
    }

    private var remainingClassDefinitions: [ClassDefinitionItem] {
        let suggestedIDs = Set(suggestedClassDefinitions.map(\.id))
        return classDefinitions
            .filter { !suggestedIDs.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var orderedDraftLinkedDefinitions: [ClassDefinitionItem] {
        classDefinitions
            .filter { draftLinkedClassDefinitionIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if item.linkedClassDefinitionIDs.first == lhs.id { return true }
                if item.linkedClassDefinitionIDs.first == rhs.id { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.className)
                        .font(.headline.weight(.bold))

                    let meta = [item.gradeLevel, item.location]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")

                    if !meta.isEmpty {
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(rosterCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
            }

            Section("Link Status") {
                VStack(alignment: .leading, spacing: 14) {
                    if let linkedClassDefinition = linkedClassDefinitions.first {
                        LabeledContent("Class Roster") {
                            Text(
                                linkedClassDefinitions.count > 1
                                    ? "\(linkedClassDefinition.displayName) + \(linkedClassDefinitions.count - 1) more"
                                    : linkedClassDefinition.displayName
                            )
                                .foregroundStyle(.primary)
                        }
                    } else {
                        LabeledContent("Class Roster") {
                            Text("Not linked")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(rosterLinkSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !classDefinitions.isEmpty {
                        Button(linkedClassDefinitions.isEmpty ? "Link Class Roster" : "Change Class Roster") {
                            draftLinkedClassDefinitionIDs = Set(item.linkedClassDefinitionIDs)
                            showingLinkClassSheet = true
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(rosterCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
            }

            Section("Roster") {
                if students.isEmpty {
                    Text("No students linked to this class and grade yet.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(rosterCardBackground(accent: .secondary))
                } else {
                    ForEach(students) { student in
                        Button {
                            editingStudent = student
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(student.name)
                                        .fontWeight(.semibold)

                                    gradePill(student.gradeLevel)
                                }

                                let info = classSummary(for: student, in: classDefinitions)
                                if !info.isEmpty {
                                    Text(info)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !student.accommodations.isEmpty {
                                    Text(student.accommodations)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !student.prompts.isEmpty {
                                    Text(student.prompts)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if let classDefinitionID = item.classDefinitionID,
                                   let context = classContext(for: student, classDefinitionID: classDefinitionID) {
                                    let classDetail = [context.behaviorNotes, context.effortNotes, context.classNotes]
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " • ")

                                    if !classDetail.isEmpty {
                                        Text(classDetail)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(item.type.themeColor == .clear ? .blue : item.type.themeColor)
                                            .lineLimit(3)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(rosterCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if item.classDefinitionID != nil {
                                Button("Assigned Work") {
                                    editingClassContextStudent = student
                                }
                                .tint(item.type.themeColor == .clear ? .blue : item.type.themeColor)
                            }

                            Button("Remove", role: .destructive) {
                                removeStudentFromClass(student)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Class Roster")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    (item.type.themeColor == .clear ? Color.blue : item.type.themeColor).opacity(0.06),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingAddExisting = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }

                Button {
                    showingAddNew = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddExisting) {
            NavigationStack {
                rosterAddSheet
            }
        }
        .sheet(isPresented: $showingLinkClassSheet) {
            NavigationStack {
                linkClassSheet
            }
        }
        .sheet(isPresented: $showingAddNew) {
            EditStudentSupportView(
                profiles: $profiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
                existing: nil,
                initialLinkedClassDefinitionIDs: item.linkedClassDefinitionIDs,
                initialClassName: item.className,
                initialGradeLevel: item.gradeLevel
            )
        }
        .sheet(item: $editingStudent) { student in
            EditStudentSupportView(
                profiles: $profiles,
                classDefinitions: $classDefinitions,
                teacherContacts: $teacherContacts,
                paraContacts: $paraContacts,
                existing: student
            )
        }
        .sheet(item: $editingClassContextStudent) { student in
            if let classDefinitionID = item.classDefinitionID {
                NavigationStack {
                    TodayStudentClassContextView(
                        item: item,
                        student: student,
                        classDefinitionID: classDefinitionID,
                        profiles: $profiles
                    )
                }
            }
        }
    }

    private var rosterAddSheet: some View {
        List {
            Section {
                Text("Add existing students to \(item.className) without creating duplicate student records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(rosterLinkSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Available Students") {
                if availableProfilesToAdd.isEmpty {
                    Text("No additional students match this class or grade right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableProfilesToAdd) { student in
                        Button {
                            addStudentToClass(student)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(student.name)
                                    .foregroundStyle(.primary)
                                Text(classSummary(for: student, in: classDefinitions))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Add to Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    showingAddExisting = false
                }
            }
        }
    }

    private var linkClassSheet: some View {
        List {
            Section {
                Text("Link this schedule block to one or more saved classes or groups. The first linked item stays the primary roster for existing class-first workflows, and every linked class or group is used for matching students and supports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !orderedDraftLinkedDefinitions.isEmpty {
                Section("Linked Classes / Groups") {
                    ForEach(Array(orderedDraftLinkedDefinitions.enumerated()), id: \.element.id) { index, definition in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(definition.displayName)
                                    .foregroundStyle(.primary)
                                Text(index == 0 ? "Primary class / group" : "Additional linked class / group")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: index == 0 ? "star.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(index == 0 ? .yellow : .blue)
                        }
                    }

                    if !draftLinkedClassDefinitionIDs.isEmpty {
                        Button("Clear Linked Classes / Groups", role: .destructive) {
                            draftLinkedClassDefinitionIDs.removeAll()
                        }
                    }
                }
            }

            Section("Available Classes / Groups") {
                ForEach(classDefinitions.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) { definition in
                    Button {
                        toggleClassDefinitionLink(definition)
                    } label: {
                        HStack(spacing: 12) {
                            classDefinitionRow(definition)
                            Spacer(minLength: 8)
                            Image(systemName: draftLinkedClassDefinitionIDs.contains(definition.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draftLinkedClassDefinitionIDs.contains(definition.id) ? .blue : .secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Link Classes / Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showingLinkClassSheet = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    applyLinkedClassDefinitionChanges()
                }
                .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private func classDefinitionRow(_ definition: ClassDefinitionItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addStudentToClass(_ student: StudentSupportProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else { return }

        if !item.linkedClassDefinitionIDs.isEmpty {
            let currentIDs = linkedClassDefinitionIDs(for: profiles[index])
            let updatedIDs = currentIDs + item.linkedClassDefinitionIDs
            profiles[index] = updatingProfile(profiles[index], linkedTo: updatedIDs, definitions: classDefinitions)
        } else {
            var updated = profiles[index]
            updated.className = mergedClassSummary(current: updated.className, adding: item.className)
            if updated.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.gradeLevel = GradeLevelOption.normalized(item.gradeLevel)
            }
            profiles[index] = updated
        }
    }

    private func removeStudentFromClass(_ student: StudentSupportProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else { return }

        if !item.linkedClassDefinitionIDs.isEmpty {
            let removalIDs = Set(item.linkedClassDefinitionIDs)
            let updatedIDs = linkedClassDefinitionIDs(for: profiles[index]).filter { !removalIDs.contains($0) }
            profiles[index] = updatingProfile(profiles[index], linkedTo: updatedIDs, definitions: classDefinitions)
        } else {
            var updated = profiles[index]
            updated.className = removingClassSummary(current: updated.className, removing: item.className)
            profiles[index] = updated
        }
    }

    private func toggleClassDefinitionLink(_ definition: ClassDefinitionItem) {
        if draftLinkedClassDefinitionIDs.contains(definition.id) {
            draftLinkedClassDefinitionIDs.remove(definition.id)
        } else {
            draftLinkedClassDefinitionIDs.insert(definition.id)
        }
    }

    private func applyLinkedClassDefinitionChanges() {
        let orderedDefinitions = classDefinitions
            .filter { draftLinkedClassDefinitionIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if item.linkedClassDefinitionIDs.first == lhs.id { return true }
                if item.linkedClassDefinitionIDs.first == rhs.id { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        let orderedIDs = orderedDefinitions.map(\.id)
        let primaryDefinition = orderedDefinitions.first
        let normalizedGrade = GradeLevelOption.normalized(primaryDefinition?.gradeLevel ?? "")
        let matchingIDs = candidateLinkBlockIDs(for: item, linkedDefinitionIDs: orderedIDs)

        for index in alarms.indices {
            guard matchingIDs.contains(alarms[index].id) else { continue }

            alarms[index].classDefinitionID = orderedIDs.first
            alarms[index].classDefinitionIDs = orderedIDs

            if !normalizedGrade.isEmpty {
                alarms[index].gradeLevelValue = normalizedGrade
            }

            if alarms[index].location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alarms[index].location = primaryDefinition?.defaultLocation ?? alarms[index].location
            }
        }

        showingLinkClassSheet = false
        dismiss()
    }

    private func candidateLinkBlockIDs(for source: AlarmItem, linkedDefinitionIDs: [UUID]) -> Set<UUID> {
        let sourceName = source.className
        let sourceGrade = source.gradeLevel
        let linkedDefinitionIDSet = Set(linkedDefinitionIDs)

        return Set(
            alarms.filter { candidate in
                if candidate.id == source.id {
                    return true
                }

                if candidate.linkedClassDefinitionIDs.contains(where: { linkedDefinitionIDSet.contains($0) }) {
                    return true
                }

                return classNamesMatch(scheduleClassName: sourceName, profileClassName: candidate.className) &&
                    gradeLevelsCompatible(sourceGrade, candidate.gradeLevel)
            }
            .map(\.id)
        )
    }

    private func rosterCardBackground(accent: Color) -> some View {
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
}

struct TodayStudentClassContextView: View {
    let item: AlarmItem
    let student: StudentSupportProfile
    let classDefinitionID: UUID
    @Binding var profiles: [StudentSupportProfile]

    @Environment(\.dismiss) private var dismiss

    @State private var behaviorNotes = ""
    @State private var effortNotes = ""
    @State private var classNotes = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(student.name)
                        .font(.headline.weight(.bold))
                    Text(item.className)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("Behavior / Support") {
                TextField("Behavior notes", text: $behaviorNotes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Effort / participation", text: $effortNotes, axis: .vertical)
                    .lineLimit(2...4)

                TextField("Class-specific notes", text: $classNotes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle("Class Details")
        .navigationBarTitleDisplayMode(.inline)
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
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if let existingContext = classContext(for: student, classDefinitionID: classDefinitionID) {
                behaviorNotes = existingContext.behaviorNotes
                effortNotes = existingContext.effortNotes
                classNotes = existingContext.classNotes
            }
        }
    }

    private func save() {
        guard let index = profiles.firstIndex(where: { $0.id == student.id }) else {
            dismiss()
            return
        }

        let context = StudentSupportProfile.ClassContext(
            classDefinitionID: classDefinitionID,
            behaviorNotes: behaviorNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            effortNotes: effortNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            classNotes: classNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        profiles[index] = updatingProfile(profiles[index], classContext: context)
        dismiss()
    }
}

// MARK: - Sub Plans

struct TodayClassSubPlanView: View {
    private enum Field: Hashable {
        case overview
        case lessonPlan
        case materials
        case subNotes
        case returnNotes
    }

    let item: AlarmItem
    let date: Date
    let students: [StudentSupportProfile]
    let alarms: [AlarmItem]
    let commitments: [CommitmentItem]
    let activeOverrideName: String?
    let attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]

    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) private var dismiss
    @State private var overview = ""
    @State private var lessonPlan = ""
    @State private var materials = ""
    @State private var subNotes = ""
    @State private var returnNotes = ""
    @State private var includeRoster = true
    @State private var includeSupports = true
    @State private var includeAttendance = true
    @State private var includeCommitments = true
    @State private var includeDaySchedule = true
    @State private var includeSubProfile = true
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var selectedDate: Date
    @State private var feedbackMessage: String?
    @FocusState private var focusedField: Field?

    init(
        item: AlarmItem,
        date: Date,
        students: [StudentSupportProfile],
        alarms: [AlarmItem],
        commitments: [CommitmentItem],
        activeOverrideName: String?,
        attendanceRecords: [AttendanceRecord],
        subPlans: Binding<[SubPlanItem]>
    ) {
        self.item = item
        self.date = date
        self.students = students
        self.alarms = alarms
        self.commitments = commitments
        self.activeOverrideName = activeOverrideName
        self.attendanceRecords = attendanceRecords
        _subPlans = subPlans
        _selectedDate = State(initialValue: date)
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: selectedDate)
    }

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var schedule: [AlarmItem] {
        alarms
            .filter { $0.dayOfWeek == selectedWeekday }
            .sorted {
                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }
                return $0.endTime < $1.endTime
            }
    }

    private var commitmentsForSelectedDate: [CommitmentItem] {
        resolvedCommitments(for: selectedDate, from: commitments)
    }

    private var displayedOverrideName: String? {
        Calendar.current.isDate(selectedDate, inSameDayAs: date) ? activeOverrideName : nil
    }

    private var linkedAlarmForSelectedDate: AlarmItem? {
        schedule.first { block in
            if !item.linkedClassDefinitionIDs.isEmpty,
               block.linkedClassDefinitionIDs.contains(where: { item.linkedClassDefinitionIDs.contains($0) }) {
                return true
            }

            return classNamesMatch(scheduleClassName: block.className, profileClassName: item.className) &&
                normalizedStudentKey(GradeLevelOption.normalized(block.gradeLevel)) ==
                normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
        }
    }

    private var existingPlan: SubPlanItem? {
        subPlans.first {
            $0.dateKey == dateKey &&
            ($0.linkedAlarmID == (linkedAlarmForSelectedDate?.id ?? item.id) || (
                classNamesMatch(scheduleClassName: $0.className, profileClassName: item.className) &&
                normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
            ))
        }
    }

    private var followUpNotes: [FollowUpNoteItem] {
        decodeFollowUpNotesFromDefaults()
    }

    private var subPlanProfile: SubPlanProfile {
        ClassTraxPersistence.loadSubPlanProfile(from: modelContext)
    }

    private var relevantClassNotes: [FollowUpNoteItem] {
        followUpNotes.filter {
            $0.kind == .classNote &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: $0.context)
        }
    }

    private var relevantStudentNotes: [FollowUpNoteItem] {
        let studentKeys = Set(students.map { normalizedStudentKey($0.name) })
        return followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            studentKeys.contains(normalizedStudentKey($0.studentOrGroup))
        }
    }

    private var attendanceSummary: [AttendanceRecord.Status: Int] {
        var summary: [AttendanceRecord.Status: Int] = [:]
        for record in attendanceRows {
            summary[record.status, default: 0] += 1
        }
        return summary
    }

    private var attendanceRows: [AttendanceRecord] {
        attendanceRecords.filter {
            $0.dateKey == dateKey &&
            (
                item.matchesLinkedClassDefinition($0.classDefinitionID) ||
                (
                    classNamesMatch(scheduleClassName: item.className, profileClassName: $0.className) &&
                    normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
                )
            )
        }
        .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.className)
                        .font(.headline.weight(.bold))

                    let meta = [
                        selectedDate.formatted(date: .abbreviated, time: .omitted),
                        item.gradeLevel,
                        item.location
                    ]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                    if !meta.isEmpty {
                        Text(meta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(displayedOverrideName ?? "Regular Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 2)

                    infoRow(
                        title: "Selected Date",
                        value: selectedDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )

                    infoRow(
                        title: "Linked Block",
                        value: linkedBlockSummaryText,
                        systemImage: linkedAlarmForSelectedDate == nil ? "exclamationmark.triangle" : "checkmark.circle"
                    )

                    infoRow(
                        title: "Saved Draft",
                        value: existingPlan == nil ? "No saved class packet yet" : "Existing class packet found",
                        systemImage: existingPlan == nil ? "tray" : "tray.full"
                    )

                    infoRow(
                        title: "Workflow Role",
                        value: "Secondary packet for one class block",
                        systemImage: "square.stack.3d.down.right"
                    )
                }
                .padding(.vertical, 8)
                .listRowBackground(subPlanCardBackground(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor))
            }

            if let feedbackMessage {
                Section {
                    feedbackRow(message: feedbackMessage, accent: .green)
                }
                .listRowBackground(subPlanCardBackground(accent: .green))
            }

            Section("Plan Date") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )

                Text(
                    linkedAlarmForSelectedDate == nil
                    ? "No matching class block is scheduled on that date yet. You can still prep the packet now and link it to the saved class when that block exists."
                    : "Choose the day first so this class sub plan saves against the correct class block."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Sub Overview") {
                TextField("Quick summary for the substitute", text: $overview, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .overview)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .lessonPlan
                    }
                TextField("Lesson plan or class flow", text: $lessonPlan, axis: .vertical)
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .lessonPlan)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .materials
                    }
            }

            Section("Materials & Notes") {
                TextField("Materials, copies, links, devices", text: $materials, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .materials)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .subNotes
                    }
                TextField("Sub notes, routines, dismissal reminders", text: $subNotes, axis: .vertical)
                    .lineLimit(4...8)
                    .focused($focusedField, equals: .subNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .returnNotes
                    }
                TextField("Notes the substitute can leave for you", text: $returnNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .returnNotes)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            Section("Include in Export") {
                Toggle("Include roster", isOn: $includeRoster)
                Toggle("Include accommodations and prompts", isOn: $includeSupports)
                Toggle("Include attendance snapshot", isOn: $includeAttendance)
                Toggle("Include commitments", isOn: $includeCommitments)
                Toggle("Include day schedule", isOn: $includeDaySchedule)
                Toggle("Include Sub Plan Profile", isOn: $includeSubProfile)
            }

            Section("Packet Preview") {
                Label("\(students.count) linked student\(students.count == 1 ? "" : "s")", systemImage: "person.3.sequence.fill")
                Label("\(relevantClassNotes.count) class note\(relevantClassNotes.count == 1 ? "" : "s")", systemImage: "note.text")
                Label("\(relevantStudentNotes.count) student note\(relevantStudentNotes.count == 1 ? "" : "s")", systemImage: "person.text.rectangle")
                Label("\(schedule.count) block\(schedule.count == 1 ? "" : "s") in day schedule", systemImage: "calendar")
                Label("\(attendanceRows.count) attendance record\(attendanceRows.count == 1 ? "" : "s")", systemImage: "checklist.checked")
                Label("\(relevantCommitments.count) commitment\(relevantCommitments.count == 1 ? "" : "s")", systemImage: "briefcase")
            }
            .listRowBackground(subPlanCardBackground(accent: .indigo))

            if includeDaySchedule {
                Section("Day Schedule Snapshot") {
                    ForEach(schedule) { block in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.className)
                                    .fontWeight(.semibold)

                                let meta = [block.gradeLevel, block.location]
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " • ")

                                if !meta.isEmpty {
                                    Text(meta)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if includeAttendance {
                Section("Attendance Snapshot") {
                    if attendanceRows.isEmpty {
                        Text("No attendance has been taken for this class yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            ForEach(AttendanceRecord.Status.allCases) { status in
                                if let count = attendanceSummary[status], count > 0 {
                                    Text("\(status.rawValue): \(count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        ForEach(attendanceRows) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(record.studentName)
                                    Spacer()
                                    Text(record.status.rawValue)
                                        .foregroundStyle(.secondary)
                                }

                                if record.status == .absent && !record.absentHomework.isEmpty {
                                    Text("Homework: \(record.absentHomework)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !missingWorkRows.isEmpty {
                Section("Missing Work for Absent Students") {
                    ForEach(missingWorkRows) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.studentName)
                                .fontWeight(.semibold)
                            Text(record.absentHomework)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if includeCommitments {
                Section("Commitments Snapshot") {
                    if relevantCommitments.isEmpty {
                        Text("No commitments overlap with this class block.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(relevantCommitments) { commitment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(commitment.title)
                                    .fontWeight(.semibold)
                                Text(commitmentTimeText(commitment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sub Plans")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    (item.type.themeColor == .clear ? Color.blue : item.type.themeColor).opacity(0.06),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Share Text") {
                    focusedField = nil
                    save()
                    exportTextPlan()
                }

                Menu {
                    Button("PDF Packet") {
                        focusedField = nil
                        save()
                        exportPDFPlan()
                    }

                    Divider()

                    Button("Save Packet") {
                        focusedField = nil
                        save()
                        dismiss()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .onChange(of: selectedDate) { _, _ in
            focusedField = nil
            loadExisting()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func loadExisting() {
        overview = ""
        lessonPlan = ""
        materials = ""
        subNotes = ""
        returnNotes = ""
        includeRoster = true
        includeSupports = true
        includeAttendance = true
        includeCommitments = true
        includeDaySchedule = true
        includeSubProfile = true

        if let existingPlan {
            overview = existingPlan.overview
            lessonPlan = existingPlan.lessonPlan
            materials = existingPlan.materials
            subNotes = existingPlan.subNotes
            returnNotes = existingPlan.returnNotes
            includeRoster = existingPlan.includeRoster
            includeSupports = existingPlan.includeSupports
            includeAttendance = existingPlan.includeAttendance
            includeCommitments = existingPlan.includeCommitments
            includeDaySchedule = existingPlan.includeDaySchedule
            includeSubProfile = existingPlan.includeSubProfile
        } else {
            subNotes = linkedAlarmForSelectedDate?.blockSupportNote ?? item.blockSupportNote
        }
    }

    private func save() {
        let updated = SubPlanItem(
            id: existingPlan?.id ?? UUID(),
            dateKey: dateKey,
            linkedAlarmID: linkedAlarmForSelectedDate?.id ?? item.id,
            className: item.className,
            gradeLevel: GradeLevelOption.normalized(item.gradeLevel),
            location: item.location,
            overview: overview.trimmingCharacters(in: .whitespacesAndNewlines),
            lessonPlan: lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines),
            materials: materials.trimmingCharacters(in: .whitespacesAndNewlines),
            subNotes: subNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeAttendance: includeAttendance,
            includeCommitments: includeCommitments,
            includeDaySchedule: includeDaySchedule,
            includeSubProfile: includeSubProfile,
            createdAt: existingPlan?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if let index = subPlans.firstIndex(where: { $0.id == updated.id }) {
            subPlans[index] = updated
        } else {
            subPlans.insert(updated, at: 0)
        }

        feedbackMessage = "Saved \(item.className) for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private func exportTextPlan() {
        let filename = "classtrax-sub-plan-\(dateKey)-\(item.className.replacingOccurrences(of: " ", with: "-")).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? exportText().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Text packet is ready to share."
    }

    private func exportPDFPlan() {
        let safeName = item.className.replacingOccurrences(of: " ", with: "-")
        let title = "ClassTrax Sub Plans"
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName)"
        if let url = makeSubPlanPDF(title: title, filename: filename, body: exportText()) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "PDF packet is ready to share."
        } else {
            exportTextPlan()
        }
    }

    private func exportText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let classHeader = [
            item.className,
            [GradeLevelOption.normalized(item.gradeLevel), resolvedRoomText()]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " • "),
            timeRangeText(using: timeFormatter)
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")

        let rosterLines: [String] = includeRoster ? students.map { student in
            var line = "\(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"
            if includeSupports {
                let supportParts = [student.accommodations, student.prompts]
                    .compactMap(cleanedExportText)
                if !supportParts.isEmpty {
                    line += " — Supports: \(supportParts.joined(separator: " • "))"
                }
            }
            return line
        } : []

        let classNoteLines: [String] = relevantClassNotes.compactMap { cleanedExportText($0.note) }
        let studentNoteLines: [String] = relevantStudentNotes.compactMap { note -> String? in
            guard let body = cleanedExportText(note.note) else { return nil }
            if let student = students.first(where: {
                normalizedStudentKey($0.name) == normalizedStudentKey(note.studentOrGroup)
            }) {
                return "\(note.studentOrGroup) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]: \(body)"
            }
            return "\(note.studentOrGroup): \(body)"
        }

        let dayScheduleLines: [String] = includeDaySchedule ? schedule.map { block in
            let timeRange = "\(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))"
            let meta = [block.gradeLevel, block.location]
                .compactMap(cleanedExportText)
                .joined(separator: " • ")
            return meta.isEmpty ? "\(timeRange): \(block.className)" : "\(timeRange): \(block.className) (\(meta))"
        } : []

        let attendanceSummaryLine: String? = {
            guard includeAttendance, !attendanceRows.isEmpty else { return nil }
            let parts = AttendanceRecord.Status.allCases.compactMap { status -> String? in
                guard let count = attendanceSummary[status], count > 0 else { return nil }
                return "\(status.rawValue): \(count)"
            }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }()

        let absentHomeworkLines: [String] = includeAttendance
            ? attendanceRows.compactMap { record -> String? in
                guard record.status == .absent, let homework = cleanedExportText(record.absentHomework) else { return nil }
                return "\(record.studentName): \(homework)"
            }
            : []

        let commitmentLines: [String] = includeCommitments
            ? relevantCommitments.map { "\($0.title): \(commitmentTimeText($0))" }
            : []

        let sections: [String?] = [
            exportSection("Date", body: selectedDate.formatted(date: .complete, time: .omitted)),
            exportSection("Active Schedule", body: displayedOverrideName ?? "Regular Day"),
            includeSubProfile ? exportSection("Teacher Contact", body: cleanedExportText(teacherContactBlock())) : nil,
            includeSubProfile ? exportSection("Emergency / Drill", body: cleanedExportText(emergencyDrillBlock())) : nil,
            includeSubProfile ? exportSection("Classroom Access", body: cleanedExportText(classroomAccessBlock())) : nil,
            includeSubProfile ? exportSection("Static Notes", body: cleanedExportText(staticNotesBlock())) : nil,
            exportSection("Class", body: cleanedExportText(classHeader)),
            exportSection("Overview", body: cleanedExportText(overview)),
            exportSection("Lesson Plan", body: cleanedExportText(lessonPlan)),
            exportSection("Materials", body: cleanedExportText(materials)),
            exportSection("Sub Notes", body: cleanedExportText(subNotes)),
            exportSection("Return Notes", body: cleanedExportText(returnNotes)),
            exportSection("Roster", body: exportBulletLines(rosterLines)),
            exportSection("Assigned Work", body: exportBulletLines(classNoteLines)),
            exportSection("Student Notes", body: exportBulletLines(studentNoteLines)),
            exportSection("Commitments", body: exportBulletLines(commitmentLines)),
            exportSection("Day Schedule", body: exportBulletLines(dayScheduleLines)),
            exportSection("Attendance Summary", body: attendanceSummaryLine),
            exportSection("Absent / Missing Work", body: exportBulletLines(absentHomeworkLines))
        ]

        return joinExportSections(sections)
    }

    private func resolvedRoomText() -> String {
        let room = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty { return room }
        let fallback = subPlanProfile.room.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "Room not set" : fallback
    }

    private var linkedBlockSummaryText: String {
        guard let block = linkedAlarmForSelectedDate else {
            return "No matching block scheduled"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: block.startTime)) - \(formatter.string(from: block.endTime))"
    }

    private var missingWorkRows: [AttendanceRecord] {
        attendanceRows.filter {
            $0.status == .absent &&
            !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func feedbackRow(message: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func timeRangeText(using formatter: DateFormatter) -> String {
        let block = linkedAlarmForSelectedDate ?? item
        return "\(formatter.string(from: block.startTime)) - \(formatter.string(from: block.endTime))"
    }

    private func infoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func teacherContactBlock() -> String {
        let lines = [
            labeledLine("Teacher", subPlanProfile.teacherName),
            labeledLine("Room", resolvedRoomText()),
            labeledLine("Email", subPlanProfile.contactEmail),
            labeledLine("Phone", subPlanProfile.contactPhone),
            labeledLine("Front Office", subPlanProfile.schoolFrontOfficeContact),
            labeledLine("Neighboring Teacher", subPlanProfile.neighboringTeacher)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func emergencyDrillBlock() -> String {
        let lines = [
            blockText(subPlanProfile.emergencyDrillProcedures),
            labeledLine("File Link", subPlanProfile.emergencyDrillFileLink)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func classroomAccessBlock() -> String {
        let credentialText = subPlanProfile.appCredentials
            .filter(\.hasContent)
            .map { credential in
                [
                    labeledLine("App", credential.applicationName),
                    labeledLine("Link", credential.applicationLink),
                    labeledLine("Username", credential.username),
                    labeledLine("Password", credential.password)
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let lines = [
            labeledLine("Extensions", subPlanProfile.phoneExtensions),
            blockText(subPlanProfile.passwordsAccessNotes),
            credentialText.isEmpty ? nil : credentialText
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func staticNotesBlock() -> String {
        blockText(subPlanProfile.staticNotes) ?? "Not added yet"
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func blockText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var relevantCommitments: [CommitmentItem] {
        let block = linkedAlarmForSelectedDate ?? item
        return commitmentsForSelectedDate.filter { commitment in
            let start = anchoredDate(commitment.startTime, on: selectedDate)
            let end = anchoredDate(commitment.endTime, on: selectedDate)
            let classStart = anchoredDate(block.startTime, on: selectedDate)
            let classEnd = anchoredDate(block.endTime, on: selectedDate)
            return start < classEnd && end > classStart
        }
    }

    private func anchoredDate(_ time: Date, on day: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func commitmentTimeText(_ commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    private func subPlanCardBackground(accent: Color) -> some View {
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
}

struct TodayDailySubPlanView: View {
    private enum Field: Hashable {
        case morningNotes
        case sharedMaterials
        case dismissalNotes
        case emergencyNotes
        case returnNotes
    }

    let date: Date
    let alarms: [AlarmItem]
    let commitments: [CommitmentItem]
    let activeOverrideName: String?
    let students: [StudentSupportProfile]
    let attendanceRecords: [AttendanceRecord]
    @Binding var subPlans: [SubPlanItem]
    @Binding var dailySubPlans: [DailySubPlanItem]

    @Environment(\.modelContext) private var modelContext

    @Environment(\.dismiss) private var dismiss
    @State private var morningNotes = ""
    @State private var sharedMaterials = ""
    @State private var dismissalNotes = ""
    @State private var emergencyNotes = ""
    @State private var returnNotes = ""
    @State private var includeAttendance = true
    @State private var includeRoster = true
    @State private var includeSupports = true
    @State private var includeCommitments = true
    @State private var includeSubProfile = true
    @State private var selectedBlockIDs: Set<UUID> = []
    @State private var blockPlans: [UUID: BlockSubPlanDraft] = [:]
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var selectedDate: Date
    @State private var feedbackMessage: String?
    @FocusState private var focusedField: Field?

    private struct BlockSubPlanDraft {
        var overview: String = ""
        var lessonPlan: String = ""
        var materials: String = ""
        var subNotes: String = ""
    }

    init(
        date: Date,
        alarms: [AlarmItem],
        commitments: [CommitmentItem],
        activeOverrideName: String?,
        students: [StudentSupportProfile],
        attendanceRecords: [AttendanceRecord],
        subPlans: Binding<[SubPlanItem]>,
        dailySubPlans: Binding<[DailySubPlanItem]>
    ) {
        self.date = date
        self.alarms = alarms
        self.commitments = commitments
        self.activeOverrideName = activeOverrideName
        self.students = students
        self.attendanceRecords = attendanceRecords
        _subPlans = subPlans
        _dailySubPlans = dailySubPlans
        _selectedDate = State(initialValue: date)
    }

    private var dateKey: String {
        AttendanceRecord.dateKey(for: selectedDate)
    }

    private var existingDailyPlan: DailySubPlanItem? {
        dailySubPlans.first { $0.dateKey == dateKey }
    }

    private var selectedWeekday: Int {
        Calendar.current.component(.weekday, from: selectedDate)
    }

    private var schedule: [AlarmItem] {
        alarms
            .filter { $0.dayOfWeek == selectedWeekday }
            .sorted {
                if $0.startTime != $1.startTime {
                    return $0.startTime < $1.startTime
                }
                return $0.endTime < $1.endTime
            }
    }

    private var commitmentsForSelectedDate: [CommitmentItem] {
        resolvedCommitments(for: selectedDate, from: commitments)
    }

    private var displayedOverrideName: String? {
        Calendar.current.isDate(selectedDate, inSameDayAs: date) ? activeOverrideName : nil
    }

    private var selectedBlocksForPlan: [AlarmItem] {
        schedule.filter { selectedBlockIDs.contains($0.id) }
    }

    private var followUpNotes: [FollowUpNoteItem] {
        decodeFollowUpNotesFromDefaults()
    }

    private var subPlanProfile: SubPlanProfile {
        ClassTraxPersistence.loadSubPlanProfile(from: modelContext)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline.weight(.bold))
                    Text("\(schedule.count) block\(schedule.count == 1 ? "" : "s") prepared for the day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(displayedOverrideName ?? "Regular Day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 2)

                    dailyInfoRow(
                        title: "Selected Date",
                        value: selectedDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )

                    dailyInfoRow(
                        title: "Saved Draft",
                        value: existingDailyPlan == nil ? "No saved daily packet yet" : "Existing daily packet found",
                        systemImage: existingDailyPlan == nil ? "tray" : "tray.full"
                    )

                    dailyInfoRow(
                        title: "Class Blocks",
                        value: "\(selectedBlocksForPlan.count) selected of \(schedule.count) • \(savedBlockCount) saved • \(draftBlockCount) draft",
                        systemImage: "square.stack.3d.up"
                    )

                    dailyInfoRow(
                        title: "Workflow Role",
                        value: "Primary substitute packet",
                        systemImage: "star.circle"
                    )
                }
                .padding(.vertical, 8)
                .listRowBackground(dailySubPlanCardBackground(accent: .blue))
            }

            if let feedbackMessage {
                Section {
                    dailyFeedbackRow(message: feedbackMessage, accent: .green)
                }
                .listRowBackground(dailySubPlanCardBackground(accent: .green))
            }

            Section("Plan Date") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )

                Text("Choose the day first so the correct class blocks load into this sub plan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    SubPlanProfileSettingsView()
                } label: {
                    Label("Review Sub Plan Profile", systemImage: "person.text.rectangle")
                }

                Text("Check your reusable teacher contact, emergency, access, and static note details before exporting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Day-Wide Notes") {
                TextField("Morning notes for the substitute", text: $morningNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .morningNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .sharedMaterials
                    }
                TextField("Shared materials, links, copies, devices", text: $sharedMaterials, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .sharedMaterials)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .dismissalNotes
                    }
                TextField("Dismissal notes and end-of-day reminders", text: $dismissalNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .dismissalNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .emergencyNotes
                    }
                TextField("Emergency / important alerts", text: $emergencyNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .emergencyNotes)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .returnNotes
                    }
                TextField("Notes the substitute can leave for you", text: $returnNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .returnNotes)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            }

            Section("Include in Export") {
                Toggle("Include attendance snapshots", isOn: $includeAttendance)
                Toggle("Include rosters", isOn: $includeRoster)
                Toggle("Include accommodations and prompts", isOn: $includeSupports)
                Toggle("Include commitments", isOn: $includeCommitments)
                Toggle("Include Sub Plan Profile", isOn: $includeSubProfile)
            }

            Section("Class Blocks") {
                if schedule.isEmpty {
                    ContentUnavailableView(
                        "No Class Blocks for This Date",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pick another day or add schedule blocks for this weekday to prepare a full daily sub plan.")
                    )
                } else {
                    ForEach(schedule) { block in
                        let draft = binding(for: block)
                        DisclosureGroup {
                            VStack(spacing: 10) {
                                Toggle("Needs class notes", isOn: selectionBinding(for: block))
                                    .font(.subheadline.weight(.semibold))

                                TextField("Overview", text: draft.overview, axis: .vertical)
                                    .lineLimit(2...4)
                                    .disabled(!selectedBlockIDs.contains(block.id))
                                TextField("Lesson plan", text: draft.lessonPlan, axis: .vertical)
                                    .lineLimit(3...6)
                                    .disabled(!selectedBlockIDs.contains(block.id))
                                TextField("Materials", text: draft.materials, axis: .vertical)
                                    .lineLimit(2...4)
                                    .disabled(!selectedBlockIDs.contains(block.id))
                                TextField("Sub notes", text: draft.subNotes, axis: .vertical)
                                    .lineLimit(3...6)
                                    .disabled(!selectedBlockIDs.contains(block.id))
                            }
                            .padding(.top, 6)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(block.className)
                                            .fontWeight(.semibold)
                                        Text("\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    Text(blockDraftStatus(for: block))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(blockHasSavedDraft(block) ? .green : (selectedBlockIDs.contains(block.id) ? .blue : .secondary))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill((blockHasSavedDraft(block) ? Color.green : (selectedBlockIDs.contains(block.id) ? Color.blue : Color.secondary)).opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                }
            }

            if !missingWorkRows.isEmpty {
                Section("Missing Work for Absent Students") {
                    ForEach(missingWorkRows) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.studentName)
                                .fontWeight(.semibold)
                            Text("\(record.className) • \(record.absentHomework)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Daily Sub Plan")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color.blue.opacity(0.05),
                    Color.orange.opacity(0.03),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Share Text") {
                    focusedField = nil
                    save()
                    exportTextPlan()
                }

                Menu {
                    Menu("Whole Day") {
                        Button("Text Packet") {
                            focusedField = nil
                            save()
                            exportTextPlan()
                        }

                        Button("PDF Packet") {
                            focusedField = nil
                            save()
                            exportPDFPlan()
                        }
                    }

                    Menu("Specific Class") {
                        if schedule.isEmpty {
                            Text("No Class Blocks")
                        } else {
                            ForEach(schedule) { block in
                                Menu(block.className) {
                                    Button("Class Packet (Text)") {
                                        focusedField = nil
                                        save()
                                        exportSingleBlockTextPlan(for: block)
                                    }

                                    Button("Class Packet (PDF)") {
                                        focusedField = nil
                                        save()
                                        exportSingleBlockPDFPlan(for: block)
                                    }
                                }
                            }
                        }
                    }

                    Button("Missing Work (CSV)") {
                        focusedField = nil
                        exportMissingWork()
                    }
                    
                    Divider()

                    Button("Save Packet") {
                        focusedField = nil
                        save()
                        dismiss()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            loadExisting()
        }
        .onChange(of: selectedDate) { _, _ in
            focusedField = nil
            loadExisting()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func loadExisting() {
        morningNotes = ""
        sharedMaterials = ""
        dismissalNotes = ""
        emergencyNotes = ""
        returnNotes = ""
        includeAttendance = true
        includeRoster = true
        includeSupports = true
        includeCommitments = true
        includeSubProfile = true
        selectedBlockIDs = Set(schedule.map(\.id))
        blockPlans = [:]

        if let existingDailyPlan {
            morningNotes = existingDailyPlan.morningNotes
            sharedMaterials = existingDailyPlan.sharedMaterials
            dismissalNotes = existingDailyPlan.dismissalNotes
            emergencyNotes = existingDailyPlan.emergencyNotes
            returnNotes = existingDailyPlan.returnNotes
            includeAttendance = existingDailyPlan.includeAttendance
            includeRoster = existingDailyPlan.includeRoster
            includeSupports = existingDailyPlan.includeSupports
            includeCommitments = existingDailyPlan.includeCommitments
            includeSubProfile = existingDailyPlan.includeSubProfile
            if existingDailyPlan.selectedBlockIDs.isEmpty {
                selectedBlockIDs = Set(schedule.map(\.id))
            } else {
                selectedBlockIDs = Set(existingDailyPlan.selectedBlockIDs).intersection(schedule.map(\.id))
            }
        }

        for block in schedule {
            if let existing = subPlans.first(where: { $0.dateKey == dateKey && $0.linkedAlarmID == block.id }) {
                blockPlans[block.id] = BlockSubPlanDraft(
                    overview: existing.overview,
                    lessonPlan: existing.lessonPlan,
                    materials: existing.materials,
                    subNotes: existing.subNotes
                )
            } else {
                blockPlans[block.id] = blockPlans[block.id] ?? BlockSubPlanDraft(subNotes: block.blockSupportNote)
            }
        }
    }

    private func binding(for block: AlarmItem) -> (
        overview: Binding<String>,
        lessonPlan: Binding<String>,
        materials: Binding<String>,
        subNotes: Binding<String>
    ) {
        (
            overview: Binding(
                get: { blockPlans[block.id]?.overview ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].overview = $0 }
            ),
            lessonPlan: Binding(
                get: { blockPlans[block.id]?.lessonPlan ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].lessonPlan = $0 }
            ),
            materials: Binding(
                get: { blockPlans[block.id]?.materials ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].materials = $0 }
            ),
            subNotes: Binding(
                get: { blockPlans[block.id]?.subNotes ?? "" },
                set: { blockPlans[block.id, default: BlockSubPlanDraft()].subNotes = $0 }
            )
        )
    }

    private func selectionBinding(for block: AlarmItem) -> Binding<Bool> {
        Binding(
            get: { selectedBlockIDs.contains(block.id) },
            set: { isSelected in
                if isSelected {
                    selectedBlockIDs.insert(block.id)
                } else {
                    selectedBlockIDs.remove(block.id)
                }
            }
        )
    }

    private func blockHasSavedDraft(_ block: AlarmItem) -> Bool {
        subPlans.contains { $0.dateKey == dateKey && $0.linkedAlarmID == block.id }
    }

    private var savedBlockCount: Int {
        selectedBlocksForPlan.filter(blockHasSavedDraft).count
    }

    private var draftBlockCount: Int {
        selectedBlocksForPlan.filter { block in
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let hasTypedContent = !draft.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasTypedContent && !blockHasSavedDraft(block)
        }.count
    }

    private func blockDraftStatus(for block: AlarmItem) -> String {
        guard selectedBlockIDs.contains(block.id) else {
            return blockHasSavedDraft(block) ? "Saved" : "Skipped"
        }

        let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
        let hasTypedContent = !draft.overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.materials.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasTypedContent {
            return blockHasSavedDraft(block) ? "Saved" : "Draft"
        }

        return blockHasSavedDraft(block) ? "Saved" : "Empty"
    }

    private func save() {
        let updatedDaily = DailySubPlanItem(
            id: existingDailyPlan?.id ?? UUID(),
            dateKey: dateKey,
            morningNotes: morningNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            sharedMaterials: sharedMaterials.trimmingCharacters(in: .whitespacesAndNewlines),
            dismissalNotes: dismissalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            emergencyNotes: emergencyNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            includeAttendance: includeAttendance,
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeCommitments: includeCommitments,
            includeSubProfile: includeSubProfile,
            selectedBlockIDs: selectedBlockIDs.sorted { $0.uuidString < $1.uuidString },
            createdAt: existingDailyPlan?.createdAt ?? Date(),
            updatedAt: Date()
        )

        if let index = dailySubPlans.firstIndex(where: { $0.id == updatedDaily.id }) {
            dailySubPlans[index] = updatedDaily
        } else {
            dailySubPlans.insert(updatedDaily, at: 0)
        }

        let selectedIDs = Set(selectedBlockIDs)
        subPlans.removeAll { plan in
            guard let linkedAlarmID = plan.linkedAlarmID else { return false }
            return plan.dateKey == dateKey &&
                schedule.contains(where: { $0.id == linkedAlarmID }) &&
                !selectedIDs.contains(linkedAlarmID)
        }

        for block in selectedBlocksForPlan {
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let existing = subPlans.first(where: { $0.dateKey == dateKey && $0.linkedAlarmID == block.id })
            let updated = SubPlanItem(
                id: existing?.id ?? UUID(),
                dateKey: dateKey,
                linkedAlarmID: block.id,
                className: block.className,
                gradeLevel: GradeLevelOption.normalized(block.gradeLevel),
                location: block.location,
                overview: draft.overview.trimmingCharacters(in: .whitespacesAndNewlines),
                lessonPlan: draft.lessonPlan.trimmingCharacters(in: .whitespacesAndNewlines),
                materials: draft.materials.trimmingCharacters(in: .whitespacesAndNewlines),
                subNotes: draft.subNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                returnNotes: returnNotes.trimmingCharacters(in: .whitespacesAndNewlines),
                includeRoster: includeRoster,
                includeSupports: includeSupports,
                includeAttendance: includeAttendance,
                includeCommitments: includeCommitments,
                includeDaySchedule: true,
                includeSubProfile: includeSubProfile,
                createdAt: existing?.createdAt ?? Date(),
                updatedAt: Date()
            )

            if let index = subPlans.firstIndex(where: { $0.id == updated.id }) {
                subPlans[index] = updated
            } else {
                subPlans.append(updated)
            }
        }

        feedbackMessage = "Saved daily plan for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private func exportTextPlan() {
        let filename = "classtrax-daily-sub-plan-\(dateKey).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? exportText().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Whole-day packet is ready to share."
    }

    private func exportPDFPlan() {
        let filename = "classtrax-daily-sub-plan-\(dateKey)"
        if let url = makeSubPlanPDF(title: "ClassTrax Daily Sub Plan", filename: filename, body: exportText()) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "Whole-day PDF packet is ready to share."
        } else {
            exportTextPlan()
        }
    }

    private func exportSingleBlockTextPlan(for block: AlarmItem) {
        let safeName = block.className.replacingOccurrences(of: " ", with: "-")
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? singleBlockExportText(for: block).write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "\(block.className) packet is ready to share."
    }

    private func exportSingleBlockPDFPlan(for block: AlarmItem) {
        let safeName = block.className.replacingOccurrences(of: " ", with: "-")
        let filename = "classtrax-sub-plan-\(dateKey)-\(safeName)"
        if let url = makeSubPlanPDF(
            title: "ClassTrax Sub Plans",
            filename: filename,
            body: singleBlockExportText(for: block)
        ) {
            exportURL = url
            showingShareSheet = true
            feedbackMessage = "\(block.className) PDF packet is ready to share."
        } else {
            exportSingleBlockTextPlan(for: block)
        }
    }

    private func exportMissingWork() {
        let filename = "classtrax-missing-work-\(dateKey).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? missingWorkCSV().write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
        showingShareSheet = true
        feedbackMessage = "Missing-work CSV is ready to share."
    }

    private func exportText() -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let blockText: String = selectedBlocksForPlan.map { block in
            let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
            let roster = rosterForBlock(block)
            let attendance = attendanceForBlock(block)
            let classNotes = classNotesForBlock(block)
            let studentNotes = studentNotesForBlock(block, roster: roster)
            let blockCommitments = commitmentsForBlock(block)

            let header = [
                block.className,
                "\(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))",
                [block.gradeLevel, block.location]
                    .compactMap(cleanedExportText)
                    .joined(separator: " • ")
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

            let rosterLines: [String] = includeRoster ? roster.map { student in
                var line = "\(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"
                if includeSupports {
                    let supports = [student.accommodations, student.prompts]
                        .compactMap(cleanedExportText)
                    if !supports.isEmpty {
                        line += " — Supports: \(supports.joined(separator: " • "))"
                    }
                }
                return line
            } : []

            let classNoteLines = classNotes.compactMap { cleanedExportText($0.note) }
            let studentNoteLines = studentNotes.compactMap { note -> String? in
                guard let body = cleanedExportText(note.note) else { return nil }
                if let student = roster.first(where: {
                    normalizedStudentKey($0.name) == normalizedStudentKey(note.studentOrGroup)
                }) {
                    return "\(note.studentOrGroup) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]: \(body)"
                }
                return "\(note.studentOrGroup): \(body)"
            }

            let attendanceSummary: String? = includeAttendance ? {
                let counts = Dictionary(grouping: attendance, by: \.status)
                let parts = AttendanceRecord.Status.allCases.compactMap { status -> String? in
                    guard let count = counts[status]?.count, count > 0 else { return nil }
                    return "\(status.rawValue): \(count)"
                }
                return parts.isEmpty ? nil : parts.joined(separator: " • ")
            }() : nil

            let absentHomeworkLines: [String] = includeAttendance
                ? attendance.compactMap { record -> String? in
                    guard record.status == .absent, let homework = cleanedExportText(record.absentHomework) else { return nil }
                    return "\(record.studentName): \(homework)"
                }
                : []

            let commitmentLines: [String] = includeCommitments
                ? blockCommitments.map { "\($0.title): \(commitmentTimeText($0))" }
                : []

            return joinExportSections([
                exportSection("Block", body: cleanedExportText(header)),
                exportSection("Overview", body: cleanedExportText(draft.overview)),
                exportSection("Lesson Plan", body: cleanedExportText(draft.lessonPlan)),
                exportSection("Materials", body: cleanedExportText(draft.materials)),
                exportSection("Sub Notes", body: cleanedExportText(draft.subNotes)),
                exportSection("Roster", body: exportBulletLines(rosterLines)),
                exportSection("Attendance Summary", body: attendanceSummary),
                exportSection("Absent / Missing Work", body: exportBulletLines(absentHomeworkLines)),
                exportSection("Assigned Work", body: exportBulletLines(classNoteLines)),
                exportSection("Student Notes", body: exportBulletLines(studentNoteLines)),
                exportSection("Commitments", body: exportBulletLines(commitmentLines))
            ])
        }.joined(separator: "\n\n--------------------\n\n")

        let renderedBlockText: String? = blockText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : blockText

        return joinExportSections([
            exportSection("Date", body: selectedDate.formatted(date: .complete, time: .omitted)),
            exportSection("Active Schedule", body: displayedOverrideName ?? "Regular Day"),
            includeSubProfile ? exportSection("Teacher Contact", body: cleanedExportText(teacherContactBlock())) : nil,
            includeSubProfile ? exportSection("Emergency / Drill", body: cleanedExportText(emergencyDrillBlock())) : nil,
            includeSubProfile ? exportSection("Classroom Access", body: cleanedExportText(classroomAccessBlock())) : nil,
            includeSubProfile ? exportSection("Static Notes", body: cleanedExportText(staticNotesBlock())) : nil,
            exportSection("Morning Notes", body: cleanedExportText(morningNotes)),
            exportSection("Shared Materials", body: cleanedExportText(sharedMaterials)),
            exportSection("Dismissal Notes", body: cleanedExportText(dismissalNotes)),
            exportSection("Emergency Notes", body: cleanedExportText(emergencyNotes)),
            exportSection("Return Notes", body: cleanedExportText(returnNotes)),
            exportSection("Day Schedule and Block Plans", body: renderedBlockText)
        ])
    }

    private var missingWorkRows: [AttendanceRecord] {
        attendanceRecords
            .filter {
                $0.dateKey == dateKey &&
                $0.status == .absent &&
                !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { first, second in
                if first.className.localizedCaseInsensitiveCompare(second.className) != .orderedSame {
                    return first.className.localizedCaseInsensitiveCompare(second.className) == .orderedAscending
                }
                return first.studentName.localizedCaseInsensitiveCompare(second.studentName) == .orderedAscending
            }
    }

    private func dailyFeedbackRow(message: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }

    private func missingWorkCSV() -> String {
        let header = "date,className,gradeLevel,studentName,status,absentHomework"
        let rows = schedule.flatMap { block in
            attendanceForBlock(block)
                .filter { $0.status == .absent && !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { record in
                    [
                        dateKey,
                        block.className,
                        GradeLevelOption.normalized(block.gradeLevel),
                        record.studentName,
                        record.status.rawValue,
                        record.absentHomework
                    ]
                    .map(csvEscape)
                    .joined(separator: ",")
                }
        }

        if rows.isEmpty {
            let fallbackRow = [
                dateKey,
                "No absent work recorded",
                "",
                "",
                "",
                ""
            ]
            .map(csvEscape)
            .joined(separator: ",")

            return ([header, fallbackRow]).joined(separator: "\n")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    private func singleBlockExportText(for block: AlarmItem) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        let draft = blockPlans[block.id] ?? BlockSubPlanDraft()
        let roster = rosterForBlock(block)
        let attendance = attendanceForBlock(block)
        let classNotes = classNotesForBlock(block)
        let studentNotes = studentNotesForBlock(block, roster: roster)
        let blockCommitments = commitmentsForBlock(block)

        let rosterLines: [String] = includeRoster ? roster.map { student in
            var line = "\(student.name) [\(GradeLevelOption.pillLabel(for: student.gradeLevel))]"
            if includeSupports {
                let supports = [student.accommodations, student.prompts]
                    .compactMap(cleanedExportText)
                if !supports.isEmpty {
                    line += " — Supports: \(supports.joined(separator: " • "))"
                }
            }
            return line
        } : []

        let attendanceSummary = includeAttendance ? {
            let counts = Dictionary(grouping: attendance, by: \.status)
            let parts = AttendanceRecord.Status.allCases.compactMap { status -> String? in
                guard let count = counts[status]?.count, count > 0 else { return nil }
                return "\(status.rawValue): \(count)"
            }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }() : nil

        let absentHomeworkLines: [String] = includeAttendance
            ? attendance.compactMap { record -> String? in
                guard record.status == .absent, let homework = cleanedExportText(record.absentHomework) else { return nil }
                return "\(record.studentName): \(homework)"
            }
            : []

        let classNoteLines = classNotes.compactMap { cleanedExportText($0.note) }
        let studentNoteLines = studentNotes.compactMap { note -> String? in
            guard let body = cleanedExportText(note.note) else { return nil }
            return "\(note.studentOrGroup): \(body)"
        }
        let commitmentLines: [String] = includeCommitments
            ? blockCommitments.map { commitment in
                let start = anchoredDate(commitment.startTime, on: selectedDate)
                let end = anchoredDate(commitment.endTime, on: selectedDate)
                return "\(commitment.title) (\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end)))"
            }
            : []

        let header = [
            selectedDate.formatted(date: .complete, time: .omitted),
            block.className,
            "\(timeFormatter.string(from: anchoredDate(block.startTime, on: selectedDate))) - \(timeFormatter.string(from: anchoredDate(block.endTime, on: selectedDate)))",
            displayedOverrideName ?? "Regular Day"
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")

        return joinExportSections([
            exportSection("Class Packet", body: cleanedExportText(header)),
            includeSubProfile ? exportSection("Teacher Contact", body: cleanedExportText(teacherContactBlock())) : nil,
            includeSubProfile ? exportSection("Emergency / Drill", body: cleanedExportText(emergencyDrillBlock())) : nil,
            includeSubProfile ? exportSection("Classroom Access", body: cleanedExportText(classroomAccessBlock())) : nil,
            includeSubProfile ? exportSection("Static Notes", body: cleanedExportText(staticNotesBlock())) : nil,
            exportSection("Shared Materials", body: cleanedExportText(sharedMaterials)),
            exportSection("Overview", body: cleanedExportText(draft.overview)),
            exportSection("Lesson Plan", body: cleanedExportText(draft.lessonPlan)),
            exportSection("Materials", body: cleanedExportText(draft.materials)),
            exportSection("Sub Notes", body: cleanedExportText(draft.subNotes)),
            exportSection("Return Notes", body: cleanedExportText(returnNotes)),
            exportSection("Roster", body: exportBulletLines(rosterLines)),
                exportSection("Attendance Summary", body: attendanceSummary),
            exportSection("Absent / Missing Work", body: exportBulletLines(absentHomeworkLines)),
            exportSection("Assigned Work", body: exportBulletLines(classNoteLines)),
            exportSection("Student Notes", body: exportBulletLines(studentNoteLines)),
            exportSection("Commitments", body: exportBulletLines(commitmentLines))
        ])
    }

    private func teacherContactBlock() -> String {
        let lines = [
            labeledLine("Teacher", subPlanProfile.teacherName),
            labeledLine("Room", subPlanProfile.room),
            labeledLine("Email", subPlanProfile.contactEmail),
            labeledLine("Phone", subPlanProfile.contactPhone),
            labeledLine("Front Office", subPlanProfile.schoolFrontOfficeContact),
            labeledLine("Neighboring Teacher", subPlanProfile.neighboringTeacher)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func emergencyDrillBlock() -> String {
        let lines = [
            blockText(subPlanProfile.emergencyDrillProcedures),
            labeledLine("File Link", subPlanProfile.emergencyDrillFileLink)
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func classroomAccessBlock() -> String {
        let credentialText = subPlanProfile.appCredentials
            .filter(\.hasContent)
            .map { credential in
                [
                    labeledLine("App", credential.applicationName),
                    labeledLine("Link", credential.applicationLink),
                    labeledLine("Username", credential.username),
                    labeledLine("Password", credential.password)
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let lines = [
            labeledLine("Extensions", subPlanProfile.phoneExtensions),
            blockText(subPlanProfile.passwordsAccessNotes),
            credentialText.isEmpty ? nil : credentialText
        ].compactMap { $0 }
        return lines.isEmpty ? "Not added yet" : lines.joined(separator: "\n")
    }

    private func staticNotesBlock() -> String {
        blockText(subPlanProfile.staticNotes) ?? "Not added yet"
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(label): \(trimmed)"
    }

    private func blockText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rosterForBlock(_ block: AlarmItem) -> [StudentSupportProfile] {
        let linkedIDs = Set(block.linkedStudentIDs)
        if !linkedIDs.isEmpty {
            return students.filter { linkedIDs.contains($0.id) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        let normalizedGrade = GradeLevelOption.normalized(block.gradeLevel)
        return students.filter { profile in
            classNamesMatch(scheduleClassName: block.className, profileClassName: profile.className) &&
            (
                normalizedGrade.isEmpty ||
                profile.gradeLevel.isEmpty ||
                normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel)) == normalizedStudentKey(normalizedGrade)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func attendanceForBlock(_ block: AlarmItem) -> [AttendanceRecord] {
        attendanceRecords.filter {
            $0.dateKey == dateKey &&
            $0.isAttendanceEntry &&
            classNamesMatch(scheduleClassName: block.className, profileClassName: $0.className) &&
            normalizedStudentKey($0.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(block.gradeLevel))
        }
        .sorted { $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending }
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func classNotesForBlock(_ block: AlarmItem) -> [FollowUpNoteItem] {
        followUpNotes.filter {
            $0.kind == .classNote &&
            classNamesMatch(scheduleClassName: block.className, profileClassName: $0.context)
        }
    }

    private func studentNotesForBlock(_ block: AlarmItem, roster: [StudentSupportProfile]) -> [FollowUpNoteItem] {
        let studentKeys = Set(roster.map { normalizedStudentKey($0.name) })
        return followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            studentKeys.contains(normalizedStudentKey($0.studentOrGroup))
        }
    }

    private func commitmentsForBlock(_ block: AlarmItem) -> [CommitmentItem] {
        commitmentsForSelectedDate.filter { commitment in
            let start = anchoredDate(commitment.startTime, on: selectedDate)
            let end = anchoredDate(commitment.endTime, on: selectedDate)
            let blockStart = anchoredDate(block.startTime, on: selectedDate)
            let blockEnd = anchoredDate(block.endTime, on: selectedDate)
            return start < blockEnd && end > blockStart
        }
    }

    private func anchoredDate(_ time: Date, on day: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func commitmentTimeText(_ commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    private func dailySubPlanCardBackground(accent: Color) -> some View {
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

    private func dailyInfoRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Commitments

struct TodayCommitmentsManagerView: View {
    @Binding var commitments: [CommitmentItem]
    let onAdd: () -> Void
    let onEdit: (CommitmentItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private var groupedCommitments: [(day: WeekdayTab, items: [CommitmentItem])] {
        WeekdayTab.allCases.compactMap { day in
            let items = commitments
                .filter { $0.dayOfWeek == day.rawValue }
                .sorted {
                    if $0.startTime == $1.startTime {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return $0.startTime < $1.startTime
                }

            guard !items.isEmpty else { return nil }
            return (day, items)
        }
    }

    var body: some View {
        List {
            Section {
                Text("Commitments can repeat weekly or be saved as one-time events for a specific date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if groupedCommitments.isEmpty {
                Section("No Commitments Yet") {
                    Text("Add duties, meetings, conferences, or coverage blocks so they stay attached to the correct weekday.")
                        .foregroundStyle(.secondary)

                    Button("Add Commitment", systemImage: "plus.circle.fill") {
                        onAdd()
                    }
                }
            } else {
                ForEach(groupedCommitments, id: \.day) { section in
                    Section(section.day.title) {
                        ForEach(section.items) { commitment in
                            Button {
                                onEdit(commitment)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(commitment.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(
                                        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    Text(commitment.recurrence == .oneTime
                                        ? "One Time • \((commitment.specificDate ?? Date()).formatted(date: .abbreviated, time: .omitted))"
                                        : "Recurring Weekly")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if !commitment.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(commitment.location)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Commitments")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onAdd()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
}

func makeSubPlanPDF(title: String, filename: String, body: String) -> URL? {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(filename)-\(UUID().uuidString).pdf")

    let attributed = makeStyledSubPlanAttributedString(title: title, body: body)
    let printableRect = CGRect(x: 36, y: 36, width: 540, height: 720)

    do {
        try renderer.writePDF(to: url) { context in
            var range = NSRange(location: 0, length: attributed.length)
            var pageNumber = 1

            while range.location < attributed.length {
                context.beginPage()
                drawSubPlanPageHeader(title: title, pageNumber: pageNumber, in: printableRect)
                range = drawSubPlanAttributedString(attributed, in: printableRect, range: range)
                pageNumber += 1
            }
        }
        return url
    } catch {
        return nil
    }
}

private func drawSubPlanAttributedString(_ string: NSAttributedString, in rect: CGRect, range: NSRange) -> NSRange {
    let framesetter = CTFramesetterCreateWithAttributedString(string)
    guard let context = UIGraphicsGetCurrentContext() else {
        return range
    }

    let pageBounds = UIGraphicsGetPDFContextBounds()
    let coreTextRect = CGRect(
        x: rect.minX,
        y: pageBounds.height - rect.maxY,
        width: rect.width,
        height: rect.height
    )
    let path = CGPath(rect: coreTextRect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(range.location, range.length), path, nil)

    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: 0, y: pageBounds.height)
    context.scaleBy(x: 1, y: -1)
    CTFrameDraw(frame, context)
    context.restoreGState()

    let visibleRange = CTFrameGetVisibleStringRange(frame)
    return NSRange(location: range.location + visibleRange.length, length: string.length - range.location - visibleRange.length)
}

private func makeStyledSubPlanAttributedString(title: String, body: String) -> NSAttributedString {
    let result = NSMutableAttributedString()

    let titleParagraph = NSMutableParagraphStyle()
    titleParagraph.alignment = .left
    titleParagraph.lineBreakMode = .byWordWrapping
    titleParagraph.paragraphSpacing = 10

    let headingParagraph = NSMutableParagraphStyle()
    headingParagraph.alignment = .left
    headingParagraph.lineBreakMode = .byWordWrapping
    headingParagraph.paragraphSpacing = 6
    headingParagraph.paragraphSpacingBefore = 10

    let bodyParagraph = NSMutableParagraphStyle()
    bodyParagraph.alignment = .left
    bodyParagraph.lineBreakMode = .byWordWrapping
    bodyParagraph.lineSpacing = 3
    bodyParagraph.paragraphSpacing = 8

    let bulletParagraph = NSMutableParagraphStyle()
    bulletParagraph.alignment = .left
    bulletParagraph.lineBreakMode = .byWordWrapping
    bulletParagraph.lineSpacing = 2
    bulletParagraph.paragraphSpacing = 4
    bulletParagraph.headIndent = 16
    bulletParagraph.firstLineHeadIndent = 0

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: UIColor.label,
        .paragraphStyle: titleParagraph
    ]

    let headingAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: UIColor.label,
        .paragraphStyle: headingParagraph
    ]

    let bodyAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12.5, weight: .regular),
        .foregroundColor: UIColor.label,
        .paragraphStyle: bodyParagraph
    ]

    let bulletAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular),
        .foregroundColor: UIColor.label,
        .paragraphStyle: bulletParagraph
    ]

    result.append(NSAttributedString(string: "\(title)\n", attributes: titleAttributes))

    let blocks = body
        .components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    for block in blocks {
        let lines = block.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { continue }
        let remainingLines = Array(lines.dropFirst())

        if !remainingLines.isEmpty {
            result.append(NSAttributedString(string: "\(firstLine)\n", attributes: headingAttributes))
            appendSubPlanBodyLines(remainingLines, to: result, bodyAttributes: bodyAttributes, bulletAttributes: bulletAttributes)
        } else {
            let isBullet = firstLine.trimmingCharacters(in: .whitespaces).hasPrefix("-")
            let attributes = isBullet ? bulletAttributes : bodyAttributes
            result.append(NSAttributedString(string: "\(firstLine)\n", attributes: attributes))
        }

        result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
    }

    return result
}

private func appendSubPlanBodyLines(
    _ lines: [String],
    to result: NSMutableAttributedString,
    bodyAttributes: [NSAttributedString.Key: Any],
    bulletAttributes: [NSAttributedString.Key: Any]
) {
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let isBullet = trimmedLine.hasPrefix("-")
        let isIndented = line.hasPrefix("  ")
        let attributes = (isBullet || isIndented) ? bulletAttributes : bodyAttributes
        result.append(NSAttributedString(string: "\(line)\n", attributes: attributes))
    }
}

private func drawSubPlanPageHeader(title: String, pageNumber: Int, in rect: CGRect) {
    let headerText = "\(title)    Page \(pageNumber)"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .right

    let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 9, weight: .medium),
        .foregroundColor: UIColor.secondaryLabel,
        .paragraphStyle: paragraph
    ]

    let headerRect = CGRect(x: rect.minX, y: 18, width: rect.width, height: 16)
    headerText.draw(in: headerRect, withAttributes: attributes)
}

private func cleanedExportText(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func exportSection(_ title: String, body: String?) -> String? {
    guard let body = body, !body.isEmpty else { return nil }
    return "\(title)\n\(body)"
}

private func exportBulletLines(_ lines: [String]) -> String? {
    let cleaned = lines
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard !cleaned.isEmpty else { return nil }
    return cleaned.map { "- \($0)" }.joined(separator: "\n")
}

private func joinExportSections(_ sections: [String?]) -> String {
    sections
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
}

func exportContextPill(title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
}

// MARK: - Core Dashboard Cards

extension TodayView {
    @ViewBuilder
    func classSectionCard(activeItem: AlarmItem?, nextItem: AlarmItem?, schedule: [AlarmItem], now: Date, compact: Bool) -> some View {
        let completedItem = schedule.last(where: {
            endDateToday(for: $0, now: now) < now
        })

        if let item = activeItem ?? nextItem ?? completedItem {
            let context = item.instructionalContextSummary(using: classDefinitions, workflowMode: teacherWorkflowMode)
            let displayClassTitle = item.className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? context.displayTitle
                : item.className
            let linkedContextNames = item.linkedInstructionalContextNames(using: classDefinitions, workflowMode: teacherWorkflowMode)
            let hasMultipleContexts = linkedContextNames.count > 1
            let roster = rosterStudents(for: item)
            let behaviorRoster = behaviorTrackedStudents(from: roster)
            let behaviorSummary = behaviorSnapshot(for: item, roster: behaviorRoster)
            let recentBehaviorNotes = recentBehaviorNotes(for: item, roster: behaviorRoster)
            let needsSupportStudents = needsSupportStudents(for: item, roster: behaviorRoster)
            let behaviorPatternInsights = behaviorPatternInsights(for: item, roster: behaviorRoster)
            let classBehaviorNote = latestClassBehaviorNote(for: item)
            let classBehaviorSnapshot = classBehaviorSnapshot(for: item, roster: behaviorRoster, now: now)
            VStack(alignment: .leading, spacing: compact ? 7 : 9) {
                Text(currentContextCardTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    if roster.isEmpty {
                        openBlock(item)
                    } else {
                        rosterItem = item
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item.type.themeColor.opacity(item.type == .blank ? 0.10 : 0.16))
                                .frame(width: compact ? 30 : 34, height: compact ? 50 : 56)

                            Image(systemName: item.type.symbolName)
                                .font(.system(size: compact ? 13 : 15, weight: .bold))
                                .foregroundStyle(item.type == .blank ? .secondary : item.type.themeColor)
                        }

                        VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(displayClassTitle)
                                    .font(compact ? .subheadline.weight(.bold) : .headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Text(
                                    activeItem?.id == item.id
                                        ? "NOW"
                                        : (nextItem?.id == item.id ? "NEXT" : "LAST")
                                )
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    activeItem?.id == item.id
                                        ? item.type.themeColor
                                        : (nextItem?.id == item.id ? Color.orange : Color.secondary),
                                    in: Capsule()
                                )

                                if teacherWorkflowMode != .classroom || hasMultipleContexts {
                                    HStack(spacing: 6) {
                                        if teacherWorkflowMode != .classroom {
                                            Text(context.kind.displayName)
                                                .font(.caption2.weight(.black))
                                                .foregroundStyle(item.type == .blank ? .secondary : item.type.themeColor)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill((item.type == .blank ? Color.secondary : item.type.themeColor).opacity(0.12))
                                                )
                                        }

                                    }
                                }

                                Spacer(minLength: 6)

                                if item.type != .blank {
                                    TypeBadge(type: item.type)
                                }
                            }

                            HStack(spacing: 10) {
                                Text(
                                    "\(startDateToday(for: item, now: now).formatted(date: .omitted, time: .shortened)) – \(endDateToday(for: item, now: now).formatted(date: .omitted, time: .shortened))"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(item.location)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                let meta = [item.gradeLevel, item.location]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " • ")

                if !meta.isEmpty {
                    Text(meta)
                        .font(compact ? .caption : .footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !item.blockSupportNote.isEmpty {
                    Text("Support note: \(item.blockSupportNote)")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if hasMultipleContexts {
                    Text(linkedContextNames.joined(separator: " • "))
                        .font(compact ? .caption2 : .footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if isHomeworkEnabled {
                        taskStatusPill(
                            title: "Homework",
                            isComplete: hasHomeworkLogged(for: item, now: now),
                            color: .cyan
                        )
                    }

                    if isHomeworkEnabled {
                        taskStatusPill(
                            title: "Assigned Work",
                            isComplete: !classHomeworkText(for: item, now: now)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty,
                            color: .teal
                        )
                    }

                    if isBehaviorEnabled {
                        taskStatusPill(
                            title: "Behavior",
                            isComplete: behaviorSummary.totalCount > 0,
                            color: .pink
                        )
                    }
                }

                if isBehaviorEnabled, classBehaviorSnapshot.totalCount > 0 {
                    currentClassBehaviorSnapshotCard(snapshot: classBehaviorSnapshot)
                }

                if !roster.isEmpty {
                    if isBehaviorEnabled, behaviorSummary.totalCount > 0 {
                        Text("Behavior logged for \(behaviorSummary.totalCount) student\(behaviorSummary.totalCount == 1 ? "" : "s") in this block today.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            if !needsSupportStudents.isEmpty {
                                todayBehaviorRollupRow(
                                    title: "Needs support",
                                    detail: needsSupportStudents
                                        .prefix(3)
                                        .map { "\($0.studentName) (\($0.behavior.shortLabel))" }
                                        .joined(separator: ", "),
                                    tint: .orange
                                )
                            }

                            if let trigger = behaviorPatternInsights.trigger {
                                todayBehaviorRollupRow(
                                    title: "Trigger",
                                    detail: "\(trigger.value) • \(trigger.count)x today",
                                    tint: .orange
                                )
                            }

                            if let intervention = behaviorPatternInsights.intervention {
                                todayBehaviorRollupRow(
                                    title: "Intervention",
                                    detail: "\(intervention.value) • \(intervention.count)x today",
                                    tint: .blue
                                )
                            }

                            if !recentBehaviorNotes.isEmpty {
                                let notedStudents = recentBehaviorNotes
                                    .prefix(3)
                                    .map(\.studentName)
                                    .joined(separator: ", ")
                                todayBehaviorRollupRow(
                                    title: "Notes",
                                    detail: "\(recentBehaviorNotes.count) recent note\(recentBehaviorNotes.count == 1 ? "" : "s")" + (notedStudents.isEmpty ? "" : " • \(notedStudents)"),
                                    tint: .blue
                                )
                            }

                            if let classBehaviorNote,
                               !classBehaviorNote.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                todayBehaviorRollupRow(
                                    title: "Class note",
                                    detail: classBehaviorNote.note,
                                    tint: .purple
                                )
                            }
                        }
                    } else if isBehaviorEnabled {
                        Text("No behavior check-ins saved for this block yet today.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)

                        if behaviorRoster.isEmpty {
                            Text("No behavior-tracked students are linked to this block.")
                                .font(compact ? .caption2 : .caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button {
                                markAllStudentsOK(for: item, roster: behaviorRoster)
                            } label: {
                                Label("Log All Students OK", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(behaviorRoster.isEmpty)

                            Button {
                                classBehaviorNoteItem = item
                            } label: {
                                Label("Class Note", systemImage: "note.text")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                        }
                    } else if let classBehaviorNote,
                              !classBehaviorNote.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        todayBehaviorRollupRow(
                            title: "Class note",
                            detail: classBehaviorNote.note,
                            tint: .purple
                        )
                    }
                }

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        if isAttendanceEnabled {
                            Button {
                                presentRollCall(for: item, now: now, schedule: schedule)
                            } label: {
                                Label("Attendance", systemImage: "checklist.checked")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(dashboardPrimaryTint)
                            .controlSize(compact ? .small : .regular)
                            .disabled(roster.isEmpty)
                            .opacity(attendanceCompletionText(for: item, now: now) == "Attendance complete" ? 0.58 : 1)
                        }

                        if isHomeworkEnabled {
                            Button {
                                presentHomeworkCapture(for: item, now: now)
                            } label: {
                                Label(
                                    "Homework Check-In",
                                    systemImage: "text.book.closed"
                                )
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .controlSize(compact ? .small : .regular)
                            .opacity(
                                classHomeworkText(for: item, now: now)
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty ? 1 : 0.58
                            )
                        }
                    }

                    if !roster.isEmpty {
                        HStack(spacing: 10) {
                            Button {
                                presentStudentLookup(for: item)
                            } label: {
                                Label(hasMultipleContexts ? "Choose Student Group (\(roster.count))" : "Students (\(roster.count))", systemImage: "person.text.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .buttonStyle(.bordered)
                            .tint(.mint)
                            .controlSize(compact ? .small : .regular)

                            if isBehaviorEnabled {
                                Button {
                                    presentBehaviorLookup(for: item)
                                } label: {
                                    Label("Behavior", systemImage: "face.smiling")
                                        .frame(maxWidth: .infinity)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.pink)
                                .controlSize(compact ? .small : .regular)
                                .disabled(behaviorRoster.isEmpty)
                                .opacity(behaviorSummary.totalCount > 0 ? 0.58 : 1)
                            }
                        }
                    }

                    Menu {
                        Button("Open Roster", systemImage: "person.3") {
                            rosterItem = item
                        }

                        Button("Sub Plans", systemImage: "doc.text") {
                            subPlanItem = item
                        }

                        Button("Class Controls", systemImage: "ellipsis.circle") {
                            sessionActionItem = item
                            showingSessionActions = true
                        }
                    } label: {
                        Label(hasMultipleContexts ? "Classes / Groups & More" : rosterAndMoreLabel, systemImage: "ellipsis.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .buttonStyle(.bordered)
                    .tint(dashboardSecondaryTint)
                    .controlSize(compact ? .small : .regular)
                }

            }
            .modifier(DashboardCardStyle(accent: item.type.themeColor == .clear ? .blue : item.type.themeColor, compact: compact))
        }
    }

    @ViewBuilder
    func attendanceDashboardCard(
        schedule: [AlarmItem],
        now: Date,
        activeItem: AlarmItem?,
        compact: Bool
    ) -> some View {
        let currentAttendanceTarget = activeItem ?? schedule.first {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }
        let attendanceSummary = todayAttendanceSummary(now: now, schedule: schedule)
        let activeAttendanceSnapshot = currentAttendanceTarget.map { classAttendanceSnapshot(for: $0, now: now) }
        let previousAttendanceItems = schedule
            .filter {
                endDateToday(for: $0, now: now) < now &&
                !rosterStudents(for: $0).isEmpty
            }
            .sorted {
                endDateToday(for: $0, now: now) > endDateToday(for: $1, now: now)
            }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Class Operations", systemImage: "checklist.checked")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()
            }

            HStack(spacing: 8) {
                attendanceSummaryPill(title: "Done", value: "\(attendanceSummary.completedBlocks)", accent: .green)
                attendanceSummaryPill(title: "Pending", value: "\(attendanceSummary.pendingBlocks)", accent: .orange)
                attendanceSummaryPill(title: "Absent", value: "\(attendanceSummary.absentStudents)", accent: .red)
            }

            if let currentAttendanceTarget {
                Button {
                    openBlock(currentAttendanceTarget)
                } label: {
                    Text(currentAttendanceTarget.className)
                        .font((compact ? Font.caption : .subheadline).weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if let completionText = attendanceCompletionText(for: currentAttendanceTarget, now: now) {
                    Text(completionText)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }

                Text(
                    isHomeworkEnabled
                        ? "Take attendance for the current block, then review homework or open the roster if you need more detail."
                        : "Take attendance for the current block, then open the roster if you need more detail."
                )
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)

                if let activeAttendanceSnapshot, activeAttendanceSnapshot.totalCount > 0 {
                    currentClassAttendanceSnapshotCard(snapshot: activeAttendanceSnapshot)
                }

                Button {
                    presentRollCall(for: currentAttendanceTarget, now: now, schedule: schedule)
                } label: {
                    Label("Take Attendance", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(dashboardPrimaryTint)
                .disabled(rosterStudents(for: currentAttendanceTarget).isEmpty)
                .opacity(attendanceCompletionText(for: currentAttendanceTarget, now: now) == "Attendance complete" ? 0.58 : 1)

                Button {
                    rosterItem = currentAttendanceTarget
                } label: {
                    Label("Open Roster", systemImage: "person.3")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(dashboardSecondaryTint)
            } else {
                Text("No active class or group right now.")
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                Text("Use the most recent block below if you need to catch up on attendance.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }

            if !previousAttendanceItems.isEmpty {
                Menu {
                    ForEach(previousAttendanceItems) { previousItem in
                        Button {
                            presentRollCall(for: previousItem, now: now, schedule: schedule)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(previousItem.className)
                                Text(
                                    "\(previousItem.startTime.formatted(date: .omitted, time: .shortened)) - \(previousItem.endTime.formatted(date: .omitted, time: .shortened))"
                                )
                            }
                        }
                    }
                } label: {
                    Label("Review Another Class (\(previousAttendanceItems.count))", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(dashboardSecondaryTint)
            }

            if isHomeworkEnabled {
                Button {
                    homeworkReviewDate = now
                    showingHomeworkReview = true
                } label: {
                    Label("Review Assigned & Missing Work", systemImage: "text.book.closed")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(dashboardSecondaryTint)
                .disabled(attendanceRecordsForToday(now: now).allSatisfy {
                    $0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                })
            }

            Menu {
                Button("All Attendance (.txt)", systemImage: "doc.text") {
                    exportTodayAttendance(as: .text, scope: .all, schedule: schedule, now: now)
                }

                Button("All Attendance (.csv)", systemImage: "tablecells") {
                    exportTodayAttendance(as: .csv, scope: .all, schedule: schedule, now: now)
                }

                Divider()

                Button("Absent Only (.txt)", systemImage: "doc.text.magnifyingglass") {
                    exportTodayAttendance(as: .text, scope: .absentOnly, schedule: schedule, now: now)
                }

                Button("Absent Only (.csv)", systemImage: "tablecells.badge.ellipsis") {
                    exportTodayAttendance(as: .csv, scope: .absentOnly, schedule: schedule, now: now)
                }
            } label: {
                Label("Export Attendance", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(dashboardSecondaryTint)
            .disabled(attendanceRecordsForToday(now: now).isEmpty)
        }
        .modifier(DashboardCardStyle(accent: .blue, compact: compact))
    }

    private func attendanceSummaryPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
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
    func subPlanCard(schedule: [AlarmItem], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sub Plans", systemImage: "doc.text")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))
                Spacer()
            }

            Text("Choose a plan date, then build the substitute packet with the correct schedule, roster, supports, notes, and attendance for that day.")
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.secondary)

            DatePicker(
                "Plan Date",
                selection: $dailySubPlanDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()

            Button {
                showingDailySubPlan = true
            } label: {
                Label(
                    "Open \(shortPlanDateLabel(for: dailySubPlanDate)) Sub Plan",
                    systemImage: "square.and.pencil"
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }

    @ViewBuilder
    func studentSupportCard(activeItem: AlarmItem?, nextItem: AlarmItem?, compact: Bool) -> some View {
        let activeSupports = activeItem.map { rosterStudents(for: $0) } ?? []
        let nextSupports = nextItem.map { rosterStudents(for: $0) } ?? []
        let relevantTasks = topTasks(for: Date()).filter {
            let key = $0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            return !key.isEmpty && studentSupportsByName[key] != nil
        }

        if let activeItem, !activeSupports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(activeSupportCardTitle, systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        rosterItem = activeItem
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(activeItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryView(
                    students: activeSupports,
                    compact: compact,
                    fallback: "Student details stay private until you open the roster."
                )
            }
            .modifier(DashboardCardStyle(accent: activeItem.type.themeColor == .clear ? .blue : activeItem.type.themeColor, compact: compact))
        } else if let nextItem, !nextSupports.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(upcomingSupportCardTitle, systemImage: "person.2.wave.2.fill")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        rosterItem = nextItem
                    }
                    .font(.caption.weight(.semibold))
                }

                Text(nextItem.className)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                supportSummaryView(
                    students: nextSupports,
                    compact: compact,
                    fallback: "Open the class to review roster details when you need them."
                )
            }
            .modifier(DashboardCardStyle(accent: nextItem.type.themeColor == .clear ? .blue : nextItem.type.themeColor, compact: compact))
        } else if relevantTasks.compactMap({ task in
            studentSupportsByName[task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)]
        }).first != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Student Support", systemImage: "person.crop.circle.badge.checkmark")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    Button("Open") {
                        openStudentsTab()
                    }
                    .font(.caption.weight(.semibold))
                }

                Text("Confidential student support item")
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))

                Text("Open the linked class or student notes to review details.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
            .modifier(DashboardCardStyle(accent: .mint, compact: compact))
        }
    }

    func rosterStudents(for item: AlarmItem, targetClassDefinitionID: UUID? = nil) -> [StudentSupportProfile] {
        let explicitLinkedProfiles: [StudentSupportProfile] = {
            guard !item.linkedStudentIDs.isEmpty else { return [] }
            let linkedIDs = Set(item.linkedStudentIDs)
            var linkedProfiles = studentSupportProfiles.filter { linkedIDs.contains($0.id) }
            if let targetClassDefinitionID {
                linkedProfiles = linkedProfiles.filter { profileMatches(classDefinitionID: targetClassDefinitionID, profile: $0) }
            }
            return linkedProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }()

        let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))

        let nameMatchedProfiles = studentSupportProfiles
            .filter { profile in
                let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                guard classNamesMatch(scheduleClassName: item.className, profileClassName: profile.className) else { return false }
                if gradeKey.isEmpty || profileGradeKey.isEmpty {
                    return true
                }
                return profileGradeKey == gradeKey
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let contextMatchedProfiles = studentSupportProfiles
            .filter { profile in
                if let targetClassDefinitionID {
                    let matchesLinkedContext = profileMatches(classDefinitionID: targetClassDefinitionID, profile: profile)
                    guard matchesLinkedContext else { return false }
                    if gradeKey.isEmpty {
                        return true
                    }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }

                if !item.linkedClassDefinitionIDs.isEmpty {
                    let matchesLinkedContext = item.linkedClassDefinitionIDs.contains { linkedID in
                        profileMatches(classDefinitionID: linkedID, profile: profile)
                    }
                    guard matchesLinkedContext else { return false }
                    if gradeKey.isEmpty {
                        return true
                    }
                    let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                    return profileGradeKey.isEmpty || profileGradeKey == gradeKey
                }

                return nameMatchedProfiles.contains(where: { $0.id == profile.id })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let resolvedContextProfiles: [StudentSupportProfile] = {
            guard contextMatchedProfiles.isEmpty else { return contextMatchedProfiles }

            if let targetClassDefinitionID,
               let targetDefinition = classDefinitions.first(where: { $0.id == targetClassDefinitionID }) {
                let targetName = targetDefinition.name
                return studentSupportProfiles
                    .filter { profile in
                        let profileGradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
                        guard classNamesMatch(scheduleClassName: targetName, profileClassName: profile.className) else { return false }
                        if gradeKey.isEmpty || profileGradeKey.isEmpty {
                            return true
                        }
                        return profileGradeKey == gradeKey
                    }
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }

            if !item.linkedClassDefinitionIDs.isEmpty {
                return nameMatchedProfiles
            }

            return contextMatchedProfiles
        }()

        guard !explicitLinkedProfiles.isEmpty else {
            return resolvedContextProfiles
        }

        var mergedProfiles = explicitLinkedProfiles
        let existingIDs = Set(explicitLinkedProfiles.map(\.id))
        mergedProfiles.append(contentsOf: resolvedContextProfiles.filter { !existingIDs.contains($0.id) })
        return mergedProfiles
    }

    func presentAttendance(for item: AlarmItem, now: Date, schedule: [AlarmItem], targetClassDefinitionID: UUID? = nil, targetTitle: String? = nil) {
        attendanceSession = AttendanceSession(
            item: item,
            date: now,
            schedule: schedule,
            students: rosterStudents(for: item, targetClassDefinitionID: targetClassDefinitionID),
            targetClassDefinitionID: targetClassDefinitionID,
            targetTitle: targetTitle
        )
    }

    func adjustedTodaySchedule(for now: Date) -> [AlarmItem] {
        let weekday = Calendar.current.component(.weekday, from: now)

        let todaysItems = (overrideSchedule ?? alarms)
            .filter { $0.dayOfWeek == weekday }
            .sorted { $0.startTime < $1.startTime }

        var cumulativeOffset: TimeInterval = 0
        var adjustedItems: [AlarmItem] = []

        for item in todaysItems {
            var adjusted = item

            adjusted.start = item.start.addingTimeInterval(cumulativeOffset)

            let liveHold = liveHoldDuration(for: item, now: now)
            let extra = (extraTimeByItemID[item.id] ?? 0) + liveHold

            adjusted.end = item.end
                .addingTimeInterval(cumulativeOffset)
                .addingTimeInterval(extra)

            adjustedItems.append(adjusted)
            cumulativeOffset += extra
        }

        return adjustedItems
    }

    func laterTodayItems(
        from schedule: [AlarmItem],
        now: Date,
        nextItem: AlarmItem?
    ) -> [AlarmItem] {
        let nextID = nextItem?.id

        return schedule
            .filter { startDateToday(for: $0, now: now) > now && $0.id != nextID }
            .prefix(3)
            .map { $0 }
    }

    func displayableNextItem(_ item: AlarmItem?, now: Date) -> AlarmItem? {
        guard let item else { return nil }
        guard startDateToday(for: item, now: now).timeIntervalSince(now) <= 7200 else { return nil }
        return item
    }

    func commitmentsForToday(now: Date) -> [CommitmentItem] {
        resolvedCommitments(for: now, from: commitments)
    }

    func todayCustomizationCard(compact: Bool) -> some View {
        let accent = Color.blue

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font((compact ? Font.subheadline : .headline).weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Keeping Today Focused")
                        .font((compact ? Font.subheadline : .subheadline).weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Open Customize Today to show or hide cards and tailor the screen to your routine.")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button("Customize Today") {
                showingLayoutCustomization = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
        }
        .modifier(DashboardCardStyle(accent: accent, compact: compact))
    }
}

// MARK: - Dashboard Summary and Secondary Cards

extension TodayView {
    @ViewBuilder
    func supportSummaryView(
        students: [StudentSupportProfile],
        compact: Bool,
        fallback: String
    ) -> some View {
        let accommodationsCount = students.filter {
            !$0.accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let promptCount = students.filter {
            !$0.prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        let spedCount = students.filter(\.isSped).count
        let firstPrompt = students
            .map { $0.prompts.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        let firstSupportSummary = students
            .map { supportSummary(for: $0, teachers: teacherContacts, paras: paraContacts) }
            .first { !$0.isEmpty }

        let summaryParts = [
            students.isEmpty ? nil : "\(students.count) student\(students.count == 1 ? "" : "s")",
            spedCount == 0 ? nil : "\(spedCount) with additional supports",
            accommodationsCount == 0 ? nil : "\(accommodationsCount) with accommodations",
            promptCount == 0 ? nil : "\(promptCount) with prompts"
        ].compactMap { $0 }

        Text(summaryParts.isEmpty ? fallback : summaryParts.joined(separator: " • "))
            .font(compact ? .caption2 : .caption)
            .foregroundStyle(.secondary)

        if let firstSupportSummary {
            Text(firstSupportSummary)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        } else if let firstPrompt {
            Text(firstPrompt)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
    }

    func dayStatusCard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let remainingCount = schedule.filter { endDateToday(for: $0, now: now) > now }.count
        let finalBlock = schedule.max { startDateToday(for: $0, now: now) < startDateToday(for: $1, now: now) }
        let statusTitle: String
        let statusDetail: String
        let tint: Color

        if let ignoreDate, ignoreDate > now {
            statusTitle = "Alerts Snoozed"
            statusDetail = "Notifications are snoozed until \(ignoreDate.formatted(date: .abbreviated, time: .shortened))."
            tint = .orange
        } else if let activeItem {
            statusTitle = "School Day In Motion"
            statusDetail = "\(remainingCount) block\(remainingCount == 1 ? "" : "s") left today"
            tint = activeItem.accentColor == .clear ? .blue : activeItem.accentColor
        } else if let next = schedule.first(where: { startDateToday(for: $0, now: now) > now }) {
            statusTitle = "Next Block Ahead"
            statusDetail = "\(next.className) starts at \(startDateToday(for: next, now: now).formatted(date: .omitted, time: .shortened))"
            tint = next.accentColor == .clear ? .blue : next.accentColor
        } else {
            statusTitle = "School Day Wrapped"
            statusDetail = "No more scheduled blocks today."
            tint = .indigo
        }

        return VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: ignoreDate != nil && (ignoreDate ?? now) > now ? "bell.slash.fill" : "sparkles")
                    .foregroundStyle(tint)
                    .font(compact ? .headline : .title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Text(statusDetail)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                if isScheduleEnabled {
                    Button {
                        openScheduleTab()
                    } label: {
                        cardActionLabel("Schedule", accent: tint)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: compact ? 8 : 10) {
                statusPill(
                    title: "Blocks Left",
                    value: "\(remainingCount)",
                    compact: compact
                )

                if let finalBlock {
                    statusPill(
                        title: "Dismissal",
                        value: endDateToday(for: finalBlock, now: now).formatted(date: .omitted, time: .shortened),
                        compact: compact
                    )
                }
            }
        }
        .modifier(DashboardCardStyle(accent: tint, compact: compact))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    var teacherWorkflowMode: TeacherWorkflowMode {
        TeacherWorkflowMode(rawValue: teacherWorkflowModeRawValue) ?? .classroom
    }

    var currentContextCardTitle: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Current / Next Class"
        case .resourceSped:
            return "Current / Next Session"
        case .hybrid:
            return "Current / Next Class / Group"
        }
    }

    var rosterAndMoreLabel: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Roster & More"
        case .resourceSped:
            return "Students & More"
        case .hybrid:
            return "Class / Group & More"
        }
    }

    var activeSupportCardTitle: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Class Support"
        case .resourceSped:
            return "Active Group Support"
        case .hybrid:
            return "Active Class / Group Support"
        }
    }

    var upcomingSupportCardTitle: String {
        switch teacherWorkflowMode {
        case .classroom:
            return "Next Class Support"
        case .resourceSped:
            return "Next Group Support"
        case .hybrid:
            return "Next Class / Group Support"
        }
    }

    func teacherContextRibbon(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let remainingCount = schedule.filter { endDateToday(for: $0, now: now) > now }.count
        let label: String
        let detail: String
        let tint: Color

        if let nextItem {
            label = "Next"
            detail = "\(nextItem.className) at \(startDateToday(for: nextItem, now: now).formatted(date: .omitted, time: .shortened))"
            tint = nextItem.accentColor == .clear ? .orange : nextItem.accentColor
        } else if let activeItem {
            label = "Now"
            detail = activeItem.className
            tint = activeItem.accentColor == .clear ? .blue : activeItem.accentColor
        } else if schedule.isEmpty {
            label = "Today"
            detail = "No scheduled blocks"
            tint = .secondary
        } else {
            label = "Today"
            detail = "Day is wrapped"
            tint = .indigo
        }

        return Group {
            if let editableItem = nextItem ?? activeItem {
                Button {
                    editingAlarm = editableItem
                } label: {
                    teacherContextRibbonContent(
                        label: label,
                        detail: detail,
                        remainingCount: remainingCount,
                        tint: tint,
                        compact: compact
                    )
                }
                .buttonStyle(.plain)
            } else {
                teacherContextRibbonContent(
                    label: label,
                    detail: detail,
                    remainingCount: remainingCount,
                    tint: tint,
                    compact: compact
                )
            }
        }
    }

    func teacherContextRibbonContent(
        label: String,
        detail: String,
        remainingCount: Int,
        tint: Color,
        compact: Bool
    ) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            Label(label, systemImage: label == "Next" ? "calendar.badge.clock" : "play.circle.fill")
                .font((compact ? Font.caption : .subheadline).weight(.bold))
                .foregroundStyle(tint)

            Text(detail)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("\(remainingCount) left")
                .font((compact ? Font.caption2 : .caption).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 5 : 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.92))
                )
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.10),
                            Color(.secondarySystemBackground).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    func statusPill(title: String, value: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(value)
                .font((compact ? Font.caption : .subheadline).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }
}

// MARK: - Header and Background

extension TodayView {
    struct TodayActionPrompt: Identifiable {
        let id: String
        let title: String
        let detail: String
        let systemImage: String
        let tint: Color
        let action: () -> Void
    }

    @ViewBuilder
    func portraitDashboard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    compactDateHeader(now: now)
                        .padding(.horizontal)

                    if let activeOverrideName {
                        overrideBanner(name: activeOverrideName)
                            .padding(.horizontal)
                    }

                    if showsOnlyMinimalTodayCards {
                        if let active = activeItem {
                            Button {
                                editingAlarm = active
                            } label: {
                                ActiveTimerCard(
                                    item: active,
                                    now: now,
                                    isHeld: isHeld(active),
                                    bellSkipped: skippedBellItemIDs.contains(active.id)
                                )
                                .frame(height: 200)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }

                        classSectionCard(
                            activeItem: activeItem,
                            nextItem: nextItem,
                            schedule: schedule,
                            now: now,
                            compact: false
                        )
                        .id(TodayDashboardCard.currentClass)
                        .padding(.horizontal)

                        nextActionsCard(
                            now: now,
                            schedule: schedule,
                            activeItem: activeItem,
                            nextItem: nextItem,
                            compact: false
                        )
                        .padding(.horizontal)

                        if activeItem != nil, let next = nextItem {
                            NextUpSummaryCard(item: next, now: now)
                                .padding(.horizontal)
                        }
                    } else {
                        if let active = activeItem {
                            Button {
                                editingAlarm = active
                            } label: {
                                ActiveTimerCard(
                                    item: active,
                                    now: now,
                                    isHeld: isHeld(active),
                                    bellSkipped: skippedBellItemIDs.contains(active.id)
                                )
                                .frame(height: 260)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        } else if let next = nextItem {
                            NextUpSummaryCard(item: next, now: now)
                                .padding(.horizontal)
                        }

                        classSectionCard(
                            activeItem: activeItem,
                            nextItem: nextItem,
                            schedule: schedule,
                            now: now,
                            compact: false
                        )
                        .id(TodayDashboardCard.currentClass)
                        .padding(.horizontal)

                        nextActionsCard(
                            now: now,
                            schedule: schedule,
                            activeItem: activeItem,
                            nextItem: nextItem,
                            compact: false
                        )
                        .padding(.horizontal)

                        if shouldShowDayStatus(now: now, schedule: schedule, activeItem: activeItem) {
                            dayStatusCard(now: now, schedule: schedule, activeItem: activeItem)
                                .padding(.horizontal)
                        }

                        dashboardSummaryRow(
                            now: now,
                            schedule: schedule,
                            activeItem: activeItem,
                            nextItem: nextItem,
                            todayCommitments: todayCommitments,
                            excludedCards: [.currentClass]
                        )
                        .padding(.horizontal)
                    }

                    if schedule.isEmpty {
                        emptyState(for: now)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 88)
                .padding(.top, -6)
            }
            .onChange(of: scrollTargetCard) { _, newValue in
                guard let newValue else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    proxy.scrollTo(newValue, anchor: .top)
                }
            }
        }
        .refreshable {
            onRefresh()
        }
    }

    @ViewBuilder
    func landscapeDashboard(
        availableSize: CGSize,
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem]
    ) -> some View {
        VStack(spacing: 4) {
            compactDateHeader(now: now)

            if let activeOverrideName {
                overrideBanner(name: activeOverrideName)
            }

            HStack(alignment: .top, spacing: 16) {
                let primaryCardMaxHeight = min(max(availableSize.height - 48, 320), 520)

                Group {
                    if let active = activeItem {
                        Button {
                            editingAlarm = active
                        } label: {
                            ActiveTimerCard(
                                item: active,
                                now: now,
                                isTeacherMode: true,
                                isHeld: isHeld(active),
                                bellSkipped: skippedBellItemIDs.contains(active.id)
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let next = nextItem {
                        NextUpSummaryCard(
                            item: next,
                            now: now,
                            isCompact: true
                        )
                    } else {
                        emptyState(for: now)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: primaryCardMaxHeight, alignment: .top)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if showsOnlyMinimalTodayCards {
                                classSectionCard(
                                    activeItem: activeItem,
                                    nextItem: nextItem,
                                    schedule: schedule,
                                    now: now,
                                    compact: true
                                )
                                .id(TodayDashboardCard.currentClass)

                                nextActionsCard(
                                    now: now,
                                    schedule: schedule,
                                    activeItem: activeItem,
                                    nextItem: nextItem,
                                    compact: true
                                )

                                if activeItem != nil, let nextItem {
                                    NextUpSummaryCard(
                                        item: nextItem,
                                        now: now,
                                        isCompact: true
                                    )
                                }
                            } else {
                                classSectionCard(
                                    activeItem: activeItem,
                                    nextItem: nextItem,
                                    schedule: schedule,
                                    now: now,
                                    compact: true
                                )
                                .id(TodayDashboardCard.currentClass)

                                nextActionsCard(
                                    now: now,
                                    schedule: schedule,
                                    activeItem: activeItem,
                                    nextItem: nextItem,
                                    compact: true
                                )

                                if shouldShowDayStatus(now: now, schedule: schedule, activeItem: activeItem) {
                                    dayStatusCard(now: now, schedule: schedule, activeItem: activeItem, compact: true)
                                }

                                dashboardSummaryColumn(
                                    now: now,
                                    schedule: schedule,
                                    activeItem: activeItem,
                                    nextItem: nextItem,
                                    todayCommitments: todayCommitments,
                                    excludedCards: [.currentClass]
                                )
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .frame(width: 320)
                    .onChange(of: scrollTargetCard) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            proxy.scrollTo(newValue, anchor: .top)
                        }
                    }
                    .refreshable {
                        onRefresh()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    func dashboardSummaryRow(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        excludedCards: Set<TodayDashboardCard> = []
    ) -> some View {
        VStack(spacing: 10) {
            if shouldShowAfterHoursPersonalMode(now: now, schedule: schedule) {
                schoolBoundaryCard(now: now, schedule: schedule)
                if showPersonalFocusCard {
                    personalFocusCard(now: now)
                }
                if showEndOfDayWrapUp {
                    endOfDayCard(now: now, schedule: schedule)
                }
            } else {
                orderedDashboardCards(
                    now: now,
                    schedule: schedule,
                    activeItem: activeItem,
                    nextItem: nextItem,
                    todayCommitments: todayCommitments,
                    compact: false,
                    excludedCards: excludedCards
                )
            }
        }
    }

    @ViewBuilder
    func dashboardSummaryColumn(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        excludedCards: Set<TodayDashboardCard> = []
    ) -> some View {
        VStack(spacing: 10) {
            if shouldShowAfterHoursPersonalMode(now: now, schedule: schedule) {
                schoolBoundaryCard(now: now, schedule: schedule, compact: true)
                if showPersonalFocusCard {
                    personalFocusCard(now: now, compact: true)
                }
                if showEndOfDayWrapUp {
                    endOfDayCard(now: now, schedule: schedule, compact: true)
                }
            } else {
                orderedDashboardCards(
                    now: now,
                    schedule: schedule,
                    activeItem: activeItem,
                    nextItem: nextItem,
                    todayCommitments: todayCommitments,
                    compact: true,
                    excludedCards: excludedCards
                )
            }
        }
    }

    @ViewBuilder
    func orderedDashboardCards(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        compact: Bool,
        excludedCards: Set<TodayDashboardCard> = []
    ) -> some View {
        ForEach(visibleDashboardCards.filter { !excludedCards.contains($0) }, id: \.self) { card in
            dashboardCardView(
                card,
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem,
                todayCommitments: todayCommitments,
                compact: compact
            )
            .id(card)
        }
    }

    var visibleDashboardCards: [TodayDashboardCard] {
        dashboardCardOrder.filter { card in
            guard !hiddenDashboardCards.contains(card) else { return false }
            if card == .endOfDay {
                return showEndOfDayWrapUp
            }
            if card == .attendance {
                return isAttendanceEnabled
            }
            return true
        }
    }

    @ViewBuilder
    func dashboardCardView(
        _ card: TodayDashboardCard,
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        todayCommitments: [CommitmentItem],
        compact: Bool
    ) -> some View {
        switch card {
        case .teacherContext:
            teacherContextRibbon(
                now: now,
                schedule: schedule,
                activeItem: activeItem,
                nextItem: nextItem,
                compact: compact
            )
            .padding(.top, 6)
        case .currentClass:
            classSectionCard(activeItem: activeItem, nextItem: nextItem, schedule: schedule, now: now, compact: compact)
        case .attendance:
            attendanceDashboardCard(schedule: schedule, now: now, activeItem: activeItem, compact: compact)
        case .commitments:
            commitmentsCard(todayCommitments: todayCommitments, compact: compact)
        case .upcoming:
            upcomingStrip(schedule: schedule, now: now, nextItem: nextItem, compact: compact)
        case .tasks:
            topTasksCard(now: now, compact: compact)
        case .support:
            studentSupportCard(activeItem: activeItem, nextItem: nextItem, compact: compact)
        case .notes:
            notesSnapshotCard(compact: compact)
        case .endOfDay:
            if showEndOfDayWrapUp {
                endOfDayCard(now: now, schedule: schedule, compact: compact)
            }
        case .subPlan:
            subPlanCard(schedule: schedule, compact: compact)
        }
    }

    func floatingActionMenu(activeItem: AlarmItem?, now: Date) -> some View {
        Menu {
            Button("Quick Capture", systemImage: "plus.bubble") {
                showingQuickCapture = true
            }

            if isAttendanceEnabled {
                Button("Attendance", systemImage: "checklist.checked") {
                    if let activeItem,
                       !rosterStudents(for: activeItem).isEmpty {
                        presentRollCall(for: activeItem, now: now, schedule: adjustedTodaySchedule(for: now))
                    } else {
                        openAttendanceTab()
                    }
                }
            }

            if isHomeworkEnabled {
                Button("Work", systemImage: "text.book.closed") {
                    homeworkReviewDate = now
                    showingHomeworkReview = true
                }
            }

            Button("Sub Plans", systemImage: "doc.text") {
                dailySubPlanDate = now
                showingDailySubPlan = true
            }

            Button("Students", systemImage: "person.text.rectangle") {
                openStudentsTab()
            }

            Button("Planner & Notes", systemImage: "calendar.badge.checkmark") {
                openTodoTab()
            }

            if isScheduleEnabled {
                Button("Schedule", systemImage: "calendar") {
                    openScheduleTab()
                }
            }

            Button(soundsMuted ? "Unmute Sounds" : "Mute Sounds", systemImage: soundsMuted ? "bell.fill" : "bell.slash.fill") {
                soundsMuted.toggle()
                onRefreshNotifications()
            }

            Button("Settings", systemImage: "gearshape") {
                openSettingsTab()
            }
        } label: {
            ToolbarPrimaryActionLabel(
                title: "Actions",
                systemImage: "plus",
                colors: [
                    Color(red: 0.44, green: 0.30, blue: 0.80),
                    Color(red: 0.24, green: 0.47, blue: 0.84)
                ]
            )
        }
    }

    func upcomingStrip(
        schedule: [AlarmItem],
        now: Date,
        nextItem: AlarmItem?,
        compact: Bool = false
    ) -> some View {
        let upcomingItems = laterTodayItems(from: schedule, now: now, nextItem: nextItem)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Coming Later Today", systemImage: "calendar.badge.clock")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if isScheduleEnabled, !upcomingItems.isEmpty {
                    Button {
                        openScheduleTab()
                    } label: {
                        cardActionLabel("Schedule", accent: .blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            if upcomingItems.isEmpty {
                Text("No more scheduled blocks after next up.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(upcomingItems) { item in
                            upcomingChip(for: item, compact: compact)
                        }
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .blue, compact: compact))
    }

    func upcomingChip(for item: AlarmItem, compact: Bool) -> some View {
        Button {
            openBlock(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.accentColor == .clear ? Color.gray.opacity(0.2) : item.accentColor)
                        .frame(width: 8, height: 8)

                    Text(item.className)
                        .font((compact ? Font.caption : .subheadline).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(item.location, systemImage: "mappin.and.ellipse")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: compact ? 140 : 168, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.08),
                                Color(.secondarySystemBackground).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    func openBlock(_ item: AlarmItem) {
        guard isScheduleEnabled else { return }
        openScheduleBlock(item)
    }

    private func behaviorSnapshot(for item: AlarmItem, roster: [StudentSupportProfile]) -> (positiveCount: Int, neutralCount: Int, needsSupportCount: Int, notedCount: Int, totalCount: Int) {
        let segmentKey = item.className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let todaysLogs: [BehaviorLogItem] = roster.flatMap { profile in
            behaviorLogsForStudent(profile).filter {
                Calendar.current.isDateInToday($0.timestamp) &&
                $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == segmentKey
            }
        }

        let latestByStudent: [UUID: BehaviorLogItem] = Dictionary(grouping: todaysLogs, by: { $0.studentID })
            .compactMapValues { logs in
                logs.sorted { $0.timestamp > $1.timestamp }.first
            }

        let latestLogs: [BehaviorLogItem] = Array(latestByStudent.values)

        return (
            positiveCount: latestLogs.filter { $0.rating == BehaviorLogItem.Rating.onTask }.count,
            neutralCount: latestLogs.filter { $0.rating == BehaviorLogItem.Rating.neutral }.count,
            needsSupportCount: latestLogs.filter { $0.rating == BehaviorLogItem.Rating.needsSupport }.count,
            notedCount: latestLogs.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
            totalCount: latestLogs.count
        )
    }

    private func behaviorSnapshotPill(title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.black))
            Text("\(value)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(color == .yellow ? .orange : color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill((color == .yellow ? Color.yellow : color).opacity(0.12))
        )
    }

    private func taskStatusPill(title: String, isComplete: Bool, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.caption)
            Text(title)
                .font(.caption2.weight(.regular))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(isComplete ? color : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill((isComplete ? color : Color.secondary).opacity(isComplete ? 0.12 : 0.08))
        )
    }

    private func hasHomeworkLogged(for item: AlarmItem, now: Date) -> Bool {
        let dateKey = AttendanceRecord.dateKey(for: now)
        return attendanceRecords.contains { record in
            guard record.dateKey == dateKey else { return false }
            guard attendanceRecordMatchesClass(record, item: item) else { return false }

            let hasAssigned = !record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasMissing = !record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return hasAssigned || hasMissing
        }
    }

    private struct ClassAttendanceSnapshot {
        let weeklyPresentCount: Int
        let weeklyTotalCount: Int
        let monthlyPresentCount: Int
        let monthlyTotalCount: Int
        let todayAbsentCount: Int
        let todayTardyCount: Int
        let totalCount: Int

        var weeklyRateText: String {
            rateText(present: weeklyPresentCount, total: weeklyTotalCount)
        }

        var monthlyRateText: String {
            rateText(present: monthlyPresentCount, total: monthlyTotalCount)
        }

        private func rateText(present: Int, total: Int) -> String {
            guard total > 0 else { return "No Data" }
            let percent = Int((Double(present) / Double(total) * 100).rounded())
            return "\(percent)%"
        }
    }

    private struct ClassBehaviorSnapshot {
        let weeklyNeedsSupportCount: Int
        let weeklyLoggedCount: Int
        let monthlyNeedsSupportCount: Int
        let monthlyLoggedCount: Int
        let todayNotedCount: Int
        let totalCount: Int

        var weeklySupportText: String {
            supportText(needsSupport: weeklyNeedsSupportCount, total: weeklyLoggedCount)
        }

        var monthlySupportText: String {
            supportText(needsSupport: monthlyNeedsSupportCount, total: monthlyLoggedCount)
        }

        private func supportText(needsSupport: Int, total: Int) -> String {
            guard total > 0 else { return "No Data" }
            return "\(needsSupport) / \(total)"
        }
    }

    private func classAttendanceSnapshot(for item: AlarmItem, now: Date) -> ClassAttendanceSnapshot {
        let weekKeys = AttendanceRecord.currentWeekDateKeys(containing: now)
        let monthKeys = currentMonthDateKeys(containing: now)
        let todayKey = AttendanceRecord.dateKey(for: now)

        let classRecords = attendanceRecords.filter { record in
            record.isAttendanceEntry && attendanceRecordMatchesClass(record, item: item)
        }
        let weeklyRecords = classRecords.filter { weekKeys.contains($0.dateKey) }
        let monthlyRecords = classRecords.filter { monthKeys.contains($0.dateKey) }
        let todayRecords = classRecords.filter { $0.dateKey == todayKey }

        return ClassAttendanceSnapshot(
            weeklyPresentCount: weeklyRecords.filter { $0.status == .present }.count,
            weeklyTotalCount: weeklyRecords.count,
            monthlyPresentCount: monthlyRecords.filter { $0.status == .present }.count,
            monthlyTotalCount: monthlyRecords.count,
            todayAbsentCount: todayRecords.filter { $0.status == .absent }.count,
            todayTardyCount: todayRecords.filter { $0.status == .tardy }.count,
            totalCount: classRecords.count
        )
    }

    private func currentMonthDateKeys(containing date: Date) -> Set<String> {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: date)
        let start = interval?.start ?? date
        let end = interval?.end ?? date
        var dateKeys = Set<String>()
        var current = start

        while current < end {
            dateKeys.insert(AttendanceRecord.dateKey(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dateKeys
    }

    private func currentClassAttendanceSnapshotCard(snapshot: ClassAttendanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Class Attendance Snapshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                attendanceSummaryPill(title: "Week Present", value: snapshot.weeklyRateText, accent: ClassTraxSemanticColor.primaryAction)
                attendanceSummaryPill(title: "Month Present", value: snapshot.monthlyRateText, accent: ClassTraxSemanticColor.secondaryAction)
            }

            let exceptionParts = [
                snapshot.todayAbsentCount > 0 ? "Absent \(snapshot.todayAbsentCount)" : nil,
                snapshot.todayTardyCount > 0 ? "Tardy \(snapshot.todayTardyCount)" : nil
            ].compactMap { $0 }

            if !exceptionParts.isEmpty {
                Text("Today: \(exceptionParts.joined(separator: " • "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ClassTraxSemanticColor.attendance.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ClassTraxSemanticColor.attendance.opacity(0.16), lineWidth: 1)
        )
    }

    private func classBehaviorSnapshot(for item: AlarmItem, roster: [StudentSupportProfile], now: Date) -> ClassBehaviorSnapshot {
        let weekKeys = AttendanceRecord.currentWeekDateKeys(containing: now)
        let monthKeys = currentMonthDateKeys(containing: now)
        let todayKey = AttendanceRecord.dateKey(for: now)

        let classLogs = roster
            .flatMap { behaviorLogsForStudent($0) }
            .filter { log in
                classNamesMatch(scheduleClassName: item.className, profileClassName: log.segmentTitle)
            }

        let weeklyLogs = classLogs.filter { weekKeys.contains(AttendanceRecord.dateKey(for: $0.timestamp)) }
        let monthlyLogs = classLogs.filter { monthKeys.contains(AttendanceRecord.dateKey(for: $0.timestamp)) }
        let todayLogs = classLogs.filter { AttendanceRecord.dateKey(for: $0.timestamp) == todayKey }

        return ClassBehaviorSnapshot(
            weeklyNeedsSupportCount: weeklyLogs.filter { $0.rating == .needsSupport }.count,
            weeklyLoggedCount: weeklyLogs.count,
            monthlyNeedsSupportCount: monthlyLogs.filter { $0.rating == .needsSupport }.count,
            monthlyLoggedCount: monthlyLogs.count,
            todayNotedCount: todayLogs.filter {
                !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count,
            totalCount: classLogs.count
        )
    }

    private func currentClassBehaviorSnapshotCard(snapshot: ClassBehaviorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Class Behavior Snapshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                attendanceSummaryPill(title: "Week Support", value: snapshot.weeklySupportText, accent: .orange)
                attendanceSummaryPill(title: "Month Support", value: snapshot.monthlySupportText, accent: .pink)
            }

            if snapshot.todayNotedCount > 0 {
                Text("Today: Notes \(snapshot.todayNotedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.pink.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.pink.opacity(0.16), lineWidth: 1)
        )
    }

    private func recentBehaviorNotes(for item: AlarmItem, roster: [StudentSupportProfile]) -> [BehaviorLogItem] {
        let segmentKey = item.className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return roster
            .flatMap { profile in
                behaviorLogsForStudent(profile).filter {
                    Calendar.current.isDateInToday($0.timestamp) &&
                    !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == segmentKey
                }
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { $0 }
    }

    private func needsSupportStudents(for item: AlarmItem, roster: [StudentSupportProfile]) -> [BehaviorLogItem] {
        let segmentKey = item.className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let todaysLogs: [BehaviorLogItem] = roster.flatMap { profile in
            behaviorLogsForStudent(profile).filter {
                Calendar.current.isDateInToday($0.timestamp) &&
                $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == segmentKey
            }
        }

        let latestByStudent = Dictionary(grouping: todaysLogs, by: \.studentID)
            .compactMapValues { logs in
                logs.sorted { $0.timestamp > $1.timestamp }.first
            }

        return Array(latestByStudent.values)
            .filter { $0.rating == .needsSupport }
            .sorted { lhs, rhs in
                lhs.studentName.localizedCaseInsensitiveCompare(rhs.studentName) == .orderedAscending
            }
    }

    private func behaviorPatternInsights(for item: AlarmItem, roster: [StudentSupportProfile]) -> (trigger: BehaviorPatternInsight?, intervention: BehaviorPatternInsight?) {
        let todaysLogs = todayBehaviorLogs(for: item, roster: roster)
        return (
            trigger: mostCommonBehaviorPattern(from: todaysLogs.compactMap(\.triggerSummary)),
            intervention: mostCommonBehaviorPattern(from: todaysLogs.compactMap(\.interventionSummary))
        )
    }

    private func todayBehaviorLogs(for item: AlarmItem, roster: [StudentSupportProfile]) -> [BehaviorLogItem] {
        let segmentKey = item.className.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return roster.flatMap { profile in
            behaviorLogsForStudent(profile).filter {
                Calendar.current.isDateInToday($0.timestamp) &&
                $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == segmentKey
            }
        }
    }

    private func mostCommonBehaviorPattern(from values: [String]) -> BehaviorPatternInsight? {
        let grouped = Dictionary(grouping: values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }, by: \.self)

        return grouped
            .compactMap { value, matches in
                matches.count >= 2 ? BehaviorPatternInsight(value: value, count: matches.count) : nil
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
            .first
    }

    private func todayBehaviorInsightCard(
        title: String,
        systemImage: String,
        detail: String,
        count: Int,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("\(count)x today")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func todayBehaviorRollupRow(title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 78, alignment: .leading)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private struct BehaviorPatternInsight {
        let value: String
        let count: Int
    }

    func latestClassBehaviorNote(for item: AlarmItem) -> FollowUpNoteItem? {
        decodeFollowUpNotesFromDefaults()
            .filter {
                $0.kind == .classNote &&
                classNamesMatch(scheduleClassName: item.className, profileClassName: $0.context)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func saveClassBehaviorNote(_ text: String, for item: AlarmItem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes = decodeFollowUpNotesFromDefaults()
        let existingIndex = notes.firstIndex { note in
            note.kind == .classNote &&
            classNamesMatch(scheduleClassName: item.className, profileClassName: note.context)
        }

        if trimmed.isEmpty {
            if let existingIndex {
                notes.remove(at: existingIndex)
            }
        } else {
            let updated = FollowUpNoteItem(
                id: existingIndex.flatMap { notes[$0].id } ?? UUID(),
                kind: .classNote,
                context: item.className,
                studentOrGroup: "",
                note: trimmed,
                followUpDate: Date(),
                createdAt: Date()
            )

            if let existingIndex {
                notes[existingIndex] = updated
            } else {
                notes.append(updated)
            }
        }

        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: "follow_up_notes_v1_data")
        }
    }

    func markAllStudentsOK(for item: AlarmItem, roster: [StudentSupportProfile]) {
        guard !roster.isEmpty else {
            let timestamp = Date().formatted(date: .omitted, time: .shortened)
            let existing = latestClassBehaviorNote(for: item)?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let marker = "All students OK logged at \(timestamp)."
            let updated = existing.isEmpty ? marker : "\(existing)\n\(marker)"
            saveClassBehaviorNote(updated, for: item)
            return
        }

        for profile in roster {
            let latestProfile = latestStudentProfile(for: profile)
            onLogBehavior(latestProfile, .onTask, .onTask, item.id)
        }
    }
}

// MARK: - Dashboard Layout Persistence

extension TodayView {
    func commitmentsCard(todayCommitments: [CommitmentItem], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Planner Schedule", systemImage: "person.3.sequence.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(todayCommitments.isEmpty ? "Add" : "Manage") {
                    if todayCommitments.isEmpty {
                        showingAddCommitment = true
                    } else {
                        showingCommitmentsManager = true
                    }
                }
                .font(.caption.weight(.semibold))

                if !todayCommitments.isEmpty {
                    Button {
                        showingAddCommitment = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .font(.headline)
                }
            }

            if todayCommitments.isEmpty {
                Text("Add duties, meetings, conferences, or coverage blocks so planner schedule and planner queue reflect the full shape of the school day.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayCommitments.prefix(compact ? 3 : 4)) { commitment in
                        Button {
                            editingCommitment = commitment
                        } label: {
                            commitmentRow(for: commitment, compact: compact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }

    func commitmentRow(for commitment: CommitmentItem, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: commitment.kind.systemImage)
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(commitment.kind.tint)
                .frame(width: compact ? 22 : 26, height: compact ? 22 : 26)
                .background(
                    Circle()
                        .fill(commitment.kind.tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(commitmentTimeText(for: commitment))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)

                if !commitment.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(commitment.location)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            commitment.kind.tint.opacity(0.12),
                            Color(.secondarySystemBackground).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(commitment.kind.tint.opacity(0.14), lineWidth: 1)
        )
    }

    func topTasksCard(now: Date, compact: Bool = false) -> some View {
        let tasks = topTasks(for: now)
        let highPriorityCount = tasks.filter { $0.priority == .high }.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("School Priorities", systemImage: "checklist")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if !tasks.isEmpty {
                    cardMetricLabel(
                        "\(highPriorityCount) high",
                        accent: .orange
                    )
                }

                Button {
                    openTodoTab()
                } label: {
                    cardActionLabel(tasks.isEmpty ? "Add" : "Open", accent: .orange)
                }
                .buttonStyle(.plain)
            }

            if tasks.isEmpty {
                Text("No active school planner items. Add a few to make Today your command center.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        let linkedStudent = savedStudentProfile(for: task.studentOrGroup)
                        Button {
                            openTodoItem(task)
                        } label: {
                            taskSummaryRow(task: task, linkedStudent: linkedStudent, compact: compact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .orange, compact: compact))
    }

    func notesSnapshotCard(compact: Bool) -> some View {
        let snapshot = notesSnapshot

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Notes", systemImage: "square.and.pencil")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                if snapshot != nil {
                    cardMetricLabel("Live", accent: .teal)
                }

                Button {
                    openNotesTab()
                } label: {
                    cardActionLabel(snapshot == nil ? "Add" : "Open", accent: .teal)
                }
                .buttonStyle(.plain)
            }

            if let snapshot {
                Text(snapshot)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 3 : 4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.teal.opacity(0.08))
                    )
            } else {
                Text("No school notes yet. Use this running log for duties, missing work context, reminders, and meeting details.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Quick note", text: $quickSchoolNoteText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submitQuickSchoolNote()
                    }

                Button("Submit") {
                    submitQuickSchoolNote()
                }
                .buttonStyle(.borderedProminent)
                .tint(dashboardPrimaryTint)
                .disabled(quickSchoolNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .modifier(DashboardCardStyle(accent: .teal, compact: compact))
    }

    func submitQuickSchoolNote() {
        let trimmed = quickSchoolNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        todayQuickNoteDraft = trimmed
        todayQuickNoteDraftToken = Date().timeIntervalSince1970
        quickSchoolNoteText = ""
        openNotesTab()
    }

    func taskSummaryRow(
        task: TodoItem,
        linkedStudent: StudentSupportProfile?,
        compact: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(task.priority.color)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.task)
                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                    .lineLimit(2)

                if let linkedStudent {
                    HStack(spacing: 8) {
                        Text(linkedStudent.name)
                            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        studentGradePill(linkedStudent.gradeLevel)
                    }
                }

                Text(taskSubtitle(for: task))
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(task.priority.rawValue.capitalized)
                .font(.caption2.weight(.bold))
                .foregroundStyle(task.priority.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(task.priority.color.opacity(0.12))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.10), lineWidth: 1)
        )
    }

    func cardActionLabel(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
            )
    }

    func cardMetricLabel(_ value: String, accent: Color) -> some View {
        Text(value)
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.10))
            )
    }

    func schoolBoundaryCard(
        now: Date,
        schedule: [AlarmItem],
        compact: Bool = false
    ) -> some View {
        let afterHours = isAfterSchoolQuietStart(now)
        let quietStart = schoolQuietStart(on: now)
        let unfinishedSchoolTasks = todos.filter { !$0.isCompleted && $0.workspace == .school }.count
        let unfinishedPersonalTasks = todos.filter { !$0.isCompleted && $0.workspace == .personal }.count
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }.count

        let title: String
        let message: String
        let tint: Color

        if schoolQuietHoursEnabled && afterHours {
            title = hideSchoolDashboardAfterHours ? "School Day Closed" : "After Hours Boundary"
            message = "School alerts are quiet after \(quietStart.formatted(date: .omitted, time: .shortened)). \(unfinishedSchoolTasks) school task\(unfinishedSchoolTasks == 1 ? "" : "s") are paused, and \(unfinishedPersonalTasks) personal task\(unfinishedPersonalTasks == 1 ? "" : "s") remain visible."
            tint = .indigo
        } else if schoolQuietHoursEnabled {
            title = "School Boundary Set"
            message = "Routine school alerts quiet at \(quietStart.formatted(date: .omitted, time: .shortened)). \(remainingBlocks) block\(remainingBlocks == 1 ? "" : "s") remain in today's school flow."
            tint = .teal
        } else {
            title = "After Hours Boundary"
            message = "Set an after-hours quiet time so school reminders stop following you home."
            tint = .secondary
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: afterHours ? "moon.stars.fill" : "lock.shield.fill")
                    .font(compact ? .headline : .title3)
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Text(message)
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button("Settings") {
                    openSettingsTab()
                }
                .font(.caption.weight(.bold))
            }
        }
        .modifier(DashboardCardStyle(accent: tint, compact: compact))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    func personalFocusCard(now: Date, compact: Bool = false) -> some View {
        let tasks = topTasks(for: now, workspace: .personal)
        let personalNotePreview = personalNotesText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Personal Focus", systemImage: "house.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()

                Button(tasks.isEmpty ? "Add" : "Open") {
                    openTodoTab()
                }
                .font(.caption.weight(.semibold))
            }

            if tasks.isEmpty {
                Text("No personal tasks queued. Add a few personal reminders so after-hours mode has a clean landing zone.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(task.priority.color)
                                .frame(width: 9, height: 9)
                                .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.task)
                                    .font((compact ? Font.caption : .subheadline).weight(.semibold))
                                    .lineLimit(2)

                                Text(taskSubtitle(for: task))
                                    .font(compact ? .caption2 : .caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if !personalNotePreview.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Personal Notes", systemImage: "square.and.pencil")
                            .font((compact ? Font.caption : .subheadline).weight(.semibold))

                        Spacer()

                        Button("Open") {
                            openNotesTab()
                        }
                        .font(.caption.weight(.semibold))
                    }

                    Text(personalNotePreview)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 2 : 3)
                }
            }
        }
        .modifier(DashboardCardStyle(accent: .green, compact: compact))
    }

    func endOfDayCard(now: Date, schedule: [AlarmItem], compact: Bool = false) -> some View {
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }
        let unfinishedTasks = todos.filter { !$0.isCompleted && $0.workspace == .school }.count
        let dismissal = remainingBlocks.last.map { endDateToday(for: $0, now: now) }
        let carryoverTasks = todos.filter { !$0.isCompleted && $0.bucket == .today && $0.workspace == .school }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("End of Day", systemImage: "sunset.fill")
                    .font((compact ? Font.subheadline : .headline).weight(.bold))

                Spacer()
            }

            if remainingBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The teaching day is wrapped. \(unfinishedTasks) task\(unfinishedTasks == 1 ? "" : "s") still open.")
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)

                    if !carryoverTasks.isEmpty {
                        Text("\(carryoverTasks.count) task\(carryoverTasks.count == 1 ? "" : "s") are still marked for today.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)

                        if !compact {
                            ForEach(carryoverTasks.prefix(3)) { task in
                                Text("• \(task.task)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if offerTaskCarryover {
                            Button("Roll Today's Planner Items to Tomorrow") {
                                rollTodayTasksToTomorrow()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.39, green: 0.39, blue: 0.66))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(remainingBlocks.count) block\(remainingBlocks.count == 1 ? "" : "s") remain, with dismissal around \(dismissal?.formatted(date: .omitted, time: .shortened) ?? "later").")
                        .font(compact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(unfinishedTasks) open task\(unfinishedTasks == 1 ? "" : "s") still need attention.")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    showingDailyExport = true
                } label: {
                    Label("Export Day", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                Button {
                    openTodoTab()
                } label: {
                    Label("Open Planner", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .modifier(DashboardCardStyle(accent: .indigo, compact: compact))
    }
}

// MARK: - Task and Capture Helpers

extension TodayView {
    @ViewBuilder
    func nextActionsCard(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?,
        compact: Bool
    ) -> some View {
        let prompts = nextActionPrompts(
            now: now,
            schedule: schedule,
            activeItem: activeItem,
            nextItem: nextItem
        )

        if !prompts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Next Actions", systemImage: "bolt.fill")
                        .font((compact ? Font.subheadline : .headline).weight(.bold))

                    Spacer()

                    cardMetricLabel("\(prompts.count)", accent: .pink)
                }

                Text("Work the day from the live moment outward: handle the active block, note what matters, then prep what comes next.")
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(prompts) { prompt in
                        Button(action: prompt.action) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: prompt.systemImage)
                                    .font(compact ? .subheadline : .headline)
                                    .foregroundStyle(prompt.tint)
                                    .frame(width: compact ? 24 : 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(prompt.title)
                                        .font((compact ? Font.caption : .subheadline).weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(prompt.detail)
                                        .font(compact ? .caption2 : .caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, compact ? 10 : 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(prompt.tint.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(prompt.tint.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .modifier(DashboardCardStyle(accent: .pink, compact: compact))
        }
    }

    func nextActionPrompts(
        now: Date,
        schedule: [AlarmItem],
        activeItem: AlarmItem?,
        nextItem: AlarmItem?
    ) -> [TodayActionPrompt] {
        var prompts: [TodayActionPrompt] = []

        if isAttendanceEnabled,
           let activeItem,
           !rosterStudents(for: activeItem).isEmpty,
           let completionText = attendanceCompletionText(for: activeItem, now: now),
           completionText != "Attendance complete" {
            prompts.append(
                    TodayActionPrompt(
                        id: "attendance-\(activeItem.id.uuidString)",
                        title: "Take attendance now",
                    detail: "\(activeItem.className) • \(completionText)",
                    systemImage: "checklist.checked",
                    tint: dashboardPrimaryTint,
                    action: {
                        presentRollCall(for: activeItem, now: now, schedule: schedule)
                    }
                )
            )
        }

        if isScheduleEnabled, let nextItem {
            let nextStart = startDateToday(for: nextItem, now: now)
                .formatted(date: .omitted, time: .shortened)
            let nextMeta = [nextItem.gradeLevel, nextItem.location]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
            let nextRosterCount = rosterStudents(for: nextItem).count
            let linkedGroupCount = max(nextItem.linkedClassDefinitionIDs.count, 1)
            let extraDetails = [
                nextMeta.isEmpty ? nil : nextMeta,
                nextRosterCount == 0 ? nil : "\(nextRosterCount) student\(nextRosterCount == 1 ? "" : "s")",
                linkedGroupCount > 1 ? "\(linkedGroupCount) groups" : nil
            ].compactMap { $0 }
            prompts.append(
                TodayActionPrompt(
                    id: "prep-\(nextItem.id.uuidString)",
                    title: "Open next \(teacherWorkflowMode == .classroom ? "class" : "group")",
                    detail: ([nextItem.className, extraDetails.isEmpty ? nil : extraDetails.joined(separator: " • "), "Starts \(nextStart)"] as [String?])
                        .compactMap { $0 }
                        .joined(separator: " • "),
                    systemImage: "arrowshape.right.fill",
                    tint: .blue,
                    action: {
                        openScheduleBlock(nextItem)
                    }
                )
            )
        }

        if let activeItem {
            let roster = rosterStudents(for: activeItem)
            if !roster.isEmpty {
                if isBehaviorEnabled {
                    prompts.append(
                        TodayActionPrompt(
                            id: "behavior-\(activeItem.id.uuidString)",
                            title: "Behavior check-in",
                            detail: "Tap a student, choose a face, and add a quick note for \(activeItem.className).",
                            systemImage: "face.smiling",
                            tint: .pink,
                            action: {
                                presentBehaviorLookup(for: activeItem)
                            }
                        )
                    )
                }

                prompts.append(
                    TodayActionPrompt(
                        id: "students-\(activeItem.id.uuidString)",
                        title: "Review students & supports",
                        detail: activeItem.linkedClassDefinitionIDs.count > 1
                            ? "Choose a class or group inside \(activeItem.className) to review students and supports."
                            : studentLookupSubtitle(for: activeItem, studentCount: roster.count),
                        systemImage: "person.text.rectangle",
                        tint: .mint,
                        action: {
                            presentStudentLookup(for: activeItem)
                        }
                    )
                )
            }
        }

        let carryoverTasks = todos.filter { !$0.isCompleted && $0.bucket == .today && $0.workspace == .school }
        let remainingBlocks = schedule.filter { endDateToday(for: $0, now: now) > now }
        if remainingBlocks.isEmpty, (!carryoverTasks.isEmpty || !topTasks(for: now).isEmpty) {
            prompts.append(
                TodayActionPrompt(
                    id: "closeout",
                    title: "Close out the day",
                    detail: carryoverTasks.isEmpty
                        ? "Review open planner items before tomorrow starts."
                        : "\(carryoverTasks.count) planner item\(carryoverTasks.count == 1 ? "" : "s") still sit in today’s bucket.",
                    systemImage: "sunset.fill",
                    tint: .indigo,
                    action: {
                        scrollTargetCard = .endOfDay
                    }
                )
            )
        }

        return Array(prompts.prefix(5))
    }

    func shortPlanDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("Mdy")
        return formatter.string(from: date)
    }

    func header(now: Date) -> some View {
        let accent = currentHeaderAccent(now: now)
        let blockCount = todaysBlockCount(for: now)
        let commitmentCount = commitmentsForToday(now: now).count
        let taskCount = topTasks(for: now).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(now.formatted(.dateTime.weekday(.wide)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .tracking(4)

                    Text(now.formatted(.dateTime.month().day()))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button {
                        showingLayoutCustomization = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.secondary.opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customize Today")

                    if isScheduleEnabled {
                        Button {
                            openScheduleTab()
                        } label: {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Schedule")
                    }
                }
            }

            HStack(spacing: 10) {
                todayHeaderStat(
                    title: "Mode",
                    value: teacherWorkflowMode.shortLabel,
                    accent: .purple
                )
                if isScheduleEnabled {
                    todayHeaderStat(
                        title: "Blocks",
                        value: "\(blockCount)",
                        accent: accent
                    ) {
                        openScheduleTab()
                    }
                } else {
                    todayHeaderStat(
                        title: "Blocks",
                        value: "\(blockCount)",
                        accent: accent
                    )
                }
                todayHeaderStat(
                    title: "Planner",
                    value: "\(taskCount)",
                    accent: .orange
                ) {
                    scrollTargetCard = .tasks
                }
                todayHeaderStat(
                    title: "Schedule",
                    value: "\(commitmentCount)",
                    accent: .indigo
                ) {
                    scrollTargetCard = .commitments
                }
            }

            if let ignoreDate, ignoreDate > now {
                notificationPauseBadge(until: ignoreDate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(todayHeaderBackground(accent: accent))
        .overlay(todayHeaderBorder(accent: accent))
        .padding(.horizontal)
        .padding(.top, 2)
    }

    @ViewBuilder
    func todayBackground(for item: AlarmItem?) -> some View {
        LinearGradient(
            colors: [
                Color(.systemGray6),
                Color(.systemBackground),
                Color(.systemGray6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    func emptyState(for now: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if classDefinitions.isEmpty && studentSupportProfiles.isEmpty {
                Text("Set up your teacher workspace first.")
                    .font(.headline)

                Text("Add your classes or groups, then students, and Today will become useful right away.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    openSettingsTab()
                } label: {
                    Label("Open Setup", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .tint(dashboardPrimaryTint)
            } else {
                Text("No blocks scheduled for today.")
                    .font(.headline)

                Text("Add your first block in Schedule and it will appear here right away.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    openScheduleTab()
                } label: {
                    Label("Open Schedule", systemImage: "calendar")
                }
                .buttonStyle(.borderedProminent)
                .tint(dashboardPrimaryTint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    func compactDateHeader(now: Date) -> some View {
        let accent = currentHeaderAccent(now: now)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(now.formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(accent)
                    .tracking(2.6)

                Text(now.formatted(.dateTime.month(.wide).day()))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button {
                    presentStudentLookup(
                        title: "Students",
                        subtitle: "Search all saved students, supports, and linked groups.",
                        students: studentSupportProfiles,
                        fallbackToAllStudents: false
                    )
                } label: {
                    Image(systemName: "person.text.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search Students")

                Button {
                    openScheduleTab()
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Schedule")

                Button {
                    openSettingsTab()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Settings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    func overrideBanner(name: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Schedule Override")
                    .font(.subheadline.weight(.bold))

                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Today is using an override schedule.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Manage") {
                openScheduleTab()
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(dashboardPrimaryTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.14),
                            Color.cyan.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Schedule and Runtime Helpers

extension TodayView {
    func loadDashboardCardOrderIfNeeded() {
        let stored = decodeDashboardCardOrder(from: storedDashboardCardOrder)
        dashboardCardOrder = stored.isEmpty ? TodayDashboardCard.defaultOrder : stored
        let hiddenValue = storedHiddenDashboardCards.trimmingCharacters(in: .whitespacesAndNewlines)
        if hiddenValue.isEmpty {
            hiddenDashboardCards = TodayDashboardCard.defaultHidden
        } else if hiddenValue == "__none__" {
            hiddenDashboardCards = []
        } else {
            hiddenDashboardCards = decodeHiddenDashboardCards(from: storedHiddenDashboardCards)
        }
    }

    func persistDashboardCardOrder(_ cards: [TodayDashboardCard]) {
        storedDashboardCardOrder = cards.map(\.rawValue).joined(separator: ",")
    }

    func persistHiddenDashboardCards(_ cards: Set<TodayDashboardCard>) {
        storedHiddenDashboardCards = cards.isEmpty
            ? "__none__"
            : cards.map(\.rawValue).sorted().joined(separator: ",")
    }

    func decodeDashboardCardOrder(from string: String) -> [TodayDashboardCard] {
        let keys = string
            .split(separator: ",")
            .map(String.init)

        guard !keys.isEmpty else {
            return TodayDashboardCard.defaultOrder
        }

        var seen = Set<TodayDashboardCard>()
        var resolved: [TodayDashboardCard] = []

        for key in keys {
            guard let card = TodayDashboardCard(rawValue: key), !seen.contains(card) else { continue }
            resolved.append(card)
            seen.insert(card)
        }

        for card in TodayDashboardCard.defaultOrder where !seen.contains(card) {
            resolved.append(card)
        }

        return resolved
    }

    func decodeHiddenDashboardCards(from string: String) -> Set<TodayDashboardCard> {
        Set(
            string
                .split(separator: ",")
                .compactMap { TodayDashboardCard(rawValue: String($0)) }
        )
    }

    func resetDashboardLayout() {
        dashboardCardOrder = TodayDashboardCard.defaultOrder
        hiddenDashboardCards = TodayDashboardCard.defaultHidden
    }

    var showsOnlyMinimalTodayCards: Bool {
        hiddenDashboardCards == TodayDashboardCard.defaultHidden
    }
}

// MARK: - Header Status Helpers

extension TodayView {
    func topTasks(for now: Date, workspace: TodoItem.Workspace = .school) -> [TodoItem] {
        todos
            .filter { !$0.isCompleted && $0.workspace == workspace }
            .sorted { lhs, rhs in
                let lhsBucket = bucketRank(lhs.bucket)
                let rhsBucket = bucketRank(rhs.bucket)

                if lhsBucket != rhsBucket {
                    return lhsBucket < rhsBucket
                }

                let lhsRank = priorityRank(lhs.priority)
                let rhsRank = priorityRank(rhs.priority)

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?):
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.task.localizedCaseInsensitiveCompare(rhs.task) == .orderedAscending
                }
            }
            .prefix(3)
            .map { $0 }
    }

    func taskSubtitle(for task: TodoItem) -> String {
        var parts = [task.workspace.displayName, task.category.displayName, task.bucket.displayName]

        if let due = task.dueDate {
            parts.append("Due \(due.formatted(date: .abbreviated, time: .omitted))")
        }

        if !task.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.linkedContext)
        }

        if !task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.studentOrGroup)
        }

        if task.reminder != .none {
            parts.append(task.reminder.displayName)
        }

        if !task.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.followUpNote)
        }

        if task.priority != .none {
            parts.append("\(task.priority.rawValue) Priority")
        }

        return parts.joined(separator: " • ")
    }

    func savedStudentProfile(for name: String) -> StudentSupportProfile? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return studentSupportsByName[key]
    }

    func latestStudentProfile(for profile: StudentSupportProfile) -> StudentSupportProfile {
        studentSupportProfiles.first(where: { $0.id == profile.id }) ?? profile
    }

    func behaviorTrackedStudents(from students: [StudentSupportProfile]) -> [StudentSupportProfile] {
        students
            .map(latestStudentProfile(for:))
            .filter(\.behaviorTrackingEnabled)
    }

    func presentStudentLookup(
        title: String,
        subtitle: String,
        students: [StudentSupportProfile],
        behaviorContext: TodayBehaviorQuickLogContext? = nil,
        fallbackToAllStudents: Bool = true
    ) {
        let resolvedStudents: [StudentSupportProfile]
        if students.isEmpty, fallbackToAllStudents {
            resolvedStudents = studentSupportProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            resolvedStudents = students.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        studentLookupSession = TodayStudentLookupSession(
            title: title,
            subtitle: subtitle,
            students: resolvedStudents,
            behaviorContext: behaviorContext
        )
    }

    func presentStudentLookup(for item: AlarmItem) {
        if let session = makeGroupActionSession(for: item, action: .students) {
            groupActionSession = session
            return
        }

        let roster = rosterStudents(for: item)
        presentStudentLookup(
            title: item.className,
            subtitle: studentLookupSubtitle(for: item, studentCount: roster.count),
            students: roster,
            fallbackToAllStudents: false
        )
    }

    func presentBehaviorLookup(for item: AlarmItem) {
        if let session = makeGroupActionSession(for: item, action: .behavior) {
            groupActionSession = session
            return
        }

        let roster = behaviorTrackedStudents(from: rosterStudents(for: item))
        presentStudentLookup(
            title: "\(item.className) Behavior",
            subtitle: "Tap a behavior state to start a quick note with the block and timestamp already filled in.",
            students: roster,
            behaviorContext: TodayBehaviorQuickLogContext(
                segmentID: item.id,
                segmentTitle: item.className
            ),
            fallbackToAllStudents: false
        )
    }

    func presentHomeworkCapture(for item: AlarmItem, now: Date) {
        if let session = makeGroupActionSession(for: item, action: .homework) {
            groupActionSession = session
            return
        }

        homeworkCaptureSession = HomeworkCaptureSession(
            item: item,
            date: now,
            targetClassDefinitionID: nil,
            targetTitle: nil
        )
    }

    func presentRollCall(for item: AlarmItem, now: Date, schedule: [AlarmItem]) {
        if let session = makeGroupActionSession(for: item, action: .rollCall) {
            groupActionSession = session
            return
        }

        presentAttendance(for: item, now: now, schedule: schedule)
    }

    func makeGroupActionSession(for item: AlarmItem, action: TodayGroupActionKind) -> TodayGroupActionSession? {
        let linkedDefinitions = item.linkedClassDefinitionIDs.compactMap { linkedID in
            classDefinitions.first(where: { $0.id == linkedID })
        }

        guard linkedDefinitions.count > 1 else { return nil }

        let choices = linkedDefinitions.map { definition in
            let studentCount = rosterStudents(for: item, targetClassDefinitionID: definition.id).count
            return TodayGroupActionSession.Selection(
                itemID: item.id,
                action: action,
                classDefinitionID: definition.id,
                title: definition.displayName,
                studentCount: studentCount
            )
        }

        return TodayGroupActionSession(action: action, choices: choices)
    }

    func handleGroupActionSelection(_ selection: TodayGroupActionSession.Selection, now: Date, schedule: [AlarmItem]) {
        guard let item = alarms.first(where: { $0.id == selection.itemID }) ?? schedule.first(where: { $0.id == selection.itemID }) else {
            return
        }

        switch selection.action {
        case .rollCall:
            presentAttendance(
                for: item,
                now: now,
                schedule: schedule,
                targetClassDefinitionID: selection.classDefinitionID,
                targetTitle: selection.title
            )
        case .homework:
            homeworkCaptureSession = HomeworkCaptureSession(
                item: item,
                date: now,
                targetClassDefinitionID: selection.classDefinitionID,
                targetTitle: selection.title
            )
        case .students:
            let students = rosterStudents(for: item, targetClassDefinitionID: selection.classDefinitionID)
            presentStudentLookup(
                title: selection.title,
                subtitle: studentLookupSubtitle(for: item, studentCount: students.count),
                students: students,
                fallbackToAllStudents: false
            )
        case .behavior:
            let students = behaviorTrackedStudents(
                from: rosterStudents(for: item, targetClassDefinitionID: selection.classDefinitionID)
            )
            presentStudentLookup(
                title: "\(selection.title) Behavior",
                subtitle: "Tap a behavior state to start a quick note with the block and timestamp already filled in.",
                students: students,
                behaviorContext: TodayBehaviorQuickLogContext(
                    segmentID: item.id,
                    segmentTitle: selection.title
                ),
                fallbackToAllStudents: false
            )
        }
    }

    func studentLookupSubtitle(for item: AlarmItem, studentCount: Int) -> String {
        let linkedGroupCount = item.linkedClassDefinitionIDs.count
        let location = item.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if studentCount == 0 {
            let emptyParts = [
                linkedGroupCount > 1 ? "\(linkedGroupCount) linked groups" : nil,
                location.isEmpty ? nil : location
            ].compactMap { $0 }
            let suffix = emptyParts.isEmpty ? "" : " • " + emptyParts.joined(separator: " • ")
            return "No students linked yet\(suffix)"
        }
        let parts = [
            "\(studentCount) student\(studentCount == 1 ? "" : "s")",
            linkedGroupCount > 1 ? "\(linkedGroupCount) linked groups" : nil,
            location.isEmpty ? nil : location
        ].compactMap { $0 }

        return parts.isEmpty ? "Student quick lookup" : parts.joined(separator: " • ")
    }

    @ViewBuilder
    func studentGradePill(_ gradeLevel: String) -> some View {
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

    func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high: return 0
        case .med: return 1
        case .low: return 2
        case .none: return 3
        }
    }

    func bucketRank(_ bucket: TodoItem.Bucket) -> Int {
        switch bucket {
        case .today: return 0
        case .tomorrow: return 1
        case .thisWeek: return 2
        case .later: return 3
        }
    }

    func shouldShowDayStatus(now: Date, schedule: [AlarmItem], activeItem: AlarmItem?) -> Bool {
        if let ignoreDate, ignoreDate > now {
            return true
        }

        if activeItem != nil {
            return false
        }

        return schedule.isEmpty || schedule.contains { startDateToday(for: $0, now: now) > now }
    }

    var notesSnapshot: String? {
        let trimmed = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " • ")

        return normalized.isEmpty ? nil : normalized
    }

    var suggestedTaskContexts: [String] {
        let classContexts = (overrideSchedule ?? alarms)
            .map(\.className)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let commitmentContexts = commitments
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Array(Set((classContexts + commitmentContexts).filter { !$0.isEmpty }))
            .sorted()
    }

    func preferredCaptureContext(for schedule: [AlarmItem]) -> String? {
        let now = Date()
        if let active = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }) {
            return active.className
        }

        return schedule.first(where: {
            startDateToday(for: $0, now: now) > now
        })?.className
    }

    func preferredCaptureCategory(for schedule: [AlarmItem], now: Date) -> TodoItem.Category? {
        let item = schedule.first(where: {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }) ?? schedule.first(where: {
            startDateToday(for: $0, now: now) > now
        })

        guard let item else { return nil }

        switch item.type {
        case .homeGroup:
            return .prep
        case .math, .ela, .science, .socialStudies:
            return .prep
        case .assembly:
            return .meetingFollowUp
        case .prep:
            return .admin
        case .studyTime:
            return .prep
        case .recess, .lunch, .transition:
            return .classroom
        case .other, .blank:
            return .other
        }
    }

    func rollTodayTasksToTomorrow() {
        for index in todos.indices {
            if !todos[index].isCompleted && todos[index].bucket == .today && todos[index].workspace == .school {
                todos[index].bucket = .tomorrow
            }
        }
    }
}

// MARK: - Attendance and Homework Helpers

extension TodayView {
    func commitmentTimeText(for commitment: CommitmentItem) -> String {
        "\(commitment.startTime.formatted(date: .omitted, time: .shortened)) - \(commitment.endTime.formatted(date: .omitted, time: .shortened)) • \(commitment.kind.displayName)"
    }

    func schoolQuietStart(on date: Date) -> Date {
        Calendar.current.date(
            bySettingHour: schoolQuietHour,
            minute: schoolQuietMinute,
            second: 0,
            of: date
        ) ?? date
    }

    func isAfterSchoolQuietStart(_ now: Date) -> Bool {
        guard schoolQuietHoursEnabled else { return false }
        return now >= schoolQuietStart(on: now)
    }

    func shouldShowAfterHoursPersonalMode(now: Date, schedule: [AlarmItem]) -> Bool {
        guard hideSchoolDashboardAfterHours else { return false }
        guard isAfterSchoolQuietStart(now) else { return false }
        return !schedule.contains { endDateToday(for: $0, now: now) > now }
    }

    func anchoredDate(for date: Date, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    func startDateToday(for item: AlarmItem, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.startTime)

        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    func endDateToday(for item: AlarmItem, now: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: item.endTime)

        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: now
        ) ?? now
    }

    func warningForUpcomingBlock(_ item: AlarmItem?, now: Date) -> InAppWarning? {
        guard let item else { return nil }
        guard item.type != .blank else { return nil }

        let start = startDateToday(for: item, now: now)
        let secondsRemaining = Int(start.timeIntervalSince(now))
        let matchingWarning = item.warningLeadTimes.first { secondsRemaining == $0 * 60 }
        return matchingWarning.map { InAppWarning(item: item, minutesRemaining: $0) }
    }

    func secondaryBackgroundColor(for item: AlarmItem?) -> Color {
        guard let item else { return Color.cyan }

        switch item.type {
        case .homeGroup:
            return .cyan
        case .math:
            return .orange
        case .ela:
            return .yellow
        case .science:
            return .green
        case .socialStudies:
            return .mint
        case .assembly:
            return .pink
        case .prep:
            return .cyan
        case .studyTime:
            return .blue
        case .recess:
            return .teal
        case .lunch:
            return .pink
        case .transition:
            return Color(.systemGray5)
        case .other:
            return Color(.systemGray3)
        case .blank:
            return Color(.systemBackground)
        }
    }

    func handleWarningTrigger(_ warning: InAppWarning?, key: String?) {
        guard let warning, let key else { return }
        guard lastWarningKey != key else { return }

        lastWarningKey = key
        warningDismissTask?.cancel()

        BellFeedbackManager.shared.playSelectedBellFeedback()

        withAnimation {
            activeWarning = warning
        }

        warningDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation {
                    activeWarning = nil
                }
            }
        }
    }

    func extend(_ item: AlarmItem, byMinutes minutes: Int) {
        SessionControlStore.extend(itemID: item.id, byMinutes: minutes)
    }

    func toggleHold(for item: AlarmItem, now: Date) {
        SessionControlStore.toggleHold(itemID: item.id, now: now)
    }

    func skipBell(for item: AlarmItem) {
        SessionControlStore.skipBell(itemID: item.id)
        BellCountdownEngine.shared.reset()
    }

    func isHeld(_ item: AlarmItem) -> Bool {
        SessionControlStore.isHeld(itemID: item.id)
    }

    func isBellSkipped(_ item: AlarmItem) -> Bool {
        SessionControlStore.skippedBellItemIDs().contains(item.id)
    }

    func liveHoldDuration(for item: AlarmItem, now: Date) -> TimeInterval {
        SessionControlStore.liveHoldDuration(for: item.id, now: now)
    }

    func handleActiveItemChange(_ newValue: UUID?) {
        if lastActiveItemID != newValue {
            BellCountdownEngine.shared.reset()
            lastActiveItemID = newValue
        }

        SessionControlStore.clearHoldIfNeeded(activeItemID: newValue)
    }

    func refreshBucket(for now: Date) -> Int {
        Int(now.timeIntervalSinceReferenceDate / 15)
    }

    @MainActor
    func applyLiveRefreshTick(at now: Date) {
        let runtime = makeRuntimeState(for: now)
        let activeItemID = runtime.activeItem?.id
        let nextItemID = runtime.nextItem?.id
        let bucket = refreshBucket(for: now)

        handleWarningTrigger(runtime.warning, key: runtime.warning?.id)
        handleActiveItemChange(activeItemID)
        processBellIfNeeded(runtime.activeItem, now: now)

        let shouldRefreshDashboard =
            bucket != lastDashboardRefreshBucket ||
            activeItemID != lastRenderedActiveItemID ||
            nextItemID != lastRenderedNextItemID

        guard shouldRefreshDashboard else { return }

        dashboardNow = now
        lastDashboardRefreshBucket = bucket
        lastRenderedActiveItemID = activeItemID
        lastRenderedNextItemID = nextItemID
    }

    func makeRuntimeState(for now: Date) -> RuntimeState {
        let schedule = adjustedTodaySchedule(for: now)
        let activeItem = schedule.first {
            now >= startDateToday(for: $0, now: now) && now <= endDateToday(for: $0, now: now)
        }
        let nextItem = schedule.first {
            startDateToday(for: $0, now: now) > now
        }

        return RuntimeState(
            now: now,
            schedule: schedule,
            activeItem: activeItem,
            nextItem: nextItem,
            warning: warningForUpcomingBlock(nextItem, now: now),
            todayCommitments: commitmentsForToday(now: now)
        )
    }

    func runDashboardRefreshLoop() async {
        await MainActor.run {
            applyLiveRefreshTick(at: Date())
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { break }

            await MainActor.run {
                applyLiveRefreshTick(at: Date())
            }
        }
    }

    func processBellIfNeeded(_ activeItem: AlarmItem?, now: Date) {
        guard let activeItem else {
            BellCountdownEngine.shared.reset()
            return
        }

        guard !skippedBellItemIDs.contains(activeItem.id) else { return }

        let secondsRemaining = Int(ceil(endDateToday(for: activeItem, now: now).timeIntervalSince(now)))
        BellCountdownEngine.shared.process(secondsRemaining: secondsRemaining)
    }

    func liveActivityState(for activeItem: AlarmItem?, now: Date) -> LiveActivitySnapshot? {
        guard liveActivitiesEnabled else { return nil }
        guard let activeItem else { return nil }

        let nextItem = displayableNextItem(adjustedTodaySchedule(for: now).first {
            startDateToday(for: $0, now: now) > now
        }, now: now)

        let room = activeItem.location.trimmingCharacters(in: .whitespacesAndNewlines)
        let liveHold = liveHoldDuration(for: activeItem, now: now)
        let stableEndTime = endDateToday(for: activeItem, now: now).addingTimeInterval(-liveHold)

        return LiveActivitySnapshot(
            className: activeItem.className,
            room: room,
            endTime: stableEndTime,
            isHeld: isHeld(activeItem),
            iconName: activeItem.scheduleType.symbolName,
            nextClassName: nextItem?.className ?? "",
            nextIconName: nextItem?.scheduleType.symbolName ?? ""
        )
    }

    func syncLiveActivity(with snapshot: LiveActivitySnapshot?) {
        pendingLiveActivityStopTask?.cancel()

        guard liveActivitiesEnabled else {
            LiveActivityManager.stop()
            return
        }

        guard let snapshot else {
            pendingLiveActivityStopTask = Task {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                LiveActivityManager.stop()
            }
            return
        }

        LiveActivityManager.sync(
            className: snapshot.className,
            room: snapshot.room,
            endTime: snapshot.endTime,
            isHeld: snapshot.isHeld,
            iconName: snapshot.iconName,
            nextClassName: snapshot.nextClassName,
            nextIconName: snapshot.nextIconName
        )
    }

    func widgetSnapshot(activeItem: AlarmItem?, nextItem: AlarmItem?, now: Date) -> ClassTraxWidgetSnapshot {
        func summary(for item: AlarmItem) -> ClassTraxWidgetSnapshot.BlockSummary {
            ClassTraxWidgetSnapshot.BlockSummary(
                id: item.id,
                className: item.className,
                room: item.location.trimmingCharacters(in: .whitespacesAndNewlines),
                gradeLevel: item.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines),
                symbolName: item.scheduleType.symbolName,
                startTime: startDateToday(for: item, now: now),
                endTime: endDateToday(for: item, now: now),
                typeName: item.typeLabel,
                isHeld: isHeld(item),
                bellSkipped: isBellSkipped(item)
            )
        }

        return ClassTraxWidgetSnapshot(
            updatedAt: now,
            current: activeItem.map(summary),
            next: displayableNextItem(nextItem, now: now).map(summary),
            currentRoster: [],
            ignoreUntil: ignoreDate
        )
    }

    func syncWidgetSnapshot(_ snapshot: ClassTraxWidgetSnapshot) {
#if canImport(WidgetKit)
        WidgetSnapshotStore.save(snapshot)
        WatchSessionSyncManager.shared.sync(snapshot: snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ClassTraxHomeWidget")
#else
        WidgetSnapshotStore.save(snapshot)
        WatchSessionSyncManager.shared.sync(snapshot: snapshot)
#endif
    }
}

extension TodayView {
    func landscapeHeader(now: Date) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(headerStatusText(for: now), systemImage: currentHeaderSymbol(now: now))
                .font(.caption.weight(.semibold))
                .foregroundStyle(currentHeaderAccent(now: now))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(currentHeaderAccent(now: now).opacity(0.12))
                )

            if let ignoreDate, ignoreDate > now {
                notificationPauseBadge(until: ignoreDate, compact: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func notificationPauseBadge(until date: Date, compact: Bool = false) -> some View {
        Label(
            compact
                ? "Snoozed Until \(date.formatted(date: .omitted, time: .shortened))"
                : "Alerts Snoozed Until \(date.formatted(date: .abbreviated, time: .shortened))",
            systemImage: "bell.slash.fill"
        )
        .font((compact ? Font.caption2 : .caption).weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
    }

    func headerStatusText(for now: Date) -> String {
        if let ignoreDate, ignoreDate > now {
            return "Alerts snoozed while you pause the school-day flow."
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return "After-hours mode is active and the dashboard is shifting personal."
        }

        let remainingBlocks = adjustedTodaySchedule(for: now).filter { endDateToday(for: $0, now: now) > now }.count
        if remainingBlocks == 0 {
            return "The schedule is clear for the rest of today."
        }

        return "\(remainingBlocks) block\(remainingBlocks == 1 ? "" : "s") remain in today's teaching flow."
    }

    func currentHeaderSymbol(now: Date) -> String {
        if let ignoreDate, ignoreDate > now {
            return "bell.slash.fill"
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return "moon.stars.fill"
        }

        return "sun.max.fill"
    }

    func currentHeaderAccent(now: Date) -> Color {
        if let ignoreDate, ignoreDate > now {
            return .orange
        }

        if schoolQuietHoursEnabled && isAfterSchoolQuietStart(now) {
            return .indigo
        }

        return .blue
    }

    func todaysBlockCount(for now: Date) -> Int {
        adjustedTodaySchedule(for: now).count
    }

    func todayHeaderStat(title: String, value: String, accent: Color, action: (() -> Void)? = nil) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    todayHeaderStatContent(title: title, value: value, accent: accent)
                }
                .buttonStyle(.plain)
            } else {
                todayHeaderStatContent(title: title, value: value, accent: accent)
            }
        }
    }

    func todayHeaderStatContent(title: String, value: String, accent: Color) -> some View {
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

    func todayHeaderBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.16),
                        Color.white.opacity(0.45),
                        Color(.secondarySystemBackground).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    func todayHeaderBorder(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(accent.opacity(0.14), lineWidth: 1)
    }
}

extension TodayView {
    func mostRecentAttendanceItem(from schedule: [AlarmItem], now: Date) -> AlarmItem? {
        schedule
            .filter { block in
                endDateToday(for: block, now: now) < now &&
                !rosterStudents(for: block).isEmpty
            }
            .max { lhs, rhs in
                endDateToday(for: lhs, now: now) < endDateToday(for: rhs, now: now)
            }
    }

    func attendanceRecordsForToday(now: Date) -> [AttendanceRecord] {
        let dateKey = AttendanceRecord.dateKey(for: now)
        return attendanceRecords.filter { $0.dateKey == dateKey }
    }

    func classHomeworkText(for item: AlarmItem, now: Date, targetClassDefinitionID: UUID? = nil) -> String {
        let dateKey = AttendanceRecord.dateKey(for: now)
        return attendanceRecords.first(where: {
            $0.dateKey == dateKey &&
            $0.isClassHomeworkNote &&
            attendanceRecordMatchesClass($0, item: item, targetClassDefinitionID: targetClassDefinitionID)
        })?.assignedHomework ?? ""
    }

    func saveClassHomework(_ text: String, for item: AlarmItem, now: Date, targetClassDefinitionID: UUID? = nil, targetTitle: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dateKey = AttendanceRecord.dateKey(for: now)

        attendanceRecords.removeAll {
            $0.dateKey == dateKey &&
            ($0.isClassHomeworkNote || $0.isHomeworkAssignmentOnly) &&
            attendanceRecordMatchesClass($0, item: item, targetClassDefinitionID: targetClassDefinitionID)
        }

        guard !trimmed.isEmpty else { return }

        attendanceRecords.append(
            AttendanceRecord(
                dateKey: dateKey,
                className: targetTitle ?? item.className,
                gradeLevel: GradeLevelOption.normalized(item.gradeLevel),
                studentName: "",
                studentID: nil,
                classDefinitionID: targetClassDefinitionID ?? item.classDefinitionID,
                blockID: item.id,
                blockStartTime: item.startTime,
                blockEndTime: item.endTime,
                status: .present,
                assignedHomework: trimmed
            )
        )
    }

    func attendanceRecordMatchesClass(_ record: AttendanceRecord, item: AlarmItem, targetClassDefinitionID: UUID? = nil) -> Bool {
        if let blockID = record.blockID, blockID == item.id {
            if let targetClassDefinitionID {
                return record.classDefinitionID == targetClassDefinitionID
            }
            return true
        }

        if recordMatchesBlockTime(record, item: item) {
            if let targetClassDefinitionID {
                return record.classDefinitionID == targetClassDefinitionID
            }
            return true
        }

        if let targetClassDefinitionID {
            if record.classDefinitionID == targetClassDefinitionID {
                return true
            }
        } else if item.matchesLinkedClassDefinition(record.classDefinitionID) {
            return true
        }

        return classNamesMatch(scheduleClassName: item.className, profileClassName: record.className) &&
            normalizedStudentKey(record.gradeLevel) == normalizedStudentKey(GradeLevelOption.normalized(item.gradeLevel))
    }

    func recordMatchesBlockTime(_ record: AttendanceRecord, item: AlarmItem) -> Bool {
        guard
            let recordStartTime = record.blockStartTime,
            let recordEndTime = record.blockEndTime
        else {
            return false
        }

        return blockTimeSignature(start: recordStartTime, end: recordEndTime) ==
            blockTimeSignature(start: item.startTime, end: item.endTime)
    }

    func blockTimeSignature(start: Date, end: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        return String(format: "%02d:%02d-%02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    func attendanceMatchKey(studentID: UUID?, studentName: String) -> String? {
        if let studentID {
            return studentID.uuidString.lowercased()
        }

        let normalizedName = normalizedStudentKey(studentName)
        return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
    }

    func attendanceCompletionText(for item: AlarmItem, now: Date, targetClassDefinitionID: UUID? = nil) -> String? {
        let roster = rosterStudents(for: item, targetClassDefinitionID: targetClassDefinitionID)
        guard !roster.isEmpty else { return nil }
        let dateKey = AttendanceRecord.dateKey(for: now)
        let markedKeys = Set(
            attendanceRecords
                .filter {
                    $0.isAttendanceEntry &&
                    $0.dateKey == dateKey &&
                    attendanceRecordMatchesClass($0, item: item, targetClassDefinitionID: targetClassDefinitionID)
                }
                .compactMap { record in
                    attendanceMatchKey(studentID: record.studentID, studentName: record.studentName)
                }
        )
        let markedCount = roster.filter { student in
            guard let key = attendanceMatchKey(studentID: student.id, studentName: student.name) else { return false }
            return markedKeys.contains(key)
        }.count
        return markedCount >= roster.count
            ? "Attendance complete"
            : "Attendance \(markedCount)/\(roster.count)"
    }

    func todayAttendanceSummary(now: Date, schedule: [AlarmItem]) -> (completedBlocks: Int, pendingBlocks: Int, absentStudents: Int) {
        let rosterBackedBlocks = schedule.filter { !rosterStudents(for: $0).isEmpty }
        let completedBlocks = rosterBackedBlocks.filter {
            attendanceCompletionText(for: $0, now: now) == "Attendance complete"
        }.count
        let pendingBlocks = max(rosterBackedBlocks.count - completedBlocks, 0)
        let absentStudents = attendanceRecordsForToday(now: now)
            .filter { $0.isAttendanceEntry && $0.status == .absent }
            .count
        return (completedBlocks, pendingBlocks, absentStudents)
    }

    enum TodayAttendanceExportScope {
        case all
        case absentOnly
    }

    enum TodayAttendanceExportFormat {
        case text
        case csv
    }

    func exportTodayAttendance(
        as format: TodayAttendanceExportFormat,
        scope: TodayAttendanceExportScope,
        schedule: [AlarmItem],
        now: Date
    ) {
        let records = filteredAttendanceRecordsForExport(scope: scope, now: now)
        guard !records.isEmpty else { return }

        let titleDate = now.formatted(date: .abbreviated, time: .omitted)
        let filenameDate = AttendanceRecord.dateKey(for: now)
        let summaryLabel = scope == .all ? "Attendance Summary" : "Absent Attendance Summary"
        let fileLabel = scope == .all ? "attendance-summary" : "attendance-absent-summary"
        let title = "\(summaryLabel) - \(titleDate)"
        let body = todayAttendanceExportBody(records: records, schedule: schedule, scope: scope)

        let exportURL: URL?
        switch format {
        case .text:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("classtrax-\(fileLabel)-\(filenameDate)-\(UUID().uuidString).txt")
            do {
                try "\(title)\n\n\(body)".write(to: url, atomically: true, encoding: .utf8)
                exportURL = url
            } catch {
                exportURL = nil
            }
        case .csv:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("classtrax-\(fileLabel)-\(filenameDate)-\(UUID().uuidString).csv")
            do {
                try todayAttendanceCSV(records: records, schedule: schedule).write(to: url, atomically: true, encoding: .utf8)
                exportURL = url
            } catch {
                exportURL = nil
            }
        }

        guard let exportURL else { return }
        todayAttendanceExportURL = exportURL
        showingTodayAttendanceShareSheet = true
    }

    enum EndOfDayExportPreset: String, CaseIterable, Identifiable {
        case fullDay
        case parentTeamSummary
        case behaviorOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fullDay:
                return "Full Day"
            case .parentTeamSummary:
                return "Parent / Team Summary"
            case .behaviorOnly:
                return "Behavior Only"
            }
        }

        var systemImage: String {
            switch self {
            case .fullDay:
                return "doc.text"
            case .parentTeamSummary:
                return "person.2"
            case .behaviorOnly:
                return "face.smiling"
            }
        }

        var filenameSuffix: String {
            switch self {
            case .fullDay:
                return "full-day"
            case .parentTeamSummary:
                return "parent-team"
            case .behaviorOnly:
                return "behavior"
            }
        }
    }

    func exportEndOfDaySummary(schedule: [AlarmItem], now: Date, preset: EndOfDayExportPreset = .fullDay) {
        let body = endOfDayExportBody(schedule: schedule, now: now, preset: preset)
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let filenameDate = AttendanceRecord.dateKey(for: now)
        let titleDate = now.formatted(date: .abbreviated, time: .omitted)
        let title = "ClassTrax \(preset.title) - \(titleDate)"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("classtrax-end-of-day-\(preset.filenameSuffix)-\(filenameDate)-\(UUID().uuidString).txt")

        do {
            try "\(title)\n\n\(body)".write(to: url, atomically: true, encoding: .utf8)
            todayAttendanceExportURL = url
            showingTodayAttendanceShareSheet = true
        } catch {
            todayAttendanceExportURL = nil
        }
    }

    func endOfDayExportBody(schedule: [AlarmItem], now: Date, preset: EndOfDayExportPreset = .fullDay) -> String {
        let todaysSchedule = adjustedTodaySchedule(for: now)
        let attendanceToday = attendanceRecordsForToday(now: now)
        let attendanceEntries = attendanceToday.filter(\.isAttendanceEntry)
        let classHomeworkNotes = attendanceToday.filter(\.isClassHomeworkNote)
        let dayCommitments = commitmentsForToday(now: now)
        let notes = decodeFollowUpNotesFromDefaults()
        let includesFullDay = preset == .fullDay
        let includesParentTeam = preset == .parentTeamSummary
        let includesBehaviorOnly = preset == .behaviorOnly

        let summaryLines = [
            "Date: \(now.formatted(date: .complete, time: .omitted))",
            "Schedule: \(activeOverrideName ?? "Regular Day")",
            "Blocks: \(todaysSchedule.count)",
            "Attendance Entries: \(attendanceEntries.count)",
            "Assignments Logged: \(classHomeworkNotes.count)",
            "Commitments: \(dayCommitments.count)"
        ]

        let commitmentLines = dayCommitments.map { commitment in
            "\(commitment.title) • \(commitmentTimeText(for: commitment))"
        }

        let exceptionLines = attendanceEntries
            .filter { $0.status != .present || !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.className.localizedCaseInsensitiveCompare($1.className) != .orderedSame {
                    return $0.className.localizedCaseInsensitiveCompare($1.className) == .orderedAscending
                }
                return $0.studentName.localizedCaseInsensitiveCompare($1.studentName) == .orderedAscending
            }
            .map { record in
                let missingWork = formattedMissingWorkLines(from: record.absentHomework)
                let missingSummary = missingWork.isEmpty ? nil : missingWork.joined(separator: " | ")
                let detailParts = [record.status.rawValue, missingSummary].compactMap { $0 }
                return "\(resolvedAttendanceClassName(for: record)) • \(record.studentName): \(detailParts.joined(separator: " • "))"
            }

        let blockSections = todaysSchedule.compactMap { block -> String? in
            let roster = rosterStudents(for: block)
            let attendance = attendanceEntries.filter { attendanceRecordMatchesClass($0, item: block) }
            let assignedWork = formattedMissingWorkLines(from: classHomeworkText(for: block, now: now))
            let classNotes = notes.filter {
                $0.kind == .classNote &&
                classNamesMatch(scheduleClassName: block.className, profileClassName: $0.context)
            }
            let behaviorLogs = todayBehaviorLogs(for: block, roster: roster)
            let behaviorSummary = behaviorSnapshot(for: block, roster: roster)
            let supportNote = block.blockSupportNote.trimmingCharacters(in: .whitespacesAndNewlines)

            let attendanceSummary = Dictionary(grouping: attendance, by: \.status)
                .compactMap { status, records in
                    records.isEmpty ? nil : "\(status.rawValue): \(records.count)"
                }
                .sorted()
                .joined(separator: " • ")

            let behaviorLines: [String] = {
                guard !behaviorLogs.isEmpty else { return [] }
                var lines = [
                    "Green: \(behaviorSummary.positiveCount) • Yellow: \(behaviorSummary.neutralCount) • Red: \(behaviorSummary.needsSupportCount) • Notes: \(behaviorSummary.notedCount)"
                ]
                let notedStudents = behaviorLogs
                    .filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .sorted { $0.timestamp > $1.timestamp }
                    .prefix(4)
                    .map { log in
                        let note = log.noteSummary ?? log.note.trimmingCharacters(in: .whitespacesAndNewlines)
                        return "\(log.studentName): \(log.rating.title)" + (note.isEmpty ? "" : " • \(note)")
                    }
                lines.append(contentsOf: notedStudents)
                return lines
            }()

            let attendanceExceptionLines = attendance.filter { $0.status != .present || !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map { record in
                let missingWork = formattedMissingWorkLines(from: record.absentHomework)
                let suffix = missingWork.isEmpty ? "" : " • Missing: \(missingWork.joined(separator: " | "))"
                return "\(record.studentName): \(record.status.rawValue)\(suffix)"
            }
            let classNoteLines = classNotes.compactMap { cleanedExportText($0.note) }

            let section = joinExportSections([
                exportSection("Block", body: cleanedExportText("\(block.className)\n\(block.startTime.formatted(date: .omitted, time: .shortened)) - \(block.endTime.formatted(date: .omitted, time: .shortened))")),
                includesFullDay ? exportSection("Assigned Work", body: exportBulletLines(assignedWork)) : nil,
                includesFullDay ? exportSection("Attendance", body: cleanedExportText(attendanceSummary)) : nil,
                (includesFullDay || includesParentTeam) ? exportSection("Attendance Exceptions", body: exportBulletLines(attendanceExceptionLines)) : nil,
                exportSection("Behavior", body: exportBulletLines(behaviorLines)),
                (includesFullDay || includesParentTeam) ? exportSection("Class Notes", body: exportBulletLines(classNoteLines)) : nil,
                includesFullDay ? exportSection("Support Note", body: cleanedExportText(supportNote)) : nil
            ].compactMap { $0 })

            if includesBehaviorOnly && behaviorLines.isEmpty {
                return nil
            }

            return section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : section
        }

        return joinExportSections([
            exportSection(includesBehaviorOnly ? "Behavior Summary" : "Summary", body: exportBulletLines(summaryLines)),
            includesBehaviorOnly ? nil : exportSection("Commitments", body: exportBulletLines(commitmentLines)),
            (includesFullDay || includesParentTeam) ? exportSection("Attendance Exceptions", body: exportBulletLines(exceptionLines)) : nil,
            exportSection("Blocks", body: blockSections.joined(separator: "\n\n"))
        ].compactMap { $0 })
    }

    func filteredAttendanceRecordsForExport(scope: TodayAttendanceExportScope, now: Date) -> [AttendanceRecord] {
        let records = attendanceRecordsForToday(now: now)
        switch scope {
        case .all:
            return records
        case .absentOnly:
            return records.filter {
                $0.isClassHomeworkNote || ($0.isAttendanceEntry && $0.status == .absent)
            }
        }
    }

    func todayAttendanceExportBody(
        records: [AttendanceRecord],
        schedule: [AlarmItem],
        scope: TodayAttendanceExportScope
    ) -> String {
        let classOrder = Dictionary(
            uniqueKeysWithValues: schedule.enumerated().map { index, block in
                (normalizedStudentKey(block.className), index)
            }
        )
        let classHomeworkNotes = records.filter(\.isClassHomeworkNote)
        let studentRecords = records.filter(\.isAttendanceEntry)
        let absentCount = studentRecords.filter { $0.status == .absent }.count
        let tardyCount = studentRecords.filter { $0.status == .tardy }.count

        let grouped = Dictionary(grouping: studentRecords) { record in
            if let studentID = record.studentID {
                return studentID.uuidString
            }
            return normalizedStudentKey(record.studentName)
        }

        var sections: [String] = grouped.values
            .sorted { lhs, rhs in
                let leftName = lhs.first?.studentName ?? ""
                let rightName = rhs.first?.studentName ?? ""
                return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
            }
            .compactMap { studentRecords in
                let sortedRecords = studentRecords.sorted { lhs, rhs in
                    let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: lhs))] ?? .max
                    let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: rhs))] ?? .max
                    if leftOrder == rightOrder {
                        return resolvedAttendanceClassName(for: lhs)
                            .localizedCaseInsensitiveCompare(resolvedAttendanceClassName(for: rhs)) == .orderedAscending
                    }
                    return leftOrder < rightOrder
                }

                let studentName = sortedRecords.first?.studentName ?? "Student"
                let gradeLevel = sortedRecords.first?.gradeLevel ?? ""
                let attendanceExceptions = sortedRecords.filter {
                    scope == .all ? $0.status != .present : $0.status == .absent
                }
                let statusLines = attendanceExceptions.map {
                    "\(resolvedAttendanceClassName(for: $0)): \($0.status.rawValue)"
                }
                let homework = sortedRecords
                    .compactMap(\.absentHomework)
                    .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                let homeworkLines = formattedMissingWorkLines(from: homework)

                guard !statusLines.isEmpty || !homeworkLines.isEmpty else {
                    return nil
                }

                var sections = ["Student: \(studentName)"]
                if !gradeLevel.isEmpty {
                    sections.append("Grade: \(gradeLevel)")
                }
                if !statusLines.isEmpty {
                    sections.append("Attendance:")
                    sections.append(contentsOf: statusLines.map { "• \($0)" })
                }
                if !homeworkLines.isEmpty {
                    sections.append("Missing Work:")
                    sections.append(contentsOf: homeworkLines.map { "• \($0)" })
                }
                return sections.joined(separator: "\n")
            }
        if !classHomeworkNotes.isEmpty {
            let homeworkSection = classHomeworkNotes
                .sorted {
                    let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: $0))] ?? .max
                    let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: $1))] ?? .max
                    return leftOrder < rightOrder
                }
                .flatMap { record in
                    formattedMissingWorkLines(from: record.assignedHomework).map {
                        "• \(resolvedAttendanceClassName(for: record)): \($0)"
                    }
                }

            if !homeworkSection.isEmpty {
                sections.append((["Assigned Work:"] + homeworkSection).joined(separator: "\n"))
            }
        }

        let headerLines = [
            "Students Logged: \(Set(studentRecords.map(\.studentName)).count)",
            "Absent: \(absentCount)",
            "Tardy: \(tardyCount)",
            "Assigned Work Notes: \(classHomeworkNotes.count)"
        ]

        if !sections.isEmpty {
            return (headerLines + [""] + sections).joined(separator: "\n\n")
        }

        switch scope {
        case .all:
            return "All recorded students were marked present."
        case .absentOnly:
            return "No absent students were recorded for today."
        }
    }

    func todayAttendanceCSV(records: [AttendanceRecord], schedule: [AlarmItem]) -> String {
        let classOrder = Dictionary(
            uniqueKeysWithValues: schedule.enumerated().map { index, block in
                (normalizedStudentKey(block.className), index)
            }
        )

        let sortedRecords = records
            .filter(\.isAttendanceEntry)
            .sorted { lhs, rhs in
                let leftName = lhs.studentName.localizedLowercase
                let rightName = rhs.studentName.localizedLowercase
                if leftName != rightName {
                    return leftName < rightName
                }

                let leftOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: lhs))] ?? .max
                let rightOrder = classOrder[normalizedStudentKey(resolvedAttendanceClassName(for: rhs))] ?? .max
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }

                return resolvedAttendanceClassName(for: lhs)
                    .localizedCaseInsensitiveCompare(resolvedAttendanceClassName(for: rhs)) == .orderedAscending
            }

        let header = [
            "date",
            "studentName",
            "gradeLevel",
            "className",
            "status",
            "missingWork",
            "classHomeworkNote"
        ].joined(separator: ",")

        let rows = sortedRecords.map { record in
            let note = records.first(where: {
                $0.isClassHomeworkNote &&
                normalizedStudentKey(resolvedAttendanceClassName(for: $0)) == normalizedStudentKey(resolvedAttendanceClassName(for: record))
            })?.assignedHomework ?? ""
            return [
                record.dateKey,
                record.studentName,
                record.gradeLevel,
                resolvedAttendanceClassName(for: record),
                record.status.rawValue,
                record.absentHomework,
                note
            ]
            .map(csvEscape)
            .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    func resolvedAttendanceClassName(for record: AttendanceRecord) -> String {
        if let classDefinitionID = record.classDefinitionID,
           let definition = classDefinitions.first(where: { $0.id == classDefinitionID }) {
            let name = definition.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }

        let rawName = record.className.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawName.isEmpty || rawName.localizedCaseInsensitiveContains("managedobject") {
            return "Class Not Set"
        }
        return rawName
    }

    func formattedMissingWorkLines(from homework: String?) -> [String] {
        guard let homework else { return [] }
        return homework
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
