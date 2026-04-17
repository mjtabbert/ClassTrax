//
//  AddTodoView.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 3:25 PM
//  Version: ClassTrax Dev Build 11.3
//

import SwiftUI

struct AddTodoView: View {
    
    @Binding var todos: [TodoItem]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let suggestedStudentGroups: [String]
    let studentSupportsByName: [String: StudentSupportProfile]
    
    var existing: TodoItem? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("add_todo_draft_v1") private var savedDraftData: Data = Data()
    
    @State private var task = ""
    @State private var priority = TodoItem.Priority.none
    @State private var category = TodoItem.Category.prep
    @State private var bucket = TodoItem.Bucket.today
    @State private var workspace = TodoItem.Workspace.school
    @State private var classLink = ""
    @State private var studentGroupLink = ""
    @State private var studentLink = ""
    @State private var followUpNote = ""
    @State private var reminder = TodoItem.Reminder.none
    @State private var recurrence = TodoItem.Recurrence.none
    @State private var recurrenceWeekday = TodoItem.RecurrenceWeekday.monday
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0
    @AppStorage("school_default_personal_capture_after_hours") private var defaultPersonalCaptureAfterHours = true

    private struct Draft: Codable, Equatable {
        var existingID: UUID?
        var task: String
        var priority: TodoItem.Priority
        var category: TodoItem.Category
        var bucket: TodoItem.Bucket
        var workspace: TodoItem.Workspace
        var classLink: String
        var studentGroupLink: String
        var studentLink: String
        var followUpNote: String
        var reminder: TodoItem.Reminder
        var recurrence: TodoItem.Recurrence
        var recurrenceWeekday: TodoItem.RecurrenceWeekday
        var hasDueDate: Bool
        var dueDate: Date
    }

