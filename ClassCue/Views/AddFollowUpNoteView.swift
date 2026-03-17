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

    @Environment(\.dismiss) private var dismiss

    @State private var kind: FollowUpNoteItem.Kind = .classNote
    @State private var context = ""
    @State private var studentOrGroup = ""
    @State private var note = ""

    init(
        notes: Binding<[FollowUpNoteItem]>,
        suggestedContexts: [String],
        suggestedStudents: [String],
        preferredKind: FollowUpNoteItem.Kind? = nil,
        existing: FollowUpNoteItem? = nil
    ) {
        _notes = notes
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.preferredKind = preferredKind
        self.existing = existing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Follow-Up") {
                    if preferredKind == nil {
                        Picker("Type", selection: $kind) {
                            ForEach(FollowUpNoteItem.Kind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                    } else {
                        LabeledContent("Type", value: kind.title)
                    }

                    if kind != .parentContact {
                        TextField(kind == .classNote ? "Class or Commitment" : "Class or Commitment (Optional)", text: $context)
                    }

                    if !suggestedContexts.isEmpty {
                        Picker("Saved Class Link", selection: $context) {
                            Text("None").tag("")
                            ForEach(suggestedContexts, id: \.self) { context in
                                Text(context).tag(context)
                            }
                        }
                    }

                    TextField(kind == .classNote ? "Student or Group (Optional)" : "Student or Group", text: $studentOrGroup)

                    if !suggestedStudents.isEmpty {
                        Picker("Saved Student / Group", selection: $studentOrGroup) {
                            Text("None").tag("")
                            ForEach(suggestedStudents, id: \.self) { student in
                                Text(student).tag(student)
                            }
                        }
                    }

                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle(existing == nil ? "Add Follow-Up" : "Edit Follow-Up")
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let existing {
                    kind = existing.kind
                    context = existing.context
                    studentOrGroup = existing.studentOrGroup
                    note = existing.note
                } else if let preferredKind {
                    kind = preferredKind
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStudent = studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedNote.isEmpty else { return false }

        switch kind {
        case .classNote:
            return !trimmedContext.isEmpty
        case .studentNote, .parentContact:
            return !trimmedStudent.isEmpty
        }
    }

    private func save() {
        let item = FollowUpNoteItem(
            id: existing?.id ?? UUID(),
            kind: kind,
            context: context.trimmingCharacters(in: .whitespacesAndNewlines),
            studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing?.createdAt ?? Date()
        )

        if let existing, let index = notes.firstIndex(where: { $0.id == existing.id }) {
            notes[index] = item
        } else {
            notes.insert(item, at: 0)
        }

        dismiss()
    }
}
