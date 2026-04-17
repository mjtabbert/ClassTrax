import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct TodayStudentLookupSession: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let students: [StudentSupportProfile]
    let behaviorContext: TodayBehaviorQuickLogContext?
}

struct TodayBehaviorQuickLogContext: Equatable {
    let segmentID: UUID?
    let segmentTitle: String
}

private struct BehaviorQuickLogDraft: Identifiable {
    let id = UUID()
    let profile: StudentSupportProfile
    let behavior: BehaviorLogItem.BehaviorKind
    let rating: BehaviorLogItem.Rating
    let segmentID: UUID?
    let segmentTitle: String
    let timestamp: Date

    var title: String {
        "Behavior Note"
    }

    var resolvedSegmentTitle: String {
        let trimmed = segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "General" : trimmed
    }
}

private struct BehaviorQuickSelectRow: View {
    let title: String
    let options: [String]
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = value.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(option) == .orderedSame
                        Button {
                            value = option
                        } label: {
                            Text(option)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemFill))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.2)
                                )
                                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }
}

private struct BehaviorQuickLogNoteView: View {
    private static let antecedentOptions = [
        "Transition",
        "Task Demand",
        "Peer Interaction",
        "Whole Group",
        "Independent Work",
        "Adult Redirection"
    ]

    private static let interventionOptions = [
        "Redirection",
        "Break",
        "Prompt",
        "Check-In",
        "Positive Reinforcement",
        "Seat Change"
    ]

    let draft: BehaviorQuickLogDraft
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var antecedentText = ""
    @State private var interventionText = ""
    @State private var consequenceText = ""
    @State private var noteText = ""

    private enum Field {
        case antecedent
        case intervention
        case consequence
        case notes
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(draft.profile.name)
                        .font(.headline.weight(.semibold))

                    HStack(spacing: 10) {
                        quickSummaryPill(title: "Behavior", value: draft.behavior.title)
                        quickSummaryPill(title: "State", value: draft.rating.colorLabel, tint: draft.rating.tint)
                    }

                    HStack(spacing: 10) {
                        quickSummaryPill(title: "Block", value: draft.resolvedSegmentTitle)
                        quickSummaryPill(
                            title: "Time",
                            value: draft.timestamp.formatted(date: .omitted, time: .shortened)
                        )
                    }
                }
            }

            Section("Trigger") {
                BehaviorQuickSelectRow(
                    title: "Quick Pick",
                    options: Self.antecedentOptions,
                    value: $antecedentText
                )

                TextField("What happened right before this?", text: $antecedentText, axis: .vertical)
                    .focused($focusedField, equals: .antecedent)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Intervention") {
                BehaviorQuickSelectRow(
                    title: "Quick Pick",
                    options: Self.interventionOptions,
                    value: $interventionText
                )

                TextField("What support or response was used?", text: $interventionText, axis: .vertical)
                    .focused($focusedField, equals: .intervention)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Follow-Up") {
                TextField("Consequence or immediate outcome", text: $consequenceText, axis: .vertical)
                    .focused($focusedField, equals: .consequence)
                    .textInputAutocapitalization(.sentences)
            }

            Section("Notes") {
                TextEditor(text: $noteText)
                    .focused($focusedField, equals: .notes)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.sentences)
                    .frame(minHeight: 140)
            }
        }
        .navigationTitle(draft.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(composedNote)
                    dismiss()
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            focusedField = .notes
        }
    }

    private var composedNote: String {
        let trimmedAntecedent = antecedentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIntervention = interventionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConsequence = consequenceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines = [
            "Block: \(draft.resolvedSegmentTitle)",
            "Behavior: \(draft.behavior.title)",
            "State: \(draft.rating.colorLabel)",
            "Time: \(draft.timestamp.formatted(date: .omitted, time: .shortened))"
        ]

        if !trimmedAntecedent.isEmpty {
            lines.append("Trigger: \(trimmedAntecedent)")
        }

        if !trimmedIntervention.isEmpty {
            lines.append("Intervention: \(trimmedIntervention)")
        }

        if !trimmedConsequence.isEmpty {
            lines.append("Follow-Up: \(trimmedConsequence)")
        }

        lines.append("")
        lines.append(trimmedNotes.isEmpty ? "Notes:" : "Notes: \(trimmedNotes)")

        return lines.joined(separator: "\n")
    }

    private func quickSummaryPill(title: String, value: String, tint: Color = Color(.secondarySystemFill)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint == Color(.secondarySystemFill) ? .primary : tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint == Color(.secondarySystemFill) ? Color(.secondarySystemFill) : tint.opacity(0.12))
        )
    }
}

enum TodayGroupActionKind: String {
    case rollCall
    case homework
    case students
    case behavior

    var title: String {
        switch self {
        case .rollCall: return "Attendance"
        case .homework: return "Homework"
        case .students: return "Students"
        case .behavior: return "Behavior"
        }
    }

    var systemImage: String {
        switch self {
        case .rollCall: return "checklist.checked"
        case .homework: return "text.book.closed"
        case .students: return "person.text.rectangle"
        case .behavior: return "face.smiling"
        }
    }
}

struct TodayGroupActionSession: Identifiable {
    struct Selection: Identifiable {
        let id = UUID()
        let itemID: UUID
        let action: TodayGroupActionKind
        let classDefinitionID: UUID
        let title: String
        let studentCount: Int

        var subtitle: String {
            studentCount == 0
                ? "No students linked yet"
                : "\(studentCount) student\(studentCount == 1 ? "" : "s") linked"
        }

        var isEnabled: Bool {
            switch action {
            case .homework:
                return true
            case .rollCall, .students, .behavior:
                return studentCount > 0
            }
        }
    }

    let id = UUID()
    let action: TodayGroupActionKind
    let choices: [Selection]

    var title: String {
        "Choose Group for \(action.title)"
    }

    var helperText: String {
        switch action {
        case .rollCall:
            return "Pick the linked group you want to mark for attendance."
        case .homework:
            return "Pick the linked group you want to edit homework for."
        case .students:
            return "Pick the linked group you want to review students for."
        case .behavior:
            return "Pick the linked group you want to use for behavior check-in."
        }
    }
}

