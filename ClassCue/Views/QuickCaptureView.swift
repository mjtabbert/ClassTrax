//
//  QuickCaptureView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import SwiftUI

struct QuickCaptureView: View {

    enum CaptureTarget: String, CaseIterable {
        case task
        case note

        var title: String {
            switch self {
            case .task: return "Task"
            case .note: return "Note"
            }
        }
    }

    enum NoteDestination: String, CaseIterable {
        case general
        case classFollowUp
        case studentFollowUp
        case parentContact

        var title: String {
            switch self {
            case .general: return "General Note"
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
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()

    @Environment(\.dismiss) private var dismiss

    @State private var target: CaptureTarget = .task
    @State private var text = ""
    @State private var category: TodoItem.Category = .prep
    @State private var linkedContext = ""
    @State private var studentOrGroup = ""
    @State private var followUpNote = ""
    @State private var reminder = TodoItem.Reminder.none
    @State private var noteDestination: NoteDestination = .general

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

                Section(target == .task ? "Task" : "Note") {
                    TextField(
                        target == .task ? "What needs to happen?" : "Quick note",
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                if target == .task {
                    Section("Teacher Context") {
                        Picker("Category", selection: $category) {
                            ForEach(TodoItem.Category.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.systemImage)
                                    .tag(category)
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

                        if !suggestedContexts.isEmpty {
                            Picker("Suggested Link", selection: $linkedContext) {
                                Text("None").tag("")
                                if let preferredContext, !preferredContext.isEmpty {
                                    Text("Current Focus: \(preferredContext)").tag(preferredContext)
                                }
                                ForEach(suggestedContexts, id: \.self) { context in
                                    Text(context).tag(context)
                                }
                            }
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
                        Button("Today") {
                            saveTask(bucket: .today, reminder: reminder)
                        }

                        Button("After School") {
                            saveTask(bucket: .today, reminder: .afterSchool)
                        }

                        Button("Tomorrow") {
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
                        dismiss()
                    }
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
                linkedContext: linkedContext.trimmingCharacters(in: .whitespacesAndNewlines),
                studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                followUpNote: followUpNote.trimmingCharacters(in: .whitespacesAndNewlines),
                reminder: reminder
            ),
            at: 0
        )

        dismiss()
    }

    private func saveNote() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let route = noteRoutePrefix()
        let noteLine = route.isEmpty ? trimmed : "\(route): \(trimmed)"

        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesText = noteLine
        } else {
            notesText = "\(noteLine)\n\n\(notesText)"
        }

        if let kind = structuredKindForDestination() {
            var notes = decodeFollowUpNotes()
            notes.insert(
                FollowUpNoteItem(
                    kind: kind,
                    context: linkedContext.trimmingCharacters(in: .whitespacesAndNewlines),
                    studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: trimmed
                ),
                at: 0
            )
            saveFollowUpNotes(notes)
        }

        dismiss()
    }

    private func noteRoutePrefix() -> String {
        var parts = ["[\(noteDestination.title)]"]

        let trimmedContext = linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStudent = studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedContext.isEmpty {
            parts.append(trimmedContext)
        }

        if !trimmedStudent.isEmpty {
            parts.append(trimmedStudent)
        }

        return parts.joined(separator: " ")
    }

    private func structuredKindForDestination() -> FollowUpNoteItem.Kind? {
        switch noteDestination {
        case .general:
            return nil
        case .classFollowUp:
            return .classNote
        case .studentFollowUp:
            return .studentNote
        case .parentContact:
            return .parentContact
        }
    }

    private func decodeFollowUpNotes() -> [FollowUpNoteItem] {
        (try? JSONDecoder().decode([FollowUpNoteItem].self, from: savedFollowUpNotes)) ?? []
    }

    private func saveFollowUpNotes(_ notes: [FollowUpNoteItem]) {
        savedFollowUpNotes = (try? JSONEncoder().encode(notes)) ?? Data()
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
}
