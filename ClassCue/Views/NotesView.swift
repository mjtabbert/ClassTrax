import SwiftUI

struct NotesView: View {
    enum NotesMode: String, CaseIterable {
        case general
        case classNotes
        case studentNotes

        var title: String {
            switch self {
            case .general:
                return "General"
            case .classNotes:
                return "Class Notes"
            case .studentNotes:
                return "Student"
            }
        }
    }

    @Binding var todos: [TodoItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()

    @State private var showingShareSheet = false
    @State private var exportText = ""
    @FocusState private var isEditorFocused: Bool
    @State private var showClearConfirm = false
    @State private var showingQuickCapture = false
    @State private var notesMode: NotesMode = .general
    @State private var selectedContextFilter = ""
    @State private var selectedStudentFilter = ""
    @State private var showingAddFollowUp = false
    @State private var editingFollowUp: FollowUpNoteItem?

    init(
        todos: Binding<[TodoItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = []
    ) {
        _todos = todos
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $notesMode) {
                    ForEach(NotesMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)

                if notesMode == .classNotes {
                    classFollowUpView
                } else if notesMode == .studentNotes {
                    studentNotesView
                } else {
                    TextEditor(text: $notesText)
                        .padding(12)
                        .focused($isEditorFocused)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if notesMode == .general && !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingQuickCapture = true
                    } label: {
                        Image(systemName: "bolt.badge.plus")
                    }

                    Button("Export") {
                        exportText = classCueNotesExportText(notes: notesText)
                        showingShareSheet = true
                    }

                    if notesMode == .classNotes || notesMode == .studentNotes {
                        Button {
                            showingAddFollowUp = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }

                    if notesMode == .general && isEditorFocused {
                        Button("Done") {
                            isEditorFocused = false
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isEditorFocused = false
                    }
                }
            }
            .confirmationDialog(
                "Clear all notes?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Notes", role: .destructive) {
                    notesText = ""
                }

                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [exportText])
            }
            .sheet(isPresented: $showingQuickCapture) {
                QuickCaptureView(
                    todos: $todos,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents
                )
            }
            .sheet(isPresented: $showingAddFollowUp) {
                AddFollowUpNoteView(
                    notes: followUpNotesBinding,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    preferredKind: notesMode == .studentNotes ? .studentNote : .classNote
                )
            }
            .sheet(item: $editingFollowUp) { note in
                AddFollowUpNoteView(
                    notes: followUpNotesBinding,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    preferredKind: nil,
                    existing: note
                )
            }
        }
    }

    private var classFollowUpView: some View {
        let groups = followUpGroups

        return List {
            if !suggestedContexts.isEmpty {
                Section("Filter") {
                    Picker("Class or Commitment", selection: $selectedContextFilter) {
                        Text("All Classes").tag("")
                        ForEach(suggestedContexts, id: \.self) { context in
                            Text(context).tag(context)
                        }
                    }
                }
            }

            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Class Notes Yet",
                        systemImage: "note.text.badge.plus",
                        description: Text("Linked tasks and class-bound notes will show up here.")
                    )
                }
            } else {
                ForEach(groups, id: \.context) { group in
                    Section(group.context) {
                        if !group.tasks.isEmpty {
                            ForEach(group.tasks) { task in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.task)
                                        .fontWeight(.semibold)

                                    Text(taskFollowUpSubtitle(for: task))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        if !group.notes.isEmpty {
                            ForEach(group.notes) { note in
                                Button {
                                    editingFollowUp = note
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(note.kind.title)
                                            .font(.subheadline.weight(.semibold))

                                        Text(note.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)

                                        if !note.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(note.studentOrGroup)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete(perform: { offsets in
                                deleteFollowUpNotes(at: offsets, from: group.notes)
                            })
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var studentNotesView: some View {
        let groups = studentNoteGroups

        return List {
            if !suggestedStudents.isEmpty {
                Section("Filter") {
                    Picker("Student or Group", selection: $selectedStudentFilter) {
                        Text("All Students").tag("")
                        ForEach(suggestedStudents, id: \.self) { student in
                            Text(student).tag(student)
                        }
                    }
                }
            }

            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Student Notes Yet",
                        systemImage: "person.text.rectangle",
                        description: Text("Student notes and parent contacts will show up here.")
                    )
                }
            } else {
                ForEach(groups, id: \.student) { group in
                    Section(group.student) {
                        if let context = group.context, !context.isEmpty {
                            Text(context)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ForEach(group.notes) { note in
                            Button {
                                editingFollowUp = note
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.kind.title)
                                        .font(.subheadline.weight(.semibold))

                                    Text(note.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            deleteFollowUpNotes(at: offsets, from: group.notes)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var followUpGroups: [(context: String, tasks: [TodoItem], notes: [FollowUpNoteItem])] {
        let notesByContext = Dictionary(grouping: followUpNotes.filter {
            $0.kind == .classNote &&
            !$0.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.context }
        let tasksByContext = Dictionary(grouping: todos.filter {
            !$0.isCompleted &&
            !$0.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.linkedContext }

        let contexts = Set(notesByContext.keys).union(tasksByContext.keys).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return contexts
            .filter { selectedContextFilter.isEmpty || $0 == selectedContextFilter }
            .map { context in
                let tasks = (tasksByContext[context] ?? []).sorted {
                    $0.task.localizedCaseInsensitiveCompare($1.task) == .orderedAscending
                }
                let notes = (notesByContext[context] ?? []).sorted { $0.createdAt > $1.createdAt }
                return (context: context, tasks: tasks, notes: notes)
            }
    }

    private var followUpNotes: [FollowUpNoteItem] {
        (try? JSONDecoder().decode([FollowUpNoteItem].self, from: savedFollowUpNotes)) ?? []
    }

    private var studentNoteGroups: [(student: String, context: String?, notes: [FollowUpNoteItem])] {
        let grouped = Dictionary(grouping: followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            !$0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.studentOrGroup }

        return grouped
            .map { student, notes in
                let sortedNotes = notes.sorted { $0.createdAt > $1.createdAt }
                let context = sortedNotes.first?.context.trimmingCharacters(in: .whitespacesAndNewlines)
                return (student: student, context: context?.isEmpty == true ? nil : context, notes: sortedNotes)
            }
            .filter { selectedStudentFilter.isEmpty || $0.student == selectedStudentFilter }
            .sorted { $0.student.localizedCaseInsensitiveCompare($1.student) == .orderedAscending }
    }

    private var followUpNotesBinding: Binding<[FollowUpNoteItem]> {
        Binding(
            get: { followUpNotes },
            set: { newValue in
                savedFollowUpNotes = (try? JSONEncoder().encode(newValue)) ?? Data()
            }
        )
    }

    private func taskFollowUpSubtitle(for task: TodoItem) -> String {
        var parts: [String] = []

        if !task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.studentOrGroup)
        }

        if !task.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(task.followUpNote)
        }

        if task.reminder != .none {
            parts.append(task.reminder.displayName)
        }

        if parts.isEmpty {
            return task.category.displayName
        }

        return parts.joined(separator: " • ")
    }

    private func deleteFollowUpNotes(at offsets: IndexSet, from groupNotes: [FollowUpNoteItem]) {
        let ids = offsets.map { groupNotes[$0].id }
        var updated = followUpNotes
        updated.removeAll { ids.contains($0.id) }
        savedFollowUpNotes = (try? JSONEncoder().encode(updated)) ?? Data()
    }
}

func classCueNotesExportText(notes: String) -> String {
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateStyle = .long
    dateOnlyFormatter.timeStyle = .none

    let timeOnlyFormatter = DateFormatter()
    timeOnlyFormatter.dateStyle = .none
    timeOnlyFormatter.timeStyle = .short

    let now = Date()

    return """
    Class Cue Notes Export
    \(dateOnlyFormatter.string(from: now))
    \(timeOnlyFormatter.string(from: now))

    \(notes)
    """
}
