//
//  AddEditView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassTrax Dev Build 23
//

import SwiftUI
import SwiftData

struct AddEditView: View {
    @Binding var alarms: [AlarmItem]
    let studentProfiles: [StudentSupportProfile]
    let classDefinitions: [ClassDefinitionItem]

    let day: Int
    var existing: AlarmItem? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var room = ""
    @State private var grade = ""
    @State private var type = AlarmItem.ScheduleType.other
    @State private var selectedClassDefinitionID: UUID?
    @State private var availableClassDefinitions: [ClassDefinitionItem] = []

    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(60 * 30)
    @State private var linkedStudentIDs: Set<UUID> = []

    @State private var showDeleteConfirm = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private struct StudentRosterGroup: Identifiable {
        let key: String
        let className: String
        let gradeLevel: String
        let students: [StudentSupportProfile]

        var id: String { key }

        var title: String {
            let parts = [className, gradeLevel]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? "Unassigned Group" : parts.joined(separator: " - ")
        }
    }

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
            type: type,
            classDefinitionID: selectedClassDefinitionID,
            linkedStudentIDs: Array(linkedStudentIDs)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    PreviewCard(item: previewItem)
                }

                Section("Class Details") {
                    Picker("Saved Class", selection: $selectedClassDefinitionID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(availableClassDefinitions) { definition in
                            Text(definition.displayName).tag(Optional(definition.id))
                        }
                    }

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

                    if selectedClassDefinitionID == nil, !candidateClassDefinitions.isEmpty {
                        Picker("Suggested Match", selection: $selectedClassDefinitionID) {
                            Text("No Match").tag(Optional<UUID>.none)
                            ForEach(candidateClassDefinitions) { definition in
                                Text(definition.displayName).tag(Optional(definition.id))
                            }
                        }
                    }
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

                if !sortedStudentProfiles.isEmpty {
                    Section("Linked Roster") {
                        if !suggestedRosterGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Suggested groups for this block")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(suggestedRosterGroups) { group in
                                    rosterGroupRow(group)
                                }
                            }
                        }

                        if !allRosterGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Roster groups")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(remainingRosterGroups) { group in
                                    rosterGroupRow(group)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            if !suggestedStudents.isEmpty || !suggestedRosterGroups.isEmpty {
                                Text("Individual students")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(sortedStudentProfiles) { profile in
                                studentToggleRow(profile)
                            }
                        }
                    }
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
                prepareAvailableClassDefinitions()
                configureInitialValues()
            }
            .onChange(of: classDefinitions) { _, newValue in
                if !newValue.isEmpty {
                    availableClassDefinitions = sortedUniqueClassDefinitions(newValue)
                }
            }
            .onChange(of: selectedClassDefinitionID) { _, newValue in
                applySelectedClassDefinition(newValue)
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
            selectedClassDefinitionID = existing.classDefinitionID ?? exactClassDefinitionMatch(
                name: existing.className,
                gradeLevel: existing.gradeLevel,
                in: availableClassDefinitions
            )?.id
            start = existing.startTime
            end = existing.endTime
            linkedStudentIDs = Set(existing.linkedStudentIDs)
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
            type: type,
            classDefinitionID: resolvedClassDefinitionID(trimmedName: trimmedName, trimmedGrade: trimmedGrade),
            linkedStudentIDs: Array(linkedStudentIDs)
        )

        if let existing,
           let index = alarms.firstIndex(where: { $0.id == existing.id }) {
            var updatedAlarms = alarms
            updatedAlarms[index] = newItem
            alarms = sortedAlarms(updatedAlarms)
        } else {
            alarms = sortedAlarms(alarms + [newItem])
        }
        dismiss()
    }

    private func deleteCurrentBlock() {
        guard let existing else { return }
        alarms = alarms.filter { $0.id != existing.id }
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
            type: existing.type,
            classDefinitionID: existing.classDefinitionID,
            linkedStudentIDs: existing.linkedStudentIDs
        )

        alarms = sortedAlarms(alarms + [duplicated])
        dismiss()
    }

    private func sortedAlarms(_ items: [AlarmItem]) -> [AlarmItem] {
        items.sorted { lhs, rhs in
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

    private var sortedStudentProfiles: [StudentSupportProfile] {
        studentProfiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedClassDefinition: ClassDefinitionItem? {
        guard let selectedClassDefinitionID else { return nil }
        return availableClassDefinitions.first { $0.id == selectedClassDefinitionID }
    }

    private var candidateClassDefinitions: [ClassDefinitionItem] {
        guard selectedClassDefinitionID == nil else { return [] }
        return classDefinitionCandidates(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gradeLevel: grade,
            in: availableClassDefinitions
        )
    }

    private var suggestedStudents: [StudentSupportProfile] {
        let normalizedGrade = GradeLevelOption.normalized(grade)
        let typeName = selectedClassDefinition?.name ?? type.displayName
        return sortedStudentProfiles.filter { profile in
            matchesCurrentClassDefinition(profile: profile, fallbackClassName: typeName) &&
            (
                normalizedGrade.isEmpty ||
                profile.gradeLevel.isEmpty ||
                normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel)) == normalizedStudentKey(normalizedGrade)
            )
        }
    }

    private var allRosterGroups: [StudentRosterGroup] {
        let grouped = Dictionary(grouping: sortedStudentProfiles) { profile in
            let classKey = normalizedClassKey(profile.className)
            let gradeKey = normalizedStudentKey(GradeLevelOption.normalized(profile.gradeLevel))
            return "\(classKey)|\(gradeKey)"
        }

        return grouped.compactMap { key, students in
            guard let first = students.first else { return nil }
            return StudentRosterGroup(
                key: key,
                className: first.className,
                gradeLevel: GradeLevelOption.normalized(first.gradeLevel),
                students: students.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var suggestedRosterGroups: [StudentRosterGroup] {
        let normalizedGrade = normalizedStudentKey(GradeLevelOption.normalized(grade))
        let typeName = selectedClassDefinition?.name ?? type.displayName

        return allRosterGroups.filter { group in
            matchesCurrentGroup(group, fallbackClassName: typeName) &&
            (
                normalizedGrade.isEmpty ||
                group.gradeLevel.isEmpty ||
                normalizedStudentKey(group.gradeLevel) == normalizedGrade
            )
        }
    }

    private var remainingRosterGroups: [StudentRosterGroup] {
        let suggestedKeys = Set(suggestedRosterGroups.map(\.key))
        return allRosterGroups.filter { !suggestedKeys.contains($0.key) }
    }

    @ViewBuilder
    private func studentToggleRow(_ profile: StudentSupportProfile) -> some View {
        let isSelected = linkedStudentIDs.contains(profile.id)
        Button {
            if isSelected {
                linkedStudentIDs.remove(profile.id)
            } else {
                linkedStudentIDs.insert(profile.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .foregroundStyle(.primary)

                    let detail = [profile.className, profile.gradeLevel]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")

                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func rosterGroupRow(_ group: StudentRosterGroup) -> some View {
        let groupIDs = Set(group.students.map(\.id))
        let selectedCount = linkedStudentIDs.intersection(groupIDs).count
        let isFullySelected = selectedCount == group.students.count

        Button {
            if isFullySelected {
                linkedStudentIDs.subtract(groupIDs)
            } else {
                linkedStudentIDs.formUnion(groupIDs)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isFullySelected ? "checkmark.circle.fill" : "circle.circle")
                    .foregroundStyle(isFullySelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .foregroundStyle(.primary)

                    Text("\(group.students.count) student\(group.students.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applySelectedClassDefinition(_ id: UUID?) {
        guard let id, let definition = availableClassDefinitions.first(where: { $0.id == id }) else { return }
        name = definition.name
        type = AlarmItem.ScheduleType(rawValue: definition.scheduleKind.rawValue) ?? .other
        grade = GradeLevelOption.normalized(definition.gradeLevel)
        if room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            room = definition.defaultLocation
        }
    }

    private func resolvedClassDefinitionID(trimmedName: String, trimmedGrade: String) -> UUID? {
        if let selectedClassDefinitionID {
            return selectedClassDefinitionID
        }

        return exactClassDefinitionMatch(
            name: trimmedName,
            gradeLevel: trimmedGrade,
            in: availableClassDefinitions
        )?.id
    }

    private func matchesCurrentClassDefinition(profile: StudentSupportProfile, fallbackClassName: String) -> Bool {
        if let selectedClassDefinitionID {
            return profile.classDefinitionID == selectedClassDefinitionID
        }

        return classNamesMatch(scheduleClassName: fallbackClassName, profileClassName: profile.className)
    }

    private func matchesCurrentGroup(_ group: StudentRosterGroup, fallbackClassName: String) -> Bool {
        if let selectedClassDefinitionID {
            return group.students.contains { $0.classDefinitionID == selectedClassDefinitionID }
        }

        return classNamesMatch(scheduleClassName: fallbackClassName, profileClassName: group.className)
    }

    private func prepareAvailableClassDefinitions() {
        if !availableClassDefinitions.isEmpty { return }
        if !classDefinitions.isEmpty {
            availableClassDefinitions = sortedUniqueClassDefinitions(classDefinitions)
            return
        }

        // Fallback to persistence if the live binding hasn't hydrated yet.
        let snapshot = ClassTraxPersistence.loadFirstSlice(from: modelContext)
        availableClassDefinitions = sortedUniqueClassDefinitions(snapshot.classDefinitions)
    }

    private func sortedUniqueClassDefinitions(_ items: [ClassDefinitionItem]) -> [ClassDefinitionItem] {
        var seen = Set<UUID>()
        let deduped = items.filter { item in
            if seen.contains(item.id) { return false }
            seen.insert(item.id)
            return true
        }
        return deduped.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
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
