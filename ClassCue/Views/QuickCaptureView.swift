//
//  QuickCaptureView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import SwiftUI
import SwiftData

struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext

    enum CapturePreset: String, CaseIterable, Identifiable {
        case planner
        case missingWork
        case studentIssue
        case parentContact

        var id: String { rawValue }

        var title: String {
            switch self {
            case .planner: return "Planner"
            case .missingWork: return "Missing Work"
            case .studentIssue: return "Student Issue"
            case .parentContact: return "Parent Contact"
            }
        }

        var systemImage: String {
            switch self {
            case .planner: return "checklist"
            case .missingWork: return "text.book.closed"
            case .studentIssue: return "person.fill.questionmark"
            case .parentContact: return "phone.fill"
            }
        }

        var tint: Color {
            switch self {
            case .planner: return .orange
            case .missingWork: return .teal
            case .studentIssue: return .indigo
            case .parentContact: return .pink
            }
        }
    }


    enum CaptureTarget: String, CaseIterable {
        case task
        case note

        var title: String {
            switch self {
            case .task: return "Planner Item"
            case .note: return "Note"
            }
        }
    }

    enum NoteDestination: String, CaseIterable {
        case general
        case personal
        case classFollowUp
        case studentFollowUp
        case parentContact

        var title: String {
            switch self {
            case .general: return "General Note"
            case .personal: return "Personal Note"
            case .classFollowUp: return "Class Follow-Up"
            case .studentFollowUp: return "Student Follow-Up"
            case .parentContact: return "Parent Contact"
            }
        }
    }

    @Binding var todos: [TodoItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    let preferredContext: String?
    let preferredCategory: TodoItem.Category?
    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("personal_notes_v1") private var personalNotesText: String = ""
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0
    @AppStorage("school_default_personal_capture_after_hours") private var defaultPersonalCaptureAfterHours = true
    @AppStorage("quick_capture_draft_v1") private var savedDraftData: Data = Data()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var target: CaptureTarget = .task
    @State private var text = ""
    @State private var category: TodoItem.Category = .prep
    @State private var workspace: TodoItem.Workspace = .school
    @State private var linkedContext = ""
    @State private var studentOrGroup = ""
    @State private var followUpNote = ""
    @State private var reminder = TodoItem.Reminder.none
    @State private var noteDestination: NoteDestination = .general

    private struct Draft: Codable, Equatable {
        var targetRawValue: String
        var text: String
        var categoryRawValue: String
        var workspaceRawValue: String
        var linkedContext: String
        var studentOrGroup: String
        var followUpNote: String
        var reminderRawValue: String
        var noteDestinationRawValue: String
    }

    init(
        todos: Binding<[TodoItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        studentSupportsByName: [String: StudentSupportProfile] = [:],
        preferredContext: String? = nil,
        preferredCategory: TodoItem.Category? = nil
    ) {
        _todos = todos
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.studentSupportsByName = studentSupportsByName
        self.preferredContext = preferredContext
        self.preferredCategory = preferredCategory
        _category = State(initialValue: preferredCategory ?? .prep)
        _linkedContext = State(initialValue: preferredContext ?? "")
        let usePersonalDefault = QuickCaptureView.shouldDefaultToPersonalCapture(
            schoolQuietHoursEnabled: UserDefaults.standard.bool(forKey: "school_quiet_hours_enabled"),
            schoolQuietHour: UserDefaults.standard.object(forKey: "school_quiet_hour") as? Int ?? 16,
            schoolQuietMinute: UserDefaults.standard.object(forKey: "school_quiet_minute") as? Int ?? 0,
            defaultPersonalCaptureAfterHours: UserDefaults.standard.object(forKey: "school_default_personal_capture_after_hours") as? Bool ?? true,
            now: Date()
        )
        _workspace = State(initialValue: usePersonalDefault ? .personal : .school)
        _noteDestination = State(initialValue: usePersonalDefault ? .personal : .general)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Capture", selection: $target) {
                        ForEach(CaptureTarget.allCases, id: \.self) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Start With") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CapturePreset.allCases) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    Label(preset.title, systemImage: preset.systemImage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(preset.tint)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(preset.tint.opacity(0.12))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section(target == .task ? "Planner Item" : "Note") {
                    TextField(
                        target == .task ? "What needs to happen?" : "Quick note",
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: workspace.systemImage)
                            .font(.headline)
                            .foregroundStyle(workspace.tint)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(captureStatusTitle)
                                .font(.subheadline.weight(.semibold))

                            Text(captureStatusSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if target == .task {
                    Section("Teacher Focus") {
                        Picker("Workspace", selection: $workspace) {
                            ForEach(TodoItem.Workspace.allCases, id: \.self) { workspace in
                                Label(workspace.displayName, systemImage: workspace.systemImage)
                                    .tag(workspace)
                            }
                        }

                        Picker("Category", selection: $category) {
                            ForEach(TodoItem.Category.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.systemImage)
                                    .tag(category)
                            }
                        }

                        if !suggestedContexts.isEmpty {
                            Picker("Class / Commitment Link", selection: $linkedContext) {
                                Text("None").tag("")
                                if let preferredContext, !preferredContext.isEmpty {
                                    Text("Current Focus: \(preferredContext)").tag(preferredContext)
                                }
                                ForEach(suggestedContexts, id: \.self) { context in
                                    Text(context).tag(context)
                                }
                            }
                        } else {
                            Text("No saved class links yet.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if !suggestedStudents.isEmpty {
                            Picker("Student / Group Link", selection: $studentOrGroup) {
                                Text("None").tag("")
                                ForEach(suggestedStudents, id: \.self) { student in
                                    Text(student).tag(student)
                                }
                            }
                        } else {
                            Text("Add names in Settings > Student Directory to reuse them here.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if let support = studentSupport {
                            supportPreview(support)
                        }

                        TextField("Follow-Up Note (Optional)", text: $followUpNote, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("Reminder") {
                        Picker("When to Re-surface", selection: $reminder) {
                            ForEach(TodoItem.Reminder.allCases, id: \.self) { option in
                                Label(option.displayName, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                    }

                    Section("Save To") {
                        Button(workspace == .school ? "Use During School" : "Do Today") {
                            saveTask(bucket: .today, reminder: reminder)
                        }

                        Button(workspace == .school ? "After School Reset" : "Tonight") {
                            saveTask(bucket: .today, reminder: .afterSchool)
                        }

                        Button("Tomorrow Morning") {
                            saveTask(bucket: .tomorrow, reminder: .tomorrowMorning)
                        }

                        Button("This Week") {
                            saveTask(bucket: .thisWeek, reminder: reminder)
                        }

                        Button("Later") {
                            saveTask(bucket: .later, reminder: reminder)
                        }
                    }
                } else {
                    Section("Route Note") {
                        Picker("Destination", selection: $noteDestination) {
                            ForEach(NoteDestination.allCases, id: \.self) { destination in
                                Text(destination.title).tag(destination)
                            }
                        }

                        TextField("Class or Commitment (Optional)", text: $linkedContext)
                        TextField("Student or Group (Optional)", text: $studentOrGroup)

                        if !suggestedStudents.isEmpty {
                            Picker("Saved Student / Group", selection: $studentOrGroup) {
                                Text("None").tag("")
                                ForEach(suggestedStudents, id: \.self) { student in
                                    Text(student).tag(student)
                                }
                            }
                        } else {
                            Text("Add names in Settings > Student Directory to reuse them here.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        if let support = studentSupport {
                            supportPreview(support)
                        }
                    }

                    Section {
                        Button("Add Note") {
                            saveNote()
                        }
                    }
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        clearDraft()
                        dismiss()
                    }
                }
            }
            .onAppear {
                restoreDraftIfNeeded()
            }
            .onChange(of: currentDraft) { _, _ in
                persistDraft()
            }
            .onChange(of: workspace) { _, newWorkspace in
                syncRoutingForWorkspace(newWorkspace)
            }
            .onChange(of: target) { _, _ in
                syncRoutingForWorkspace(workspace)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    persistDraft()
                }
            }
        }
    }

    private func saveTask(bucket: TodoItem.Bucket, reminder: TodoItem.Reminder) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        todos.insert(
            TodoItem(
                task: trimmed,
                priority: .med,
                category: category,
                bucket: bucket,
                workspace: workspace,
                linkedContext: linkedContext.trimmingCharacters(in: .whitespacesAndNewlines),
                studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                followUpNote: followUpNote.trimmingCharacters(in: .whitespacesAndNewlines),
                reminder: reminder
            ),
            at: 0
        )

        clearDraft()
        dismiss()
    }

    private func applyPreset(_ preset: CapturePreset) {
        switch preset {
        case .planner:
            target = .task
            workspace = .school
            category = preferredCategory ?? .prep
            reminder = .none
            if linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                linkedContext = preferredContext ?? linkedContext
            }
        case .missingWork:
            target = .note
            workspace = .school
            noteDestination = .classFollowUp
            if linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                linkedContext = preferredContext ?? linkedContext
            }
        case .studentIssue:
            target = .note
            workspace = .school
            noteDestination = .studentFollowUp
            category = .classroom
        case .parentContact:
            target = .note
            workspace = .school
            noteDestination = .parentContact
            category = .parentContact
        }
    }

    private func saveNote() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var notes = decodeFollowUpNotes()
        notes.insert(
            FollowUpNoteItem(
                kind: structuredKindForDestination(),
                context: linkedContext.trimmingCharacters(in: .whitespacesAndNewlines),
                studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                note: trimmed
            ),
            at: 0
        )
        saveFollowUpNotes(notes)

        clearDraft()
        dismiss()
    }

    private func structuredKindForDestination() -> FollowUpNoteItem.Kind {
        switch noteDestination {
        case .general:
            return .generalNote
        case .personal:
            return .personalNote
        case .classFollowUp:
            return .classNote
        case .studentFollowUp:
            return .studentNote
        case .parentContact:
            return .parentContact
        }
    }

    private static func shouldDefaultToPersonalCapture(
        schoolQuietHoursEnabled: Bool,
        schoolQuietHour: Int,
        schoolQuietMinute: Int,
        defaultPersonalCaptureAfterHours: Bool,
        now: Date
    ) -> Bool {
        guard schoolQuietHoursEnabled, defaultPersonalCaptureAfterHours else { return false }
        let calendar = Calendar.current
        let start = calendar.date(
            bySettingHour: schoolQuietHour,
            minute: schoolQuietMinute,
            second: 0,
            of: now
        ) ?? now
        return now >= start
    }

    private var captureStatusTitle: String {
        switch (target, workspace) {
        case (.task, .school):
            return "School planner capture"
        case (.task, .personal):
            return "Personal planner capture"
        case (.note, .school):
            return "School note capture"
        case (.note, .personal):
            return "Personal note capture"
        }
    }

    private var captureStatusSummary: String {
        var parts: [String] = []

        if let preferredContext, !preferredContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, linkedContext.isEmpty {
            parts.append("Current focus: \(preferredContext)")
        } else if !linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(linkedContext.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if !studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if target == .note {
            parts.append(noteDestination.title)
        } else if reminder != .none {
            parts.append(reminder.displayName)
        } else {
            parts.append(category.displayName)
        }

        if parts.isEmpty {
            return workspace == .school
                ? "Keep this tied to your school-day workflow."
                : "Keep this out of the school stream."
        }

        return parts.joined(separator: " • ")
    }

    private func decodeFollowUpNotes() -> [FollowUpNoteItem] {
        ClassTraxPersistence.loadFollowUpNotes(from: modelContext)
    }

    private func saveFollowUpNotes(_ notes: [FollowUpNoteItem]) {
        ClassTraxPersistence.saveFollowUpNotes(notes, into: modelContext)
        savedFollowUpNotes = (try? JSONEncoder().encode(notes)) ?? Data()
        syncLegacyNoteTextStorage(from: notes, schoolNotesText: &notesText, personalNotesText: &personalNotesText)
    }

    private var studentSupport: StudentSupportProfile? {
        studentSupportsByName[studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    @ViewBuilder
    private func supportPreview(_ support: StudentSupportProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved Support")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            let summary = [support.className, support.gradeLevel]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")

            if !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !support.accommodations.isEmpty {
                Text(support.accommodations)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if !support.prompts.isEmpty {
                Text(support.prompts)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var currentDraft: Draft {
        Draft(
            targetRawValue: target.rawValue,
            text: text,
            categoryRawValue: category.rawValue,
            workspaceRawValue: workspace.rawValue,
            linkedContext: linkedContext,
            studentOrGroup: studentOrGroup,
            followUpNote: followUpNote,
            reminderRawValue: reminder.rawValue,
            noteDestinationRawValue: noteDestination.rawValue
        )
    }

    private func restoreDraftIfNeeded() {
        guard let draft = try? JSONDecoder().decode(Draft.self, from: savedDraftData) else { return }
        target = CaptureTarget(rawValue: draft.targetRawValue) ?? .task
        text = draft.text
        category = TodoItem.Category(rawValue: draft.categoryRawValue) ?? .prep
        workspace = TodoItem.Workspace(rawValue: draft.workspaceRawValue) ?? .school
        linkedContext = draft.linkedContext
        studentOrGroup = draft.studentOrGroup
        followUpNote = draft.followUpNote
        reminder = TodoItem.Reminder(rawValue: draft.reminderRawValue) ?? .none
        noteDestination = NoteDestination(rawValue: draft.noteDestinationRawValue) ?? .general
    }

    private func persistDraft() {
        guard let encoded = try? JSONEncoder().encode(currentDraft) else { return }
        savedDraftData = encoded
    }

    private func clearDraft() {
        savedDraftData = Data()
    }

    private func syncRoutingForWorkspace(_ workspace: TodoItem.Workspace) {
        guard target == .note else { return }

        switch workspace {
        case .school:
            if noteDestination == .personal {
                noteDestination = .general
            }
        case .personal:
            noteDestination = .personal
        }
    }
}
