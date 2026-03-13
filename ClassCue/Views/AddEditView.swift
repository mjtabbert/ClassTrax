//
//  AddEditView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI

struct AddEditView: View {
    @Binding var alarms: [AlarmItem]

    let day: Int
    var existing: AlarmItem? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var room = ""
    @State private var grade = ""
    @State private var type = AlarmItem.ScheduleType.other

    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(60 * 30)

    @State private var showDeleteConfirm = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private var isEditing: Bool {
        existing != nil
    }

    private var saveButtonTitle: String {
        isEditing ? "Save Changes" : "Save Block"
    }

    private var previewItem: AlarmItem {
        AlarmItem(
            id: existing?.id ?? UUID(),
            dayOfWeek: day,
            className: previewNameText,
            location: room.trimmingCharacters(in: .whitespacesAndNewlines),
            gradeLevel: grade.trimmingCharacters(in: .whitespacesAndNewlines),
            startTime: start,
            endTime: end,
            type: type
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    PreviewCard(item: previewItem)
                }

                Section("Class Details") {
                    TextField("Class Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AlarmItem.ScheduleType.allCases, id: \.self) { itemType in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(itemType.themeColor)
                                    .frame(width: 10, height: 10)

                                Text(itemType.displayName)
                            }
                            .tag(itemType)
                        }
                    }

                    Picker("Grade Level", selection: $grade) {
                        Text("None").tag("")
                        ForEach(GradeLevelOption.optionsForPicker(), id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }

                    TextField("Room / Location", text: $room)
                }

                Section("Timing") {
                    DatePicker(
                        "Start Time",
                        selection: $start,
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "End Time",
                        selection: $end,
                        displayedComponents: .hourAndMinute
                    )
                }

                if isEditing {
                    Section("More Actions") {
                        Button {
                            duplicateCurrentBlock()
                        } label: {
                            Label("Duplicate Block", systemImage: "plus.square.on.square")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Block", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Block" : "Add Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                configureInitialValues()
            }
            .alert("Unable to Save", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
            .confirmationDialog(
                "Delete this block?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Block", role: .destructive) {
                    deleteCurrentBlock()
                }

                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var previewNameText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Block" : trimmed
    }

    private func configureInitialValues() {
        if let existing {
            name = existing.className
            room = existing.location
            grade = GradeLevelOption.normalized(existing.gradeLevel)
            type = existing.type
            start = existing.startTime
            end = existing.endTime
        } else {
            let roundedStart = roundedDate(from: Date())
            let defaultEnd = Calendar.current.date(byAdding: .minute, value: 30, to: roundedStart) ?? roundedStart.addingTimeInterval(1800)

            start = roundedStart
            end = defaultEnd
        }
    }

    private func saveItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRoom = room.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGrade = GradeLevelOption.normalized(grade)

        guard !trimmedName.isEmpty else {
            validationMessage = "Please enter a class name before saving."
            showValidationAlert = true
            return
        }

        guard end > start else {
            validationMessage = "End time must be later than start time."
            showValidationAlert = true
            return
        }

        let newItem = AlarmItem(
            id: existing?.id ?? UUID(),
            dayOfWeek: day,
            className: trimmedName,
            location: trimmedRoom,
            gradeLevel: trimmedGrade,
            startTime: start,
            endTime: end,
            type: type
        )

        if let existing,
           let index = alarms.firstIndex(where: { $0.id == existing.id }) {
            alarms[index] = newItem
        } else {
            alarms.append(newItem)
        }

        sortAlarms()
        dismiss()
    }

    private func deleteCurrentBlock() {
        guard let existing else { return }
        alarms.removeAll { $0.id == existing.id }
        dismiss()
    }

    private func duplicateCurrentBlock() {
        guard let existing else { return }

        let duration = existing.endTime.timeIntervalSince(existing.startTime)
        let newStart = existing.endTime
        let newEnd = newStart.addingTimeInterval(duration)

        let duplicated = AlarmItem(
            id: UUID(),
            dayOfWeek: existing.dayOfWeek,
            className: existing.className,
            location: existing.location,
            gradeLevel: existing.gradeLevel,
            startTime: newStart,
            endTime: newEnd,
            type: existing.type
        )

        alarms.append(duplicated)
        sortAlarms()
        dismiss()
    }

    private func sortAlarms() {
        alarms.sort { lhs, rhs in
            if lhs.dayOfWeek == rhs.dayOfWeek {
                return lhs.startTime < rhs.startTime
            }
            return lhs.dayOfWeek < rhs.dayOfWeek
        }
    }

    private func roundedDate(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        let minute = components.minute ?? 0
        let roundedMinute = minute < 30 ? 0 : 30

        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: components.hour,
                minute: roundedMinute
            )
        ) ?? date
    }
}

private struct PreviewCard: View {
    let item: AlarmItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(compactTimeRange(start: item.startTime, end: item.endTime))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Text(item.typeLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(item.type == .lunch ? .black : item.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(item.type == .lunch ? item.accentColor.opacity(0.88) : item.accentColor.opacity(0.16))
                    )
            }
            .frame(width: 140, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.className)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    if !item.gradeLevel.isEmpty {
                        Text(item.gradeLevel)
                    }

                    if !item.location.isEmpty {
                        Text("•")
                        Text(item.location)
                    }
                }
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func compactTimeRange(start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let endHour = calendar.component(.hour, from: end)

        let startMinute = calendar.component(.minute, from: start)
        let endMinute = calendar.component(.minute, from: end)

        let startIsAM = startHour < 12
        let endIsAM = endHour < 12

        let startDisplayHour = displayHour(startHour)
        let endDisplayHour = displayHour(endHour)

        let startString = "\(startDisplayHour):\(String(format: "%02d", startMinute))"
        let endString = "\(endDisplayHour):\(String(format: "%02d", endMinute))"

        if startIsAM == endIsAM {
            return "\(startString) - \(endString) \(startIsAM ? "AM" : "PM")"
        } else {
            return "\(startString) \(startIsAM ? "AM" : "PM") - \(endString) \(endIsAM ? "AM" : "PM")"
        }
    }

    private func displayHour(_ hour: Int) -> Int {
        let mod = hour % 12
        return mod == 0 ? 12 : mod
    }
}
