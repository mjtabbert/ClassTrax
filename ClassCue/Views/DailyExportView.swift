import SwiftUI
import UIKit

struct DailyExportView: View {

    // MARK: - Export Preset

    enum ExportPreset: String, CaseIterable, Identifiable {
        case fullDay = "Full Day"
        case parentSummary = "Parent / Team Summary"
        case behaviorOnly = "Behavior Only"
        case custom = "Customize"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .fullDay: return "calendar.day.timeline.left"
            case .parentSummary: return "person.2"
            case .behaviorOnly: return "face.smiling"
            case .custom: return "slider.horizontal.3"
            }
        }

        var sections: Set<ExportSection> {
            switch self {
            case .fullDay:
                return Set(ExportSection.allCases)
            case .parentSummary:
                return [.attendance, .behavior, .classNotes]
            case .behaviorOnly:
                return [.behavior]
            case .custom:
                return []
            }
        }
    }

    enum ExportSection: String, CaseIterable, Identifiable {
        case attendance = "Attendance"
        case assignedWork = "Assigned / Missing Work"
        case behavior = "Behavior"
        case classNotes = "Class Notes"
        case commitments = "Commitments / Planner"
        case blockNotes = "Block Notes"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .attendance: return "checkmark.circle"
            case .assignedWork: return "doc.text"
            case .behavior: return "face.smiling"
            case .classNotes: return "note.text"
            case .commitments: return "list.bullet.rectangle"
            case .blockNotes: return "square.and.pencil"
            }
        }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case text = "Text"
        case pdf = "PDF"

        var id: String { rawValue }
    }

    // MARK: - Inputs

    let attendanceRecords: [AttendanceRecord]
    let behaviorLogs: [BehaviorLogItem]
    let todos: [TodoItem]
    let commitments: [CommitmentItem]
    let followUpNotes: [FollowUpNoteItem]
    let classDefinitions: [ClassDefinitionItem]
    let studentProfiles: [StudentSupportProfile]

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @AppStorage("daily_export_last_preset_v1") private var storedPresetRawValue = ExportPreset.fullDay.rawValue
    @AppStorage("daily_export_last_sections_v1") private var storedSectionsRawValue = ""
    @AppStorage("daily_export_last_format_v1") private var storedFormatRawValue = ExportFormat.text.rawValue
    @State private var selectedPreset: ExportPreset = .fullDay
    @State private var customSections: Set<ExportSection> = Set(ExportSection.allCases)
    @State private var exportFormat: ExportFormat = .text
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                presetSection
                if selectedPreset == .custom {
                    customSectionsToggleSection
                }
                formatSection
                previewSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Daily Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") { export() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                DailyExportShareSheet(activityItems: shareItems)
            }
            .onAppear {
                restoreExportPreferences()
            }
            .onChange(of: selectedPreset) { _, _ in
                persistExportPreferences()
            }
            .onChange(of: customSections) { _, _ in
                persistExportPreferences()
            }
            .onChange(of: exportFormat) { _, _ in
                persistExportPreferences()
            }
        }
    }

    // MARK: - Sections

    private var presetSection: some View {
        Section("Preset") {
            ForEach(ExportPreset.allCases) { preset in
                Button {
                    selectedPreset = preset
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(ClassTraxSemanticColor.primaryAction)
                            .frame(width: 24)

                        Text(preset.rawValue)
                            .foregroundStyle(.primary)

                        Spacer()

                        if selectedPreset == preset {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.bold))
                                .foregroundStyle(ClassTraxSemanticColor.primaryAction)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customSectionsToggleSection: some View {
        Section("Include") {
            ForEach(ExportSection.allCases) { section in
                Toggle(isOn: Binding(
                    get: { customSections.contains(section) },
                    set: { enabled in
                        if enabled {
                            customSections.insert(section)
                        } else {
                            customSections.remove(section)
                        }
                    }
                )) {
                    Label(section.rawValue, systemImage: section.systemImage)
                }
                .tint(ClassTraxSemanticColor.primaryAction)
            }
        }
    }

    private var formatSection: some View {
        Section("Format") {
            Picker("Export As", selection: $exportFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            Text(exportBody)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(20)
        }
    }

    // MARK: - Active Sections

    private var activeSections: Set<ExportSection> {
        selectedPreset == .custom ? customSections : selectedPreset.sections
    }

    private func restoreExportPreferences() {
        if let preset = ExportPreset(rawValue: storedPresetRawValue) {
            selectedPreset = preset
        }

        if let format = ExportFormat(rawValue: storedFormatRawValue) {
            exportFormat = format
        }

        let tokens = storedSectionsRawValue
            .split(separator: "|")
            .map { String($0) }
        let restoredSections = Set(tokens.compactMap(ExportSection.init(rawValue:)))
        if !restoredSections.isEmpty {
            customSections = restoredSections
        }
    }

    private func persistExportPreferences() {
        storedPresetRawValue = selectedPreset.rawValue
        storedFormatRawValue = exportFormat.rawValue
        let orderedSections = ExportSection.allCases
            .filter { customSections.contains($0) }
            .map(\.rawValue)
        storedSectionsRawValue = orderedSections.joined(separator: "|")
    }

    // MARK: - Export

    private func export() {
        let title = "ClassCue Daily Export"
        let fullText = classCueNotesExportText(notes: exportBody, title: title)

        switch exportFormat {
        case .text:
            shareItems = [fullText]
        case .pdf:
            if let url = makeExportPDF(title: title, body: fullText) {
                shareItems = [url]
            } else {
                shareItems = [fullText]
            }
        }
        showingShareSheet = true
    }

    // MARK: - Body Text

    private var exportBody: String {
        let sections = activeSections
        var parts: [String] = []

        if sections.contains(.attendance) {
            let text = attendanceExportText
            if !text.isEmpty { parts.append(text) }
        }
        if sections.contains(.assignedWork) {
            let text = assignedWorkExportText
            if !text.isEmpty { parts.append(text) }
        }
        if sections.contains(.behavior) {
            let text = behaviorExportText
            if !text.isEmpty { parts.append(text) }
        }
        if sections.contains(.classNotes) {
            let text = classNotesExportText
            if !text.isEmpty { parts.append(text) }
        }
        if sections.contains(.commitments) {
            let text = commitmentsExportText
            if !text.isEmpty { parts.append(text) }
        }
        if sections.contains(.blockNotes) {
            let text = blockNotesExportText
            if !text.isEmpty { parts.append(text) }
        }

        return parts.isEmpty ? "No data for the selected sections." : parts.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Attendance

    private var todayDateKey: String {
        AttendanceRecord.dateKey(for: Date())
    }

    private var todayAttendance: [AttendanceRecord] {
        attendanceRecords.filter { $0.dateKey == todayDateKey && $0.isAttendanceEntry }
    }

    private var attendanceExportText: String {
        let records = todayAttendance
        guard !records.isEmpty else { return "" }

        var lines = ["ATTENDANCE"]
        let grouped = Dictionary(grouping: records) { $0.className }
        for (className, classRecords) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("  \(className)")
            let present = classRecords.filter { $0.status == .present }.count
            let total = classRecords.count
            lines.append("  Present: \(present)/\(total)")

            let nonPresent = classRecords.filter { $0.status != .present }
            for record in nonPresent {
                lines.append("    \(record.studentName) - \(record.status.rawValue)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Assigned / Missing Work

    private var assignedWorkExportText: String {
        let hwRecords = attendanceRecords.filter {
            $0.dateKey == todayDateKey && (
                !$0.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !$0.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        guard !hwRecords.isEmpty else { return "" }

        var lines = ["ASSIGNED / MISSING WORK"]
        let grouped = Dictionary(grouping: hwRecords) { $0.className }
        for (className, classRecords) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("  \(className)")
            for record in classRecords {
                let assigned = record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
                let absent = record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines)
                if !assigned.isEmpty {
                    let label = record.isClassHomeworkNote ? "Class Assignment" : record.studentName
                    lines.append("    \(label): \(assigned)")
                }
                if !absent.isEmpty && !record.isClassHomeworkNote {
                    lines.append("    \(record.studentName) (absent): \(absent)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Behavior

    private var todayBehaviorLogs: [BehaviorLogItem] {
        let calendar = Calendar.current
        return behaviorLogs.filter { calendar.isDateInToday($0.timestamp) }
    }

    private var behaviorExportText: String {
        let logs = todayBehaviorLogs
        guard !logs.isEmpty else { return "" }

        var lines = ["BEHAVIOR"]
        let grouped = Dictionary(grouping: logs) { $0.studentName }
        for (name, studentLogs) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("")
            lines.append("  \(name)")

            let bySegment = Dictionary(grouping: studentLogs) { $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines) }
            for (segment, segLogs) in bySegment.sorted(by: { $0.key < $1.key }) {
                let segmentLabel = segment.isEmpty ? "" : " [\(segment)]"
                for log in segLogs.sorted(by: { $0.behavior.title < $1.behavior.title }) {
                    var line = "    \(log.behavior.title): \(log.rating.title)\(segmentLabel)"
                    let note = log.trimmedNote
                    if !note.isEmpty {
                        line += " - \(note)"
                    }
                    lines.append(line)
                }
            }

            // Include per-class behavior quick notes from student profile
            if let profile = studentProfiles.first(where: { $0.id == studentLogs.first?.studentID }) {
                for ctx in profile.classContexts {
                    for (behaviorKey, quickNote) in ctx.behaviorQuickNotes {
                        let trimmed = quickNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        let className = classDefinitions.first(where: { $0.id == ctx.classDefinitionID })?.name ?? ""
                        let classLabel = className.isEmpty ? "" : " [\(className)]"
                        lines.append("    Note (\(behaviorKey))\(classLabel): \(trimmed)")
                    }
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Class Notes

    private var classNotesExportText: String {
        let classNotes = followUpNotes.filter { $0.kind == .classNote }
        guard !classNotes.isEmpty else { return "" }

        var lines = ["CLASS NOTES"]
        let grouped = Dictionary(grouping: classNotes) { $0.context }
        for (context, notes) in grouped.sorted(by: { $0.key < $1.key }) {
            let label = context.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("")
            lines.append("  \(label.isEmpty ? "General" : label)")
            for note in notes.sorted(by: { $0.createdAt > $1.createdAt }) {
                lines.append("    \(note.note)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Commitments

    private var commitmentsExportText: String {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let todayCommitments = commitments.filter { $0.dayOfWeek == todayWeekday }
        let todayTodos = todos.filter { $0.bucket == .today && !$0.isCompleted }
        guard !todayCommitments.isEmpty || !todayTodos.isEmpty else { return "" }

        var lines = ["COMMITMENTS / PLANNER"]

        if !todayCommitments.isEmpty {
            lines.append("")
            lines.append("  Scheduled")
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            for c in todayCommitments.sorted(by: { $0.startTime < $1.startTime }) {
                let time = "\(formatter.string(from: c.startTime)) - \(formatter.string(from: c.endTime))"
                lines.append("    \(c.title) (\(c.kind.displayName)) \(time)")
                let loc = c.location.trimmingCharacters(in: .whitespacesAndNewlines)
                if !loc.isEmpty {
                    lines.append("      Location: \(loc)")
                }
            }
        }

        if !todayTodos.isEmpty {
            lines.append("")
            lines.append("  Tasks")
            for todo in todayTodos {
                let pri = todo.priority == .none ? "" : " [\(todo.priority.rawValue)]"
                lines.append("    \(todo.task)\(pri)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Block Notes

    private var blockNotesExportText: String {
        let studentNotes = followUpNotes.filter { $0.kind == .studentNote || $0.kind == .parentContact }
        let schoolNotes = followUpNotes.filter { $0.kind == .generalNote }
        guard !studentNotes.isEmpty || !schoolNotes.isEmpty else { return "" }

        var lines = ["BLOCK NOTES"]

        if !schoolNotes.isEmpty {
            lines.append("")
            lines.append("  School Log")
            for note in schoolNotes.sorted(by: { $0.createdAt > $1.createdAt }).prefix(5) {
                lines.append("    \(note.note)")
            }
        }

        if !studentNotes.isEmpty {
            lines.append("")
            lines.append("  Student Notes")
            let grouped = Dictionary(grouping: studentNotes) { $0.studentOrGroup }
            for (student, notes) in grouped.sorted(by: { $0.key < $1.key }) {
                lines.append("    \(student)")
                for note in notes.sorted(by: { $0.createdAt > $1.createdAt }) {
                    lines.append("      \(note.note)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Share Sheet

private struct DailyExportShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF Helper

private func makeExportPDF(title: String, body: String) -> URL? {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClassCue_Export_\(UUID().uuidString).pdf")

    let text = "\(title)\n\n\(body)"
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 12),
        .paragraphStyle: paragraph
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let printableRect = CGRect(x: 36, y: 36, width: 540, height: 720)

    do {
        try renderer.writePDF(to: url) { context in
            var range = NSRange(location: 0, length: attributed.length)
            while range.location < attributed.length {
                context.beginPage()
                let framesetter = CTFramesetterCreateWithAttributedString(attributed)
                let pageBounds = UIGraphicsGetPDFContextBounds()
                let coreTextRect = CGRect(
                    x: printableRect.minX,
                    y: pageBounds.height - printableRect.maxY,
                    width: printableRect.width,
                    height: printableRect.height
                )
                let path = CGPath(rect: coreTextRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(range.location, range.length), path, nil)
                if let ctx = UIGraphicsGetCurrentContext() {
                    ctx.saveGState()
                    ctx.textMatrix = .identity
                    ctx.translateBy(x: 0, y: pageBounds.height)
                    ctx.scaleBy(x: 1, y: -1)
                    CTFrameDraw(frame, ctx)
                    ctx.restoreGState()
                }
                let visible = CTFrameGetVisibleStringRange(frame)
                range = NSRange(
                    location: range.location + visible.length,
                    length: attributed.length - range.location - visible.length
                )
            }
        }
        return url
    } catch {
        return nil
    }
}
