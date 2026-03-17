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
    let studentSupportsByName: [String: StudentSupportProfile]
    
    var existing: TodoItem? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var task = ""
    @State private var priority = TodoItem.Priority.none
    @State private var category = TodoItem.Category.prep
    @State private var bucket = TodoItem.Bucket.today
    @State private var workspace = TodoItem.Workspace.school
    @State private var linkedContext = ""
    @State private var studentOrGroup = ""
    @State private var followUpNote = ""
    @State private var reminder = TodoItem.Reminder.none
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @AppStorage("school_quiet_hours_enabled") private var schoolQuietHoursEnabled = false
    @AppStorage("school_quiet_hour") private var schoolQuietHour = 16
    @AppStorage("school_quiet_minute") private var schoolQuietMinute = 0
    @AppStorage("school_default_personal_capture_after_hours") private var defaultPersonalCaptureAfterHours = true

    init(
        todos: Binding<[TodoItem]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        studentSupportsByName: [String: StudentSupportProfile] = [:],
        existing: TodoItem? = nil
    ) {
        _todos = todos
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
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
                Section("Task Details") {
                    TextField("Task Name", text: $task)

                    Picker("Category", selection: $category) {
                        ForEach(TodoItem.Category.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }

                    Picker("When", selection: $bucket) {
                        ForEach(TodoItem.Bucket.allCases, id: \.self) { bucket in
                            Text(bucket.displayName).tag(bucket)
                        }
                    }

                    Picker("Workspace", selection: $workspace) {
                        ForEach(TodoItem.Workspace.allCases, id: \.self) { workspace in
                            Label(workspace.displayName, systemImage: workspace.systemImage)
                                .tag(workspace)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }

                    TextField("Linked Class or Commitment (Optional)", text: $linkedContext)

                    if !suggestedContexts.isEmpty {
                        Picker("Suggested Link", selection: $linkedContext) {
                            Text("None").tag("")
                            ForEach(suggestedContexts, id: \.self) { context in
                                Text(context).tag(context)
                            }
                        }
                    }

                    TextField("Student or Group (Optional)", text: $studentOrGroup)

                    if !suggestedStudents.isEmpty {
                        Picker("Saved Student / Group", selection: $studentOrGroup) {
                            Text("None").tag("")
                            ForEach(suggestedStudents, id: \.self) { student in
                                Text(student).tag(student)
                            }
                        }
                    } else {
                        Text("Add names in Settings > Student Directory to use a prefilled student picker here.")
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
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTodo()
                    }
                    .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existing {
                    task = existing.task
                    priority = existing.priority
                    category = existing.category
                    bucket = existing.bucket
                    workspace = existing.workspace
                    linkedContext = existing.linkedContext
                    studentOrGroup = existing.studentOrGroup
                    followUpNote = existing.followUpNote
                    reminder = existing.reminder

                    if let existingDueDate = existing.dueDate {
                        hasDueDate = true
                        dueDate = existingDueDate
                    } else {
                        hasDueDate = false
                        dueDate = Date()
                    }
                }
            }
        }
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
            linkedContext: linkedContext.trimmingCharacters(in: .whitespacesAndNewlines),
            studentOrGroup: studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines),
            followUpNote: followUpNote.trimmingCharacters(in: .whitespacesAndNewlines),
            reminder: reminder
        )
        
        if let existing,
           let index = todos.firstIndex(where: { $0.id == existing.id }) {
            todos[index] = newTodo
        } else {
            todos.append(newTodo)
        }
        
        dismiss()
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
