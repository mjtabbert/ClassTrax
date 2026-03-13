//
//  AddTodoView.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 3:25 PM
//  Version: ClassCue Dev Build 11.3
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
    @State private var linkedContext = ""
    @State private var studentOrGroup = ""
    @State private var followUpNote = ""
    @State private var reminder = TodoItem.Reminder.none
    @State private var hasDueDate = false
    @State private var dueDate = Date()

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