struct TodayGroupActionPickerView: View {
    let session: TodayGroupActionSession
    let onChoose: (TodayGroupActionSession.Selection) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text(session.helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(session.choices) { selection in
                    Button {
                        onChoose(selection)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: session.action.systemImage)
                                .foregroundStyle(selection.isEnabled ? Color.accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.title)
                                    .foregroundStyle(selection.isEnabled ? .primary : .secondary)

                                Text(selection.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!selection.isEnabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

struct TodayStudentLookupView: View {
    let session: TodayStudentLookupSession
    let onSelect: (StudentSupportProfile) -> Void
    let behaviorLogsForStudent: ((StudentSupportProfile) -> [BehaviorLogItem])?
    let onBehaviorLog: ((StudentSupportProfile, BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?, String, Date) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var behaviorDraft: BehaviorQuickLogDraft?

    var body: some View {
        List(filteredStudents) { profile in
            studentRow(profile)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search students")
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                if session.behaviorContext != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search students", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                if !session.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(session.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $behaviorDraft) { draft in
            NavigationStack {
                BehaviorQuickLogNoteView(draft: draft) { note in
                    onBehaviorLog?(draft.profile, draft.behavior, draft.rating, draft.segmentID, note, draft.timestamp)
                }
            }
        }
    }

    private var filteredStudents: [StudentSupportProfile] {
        let baseStudents = session.behaviorContext == nil
            ? session.students
            : session.students.filter(\.behaviorTrackingEnabled)

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return baseStudents }

        return baseStudents.filter { profile in
            profile.name.localizedCaseInsensitiveContains(query) ||
            profile.className.localizedCaseInsensitiveContains(query) ||
            profile.gradeLevel.localizedCaseInsensitiveContains(query) ||
            profile.accommodations.localizedCaseInsensitiveContains(query) ||
            profile.prompts.localizedCaseInsensitiveContains(query)
        }
    }

    private func studentLookupSummary(for profile: StudentSupportProfile) -> String {
        let parts = [
            profile.className.trimmingCharacters(in: .whitespacesAndNewlines),
            GradeLevelOption.normalized(profile.gradeLevel),
            profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines),
            profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        return parts.isEmpty ? "Open student quick view" : parts.joined(separator: " • ")
    }

    private func todayBehaviorSummary(for profile: StudentSupportProfile) -> String? {
        guard let behaviorLogsForStudent else { return nil }

        let todaysLogs = behaviorLogsForStudent(profile)
            .filter { Calendar.current.isDateInToday($0.timestamp) }

        guard !todaysLogs.isEmpty else { return nil }

        let ratings = BehaviorLogItem.BehaviorKind.allCases.compactMap { behavior in
            todaysLogs
                .filter { $0.behavior == behavior }
                .sorted { $0.timestamp > $1.timestamp }
                .first
                .map { "\(behavior.shortLabel) \($0.rating.emoji)" }
        }

        guard !ratings.isEmpty else { return nil }
        return "Today: " + ratings.joined(separator: "  ")
    }

    private func currentBehaviorLog(for profile: StudentSupportProfile) -> BehaviorLogItem? {
        guard
            let behaviorLogsForStudent,
            let behaviorContext = session.behaviorContext
        else {
            return nil
        }

        let segmentKey = behaviorContext.segmentTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return behaviorLogsForStudent(profile)
            .filter {
                Calendar.current.isDateInToday($0.timestamp) &&
                $0.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == segmentKey
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    @ViewBuilder
    private func studentRow(_ profile: StudentSupportProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                onSelect(profile)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .fontWeight(.semibold)

                        if !profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(GradeLevelOption.pillLabel(for: profile.gradeLevel))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(GradeLevelOption.foregroundColor(for: profile.gradeLevel))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GradeLevelOption.color(for: profile.gradeLevel), in: Capsule(style: .continuous))
                        }
                    }

                    Text(studentLookupSummary(for: profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let behaviorSummary = todayBehaviorSummary(for: profile) {
                        Text(behaviorSummary)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let currentBehaviorLog = currentBehaviorLog(for: profile) {
                        HStack(spacing: 6) {
                            Text("Current Block:")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(currentBehaviorLog.rating.colorLabel)
                                .font(.caption2.weight(.semibold))
                            if !currentBehaviorLog.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption2.weight(.bold))
                            }
                        }
                        .foregroundStyle(currentBehaviorLog.rating.tint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if let behaviorContext = session.behaviorContext, onBehaviorLog != nil {
                HStack(spacing: 10) {
                    ForEach(BehaviorLogItem.Rating.allCases) { rating in
                        let isSelected = currentBehaviorLog(for: profile)?.rating == rating
                        Button {
                            behaviorDraft = BehaviorQuickLogDraft(
                                profile: profile,
                                behavior: .onTask,
                                rating: rating,
                                segmentID: behaviorContext.segmentID,
                                segmentTitle: behaviorContext.segmentTitle,
                                timestamp: Date()
                            )
                        } label: {
                            Text(rating.emoji)
                                .font(.body.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? rating.tint.opacity(0.20) : rating.tint.opacity(0.12))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(isSelected ? rating.tint : rating.tint.opacity(0.35), lineWidth: isSelected ? 1.4 : 1)
                            )
                            .foregroundStyle(rating.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StudentQuickView: View {
    private enum BehaviorTrend: Equatable {
        case improving
        case declining
        case steady

        var title: String {
            switch self {
            case .improving:
                return "Improving"
            case .declining:
                return "Declining"
            case .steady:
                return "Steady"
            }
        }

        var symbol: String {
            switch self {
            case .improving:
                return "arrow.up.right"
            case .declining:
                return "arrow.down.right"
            case .steady:
                return "arrow.left.and.right"
            }
        }

        var tint: Color {
            switch self {
            case .improving:
                return ClassTraxSemanticColor.success
            case .declining:
                return ClassTraxSemanticColor.reviewWarning
            case .steady:
                return ClassTraxSemanticColor.secondaryAction
            }
        }
    }

    private struct BehaviorInsightAlert: Identifiable {
        let id: String
        let title: String
        let detail: String
        let tint: Color
    }

    private enum BehaviorWindow: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "This Week"

        var id: String { rawValue }
    }

    private enum StudentTimelineEventKind: Equatable {
        case attendance
        case behavior
        case assignedWork
        case missingWork
        case classNote

        var symbol: String {
            switch self {
            case .attendance:
                return "checkmark.circle.fill"
            case .behavior:
                return "face.smiling.fill"
            case .assignedWork:
                return "book.fill"
            case .missingWork:
                return "exclamationmark.circle.fill"
            case .classNote:
                return "note.text"
            }
        }
    }

    private enum TimelineFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case attendance = "Attendance"
        case behavior = "Behavior"
        case work = "Work"
        case notes = "Notes"

        var id: String { rawValue }
    }

    private struct StudentTimelineEntry: Identifiable {
        let id: String
        let timestamp: Date
        let kind: StudentTimelineEventKind
        let title: String
        let detail: String
        let tint: Color
    }

    let profile: StudentSupportProfile
    let classDefinitions: [ClassDefinitionItem]
    let teacherContacts: [ClassStaffContact]
    let paraContacts: [ClassStaffContact]
    let attendanceRecords: [AttendanceRecord]
    let behaviorLogs: [BehaviorLogItem]
    let behaviorSegments: [BehaviorSegmentOption]
    let preferredBehaviorSegmentID: UUID?
    let preferredBehaviorSegmentTitle: String
    let onEdit: () -> Void
    let onOpenStudents: () -> Void
    let onOpenRecord: () -> Void
    let onLogBehavior: ((BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?) -> Void)?
    let onLogBehaviorWithNote: ((BehaviorLogItem.BehaviorKind, BehaviorLogItem.Rating, UUID?, String, Date) -> Void)?
    let onSaveBehaviorQuickNote: ((UUID?, BehaviorLogItem.BehaviorKind, String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedBehaviorSegmentID: UUID?
    @State private var selectedBehaviorWindow: BehaviorWindow = .today
    @State private var behaviorQuickNoteDrafts: [String: String] = [:]
    @State private var selectedTimelineFilter: TimelineFilter = .all
    @State private var isBehaviorHistoryExpanded = true
    @State private var isTimelineExpanded = false
    @State private var isBehaviorCheckInExpanded = true
    @State private var externalActionErrorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title3.weight(.bold))

                            Text(primaryClassOrGroupLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(GradeLevelOption.pillLabel(for: profile.gradeLevel))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GradeLevelOption.foregroundColor(for: profile.gradeLevel))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(GradeLevelOption.color(for: profile.gradeLevel), in: Capsule(style: .continuous))
                        }
                    }

                    if !linkedClassesOrGroups.isEmpty {
                        Text(linkedClassesOrGroups.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        quickMetric(title: "Groups", value: "\(linkedGroupCount)", tint: ClassTraxSemanticColor.primaryAction)
                        quickMetric(title: "Teachers", value: "\(resolvedTeacherNames.count)", tint: ClassTraxSemanticColor.success)
                        quickMetric(title: "Paras", value: "\(resolvedParaNames.count)", tint: ClassTraxSemanticColor.reviewWarning)
                    }

                    if let latestBehaviorLog {
                        HStack(spacing: 8) {
                            Text("Latest behavior: \(latestBehaviorLog.behavior.title) \(latestBehaviorLog.rating.colorLabel)")
                                .font(.caption.weight(.semibold))
                            if !latestBehaviorLog.segmentTitle.isEmpty {
                                Text(latestBehaviorLog.segmentTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(latestBehaviorLog.rating.tint)

                        if let noteSummary = latestBehaviorLog.noteSummary {
                            Text(noteSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }

                        if !latestBehaviorLog.noteContextTags.isEmpty {
                            noteTagRow(latestBehaviorLog.noteContextTags)
                        }
                    }
                }
                .padding(14)
                .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
            }

            if !behaviorLogs.isEmpty || !studentAttendanceRecords.isEmpty {
                Section("Daily Snapshot") {
                    if !studentAttendanceRecords.isEmpty || !behaviorLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Conference Snapshot")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                quickMetric(title: "Week Present", value: weeklyAttendanceSummary, tint: ClassTraxSemanticColor.primaryAction)
                                quickMetric(title: "Month Present", value: monthlyAttendanceSummary, tint: ClassTraxSemanticColor.secondaryAction)
                            }

                            HStack(spacing: 10) {
                                quickMetric(title: "Week Support", value: "\(weeklyNeedsSupportCount)", tint: ClassTraxSemanticColor.reviewWarning)
                                quickMetric(title: "Month Support", value: "\(monthlyNeedsSupportCount)", tint: .orange)
                            }
                        }
                        .padding(12)
                        .classTraxCardChrome(accent: ClassTraxSemanticColor.primaryAction, cornerRadius: 16)
                    }

                    if !behaviorLogs.isEmpty {
                        Picker("Behavior Range", selection: $selectedBehaviorWindow) {
                            ForEach(BehaviorWindow.allCases) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 10) {
                            quickMetric(title: "Positive", value: "\(positiveBehaviorCount)", tint: ClassTraxSemanticColor.success)
                            quickMetric(title: "Neutral", value: "\(neutralBehaviorCount)", tint: ClassTraxSemanticColor.secondaryAction)
                            quickMetric(title: "Needs Support", value: "\(needsSupportBehaviorCount)", tint: ClassTraxSemanticColor.reviewWarning)
                        }
                    }

                    if !behaviorSegmentSnapshots.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(behaviorSegmentSnapshots, id: \.title) { snapshot in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(snapshot.title)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)

                                        HStack(spacing: 6) {
                                            ForEach(snapshot.ratings, id: \.behaviorTitle) { item in
                                                VStack(spacing: 2) {
                                                    Text(item.rating.emoji)
                                                    Text(item.shortLabel)
                                                        .font(.caption2.weight(.semibold))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(width: 124, alignment: .leading)
                                    .padding(12)
                                    .classTraxCardChrome(accent: snapshot.accent, cornerRadius: 16)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    if let behaviorTrend {
                        HStack(spacing: 10) {
                            Label(behaviorTrend.title, systemImage: behaviorTrend.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(behaviorTrend.tint)

                            Spacer()

                            Text(behaviorTrendDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(12)
                        .classTraxCardChrome(accent: behaviorTrend.tint, cornerRadius: 16)
                    }

                    if !behaviorInsightAlerts.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(behaviorInsightAlerts) { alert in
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(alert.title, systemImage: "exclamationmark.triangle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(alert.tint)

                                    Text(alert.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .classTraxCardChrome(accent: alert.tint, cornerRadius: 16)
                            }
                        }
                    }

                    if let hotspotSegment {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Block hotspot", systemImage: "calendar.badge.exclamationmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)

                            Text("\(hotspotSegment.title) has \(hotspotSegment.count) needs-support ratings in the current review window.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .classTraxCardChrome(accent: .orange, cornerRadius: 16)
                    }

                    if let concernBehavior {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Behavior to watch", systemImage: "eye.trianglebadge.exclamationmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ClassTraxSemanticColor.reviewWarning)

                            Text("\(concernBehavior.behavior.title) has \(concernBehavior.count) needs-support ratings in the current review window.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .classTraxCardChrome(accent: ClassTraxSemanticColor.reviewWarning, cornerRadius: 16)
                    }

                    if commonTriggerInsight != nil || commonInterventionInsight != nil {
                        HStack(spacing: 10) {
                            if let commonTriggerInsight {
                                behaviorContextCard(
                                    title: "Common trigger",
                                    symbol: "bolt.badge.clock",
                                    detail: commonTriggerInsight.value,
                                    count: commonTriggerInsight.count,
                                    tint: .orange
                                )
                            }

                            if let commonInterventionInsight {
                                behaviorContextCard(
                                    title: "Common intervention",
                                    symbol: "wand.and.stars",
                                    detail: commonInterventionInsight.value,
                                    count: commonInterventionInsight.count,
                                    tint: ClassTraxSemanticColor.primaryAction
                                )
                            }
                        }
                    }
                }
            }

            if !filteredBehaviorLogs.isEmpty {
                Section(selectedBehaviorSectionTitle) {
                    DisclosureGroup("Recent Entries", isExpanded: $isBehaviorHistoryExpanded) {
                        ForEach(filteredBehaviorLogs.prefix(6)) { log in
                            HStack(alignment: .top, spacing: 10) {
                                Text(log.rating.emoji)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(log.behavior.title) • \(log.rating.colorLabel)")
                                        .font(.subheadline.weight(.semibold))
                                    if !log.segmentTitle.isEmpty {
                                        Text(log.segmentTitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let noteSummary = log.noteSummary {
                                        Text(noteSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                    if !log.noteContextTags.isEmpty {
                                        noteTagRow(log.noteContextTags)
                                    }
                                    Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if !studentTimelineEntries.isEmpty {
                Section("Student Timeline") {
                    DisclosureGroup("Timeline Entries", isExpanded: $isTimelineExpanded) {
                        Picker("Filter", selection: $selectedTimelineFilter) {
                            ForEach(TimelineFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)

                        if let entry = filteredTimelineEntries.first,
                           let emailURL = timelineEntryEmailURL(for: entry) {
                            Button {
                                openExternalURL(emailURL, actionName: "Email Summary")
                            } label: {
                                Label("Email Parent About Latest Event", systemImage: "envelope.badge")
                            }
                            .tint(ClassTraxSemanticColor.primaryAction)
                        }

                        if filteredTimelineEntries.isEmpty {
                            Text("No timeline entries for this filter yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredTimelineEntries.prefix(30)) { entry in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: entry.kind.symbol)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(entry.tint)
                                        .frame(width: 18, height: 18)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text(entry.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)

                                        Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }

            if onLogBehavior != nil || onLogBehaviorWithNote != nil {
                Section("Behavior Check-In") {
                    if !profile.behaviorTrackingEnabled {
                        Text("Behavior tracking is turned off for this student.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("Behavior Actions", isExpanded: $isBehaviorCheckInExpanded) {
                            if !behaviorSegments.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(behaviorSegments) { segment in
                                            Button {
                                                selectedBehaviorSegmentID = segment.id
                                            } label: {
                                                Text(segment.title)
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(isSelected(segment: segment) ? ClassTraxSemanticColor.primaryAction.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                                                    )
                                                    .foregroundStyle(isSelected(segment: segment) ? ClassTraxSemanticColor.primaryAction : .primary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            } else if !preferredBehaviorSegmentTitle.isEmpty {
                                Text(preferredBehaviorSegmentTitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(BehaviorLogItem.BehaviorKind.allCases) { behavior in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 12) {
                                        Text(behavior.title)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        HStack(spacing: 8) {
                                            ForEach(BehaviorLogItem.Rating.allCases) { rating in
                                                behaviorRatingButton(behavior: behavior, rating: rating)
                                            }
                                        }
                                    }

                                    behaviorQuickNoteField(for: behavior)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
            }

            if !supportSummaryLines.isEmpty {
                Section("Supports") {
                    ForEach(supportSummaryLines, id: \.self) { line in
                        Text(line)
                    }
                }
            }

            if !profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Accommodations") {
                    Text(profile.accommodations)
                }
            }

            if !profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Prompts") {
                    Text(profile.prompts)
                }
            }

            if !contactSummaryLines.isEmpty || !parsedParentEmails.isEmpty || !parsedParentPhones.isEmpty {
                Section("Contacts") {
                    if !parentContactActions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Quick Actions")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                ForEach(parentContactActions) { action in
                                    Button {
                                        openExternalURL(action.url, actionName: action.title)
                                    } label: {
                                        Label(action.title, systemImage: action.systemImage)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(action.tint)
                                }
                            }

                            Button {
                                copyParentNotificationDraft()
                            } label: {
                                Label("Copy Parent Update Draft", systemImage: "doc.on.doc")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(ClassTraxSemanticColor.secondaryAction)
                        }
                        .padding(.vertical, 4)
                    }

                    if !profile.parentNames.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Parent / Guardian: \(profile.parentNames.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }

                    ForEach(parsedParentPhones, id: \.self) { phone in
                        Button {
                            if let url = phoneURL(for: phone) {
                                openExternalURL(url, actionName: "Call Parent")
                            }
                        } label: {
                            Label(phone, systemImage: "phone.fill")
                        }
                        .tint(ClassTraxSemanticColor.success)
                    }

                    ForEach(parsedParentEmails, id: \.self) { email in
                        Button {
                            if let url = emailURL(for: email, subject: "Re: \(profile.name)") {
                                openExternalURL(url, actionName: "Email Parent")
                            }
                        } label: {
                            Label(email, systemImage: "envelope.fill")
                        }
                        .tint(ClassTraxSemanticColor.primaryAction)
                    }

                    if !profile.studentEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let studentEmail = profile.studentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        Button {
                            if let url = emailURL(for: studentEmail, subject: "Re: \(profile.name)") {
                                openExternalURL(url, actionName: "Email Student")
                            }
                        } label: {
                            Label("Student: \(studentEmail)", systemImage: "envelope")
                        }
                        .tint(ClassTraxSemanticColor.secondaryAction)
                    }
                }
            }

            Section("Actions") {
                Button("Edit Student") {
                    dismiss()
                    onEdit()
                }
                .tint(ClassTraxSemanticColor.primaryAction)

                Button("Open Notes") {
                    dismiss()
                    onOpenRecord()
                }
                .tint(ClassTraxSemanticColor.secondaryAction)

                Button("Open Students & Supports") {
                    dismiss()
                    onOpenStudents()
                }
                .tint(ClassTraxSemanticColor.reviewWarning)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Student Quick View")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedBehaviorSegmentID == nil {
                selectedBehaviorSegmentID = preferredBehaviorSegmentID ?? behaviorSegments.first?.id
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            "Action Unavailable",
            isPresented: Binding(
                get: { externalActionErrorMessage != nil },
                set: { if !$0 { externalActionErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { externalActionErrorMessage = nil }
            },
            message: {
                Text(externalActionErrorMessage ?? "")
            }
        )
    }

    private struct ParentContactAction: Identifiable {
        let id: String
        let title: String
        let systemImage: String
        let tint: Color
        let url: URL
    }

    private var linkedGroupCount: Int {
        max(linkedClassesOrGroups.count, profile.classDefinitionIDs.isEmpty ? 0 : profile.classDefinitionIDs.count)
    }

    private var latestBehaviorLog: BehaviorLogItem? {
        filteredBehaviorLogs.sorted { $0.timestamp > $1.timestamp }.first
    }

    private var studentAttendanceRecords: [AttendanceRecord] {
        attendanceRecords.filter { record in
            guard record.isAttendanceEntry else { return false }
            if let studentID = record.studentID {
                return studentID == profile.id
            }
            return record.studentName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(profile.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }

    private var linkedClassDefinitionIDs: Set<UUID> {
        Set(profile.classDefinitionIDs + (profile.classDefinitionID.map { [$0] } ?? []))
    }

    private var classNoteTimelineRecords: [AttendanceRecord] {
        attendanceRecords.filter { record in
            guard record.isClassHomeworkNote else { return false }
            let note = record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty else { return false }

            if let classDefinitionID = record.classDefinitionID {
                return linkedClassDefinitionIDs.contains(classDefinitionID)
            }

            let recordClass = record.className.trimmingCharacters(in: .whitespacesAndNewlines)
            let profileClass = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !recordClass.isEmpty, !profileClass.isEmpty else { return false }
            return recordClass.caseInsensitiveCompare(profileClass) == .orderedSame
        }
    }

    private var studentTimelineEntries: [StudentTimelineEntry] {
        var entries: [StudentTimelineEntry] = []

        for record in studentAttendanceRecords {
            let timestamp = timelineDate(for: record)
            let classLabel = sanitizedTimelineText(record.className)
            let attendanceDetail = classLabel.isEmpty ? record.status.rawValue : "\(record.status.rawValue) • \(classLabel)"
            let attendanceTint: Color = record.status == .present ? ClassTraxSemanticColor.success : ClassTraxSemanticColor.reviewWarning

            entries.append(
                StudentTimelineEntry(
                    id: "attendance-\(record.id.uuidString)",
                    timestamp: timestamp,
                    kind: .attendance,
                    title: "Attendance",
                    detail: attendanceDetail,
                    tint: attendanceTint
                )
            )

            let assignedWork = record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
            if !assignedWork.isEmpty {
                entries.append(
                    StudentTimelineEntry(
                        id: "assigned-\(record.id.uuidString)",
                        timestamp: timestamp,
                        kind: .assignedWork,
                        title: "Assigned Work",
                        detail: assignedWork,
                        tint: ClassTraxSemanticColor.primaryAction
                    )
                )
            }

            let missingWork = record.absentHomework.trimmingCharacters(in: .whitespacesAndNewlines)
            if !missingWork.isEmpty {
                entries.append(
                    StudentTimelineEntry(
                        id: "missing-\(record.id.uuidString)",
                        timestamp: timestamp,
                        kind: .missingWork,
                        title: "Missing Work",
                        detail: missingWork,
                        tint: ClassTraxSemanticColor.reviewWarning
                    )
                )
            }
        }

        for record in classNoteTimelineRecords {
            let classLabel = sanitizedTimelineText(record.className)
            let note = record.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
            let detail = classLabel.isEmpty ? note : "\(classLabel): \(note)"

            entries.append(
                StudentTimelineEntry(
                    id: "class-note-\(record.id.uuidString)",
                    timestamp: timelineDate(for: record),
                    kind: .classNote,
                    title: "Class Note",
                    detail: detail,
                    tint: ClassTraxSemanticColor.secondaryAction
                )
            )
        }

        for log in behaviorLogs {
            let segment = log.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = segment.isEmpty
                ? "\(log.behavior.title) • \(log.rating.colorLabel)"
                : "\(log.behavior.title) • \(log.rating.colorLabel) • \(segment)"
            let detail = log.noteSummary ?? "Behavior check-in"

            entries.append(
                StudentTimelineEntry(
                    id: "behavior-\(log.id.uuidString)",
                    timestamp: log.timestamp,
                    kind: .behavior,
                    title: title,
                    detail: detail,
                    tint: log.rating.tint
                )
            )
        }

        return entries
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var filteredTimelineEntries: [StudentTimelineEntry] {
        switch selectedTimelineFilter {
        case .all:
            return studentTimelineEntries
        case .attendance:
            return studentTimelineEntries.filter { $0.kind == .attendance }
        case .behavior:
            return studentTimelineEntries.filter { $0.kind == .behavior }
        case .work:
            return studentTimelineEntries.filter { $0.kind == .assignedWork || $0.kind == .missingWork }
        case .notes:
            return studentTimelineEntries.filter { $0.kind == .classNote }
        }
    }

    private var weeklyAttendanceSummary: String {
        attendanceSummary(for: studentAttendanceRecords.filter { currentWeekDateKeys.contains($0.dateKey) })
    }

    private var monthlyAttendanceSummary: String {
        attendanceSummary(for: studentAttendanceRecords.filter { currentMonthDateKeys.contains($0.dateKey) })
    }

    private var weeklyNeedsSupportCount: Int {
        behaviorLogs.filter {
            currentWeekDateKeys.contains(AttendanceRecord.dateKey(for: $0.timestamp)) &&
            $0.rating == .needsSupport
        }.count
    }

    private var monthlyNeedsSupportCount: Int {
        behaviorLogs.filter {
            currentMonthDateKeys.contains(AttendanceRecord.dateKey(for: $0.timestamp)) &&
            $0.rating == .needsSupport
        }.count
    }

    private var currentWeekDateKeys: Set<String> {
        AttendanceRecord.currentWeekDateKeys(containing: Date())
    }

    private var currentMonthDateKeys: Set<String> {
        let calendar = Calendar.current
        let now = Date()
        let interval = calendar.dateInterval(of: .month, for: now)
        let start = interval?.start ?? now
        let end = interval?.end ?? now
        var dateKeys = Set<String>()
        var current = start

        while current < end {
            dateKeys.insert(AttendanceRecord.dateKey(for: current))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dateKeys
    }

    private var parentContactActions: [ParentContactAction] {
        var actions: [ParentContactAction] = []

        if let primaryPhone = parsedParentPhones.first, let messageURL = messageURL(for: primaryPhone) {
            actions.append(
                ParentContactAction(
                    id: "message-parent",
                    title: "Message Parent",
                    systemImage: "message.fill",
                    tint: ClassTraxSemanticColor.success,
                    url: messageURL
                )
            )
        }

        if let summaryURL = parentSummaryEmailURL {
            actions.append(
                ParentContactAction(
                    id: "email-summary",
                    title: "Email Summary",
                    systemImage: "envelope.badge.fill",
                    tint: ClassTraxSemanticColor.primaryAction,
                    url: summaryURL
                )
            )
        } else if let primaryEmail = parsedParentEmails.first,
                  let emailURL = emailURL(for: primaryEmail, subject: "Re: \(profile.name)") {
            actions.append(
                ParentContactAction(
                    id: "email-parent",
                    title: "Email Parent",
                    systemImage: "envelope.fill",
                    tint: ClassTraxSemanticColor.primaryAction,
                    url: emailURL
                )
            )
        }

        return actions
    }

    private func isSelected(behavior: BehaviorLogItem.BehaviorKind, rating: BehaviorLogItem.Rating) -> Bool {
        todayBehaviorLog(for: behavior)?.rating == rating
    }

    @ViewBuilder
    private func behaviorRatingButton(behavior: BehaviorLogItem.BehaviorKind, rating: BehaviorLogItem.Rating) -> some View {
        let selected = isSelected(behavior: behavior, rating: rating)
        let fillOpacity: Double = selected ? 0.22 : 0.12
        let strokeOpacity: Double = selected ? 0.9 : 0.35
        let strokeWidth: CGFloat = selected ? 1.4 : 1
        Button {
            let note = behaviorQuickNote(for: behavior)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let onLogBehaviorWithNote, !note.isEmpty {
                onLogBehaviorWithNote(behavior, rating, resolvedBehaviorClassDefinitionID, note, Date())
            } else {
                onLogBehavior?(behavior, rating, resolvedBehaviorClassDefinitionID)
            }
        } label: {
            Text(rating.emoji)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(rating.tint.opacity(fillOpacity))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(rating.tint.opacity(strokeOpacity), lineWidth: strokeWidth)
                )
                .foregroundStyle(rating.tint)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func behaviorQuickNoteField(for behavior: BehaviorLogItem.BehaviorKind) -> some View {
        let segmentTitle = selectedBehaviorSegmentTitle
        let placeholder = segmentTitle.isEmpty ? "Note for this class" : "Note for \(segmentTitle)"
        let noteBinding = behaviorQuickNoteBinding(for: behavior)

        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickBehaviorTemplates(for: behavior), id: \.self) { template in
                        Button {
                            noteBinding.wrappedValue = template
                        } label: {
                            Text(template)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(ClassTraxSemanticColor.primaryAction.opacity(0.12))
                                )
                                .foregroundStyle(ClassTraxSemanticColor.primaryAction)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }

            TextField(placeholder, text: noteBinding, axis: .vertical)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    private func quickBehaviorTemplates(for behavior: BehaviorLogItem.BehaviorKind) -> [String] {
        let customTemplates = profile.behaviorTemplateOverrides[behavior.rawValue]?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        if !customTemplates.isEmpty {
            return customTemplates
        }

        switch behavior {
        case .onTask:
            return [
                "Stayed focused and followed directions.",
                "Independent work completed.",
                "Returned to task after reminder."
            ]
        case .respectful:
            return [
                "Used respectful language with peers.",
                "Handled feedback calmly.",
                "Needed reminder about respectful tone."
            ]
        case .safeBody:
            return [
                "Kept hands and body safe.",
                "Needed movement break to reset.",
                "Safety reminder given and followed."
            ]
        }
    }

    private func todayBehaviorLog(for behavior: BehaviorLogItem.BehaviorKind) -> BehaviorLogItem? {
        filteredBehaviorLogs.first(where: { $0.behavior == behavior })
    }

    private var filteredBehaviorLogs: [BehaviorLogItem] {
        let title = selectedBehaviorSegmentTitle
        guard !title.isEmpty else { return windowFilteredBehaviorLogs }
        return windowFilteredBehaviorLogs.filter { normalizedSegmentTitle($0.segmentTitle) == normalizedSegmentTitle(title) }
    }

    private var selectedBehaviorSegmentTitle: String {
        if let segment = behaviorSegments.first(where: { $0.id == selectedBehaviorSegmentID }) {
            return segment.title
        }
        return preferredBehaviorSegmentTitle
    }

    private var selectedBehaviorSectionTitle: String {
        let title = selectedBehaviorSegmentTitle
        let suffix = selectedBehaviorWindow == .today ? "Today" : "This Week"
        return title.isEmpty ? "Behavior \(suffix)" : "Behavior • \(title) \(suffix)"
    }

    private var resolvedBehaviorClassDefinitionID: UUID? {
        selectedBehaviorSegmentID ?? preferredBehaviorSegmentID ?? profile.classDefinitionID
    }

    private func behaviorQuickNoteKey(for behavior: BehaviorLogItem.BehaviorKind) -> String {
        let contextKey = resolvedBehaviorClassDefinitionID?.uuidString ?? "default"
        return "\(contextKey)|\(behavior.rawValue)"
    }

    private func behaviorQuickNote(for behavior: BehaviorLogItem.BehaviorKind) -> String {
        let key = behaviorQuickNoteKey(for: behavior)
        if let draft = behaviorQuickNoteDrafts[key] {
            return draft
        }

        guard
            let classDefinitionID = resolvedBehaviorClassDefinitionID,
            let context = classContext(for: profile, classDefinitionID: classDefinitionID)
        else {
            return ""
        }

        return context.behaviorQuickNotes[behavior.rawValue] ?? ""
    }

    private func behaviorQuickNoteBinding(for behavior: BehaviorLogItem.BehaviorKind) -> Binding<String> {
        Binding(
            get: { behaviorQuickNote(for: behavior) },
            set: { newValue in
                behaviorQuickNoteDrafts[behaviorQuickNoteKey(for: behavior)] = newValue
                onSaveBehaviorQuickNote?(resolvedBehaviorClassDefinitionID, behavior, newValue)
            }
        )
    }

    private func isSelected(segment: BehaviorSegmentOption) -> Bool {
        segment.id == selectedBehaviorSegmentID
    }

    private func normalizedSegmentTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var positiveBehaviorCount: Int {
        windowFilteredBehaviorLogs.filter { $0.rating == .onTask }.count
    }

    private var neutralBehaviorCount: Int {
        windowFilteredBehaviorLogs.filter { $0.rating == .neutral }.count
    }

    private var needsSupportBehaviorCount: Int {
        windowFilteredBehaviorLogs.filter { $0.rating == .needsSupport }.count
    }

    private var behaviorTrend: BehaviorTrend? {
        let logs = windowFilteredBehaviorLogs.sorted { $0.timestamp < $1.timestamp }
        guard logs.count >= 3 else { return nil }

        let midpoint = logs.count / 2
        guard midpoint > 0, midpoint < logs.count else { return nil }

        let earlier = Array(logs.prefix(midpoint))
        let later = Array(logs.suffix(logs.count - midpoint))
        let delta = averageBehaviorScore(for: later) - averageBehaviorScore(for: earlier)

        if delta >= 0.35 {
            return .improving
        }
        if delta <= -0.35 {
            return .declining
        }
        return .steady
    }

    private var behaviorTrendDetail: String {
        let rangeLabel = selectedBehaviorWindow == .today ? "today" : "this week"
        return "\(windowFilteredBehaviorLogs.count) entries tracked \(rangeLabel)"
    }

    private var behaviorInsightAlerts: [BehaviorInsightAlert] {
        var alerts: [BehaviorInsightAlert] = []
        let chronologicalLogs = windowFilteredBehaviorLogs.sorted { $0.timestamp > $1.timestamp }

        if hasThreeConsecutiveNeedsSupport(in: chronologicalLogs) {
            alerts.append(
                BehaviorInsightAlert(
                    id: "consecutive-needs-support",
                    title: "Repeated support concern",
                    detail: "There are 3 consecutive needs-support ratings in the current review window.",
                    tint: ClassTraxSemanticColor.reviewWarning
                )
            )
        }

        if let repeatedSegment = repeatedNeedsSupportSegment(in: windowFilteredBehaviorLogs) {
            alerts.append(
                BehaviorInsightAlert(
                    id: "repeated-segment-\(repeatedSegment.title)",
                    title: "Repeated issue in \(repeatedSegment.title)",
                    detail: "\(repeatedSegment.count) needs-support ratings were logged in this block during the current review window.",
                    tint: .orange
                )
            )
        }

        return alerts
    }

    private var hotspotSegment: (title: String, count: Int)? {
        repeatedNeedsSupportSegment(in: windowFilteredBehaviorLogs)
    }

    private var concernBehavior: (behavior: BehaviorLogItem.BehaviorKind, count: Int)? {
        let grouped = Dictionary(grouping: windowFilteredBehaviorLogs.filter { $0.rating == .needsSupport }, by: \.behavior)

        return grouped
            .compactMap { behavior, logs in
                logs.count >= 2 ? (behavior: behavior, count: logs.count) : nil
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.behavior.title.localizedCaseInsensitiveCompare(rhs.behavior.title) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
            .first
    }

    private var commonTriggerInsight: BehaviorContextInsight? {
        mostCommonBehaviorContext(from: windowFilteredBehaviorLogs.compactMap(\.triggerSummary))
    }

    private var commonInterventionInsight: BehaviorContextInsight? {
        mostCommonBehaviorContext(from: windowFilteredBehaviorLogs.compactMap(\.interventionSummary))
    }

    private var behaviorSegmentSnapshots: [BehaviorSegmentSnapshot] {
        let groupedLogs = Dictionary(grouping: windowFilteredBehaviorLogs) { normalizedSegmentTitle($0.segmentTitle) }
        var snapshots: [BehaviorSegmentSnapshot] = []

        for logs in groupedLogs.values {
            guard let firstLog = logs.first else { continue }

            let ratings: [BehaviorSnapshotRating] = BehaviorLogItem.BehaviorKind.allCases.compactMap { behavior in
                guard let matchingLog = logs.first(where: { $0.behavior == behavior }) else { return nil }
                return BehaviorSnapshotRating(
                    behaviorTitle: behavior.title,
                    shortLabel: shortBehaviorLabel(for: behavior),
                    rating: matchingLog.rating
                )
            }

            guard !ratings.isEmpty else { continue }

            snapshots.append(
                BehaviorSegmentSnapshot(
                    title: firstLog.segmentTitle.isEmpty ? "General" : firstLog.segmentTitle,
                    ratings: ratings,
                    accent: accentColor(for: logs)
                )
            )
        }

        return snapshots.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var windowFilteredBehaviorLogs: [BehaviorLogItem] {
        switch selectedBehaviorWindow {
        case .today:
            return behaviorLogs.filter { Calendar.current.isDateInToday($0.timestamp) }
        case .week:
            let calendar = Calendar.current
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
                return behaviorLogs
            }
            return behaviorLogs.filter { weekInterval.contains($0.timestamp) }
        }
    }

    private func shortBehaviorLabel(for behavior: BehaviorLogItem.BehaviorKind) -> String {
        switch behavior {
        case .onTask:
            return "OT"
        case .respectful:
            return "R"
        case .safeBody:
            return "SB"
        }
    }

    private func accentColor(for logs: [BehaviorLogItem]) -> Color {
        if logs.contains(where: { $0.rating == .needsSupport }) {
            return ClassTraxSemanticColor.reviewWarning
        }
        if logs.contains(where: { $0.rating == .neutral }) {
            return ClassTraxSemanticColor.secondaryAction
        }
        return ClassTraxSemanticColor.success
    }

    private func averageBehaviorScore(for logs: [BehaviorLogItem]) -> Double {
        guard !logs.isEmpty else { return 0 }
        let total = logs.reduce(into: 0) { partialResult, log in
            partialResult += behaviorScore(for: log.rating)
        }
        return Double(total) / Double(logs.count)
    }

    private func behaviorScore(for rating: BehaviorLogItem.Rating) -> Int {
        switch rating {
        case .onTask:
            return 3
        case .neutral:
            return 2
        case .needsSupport:
            return 1
        }
    }

    private func hasThreeConsecutiveNeedsSupport(in logs: [BehaviorLogItem]) -> Bool {
        var streak = 0

        for log in logs {
            if log.rating == .needsSupport {
                streak += 1
                if streak >= 3 {
                    return true
                }
            } else {
                streak = 0
            }
        }

        return false
    }

    private func repeatedNeedsSupportSegment(in logs: [BehaviorLogItem]) -> (title: String, count: Int)? {
        let grouped = Dictionary(grouping: logs.filter { $0.rating == .needsSupport }) { log in
            let trimmed = log.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "General" : trimmed
        }

        return grouped
            .compactMap { key, value in
                value.count >= 2 ? (title: key, count: value.count) : nil
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
            .first
    }

    private func mostCommonBehaviorContext(from values: [String]) -> BehaviorContextInsight? {
        let grouped = Dictionary(grouping: values.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }, by: \.self)

        return grouped
            .compactMap { value, matches in
                matches.count >= 2 ? BehaviorContextInsight(value: value, count: matches.count) : nil
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
            .first
    }

    private struct BehaviorSegmentSnapshot {
        let title: String
        let ratings: [BehaviorSnapshotRating]
        let accent: Color
    }

    private struct BehaviorContextInsight {
        let value: String
        let count: Int
    }

    private struct BehaviorSnapshotRating {
        let behaviorTitle: String
        let shortLabel: String
        let rating: BehaviorLogItem.Rating
    }

    @ViewBuilder
    private func noteTagRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.secondarySystemFill))
                        )
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func behaviorContextCard(
        title: String,
        symbol: String,
        detail: String,
        count: Int,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text("\(count)x in current review window")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .classTraxCardChrome(accent: tint, cornerRadius: 16)
    }

    private var primaryClassOrGroupLabel: String {
        if let first = linkedClassesOrGroups.first {
            return first
        }
        let className = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        return className.isEmpty ? "No class or group linked yet" : className
    }

    private var linkedClassesOrGroups: [String] {
        let namesFromDefinitions = classDefinitions
            .filter { profile.classDefinitionIDs.contains($0.id) || profile.classDefinitionID == $0.id }
            .map(\.displayName)
        if !namesFromDefinitions.isEmpty {
            return namesFromDefinitions.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }

        let className = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        return className.isEmpty ? [] : [className]
    }

    private var resolvedTeacherNames: [String] {
        teacherContacts
            .filter { profile.supportTeacherIDs.contains($0.id) }
            .map(\.trimmedName)
            .filter { !$0.isEmpty }
    }

    private var resolvedParaNames: [String] {
        paraContacts
            .filter { profile.supportParaIDs.contains($0.id) }
            .map(\.trimmedName)
            .filter { !$0.isEmpty }
    }

    private var supportSummaryLines: [String] {
        var lines: [String] = []
        if !resolvedTeacherNames.isEmpty {
            lines.append("Teachers: \(resolvedTeacherNames.joined(separator: ", "))")
        }
        if !resolvedParaNames.isEmpty {
            lines.append("Paras: \(resolvedParaNames.joined(separator: ", "))")
        }
        let rooms = profile.supportRooms.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rooms.isEmpty {
            lines.append("Support Rooms: \(rooms)")
        }
        let scheduleNotes = profile.supportScheduleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scheduleNotes.isEmpty {
            lines.append("Support Schedule: \(scheduleNotes)")
        }
        return lines
    }

    private var contactSummaryLines: [String] {
        [
            labeledLine("Parent / Guardian", profile.parentNames),
            labeledLine("Parent Phone", profile.parentPhoneNumbers),
            labeledLine("Parent Email", profile.parentEmails),
            labeledLine("Student Email", profile.studentEmail)
        ].compactMap { $0 }
    }

    private var parsedParentEmails: [String] {
        profile.parentEmails
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var parsedParentPhones: [String] {
        profile.parentPhoneNumbers
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var parentSummaryEmailURL: URL? {
        guard !parsedParentEmails.isEmpty else { return nil }

        let subject = "ClassTrax Summary for \(profile.name)"
        let body = parentSummaryEmailBody
        let recipients = parsedParentEmails.joined(separator: ",")
        return emailURL(for: recipients, subject: subject, body: body)
    }

    private var parentSummaryEmailBody: String {
        var lines = ["Hello,", "", "Here is a quick summary for \(profile.name):"]

        let classLabel = primaryClassOrGroupLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !classLabel.isEmpty {
            lines.append("- Class / Group: \(classLabel)")
        }

        let gradeLabel = GradeLevelOption.normalized(profile.gradeLevel)
        if !gradeLabel.isEmpty {
            lines.append("- Grade: \(gradeLabel)")
        }

        if let latestBehaviorLog {
            let segment = latestBehaviorLog.segmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let segmentSuffix = segment.isEmpty ? "" : " during \(segment)"
            lines.append("- Latest behavior check-in: \(latestBehaviorLog.behavior.title) was marked \(latestBehaviorLog.rating.title.lowercased())\(segmentSuffix).")
            if let noteSummary = latestBehaviorLog.noteSummary {
                lines.append("- Recent note: \(noteSummary)")
            }
        }

        let supports = supportSummaryLines
        if !supports.isEmpty {
            lines.append("- Supports: \(supports.joined(separator: " | "))")
        }

        if !profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Accommodations: \(profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if !profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Prompts: \(profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        lines.append("")
        lines.append("Thank you,")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private var parentNotificationDraftBody: String {
        var lines = ["Class update for \(profile.name):"]

        if let latestBehaviorLog {
            lines.append("Behavior: \(latestBehaviorLog.behavior.title) • \(latestBehaviorLog.rating.title)")
        }

        let weekAttendance = weeklyAttendanceSummary
        if weekAttendance != "No Data" {
            lines.append("Week attendance: \(weekAttendance)")
        }

        if let latestClassNote = classNoteTimelineRecords.sorted(by: { timelineDate(for: $0) > timelineDate(for: $1) }).first {
            let note = latestClassNote.assignedHomework.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                lines.append("Class note: \(note)")
            }
        }

        lines.append("Sent from ClassTrax")
        return lines.joined(separator: "\n")
    }

    private func copyParentNotificationDraft() {
        copyTextToClipboard(parentNotificationDraftBody)
    }

    private func timelineEntryEmailURL(for entry: StudentTimelineEntry) -> URL? {
        guard !parsedParentEmails.isEmpty else { return nil }
        let recipients = parsedParentEmails.joined(separator: ",")
        let subject = "ClassTrax Update for \(profile.name)"
        let body = [
            "Hello,",
            "",
            "Quick update for \(profile.name):",
            "- \(entry.title)",
            "- \(entry.detail)",
            "- \(entry.timestamp.formatted(date: .abbreviated, time: .shortened))",
            "",
            "Generated from ClassTrax."
        ].joined(separator: "\n")
        return emailURL(for: recipients, subject: subject, body: body)
    }

    private func phoneURL(for phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    private func messageURL(for phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "sms:\(digits)")
    }

    private func emailURL(for recipient: String, subject: String, body: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient

        var queryItems = [URLQueryItem(name: "subject", value: subject)]
        if let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: body))
        }
        components.queryItems = queryItems
        return components.url
    }

    private func openExternalURL(_ url: URL, actionName: String) {
        openURL(url) { accepted in
            guard !accepted else { return }
            externalActionErrorMessage = "\(actionName) could not be opened. Check that a default mail or messaging app is configured on this device."
        }
    }

    private func copyTextToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func attendanceSummary(for records: [AttendanceRecord]) -> String {
        let attendanceOnly = records.filter(\.isAttendanceEntry)
        guard !attendanceOnly.isEmpty else { return "No Data" }
        let presentCount = attendanceOnly.filter { $0.status == .present }.count
        return "\(presentCount)/\(attendanceOnly.count)"
    }

    private func timelineDate(for record: AttendanceRecord) -> Date {
        if let blockStart = record.blockStartTime {
            return blockStart
        }

        if let date = dateFromDateKey(record.dateKey) {
            return date
        }

        return Date.distantPast
    }

    private func dateFromDateKey(_ dateKey: String) -> Date? {
        let trimmed = dateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "\(label): \(trimmed)"
    }

    private func sanitizedTimelineText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized.contains("nsmanagedobject") || normalized.contains("managedobject") {
            return ""
        }

        return trimmed
    }

    private func quickMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}
