//
//  DebugView.swift
//  ClassCue
//
//  Created by Mike Tabbert on 3/10/26.
//


//
//  DebugView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI

struct DebugView: View {
    @AppStorage("timer_v6_data") private var savedAlarms: Data = Data()
    @AppStorage("todo_v6_data") private var savedTodos: Data = Data()
    @AppStorage("notes_v1") private var savedNotes: String = ""
    @AppStorage("ignore_until_v1") private var ignoreUntil: Double = 0
    @AppStorage("pref_haptic") private var selectedHapticRawValue: String = ""
    @AppStorage("pref_sound") private var selectedSoundRawValue: String = ""

    @State private var alarms: [AlarmItem] = []
    @State private var todos: [TodoItem] = []

    var body: some View {
        NavigationStack {
            List {
                Section("App State") {
                    LabeledContent("Alarm Count", value: "\(alarms.count)")
                    LabeledContent("Todo Count", value: "\(todos.count)")
                    LabeledContent("Notes Length", value: "\(savedNotes.count)")
                    LabeledContent("Haptic", value: selectedHapticRawValue)
                    LabeledContent("Sound", value: selectedSoundRawValue)

                    if ignoreUntil > Date().timeIntervalSince1970 {
                        LabeledContent(
                            "Holiday Mode",
                            value: Date(timeIntervalSince1970: ignoreUntil)
                                .formatted(date: .abbreviated, time: .shortened)
                        )
                    } else {
                        LabeledContent("Holiday Mode", value: "Off")
                    }
                }

                Section("Loaded Schedule") {
                    if alarms.isEmpty {
                        Text("No alarms loaded.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(alarms.sorted { lhs, rhs in
                            if lhs.dayOfWeek == rhs.dayOfWeek {
                                return lhs.startTime < rhs.startTime
                            }
                            return lhs.dayOfWeek < rhs.dayOfWeek
                        }) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.className)
                                    .font(.headline)

                                Text("Day: \(item.dayOfWeek)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if !item.gradeLevel.isEmpty {
                                    Text("Grade: \(item.gradeLevel)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if !item.location.isEmpty {
                                    Text("Location: \(item.location)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text("Type: \(String(describing: item.type))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Loaded To Do Items") {
                    if todos.isEmpty {
                        Text("No todos loaded.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(todos) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.task)
                                    .font(.headline)

                                Text("Completed: \(item.isCompleted ? "Yes" : "No")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Priority: \(item.priority.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let due = item.dueDate {
                                    Text("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Due: None")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Debug")
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        if let decodedAlarms = try? JSONDecoder().decode([AlarmItem].self, from: savedAlarms) {
            alarms = decodedAlarms
        } else {
            alarms = []
        }

        if let decodedTodos = try? JSONDecoder().decode([TodoItem].self, from: savedTodos) {
            todos = decodedTodos
        } else {
            todos = []
        }
    }
}