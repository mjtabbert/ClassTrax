import SwiftUI
import UIKit

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
            return "Teacher Context"
        case .currentClass:
            return "Current / Next Class"
        case .attendance:
            return "Attendance"
        case .commitments:
            return "Commitments"
        case .upcoming:
            return "Upcoming"
        case .tasks:
            return "Tasks"
        case .support:
            return "Class Support"
        case .notes:
            return "Notes Snapshot"
        case .endOfDay:
            return "End of Day"
        case .subPlan:
            return "Sub Plan"
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
        .attendance,
        .commitments,
        .upcoming,
        .tasks,
        .support,
        .notes,
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
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.07),
                                Color(.secondarySystemBackground).opacity(0.94),
                                Color.white.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(0.08), lineWidth: 0.9)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
    }
}

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
        .navigationTitle("Missing Work")
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
                !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        "No Homework Saved",
                        systemImage: "text.book.closed",
                        description: Text("Class homework and absent-student missing work for \(date.formatted(date: .abbreviated, time: .omitted)) will appear here.")
                    )
                }
            } else {
                Section("Summary") {
                    LabeledContent("Class Homework Notes", value: "\(classHomeworkRecords.count)")
                    LabeledContent("Absent Students", value: "\(studentHomeworkRecords.count)")
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
                                        title: browseMode == .className ? "Class Homework" : displayClassName(for: record),
                                        subtitle: record.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Class note" : "\(record.gradeLevel) • Class note",
                                        detail: record.absentHomework,
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
        .navigationTitle("Homework Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
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
            helperText = "Edit the class-level homework note for this block."
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
            initialText: record.absentHomework
        )
    }

    private func saveHomework(_ text: String, recordID: UUID) {
        guard let index = attendanceRecords.firstIndex(where: { $0.id == recordID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if attendanceRecords[index].isClassHomeworkNote && trimmed.isEmpty {
            attendanceRecords.remove(at: index)
            return
        }

        attendanceRecords[index].absentHomework = trimmed
    }

    private func displayClassName(for record: AttendanceRecord) -> String {
        resolvedClassName(for: record)
    }

    private func studentSubtitle(for record: AttendanceRecord) -> String {
        let parts = [displayClassName(for: record), record.gradeLevel]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Student homework" : parts.joined(separator: " • ")
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
            title: "Homework Review - \(titleDate)",
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
            title: "\(label) Homework Review - \(group.title)",
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
                lines.append("Class Homework")
                for record in classRecords {
                    let detail = record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines)
                    lines.append("• \(displayClassName(for: record))")
                    lines.append(detail.isEmpty ? "  Add missing work" : "  \(detail)")
                }
                lines.append("")
            }

            if !studentRecords.isEmpty {
                lines.append("Students")
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

struct TodayLayoutCustomizationView: View {
    @Binding var cards: [TodayDashboardCard]
    @Binding var hiddenCards: Set<TodayDashboardCard>
    @Environment(\.dismiss) private var dismiss

    private var orderedCards: [TodayDashboardCard] {
        cards
    }

    private var isUsingDefaultLayout: Bool {
        cards == TodayDashboardCard.defaultOrder &&
        hiddenCards == TodayDashboardCard.defaultHidden
    }

    var body: some View {
        List {
            Section {
                Text("Current Block and Next Up stay fixed at the top. Choose which cards appear below, then drag them into the order that fits your routine.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
                EditButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        cards.move(fromOffsets: source, toOffset: destination)
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
