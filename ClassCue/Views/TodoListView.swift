//
//  TodoListView.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 3:20 PM
//  Version: ClassCue Dev Build 11.2
//

import SwiftUI

struct TodoListView: View {
    
    @Binding var todos: [TodoItem]
    
    @State private var showAdd = false
    @State private var editingTodo: TodoItem?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedTodos) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? .green : item.priority.color)
                            .font(.title3)
                            .onTapGesture {
                                toggleCompletion(for: item)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.task)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .secondary : .primary)
                            
                            Text(dueDateText(for: item))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("Priority: \(item.priority.rawValue)")
                                .font(.caption2)
                                .foregroundColor(item.priority.color)
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
                }
                .onDelete(perform: deleteTodo)
            }
            .navigationTitle("To Do")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if todos.contains(where: { $0.isCompleted }) {
                        Button("Clear Done") {
                            todos.removeAll { $0.isCompleted }
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTodoView(todos: $todos)
            }
            .sheet(item: $editingTodo) { todo in
                AddTodoView(todos: $todos, existing: todo)
            }
        }
    }
    
    private var sortedTodos: [TodoItem] {
        todos.sorted { a, b in
            if a.isCompleted != b.isCompleted {
                return !a.isCompleted
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
    
    private func toggleCompletion(for item: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == item.id }) {
            todos[index].isCompleted.toggle()
        }
    }
    
    private func deleteTodo(at offsets: IndexSet) {
        let sorted = sortedTodos
        let idsToDelete = offsets.map { sorted[$0].id }
        todos.removeAll { idsToDelete.contains($0.id) }
    }
    
    private func dueDateText(for item: TodoItem) -> String {
        if let due = item.dueDate {
            return "Due: \(due.formatted(date: .abbreviated, time: .omitted))"
        } else {
            return "No due date"
        }
    }
}

#Preview {
    TodoListView(
        todos: .constant([
            TodoItem(task: "Prep math lesson", priority: .high, dueDate: Date()),
            TodoItem(task: "Print spelling sheets", isCompleted: true, priority: .low, dueDate: nil),
            TodoItem(task: "Email parent update", priority: .med, dueDate: nil)
        ])
    )
}

