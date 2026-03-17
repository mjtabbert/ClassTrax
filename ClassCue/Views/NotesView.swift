import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext

    enum NotesMode: String, CaseIterable {
        case general
        case personal
        case classNotes
        case studentNotes

        var title: String {
            switch self {
            case .general:
                return "School"
            case .personal:
                return "Personal"
            case .classNotes:
                return "Class Notes"
            case .studentNotes:
                return "Student"
            }
        }
    }

    @Binding var todos: [TodoItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let onRefresh: @MainActor () -> Void
    let openTodayTab: () -> Void
    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("personal_notes_v1") private var personalNotesText: String = ""
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
    @State private var showingStudentDirectory = false

    init(
        todos: Binding<[TodoItem]>,
        studentProfiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        onRefresh: @escaping @MainActor () -> Void,
        openTodayTab: @escaping () -> Void
    ) {
        _todos = todos
        _studentProfiles = studentProfiles
        _classDefinitions = classDefinitions
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.onRefresh = onRefresh
        self.openTodayTab = openTodayTab
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
                } else if notesMode == .personal {
                    TextEditor(text: $personalNotesText)
                        .padding(12)
                        .focused($isEditorFocused)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    if clearableNotesText != nil {
                        Button("Clear") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu("Actions") {
                        Button("Quick Add", systemImage: "square.and.pencil") {
                            showingQuickCapture = true
                        }

                        Button("Students", systemImage: "person.3") {
                            showingStudentDirectory = true
                        }

                        Button("Refresh", systemImage: "arrow.clockwise") {
                            onRefresh()
                        }

                        Button("Daily Sub Plan", systemImage: "doc.text") {
                            openTodayTab()
                        }
                    }

                    Button {
                        showingQuickCapture = true
                    } label: {
                        Image(systemName: "bolt.badge.plus")
                    }

                    Button("Export") {
                        exportText = classCueNotesExportText(
                            notes: currentNotesText,
                            title: notesMode == .personal ? "Class Trax Personal Notes Export" : "Class Trax Notes Export"
                        )
                        showingShareSheet = true
                    }

                    if notesMode == .classNotes || notesMode == .studentNotes {
                        Button {
                            showingAddFollowUp = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }

                    if (notesMode == .general || notesMode == .personal) && isEditorFocused {
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
                    clearCurrentNotes()
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
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(profiles: $studentProfiles, classDefinitions: $classDefinitions)
                }
            }
        }
    }

    private var currentNotesText: String {
        notesMode == .personal ? personalNotesText : notesText
    }

    private var clearableNotesText: String? {
        let text = currentNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (notesMode == .general || notesMode == .personal) && !text.isEmpty ? text : nil
    }

    private func clearCurrentNotes() {
        switch notesMode {
        case .general:
            notesText = ""
        case .personal:
            personalNotesText = ""
        case .classNotes, .studentNotes:
            break
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

                                    let studentName = task.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let matchedStudent = studentProfile(named: studentName)

                                    HStack(spacing: 6) {
                                        Text(taskFollowUpSubtitle(for: task))
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        if let matchedStudent, !studentName.isEmpty {
                                            gradePill(matchedStudent.gradeLevel)
                                        }
                                    }
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
                                            HStack(spacing: 6) {
                                                Text(note.studentOrGroup)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)

                                                if let matchedStudent = studentProfile(named: note.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                                    gradePill(matchedStudent.gradeLevel)
                                                }
                                            }
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
                    Section {
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
                    header: {
                        HStack(spacing: 6) {
                            Text(group.student)

                            if let matchedStudent = studentProfile(named: group.student) {
                                gradePill(matchedStudent.gradeLevel)
                            }
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
        ClassTraxPersistence.loadFollowUpNotes(from: modelContext)
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
                persistFollowUpNotes(newValue)
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
        persistFollowUpNotes(updated)
    }

    private func persistFollowUpNotes(_ notes: [FollowUpNoteItem]) {
        ClassTraxPersistence.saveFollowUpNotes(notes, into: modelContext)
        savedFollowUpNotes = (try? JSONEncoder().encode(notes)) ?? Data()
    }

    private func studentProfile(named name: String) -> StudentSupportProfile? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return studentProfiles.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private func gradePill(_ gradeLevel: String) -> some View {
        Text(GradeLevelOption.pillLabel(for: gradeLevel))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(GradeLevelOption.color(for: gradeLevel))
            )
    }
}

func classCueNotesExportText(notes: String, title: String = "Class Trax Notes Export") -> String {
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateStyle = .long
    dateOnlyFormatter.timeStyle = .none

    let timeOnlyFormatter = DateFormatter()
    timeOnlyFormatter.dateStyle = .none
    timeOnlyFormatter.timeStyle = .short

    let now = Date()

    return """
    \(title)
    \(dateOnlyFormatter.string(from: now))
    \(timeOnlyFormatter.string(from: now))

    \(notes)
    """
}
