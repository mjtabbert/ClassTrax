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
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
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
        case school
        case personal
        case all

        var displayName: String {
            switch self {
            case .school: return "School"
            case .personal: return "Personal"
            case .all: return "All"
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

    enum PriorityFilter: String, CaseIterable {
        case all
        case high
        case med
        case low
        case none

        var displayName: String {
            switch self {
            case .all: return "All Priorities"
            case .high: return TodoItem.Priority.high.rawValue
            case .med: return TodoItem.Priority.med.rawValue
            case .low: return TodoItem.Priority.low.rawValue
            case .none: return TodoItem.Priority.none.rawValue
            }
        }

        var priority: TodoItem.Priority? {
            switch self {
            case .all: return nil
            case .high: return TodoItem.Priority.high
            case .med: return TodoItem.Priority.med
            case .low: return TodoItem.Priority.low
            case .none: return TodoItem.Priority.none
            }
        }
    }

    @State private var showAdd = false
    @State private var editingTodo: TodoItem?
    @State private var showingQuickCapture = false
    @State private var categoryFilter: CategoryFilter = .all
    @State private var workspaceFilter: WorkspaceFilter = .all
    @State private var priorityFilter: PriorityFilter = .all
    @State private var showOnlyFollowUp = false
    @State private var showOnlyStudentContext = false
    @State private var studentFilter = ""
    @State private var linkedContextFilter = ""
    @State private var showingStudentDirectory = false

    init(
        todos: Binding<[TodoItem]>,
        studentProfiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        studentSupportsByName: [String: StudentSupportProfile] = [:],
        onRefresh: @escaping @MainActor () -> Void,
        openTodayTab: @escaping () -> Void
    ) {
        _todos = todos
        _studentProfiles = studentProfiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.studentSupportsByName = studentSupportsByName
        self.onRefresh = onRefresh
        self.openTodayTab = openTodayTab
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Workspace", selection: $workspaceFilter) {
                        ForEach(WorkspaceFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Button {
                        showAdd = true
                    } label: {
                        Label("New Task", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if workspaceFilter != .personal && (!attentionItems.isEmpty || !linkedContextGroups.isEmpty || studentContextCount != 0) {
                    Section("Triage") {
                        if !attentionItems.isEmpty {
                            Button {
                                priorityFilter = .high
                                showOnlyFollowUp = true
                            } label: {
                                triageSummaryRow(
                                    title: "Needs Attention",
                                    value: "\(attentionItems.count)",
                                    detail: attentionItems.prefix(2).map(\.task).joined(separator: " • ")
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let topContext = linkedContextGroups.first {
                            Button {
                                linkedContextFilter = topContext.context
                                workspaceFilter = .school
                            } label: {
                                triageSummaryRow(
                                    title: topContext.context,
                                    value: "\(topContext.count)",
                                    detail: topContext.preview
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if studentContextCount > 0 {
                            Button {
                                showOnlyStudentContext = true
                                workspaceFilter = .school
                            } label: {
                                triageSummaryRow(
                                    title: "Student-Linked Tasks",
                                    value: "\(studentContextCount)",
                                    detail: studentContextPreview
                                )
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
            .onChange(of: workspaceFilter) { _, newValue in
                if newValue != .all {
                    clearAllWorkspaceFilters()
                }
            }
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

                            if activeFilterCount > 0 {
                                Divider()

                                Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
                                    clearFilters()
                                }
                            }
                        } label: {
                            toolbarMenuButton(systemImage: "ellipsis")
                        }

                        if workspaceFilter == .all {
                            Menu {
                                Picker("Priority", selection: $priorityFilter) {
                                    ForEach(PriorityFilter.allCases, id: \.self) { filter in
                                        Text(filter.displayName).tag(filter)
                                    }
                                }

                                Divider()

                                Picker("Category", selection: $categoryFilter) {
                                    ForEach(CategoryFilter.allCases, id: \.self) { filter in
                                        Text(filter.displayName).tag(filter)
                                    }
                                }

                                Divider()

                                Toggle("Needs Follow-Up", isOn: $showOnlyFollowUp)
                                Toggle("Student / Group Context", isOn: $showOnlyStudentContext)

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
                    StudentDirectoryView(
                        profiles: $studentProfiles,
                        classDefinitions: $classDefinitions,
                        teacherContacts: $teacherContacts,
                        paraContacts: $paraContacts
                    )
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

    private func toolbarMenuButton(systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: 30, height: 30)

            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
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
        let selectedPriority = priorityFilter.priority

        let filtered = todos.filter { item in
            guard item.bucket == bucket else { return false }

            if let selectedCategory, item.category != selectedCategory {
                return false
            }

            if let selectedWorkspace, item.workspace != selectedWorkspace {
                return false
            }

            if let selectedPriority, item.priority != selectedPriority {
                return false
            }

            if showOnlyFollowUp,
               item.followUpNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               item.reminder == .none {
                return false
            }

            if showOnlyStudentContext,
               item.effectiveStudentOrGroup.isEmpty {
                return false
            }

            if !studentFilter.isEmpty, item.effectiveStudentOrGroup != studentFilter {
                return false
            }

            if !linkedContextFilter.isEmpty, item.effectiveClassLink != linkedContextFilter {
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
        let studentName = item.effectiveStudentLink
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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        metadataBadge(
                            title: item.workspace.displayName,
                            systemImage: item.workspace.systemImage,
                            tint: item.workspace.tint
                        )

                        metadataBadge(
                            title: item.category.displayName,
                            systemImage: item.category.systemImage,
                            tint: item.category.tint
                        )

                        if item.priority != .none {
                            metadataBadge(
                                title: "Priority: \(priorityText(for: item.priority))",
                                systemImage: "flag.fill",
                                tint: item.priority.color
                            )
                        }
                    }

                    Text(todoMetadataSummary(for: item))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if item.reminder != .none {
                    Label(item.reminder.displayName, systemImage: item.reminder.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(item.reminder.tint)
                }

                Text(dueDateText(for: item))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if !item.effectiveClassLink.isEmpty ||
                    !item.effectiveStudentGroupLink.isEmpty ||
                    !item.effectiveStudentOrGroup.isEmpty {
                    contextSummaryRow(for: item, matchedStudent: matchedStudent)
                }

                if let support = studentSupportsByName[item.effectiveStudentLink],
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

            Menu {
                Button("Edit", systemImage: "pencil") {
                    editingTodo = item
                }

                Button(item.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle") {
                    toggleCompletion(for: item)
                }

                Divider()

                ForEach(TodoItem.Bucket.allCases, id: \.self) { bucket in
                    Button(bucket.displayName, systemImage: item.bucket == bucket ? "checkmark" : "folder") {
                        move(item, to: bucket)
                    }
                    .disabled(item.bucket == bucket)
                }

                if !item.effectiveClassLink.isEmpty ||
                    !item.effectiveStudentOrGroup.isEmpty {
                    Divider()

                    Button("Clear Links", systemImage: "link.badge.minus") {
                        clearLinks(for: item)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .padding(.leading, 8)
        .background(priorityAccent(for: item), alignment: .leading)
    }

    @ViewBuilder
    private func contextSummaryRow(for item: TodoItem, matchedStudent: StudentSupportProfile?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !item.effectiveClassLink.isEmpty {
                Label(item.effectiveClassLink, systemImage: "text.book.closed")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !item.effectiveStudentGroupLink.isEmpty {
                Label(item.effectiveStudentGroupLink, systemImage: "person.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !item.effectiveStudentOrGroup.isEmpty {
                HStack(spacing: 6) {
                    Label(item.effectiveStudentOrGroup, systemImage: "person.text.rectangle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let matchedStudent {
                        gradePill(matchedStudent.gradeLevel)
                    }
                }
            }

            if let matchedStudent {
                let supportSummary = [matchedStudent.className, matchedStudent.prompts]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }

                if let supportSummary {
                    Text(supportSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
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

    private func move(_ item: TodoItem, to bucket: TodoItem.Bucket) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[index].bucket = bucket
    }

    private func clearLinks(for item: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[index].linkedContext = ""
        todos[index].studentOrGroup = ""
        todos[index].classLink = ""
        todos[index].studentGroupLink = ""
        todos[index].studentLink = ""
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

    private func metadataBadge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
    }

    private func priorityText(for priority: TodoItem.Priority) -> String {
        switch priority {
        case .high:
            return "High"
        case .med:
            return "Med"
        case .low:
            return "Low"
        case .none:
            return "None"
        }
    }

    private func todoMetadataSummary(for item: TodoItem) -> String {
        let parts = [
            item.workspace.displayName,
            item.category.displayName,
            item.priority == .none ? nil : "Priority: \(priorityText(for: item.priority))"
        ]

        return parts.compactMap { $0 }.joined(separator: " • ")
    }

    private var activeFilterCount: Int {
        var count = 0
        if categoryFilter != .all { count += 1 }
        if priorityFilter != .all { count += 1 }
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

    private var attentionItems: [TodoItem] {
        todos
            .filter { item in
                !item.isCompleted && item.workspace != .personal && (
                    item.priority == .high ||
                    item.reminder != .none ||
                    item.dueDate != nil
                )
            }
            .sorted { lhs, rhs in
                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) < priorityRank(rhs.priority)
                }
                if reminderRank(lhs.reminder) != reminderRank(rhs.reminder) {
                    return reminderRank(lhs.reminder) < reminderRank(rhs.reminder)
                }
                return lhs.task.localizedCaseInsensitiveCompare(rhs.task) == .orderedAscending
            }
    }

    private var schoolTaskCount: Int {
        todos.filter { !$0.isCompleted && $0.workspace == .school }.count
    }

    private var personalTaskCount: Int {
        todos.filter { !$0.isCompleted && $0.workspace == .personal }.count
    }

    private func clearFilters() {
        categoryFilter = .all
        priorityFilter = .all
        showOnlyFollowUp = false
        showOnlyStudentContext = false
        studentFilter = ""
        linkedContextFilter = ""
    }

    private func clearAllWorkspaceFilters() {
        categoryFilter = .all
        priorityFilter = .all
        showOnlyFollowUp = false
        showOnlyStudentContext = false
        studentFilter = ""
        linkedContextFilter = ""
    }

    private var linkedContextGroups: [(context: String, count: Int, preview: String)] {
        Dictionary(grouping: todos.filter {
            !$0.isCompleted &&
            $0.workspace != .personal &&
            !$0.effectiveClassLink.isEmpty
        }) { $0.effectiveClassLink }
        .map { key, items in
            let sorted = items.sorted { priorityRank($0.priority) < priorityRank($1.priority) }
            let preview = sorted.prefix(2).map(\.task).joined(separator: " • ")
            return (context: key, count: items.count, preview: preview)
        }
        .sorted { lhs, rhs in
            lhs.context.localizedCaseInsensitiveCompare(rhs.context) == .orderedAscending
        }
    }

    private var studentContextCount: Int {
        todos.filter {
            !$0.isCompleted &&
            $0.workspace != .personal &&
            !$0.effectiveStudentOrGroup.isEmpty
        }.count
    }

    private var studentContextPreview: String {
        let names = todos
            .filter {
                !$0.isCompleted &&
                $0.workspace != .personal &&
                !$0.effectiveStudentOrGroup.isEmpty
            }
            .map(\.effectiveStudentOrGroup)

        let uniqueNames: [String] = names.reduce(into: []) { partialResult, name in
            if !partialResult.contains(name) {
                partialResult.append(name)
            }
        }

        return uniqueNames.prefix(2).joined(separator: " • ")
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
            .foregroundStyle(GradeLevelOption.foregroundColor(for: gradeLevel))
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
        teacherContacts: .constant([]),
        paraContacts: .constant([]),
        suggestedContexts: [],
        suggestedStudents: [],
        studentSupportsByName: [:],
        onRefresh: {},
        openTodayTab: {}
    )
}