    init(
        todos: Binding<[TodoItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        suggestedStudentGroups: [String] = [],
        studentSupportsByName: [String: StudentSupportProfile] = [:],
        existing: TodoItem? = nil
    ) {
        _todos = todos
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.suggestedStudentGroups = suggestedStudentGroups
        self.studentSupportsByName = studentSupportsByName
        self.existing = existing
        let usePersonalDefault = AddTodoView.shouldDefaultToPersonalCapture(
            schoolQuietHoursEnabled: UserDefaults.standard.bool(forKey: "school_quiet_hours_enabled"),
            schoolQuietHour: UserDefaults.standard.object(forKey: "school_quiet_hour") as? Int ?? 16,
            schoolQuietMinute: UserDefaults.standard.object(forKey: "school_quiet_minute") as? Int ?? 0,
            defaultPersonalCaptureAfterHours: UserDefaults.standard.object(forKey: "school_default_personal_capture_after_hours") as? Bool ?? true,
            now: Date()
        )
        _workspace = State(initialValue: existing?.workspace ?? (usePersonalDefault ? .personal : .school))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    taskOverviewCard
                }

                Section("Workspace") {
                    Picker("Workspace", selection: $workspace) {
                        ForEach(TodoItem.Workspace.allCases, id: \.self) { workspace in
                            Label(workspace.displayName, systemImage: workspace.systemImage)
                                .tag(workspace)
                        }
                    }
                }

                Section("Task Setup") {
                    TextField("Task Name", text: $task)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.primaryAction)

                    Picker("When", selection: $bucket) {
                        ForEach(TodoItem.Bucket.allCases, id: \.self) { bucket in
                            Text(bucket.displayName).tag(bucket)
                        }
                    }

                    Picker("Category", selection: $category) {
                        ForEach(TodoItem.Category.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Links & Context") {
                    Picker("Class Link", selection: $classLink) {
                        Text("None").tag("")
                        ForEach(suggestedContexts, id: \.self) { context in
                            Text(context).tag(context)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Student Group Link", selection: $studentGroupLink) {
                        Text("None").tag("")
                        ForEach(suggestedStudentGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Student Link", selection: $studentLink) {
                        Text("None").tag("")
                        ForEach(suggestedStudents, id: \.self) { student in
                            Text(student).tag(student)
                        }
                    }
                    .pickerStyle(.menu)

                    if suggestedStudents.isEmpty && suggestedStudentGroups.isEmpty {
                        Text("Add students or saved classes/groups to reuse them in planner links here.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let support = studentSupport {
                        supportPreview(support)
                    }

                    TextField("Follow-Up Note (Optional)", text: $followUpNote, axis: .vertical)
                        .lineLimit(2...4)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction)
                }

                Section("Reminder") {
                    Picker("When to Re-surface", selection: $reminder) {
                        ForEach(TodoItem.Reminder.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                }

                Section("Recurrence") {
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(TodoItem.Recurrence.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    if recurrence == .weekly {
                        Picker("Day", selection: $recurrenceWeekday) {
                            ForEach(TodoItem.RecurrenceWeekday.allCases, id: \.self) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                    }
                }
                
                Section("Due Date") {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        clearDraft()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existing == nil ? "Add" : "Save") {
                        saveTodo()
                    }
                    .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let existing {
                    task = existing.task
                    priority = existing.priority
                    category = existing.category
                    bucket = existing.bucket
                    workspace = existing.workspace
                    classLink = existing.effectiveClassLink
                    studentGroupLink = existing.effectiveStudentGroupLink
                    studentLink = existing.effectiveStudentLink
                    followUpNote = existing.followUpNote
                    reminder = existing.reminder
                    recurrence = existing.recurrence
                    recurrenceWeekday = existing.recurrenceWeekday ?? defaultRecurrenceWeekday()

                    if let existingDueDate = existing.dueDate {
                        hasDueDate = true
                        dueDate = existingDueDate
                    } else {
                        hasDueDate = false
                        dueDate = Date()
                    }
                }
            }
            .onAppear {
                restoreDraftIfNeeded()
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

    private var taskOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "Capture the task clearly." : "Refine the task.")
                .font(.headline.weight(.semibold))

            Text("Set the workspace, timing, and links once so the planner stays actionable without extra cleanup later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                taskMetric(title: "Workspace", value: workspace.displayName, accent: ClassTraxSemanticColor.primaryAction)
                taskMetric(title: "Bucket", value: bucket.displayName, accent: ClassTraxSemanticColor.secondaryAction)
                taskMetric(title: "Category", value: category.displayName, accent: ClassTraxSemanticColor.reviewWarning)
                taskMetric(title: "Repeat", value: recurrence.displayName, accent: .indigo)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func taskMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private var studentSupport: StudentSupportProfile? {
        studentSupportsByName[studentLink.trimmingCharacters(in: .whitespacesAndNewlines)]
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
        .padding(12)
        .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 16)
    }
    
    private func saveTodo() {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newTodo = TodoItem(
            id: existing?.id ?? UUID(),
            task: trimmedTask,
            isCompleted: existing?.isCompleted ?? false,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            category: category,
            bucket: bucket,
            workspace: workspace,
            linkedContext: classLink.trimmingCharacters(in: .whitespacesAndNewlines),
            studentOrGroup: studentLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? studentGroupLink.trimmingCharacters(in: .whitespacesAndNewlines)
                : studentLink.trimmingCharacters(in: .whitespacesAndNewlines),
            classLink: classLink.trimmingCharacters(in: .whitespacesAndNewlines),
            studentGroupLink: studentGroupLink.trimmingCharacters(in: .whitespacesAndNewlines),
            studentLink: studentLink.trimmingCharacters(in: .whitespacesAndNewlines),
            followUpNote: followUpNote.trimmingCharacters(in: .whitespacesAndNewlines),
            reminder: reminder,
            recurrence: recurrence,
            recurrenceWeekday: recurrence == .weekly ? recurrenceWeekday : nil
        )
        
        if let existing,
           let index = todos.firstIndex(where: { $0.id == existing.id }) {
            todos[index] = newTodo
        } else {
            todos.append(newTodo)
        }

        clearDraft()
        dismiss()
    }

    private var currentDraft: Draft {
        Draft(
            existingID: existing?.id,
            task: task,
            priority: priority,
            category: category,
            bucket: bucket,
            workspace: workspace,
            classLink: classLink,
            studentGroupLink: studentGroupLink,
            studentLink: studentLink,
            followUpNote: followUpNote,
            reminder: reminder,
            recurrence: recurrence,
            recurrenceWeekday: recurrenceWeekday,
            hasDueDate: hasDueDate,
            dueDate: dueDate
        )
    }

    private func restoreDraftIfNeeded() {
        guard let draft = try? JSONDecoder().decode(Draft.self, from: savedDraftData) else { return }
        guard draft.existingID == existing?.id else { return }
        task = draft.task
        priority = draft.priority
        category = draft.category
        bucket = draft.bucket
        workspace = draft.workspace
        classLink = draft.classLink
        studentGroupLink = draft.studentGroupLink
        studentLink = draft.studentLink
        followUpNote = draft.followUpNote
        reminder = draft.reminder
        recurrence = draft.recurrence
        recurrenceWeekday = draft.recurrenceWeekday
        hasDueDate = draft.hasDueDate
        dueDate = draft.dueDate
    }

    private func persistDraft() {
        guard let encoded = try? JSONEncoder().encode(currentDraft) else { return }
        savedDraftData = encoded
    }

    private func clearDraft() {
        savedDraftData = Data()
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

    private func defaultRecurrenceWeekday() -> TodoItem.RecurrenceWeekday {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return TodoItem.RecurrenceWeekday(rawValue: weekday) ?? .monday
    }
}

#Preview {
    AddTodoView(
        todos: .constant([
            TodoItem(task: "Sample Task", priority: .med, dueDate: nil)
        ]),
        suggestedContexts: [],
        suggestedStudents: [],
        studentSupportsByName: [:]
    )
}
