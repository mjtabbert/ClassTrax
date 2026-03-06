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
    
    var existing: TodoItem? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var task = ""
    @State private var priority = TodoItem.Priority.none
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Task Name", text: $task)
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
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
    
    private func saveTodo() {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newTodo = TodoItem(
            id: existing?.id ?? UUID(),
            task: trimmedTask,
            isCompleted: existing?.isCompleted ?? false,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil
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
        ])
    )
}
