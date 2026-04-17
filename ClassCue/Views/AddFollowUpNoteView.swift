//
//  AddFollowUpNoteView.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import SwiftUI

struct AddFollowUpNoteView: View {
    @Binding var notes: [FollowUpNoteItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let preferredKind: FollowUpNoteItem.Kind?
    let existing: FollowUpNoteItem?
    let initialNoteText: String
    let initialContext: String
    let initialStudentOrGroup: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("add_follow_up_note_draft_v1") private var savedDraftData: Data = Data()

    @State private var kind: FollowUpNoteItem.Kind = .generalNote
    @State private var context = ""
    @State private var studentOrGroup = ""
    @State private var note = ""
    @State private var followUpDate = Date()

    private struct Draft: Codable, Equatable {
        var existingID: UUID?
        var kind: FollowUpNoteItem.Kind
        var context: String
        var studentOrGroup: String
        var note: String
        var followUpDate: Date
    }

    init(
        notes: Binding<[FollowUpNoteItem]>,
        suggestedContexts: [String],
        suggestedStudents: [String],
        preferredKind: FollowUpNoteItem.Kind? = nil,
        existing: FollowUpNoteItem? = nil,
        initialNoteText: String = "",
        initialContext: String = "",
        initialStudentOrGroup: String = ""
    ) {
        _notes = notes
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.preferredKind = preferredKind
        self.existing = existing
        self.initialNoteText = initialNoteText
        self.initialContext = initialContext
        self.initialStudentOrGroup = initialStudentOrGroup
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    noteOverviewCard
                }

                Section("Note Setup") {
                    if preferredKind == nil {
                        Picker("Type", selection: $kind) {
                            ForEach(FollowUpNoteItem.Kind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                    } else {
                        LabeledContent("Type", value: kind.title)
                    }

                    if showsContextField {
                        if !suggestedContexts.isEmpty {
                            Picker(contextPickerTitle, selection: $context) {
                                if !contextIsRequired {
                                    Text("None").tag("")
                                }
                                ForEach(suggestedContexts, id: \.self) { context in
                                    Text(context).tag(context)
                                }
                            }
                        }

                        TextField(contextFieldTitle, text: $context)
                            .classTraxInputSurface(accent: ClassTraxSemanticColor.primaryAction)
                    }

                    if showsStudentField {
                        if !suggestedStudents.isEmpty {
                            Picker(studentPickerTitle, selection: $studentOrGroup) {
                                ForEach(suggestedStudents, id: \.self) { student in
                                    Text(student).tag(student)
                                }
                            }
                        }

                        TextField(studentFieldTitle, text: $studentOrGroup)
                            .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction)
                    }

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction)

                    DatePicker(
                        "Follow-Up Date",
                        selection: $followUpDate,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle(existing == nil ? "Add Note" : "Edit Note")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        clearDraft()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existing == nil ? "Add" : "Save") {
                        save()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existing {
                    kind = existing.kind
                    context = existing.context
                    studentOrGroup = existing.studentOrGroup
                    note = existing.note
                    followUpDate = existing.followUpDate
                } else {
                    if let preferredKind {
                        kind = preferredKind
                    }
                    context = initialContext
                    studentOrGroup = initialStudentOrGroup
                    note = initialNoteText
                    followUpDate = Date()
                }
                restoreDraftIfNeeded()
            }
            .onChange(of: kind) { _, newKind in
                switch newKind {
                case .classNote:
                    studentOrGroup = ""
                case .generalNote, .personalNote:
                    context = ""
                    studentOrGroup = ""
                case .studentNote, .parentContact:
                    break
                }
            }
            .onChange(of: currentDraft) { _, _ in
                persistDraft()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    persistDraft()
                }
            }
        }
    }

    private var noteOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "Capture the follow-up while it is fresh." : "Refine the follow-up note.")
                .font(.headline.weight(.semibold))

            Text("Use these notes for class follow-up, student concerns, family communication, and general reminders that should not get lost in the planner.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                noteMetric(title: "Type", value: kind.title, accent: ClassTraxSemanticColor.primaryAction)
                noteMetric(title: "Linked", value: linkedSummary, accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private var linkedSummary: String {
        if !studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Student"
        }
        if !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Context"
        }
        return "Standalone"
    }

    private func noteMetric(title: String, value: String, accent: Color) -> some View {
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

    private var canSave: Bool {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStudent = studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNote.isEmpty else { return false }

        switch kind {
        case .generalNote, .personalNote:
            return true
        case .classNote:
            return !trimmedContext.isEmpty
        case .studentNote, .parentContact:
            return !trimmedStudent.isEmpty
        }
    }

    private var showsContextField: Bool {
        switch kind {
        case .generalNote, .personalNote:
            return false
        case .classNote, .studentNote, .parentContact:
            return true
        }
    }

    private var showsStudentField: Bool {
        switch kind {
        case .generalNote, .personalNote:
            return false
        case .classNote:
            return false
        case .studentNote, .parentContact:
            return true
        }
    }

    private var contextIsRequired: Bool {
        kind == .classNote
    }

    private var contextPickerTitle: String {
        contextIsRequired ? "Class" : "Class (Optional)"
    }

    private var contextFieldTitle: String {
        contextIsRequired ? "Class" : "Class (Optional)"
    }

    private var studentPickerTitle: String {
        switch kind {
        case .parentContact:
            return "Student / Family"
        default:
            return "Student"
        }
    }

    private var studentFieldTitle: String {
        switch kind {
        case .parentContact:
            return "Student / Family"
        default:
            return "Student"
        }
    }

    private func save() {
        let item = FollowUpNoteItem(
            id: existing?.id ?? UUID(),
            kind: kind,
            context: context.trimmingCharacters(in: .whitespacesAndNewlines),
            studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            followUpDate: followUpDate,
            createdAt: existing?.createdAt ?? Date()
        )

        if let existing, let index = notes.firstIndex(where: { $0.id == existing.id }) {
            notes[index] = item
        } else {
            notes.insert(item, at: 0)
        }

        clearDraft()
        dismiss()
    }

    private var currentDraft: Draft {
        Draft(
            existingID: existing?.id,
            kind: kind,
            context: context,
            studentOrGroup: studentOrGroup,
            note: note,
            followUpDate: followUpDate
        )
    }

    private func restoreDraftIfNeeded() {
        guard let draft = try? JSONDecoder().decode(Draft.self, from: savedDraftData) else { return }
        guard draft.existingID == existing?.id else { return }
        kind = draft.kind
        context = draft.context
        studentOrGroup = draft.studentOrGroup
        note = draft.note
        followUpDate = draft.followUpDate
    }

    private func persistDraft() {
        guard let encoded = try? JSONEncoder().encode(currentDraft) else { return }
        savedDraftData = encoded
    }

    private func clearDraft() {
        savedDraftData = Data()
    }
}
