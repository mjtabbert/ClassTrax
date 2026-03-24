//
//  TodoListView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 3:20 PM
//  Version: ClassTrax Dev Build 11.2
//

import SwiftUI

struct TodoListView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var todos: [TodoItem]
    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    let onRefresh: @MainActor () -> Void
    let openTodayTab: () -> Void

    enum CategoryFilter: String, CaseIterable {
        case all
        case prep
        case grading
        case parentContact
        case copies
        case meetingFollowUp
        case admin
        case classroom
        case other

        var displayName: String {
            switch self {
            case .all: return "All"
            case .prep: return TodoItem.Category.prep.displayName
            case .grading: return TodoItem.Category.grading.displayName
            case .parentContact: return TodoItem.Category.parentContact.displayName
            case .copies: return TodoItem.Category.copies.displayName
            case .meetingFollowUp: return TodoItem.Category.meetingFollowUp.displayName
            case .admin: return TodoItem.Category.admin.displayName
            case .classroom: return TodoItem.Category.classroom.displayName
            case .other: return TodoItem.Category.other.displayName
            }
        }

        var category: TodoItem.Category? {
            switch self {
            case .all: return nil
            case .prep: return .prep
            case .grading: return .grading
            case .parentContact: return .parentContact
            case .copies: return .copies
            case .meetingFollowUp: return .meetingFollowUp
            case .admin: return .admin
            case .classroom: return .classroom
            case .other: return .other
            }
        }
    }

    enum WorkspaceFilter: String, CaseIterable {
        case all
        case school
        case personal

        var displayName: String {
            switch self {
            case .all: return "All Workspaces"
            case .school: return "School"
            case .personal: return "Personal"
            }
        }

        var workspace: TodoItem.Workspace? {
            switch self {
            case .all: return nil
            case .school: return .school
            case .personal: return .personal
            }
        }
    }

    @State private var showAdd = false
    @State private var editingTodo: TodoItem?
    @State private var showingQuickCapture = false
    @State private var categoryFilter: CategoryFilter = .all
    @State private var workspaceFilter: WorkspaceFilter = .all
    @State private var showOnlyFollowUp = false
    @State private var showOnlyStudentContext = false
    @State private var studentFilter = ""
    @State private var linkedContextFilter = ""
    @State private var showingStudentDirectory = false

    init(
        todos: Binding<[TodoItem]>,
        studentProfiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        studentSupportsByName: [String: StudentSupportProfile] = [:],
        onRefresh: @escaping @MainActor () -> Void,
        openTodayTab: @escaping () -> Void
    ) {
        _todos = todos
        _studentProfiles = studentProfiles
        _classDefinitions = classDefinitions
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.studentSupportsByName = studentSupportsByName
        self.onRefresh = onRefresh
        self.openTodayTab = openTodayTab
    }

    var body: some View {
        NavigationStack {
            List {
                let linkedGroups = linkedContextGroups

                Section("Triage") {
                    Button {
                        showAdd = true
                    } label: {
                        Label("New Task", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)

                    triageSummaryRow(
                        title: "Needs Attention",
                        value: "\(attentionCount)",
                        detail: "Open tasks with reminders, high priority, or due dates"
                    )
                    triageSummaryRow(
                        title: "School vs Personal",
                        value: "\(schoolTaskCount) / \(personalTaskCount)",
                        detail: "Keep work boundaries visible while planning"
                    )

                    if activeFilterCount > 0 {
                        Button("Clear Active Filters") {
                            clearFilters()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !linkedGroups.isEmpty {
                    Section("By Class / Commitment") {
                        ForEach(linkedGroups, id: \.context) { group in
                            Button {
                                linkedContextFilter = group.context
                            } label: {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.context)
                                            .fontWeight(.semibold)

                                        Text(group.preview)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Text("\(group.count)")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ForEach(TodoItem.Bucket.allCases, id: \.self) { bucket in
                    let bucketItems = items(for: bucket)

                    if !bucketItems.isEmpty {
                        Section(bucket.displayName) {
                            ForEach(bucketItems) { item in
                                todoRow(for: item)
                            }
                            .onDelete { offsets in
                                deleteTodo(at: offsets, in: bucketItems)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
            .refreshable {
                onRefresh()
            }
            .navigationTitle("To Do")
            .scrollContentBackground(.hidden)
            .background(todoBackground)
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if todos.contains(where: { $0.isCompleted }) {
                        Button("Clear Done") {
                            todos = todos.filter { !$0.isCompleted }
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu {
                            Button("Students", systemImage: "person.3") {
                                showingStudentDirectory = true
                            }

                            Button("Refresh", systemImage: "arrow.clockwise") {
                                onRefresh()
                            }

                            Button("Daily Sub Plan", systemImage: "doc.text") {
                                openTodayTab()
                            }
                        } label: {
                            toolbarIconButton(systemImage: "ellipsis", title: "Actions")
                        }

                        Menu {
                            Picker("Category", selection: $categoryFilter) {
                                ForEach(CategoryFilter.allCases, id: \.self) { filter in
                                    Text(filter.displayName).tag(filter)
                                }
                            }

                            Divider()

                            Toggle("Needs Follow-Up", isOn: $showOnlyFollowUp)
                            Toggle("Student / Group Context", isOn: $showOnlyStudentContext)

                            Picker("Workspace", selection: $workspaceFilter) {
                                ForEach(WorkspaceFilter.allCases, id: \.self) { filter in
                                    Text(filter.displayName).tag(filter)
                                }
                            }

                            if !suggestedStudents.isEmpty {
                                Divider()

                                Picker("Student / Group", selection: $studentFilter) {
                                    Text("All Students").tag("")
                                    ForEach(suggestedStudents, id: \.self) { student in
                                        Text(student).tag(student)
                                    }
                                }
                            }

                            if !suggestedContexts.isEmpty {
                                Divider()

                                Picker("Class / Commitment", selection: $linkedContextFilter) {
                                    Text("All Classes").tag("")
                                    ForEach(suggestedContexts, id: \.self) { context in
                                        Text(context).tag(context)
                                    }
                                }
                            }
                        } label: {
                            toolbarIconButton(
                                systemImage: activeFilterCount == 0
                                    ? "line.3.horizontal.decrease"
                                    : "line.3.horizontal.decrease.circle.fill",
                                title: activeFilterCount == 0 ? "Filters" : "Filters On"
                            )
                        }

                        Button {
                            showingQuickCapture = true
                        } label: {
                            toolbarCapsuleLabel(
                                title: "Quick",
                                systemImage: "bolt.badge.plus"
                            )
                        }

                        Button {
                            showAdd = true
                        } label: {
                            toolbarCapsuleLabel(
                                title: "New Task",
                                systemImage: "plus"
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTodoView(
                    todos: $todos,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    studentSupportsByName: studentSupportsByName
                )
            }
            .sheet(isPresented: $showingQuickCapture) {
                QuickCaptureView(
                    todos: $todos,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    studentSupportsByName: studentSupportsByName
                )
            }
            .sheet(item: $editingTodo) { todo in
                AddTodoView(
                    todos: $todos,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    studentSupportsByName: studentSupportsByName,
                    existing: todo
                )
            }
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(profiles: $studentProfiles, classDefinitions: $classDefinitions)
                }
            }
        }
    }

    private var todoBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.orange.opacity(0.05),
                Color.yellow.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func toolbarCapsuleLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            )
    }

    @ViewBuilder
    private func toolbarIconButton(systemImage: String, title: String) -> some View {
        if prefersExpandedToolbar {
            toolbarCapsuleLabel(title: title, systemImage: systemImage)
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 30, height: 30)

                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var prefersExpandedToolbar: Bool {
        horizontalSizeClass != .compact
    }

    private func triageSummaryRow(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
                Text(value)
                    .font(.headline)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func items(for bucket: TodoItem.Bucket) -> [TodoItem] {
        let selectedCategory = categoryFilter.category
        let selectedWorkspace = workspaceFilter.workspace

        let filtered = todos.filter { item in
            guard item.bucket == bucket else { return false }

            if let selectedCategory, item.category != selectedCategory {
                return false
            }

            if let selectedWorkspace, item.workspace != selectedWorkspace {
                return false
            }

            if showOnlyFollowUp,
               item.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               item.reminder == .none {
                return false
            }

            if showOnlyStudentContext,
               item.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }

            if !studentFilter.isEmpty, item.studentOrGroup != studentFilter {
                return false
            }

            if !linkedContextFilter.isEmpty, item.linkedContext != linkedContextFilter {
                return false
            }

            return true
        }

        return filtered.sorted { a, b in
                if a.isCompleted != b.isCompleted {
                    return !a.isCompleted
                }

                if reminderRank(a.reminder) != reminderRank(b.reminder) {
                    return reminderRank(a.reminder) < reminderRank(b.reminder)
                }

                if priorityRank(a.priority) != priorityRank(b.priority) {
                    return priorityRank(a.priority) < priorityRank(b.priority)
                }

                switch (a.dueDate, b.dueDate) {
                case let (lhs?, rhs?):
                    return lhs < rhs
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return a.task.localizedCaseInsensitiveCompare(b.task) == .orderedAscending
                }
            }
    }

    private func todoRow(for item: TodoItem) -> some View {
        let studentName = item.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedStudent = studentProfile(named: studentName)

        return HStack(spacing: 12) {
            Button {
                toggleCompletion(for: item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCompleted ? .green : item.priority.color)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.task)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !item.isCompleted, item.priority != .none {
                        priorityBadge(for: item.priority)
                    }
                }

                HStack(spacing: 6) {
                    Label(item.workspace.displayName, systemImage: item.workspace.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(item.workspace.tint)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Label(item.category.displayName, systemImage: item.category.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(item.category.tint)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if item.priority != .none {
                        Text(item.priority.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(item.priority.color)
                    }
                }

                if item.reminder != .none {
                    Label(item.reminder.displayName, systemImage: item.reminder.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(item.reminder.tint)
                }

                Text(dueDateText(for: item))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !item.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.linkedContext)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if !item.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 6) {
                        Label(item.studentOrGroup, systemImage: "person.text.rectangle")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let matchedStudent {
                            gradePill(matchedStudent.gradeLevel)
                        }
                    }
                }

                if let support = studentSupportsByName[item.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)],
                   !support.accommodations.isEmpty {
                    Text(support.accommodations)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if !item.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(item.followUpNote)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                editingTodo = item
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
        .background(priorityAccent(for: item), alignment: .leading)
    }

    private func toggleCompletion(for item: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        var updatedTodos = todos
        updatedTodos[index].isCompleted.toggle()
        todos = updatedTodos
    }

    private func deleteTodo(at offsets: IndexSet, in bucketItems: [TodoItem]) {
        let idsToDelete = offsets.map { bucketItems[$0].id }
        todos = todos.filter { !idsToDelete.contains($0.id) }
    }

    private func dueDateText(for item: TodoItem) -> String {
        if let due = item.dueDate {
            return "Due: \(due.formatted(date: .abbreviated, time: .omitted))"
        } else {
            return "No due date"
        }
    }

    private func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high: return 0
        case .med: return 1
        case .low: return 2
        case .none: return 3
        }
    }

    @ViewBuilder
    private func priorityAccent(for item: TodoItem) -> some View {
        if !item.isCompleted, item.priority != .none {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.priority.color.gradient)
                .frame(width: 6)
        } else {
            Color.clear.frame(width: 6)
        }
    }

    private func priorityBadge(for priority: TodoItem.Priority) -> some View {
        Text(priority.rawValue.uppercased())
            .font(.caption2.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(priority.color.gradient)
            )
    }

    private var activeFilterCount: Int {
        var count = 0
        if categoryFilter != .all { count += 1 }
        if workspaceFilter != .all { count += 1 }
        if showOnlyFollowUp { count += 1 }
        if showOnlyStudentContext { count += 1 }
        if !studentFilter.isEmpty { count += 1 }
        if !linkedContextFilter.isEmpty { count += 1 }
        return count
    }

    private var attentionCount: Int {
        todos.filter { item in
            !item.isCompleted && (
                item.priority == .high ||
                item.reminder != .none ||
                item.dueDate != nil
            )
        }.count
    }

    private var schoolTaskCount: Int {
        todos.filter { !$0.isCompleted && $0.workspace == .school }.count
    }

    private var personalTaskCount: Int {
        todos.filter { !$0.isCompleted && $0.workspace == .personal }.count
    }

    private func clearFilters() {
        categoryFilter = .all
        workspaceFilter = .all
        showOnlyFollowUp = false
        showOnlyStudentContext = false
        studentFilter = ""
        linkedContextFilter = ""
    }

    private var linkedContextGroups: [(context: String, count: Int, preview: String)] {
        Dictionary(grouping: todos.filter {
            !$0.isCompleted &&
            !$0.linkedContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.linkedContext }
        .map { key, items in
            let sorted = items.sorted { priorityRank($0.priority) < priorityRank($1.priority) }
            let preview = sorted.prefix(2).map(\.task).joined(separator: " • ")
            return (context: key, count: items.count, preview: preview)
        }
        .sorted { lhs, rhs in
            lhs.context.localizedCaseInsensitiveCompare(rhs.context) == .orderedAscending
        }
    }

    private func reminderRank(_ reminder: TodoItem.Reminder) -> Int {
        switch reminder {
        case .afterSchool: return 0
        case .tomorrowMorning: return 1
        case .none: return 2
        }
    }

    private func studentProfile(named name: String) -> StudentSupportProfile? {
        guard !name.isEmpty else { return nil }
        return studentProfiles.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(name) == .orderedSame
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

#Preview {
    TodoListView(
        todos: .constant([
            TodoItem(task: "Prep math lesson", priority: .high, dueDate: Date()),
            TodoItem(task: "Print spelling sheets", isCompleted: true, priority: .low, dueDate: nil),
            TodoItem(task: "Email parent update", priority: .med, dueDate: nil)
        ]),
        studentProfiles: .constant([]),
        classDefinitions: .constant([]),
        suggestedContexts: [],
        suggestedStudents: [],
        studentSupportsByName: [:],
        onRefresh: {},
        openTodayTab: {}
    )
}
