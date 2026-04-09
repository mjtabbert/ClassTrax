import SwiftUI

struct TodayStudentLookupSession: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let students: [StudentSupportProfile]
}

enum TodayGroupActionKind: String {
    case rollCall
    case homework
    case students

    var title: String {
        switch self {
        case .rollCall: return "Attendance"
        case .homework: return "Homework"
        case .students: return "Students"
        }
    }

    var systemImage: String {
        switch self {
        case .rollCall: return "checklist.checked"
        case .homework: return "text.book.closed"
        case .students: return "person.text.rectangle"
        }
    }
}

struct TodayGroupActionSession: Identifiable {
    struct Selection: Identifiable {
        let id = UUID()
        let itemID: UUID
        let action: TodayGroupActionKind
        let classDefinitionID: UUID
        let title: String
        let studentCount: Int

        var subtitle: String {
            studentCount == 0
                ? "No students linked yet"
                : "\(studentCount) student\(studentCount == 1 ? "" : "s") linked"
        }

        var isEnabled: Bool {
            switch action {
            case .homework:
                return true
            case .rollCall, .students:
                return studentCount > 0
            }
        }
    }

    let id = UUID()
    let action: TodayGroupActionKind
    let choices: [Selection]

    var title: String {
        "Choose Group for \(action.title)"
    }

    var helperText: String {
        switch action {
        case .rollCall:
            return "Pick the linked group you want to mark for attendance."
        case .homework:
            return "Pick the linked group you want to edit homework for."
        case .students:
            return "Pick the linked group you want to review students for."
        }
    }
}

struct TodayGroupActionPickerView: View {
    let session: TodayGroupActionSession
    let onChoose: (TodayGroupActionSession.Selection) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text(session.helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(session.choices) { selection in
                    Button {
                        onChoose(selection)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: session.action.systemImage)
                                .foregroundStyle(selection.isEnabled ? Color.accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.title)
                                    .foregroundStyle(selection.isEnabled ? .primary : .secondary)

                                Text(selection.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(!selection.isEnabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

struct TodayStudentLookupView: View {
    let session: TodayStudentLookupSession
    let onSelect: (StudentSupportProfile) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List(filteredStudents) { profile in
            Button {
                onSelect(profile)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .fontWeight(.semibold)

                        if !profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(GradeLevelOption.pillLabel(for: profile.gradeLevel))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(GradeLevelOption.foregroundColor(for: profile.gradeLevel))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GradeLevelOption.color(for: profile.gradeLevel), in: Capsule(style: .continuous))
                        }
                    }

                    Text(studentLookupSummary(for: profile))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search students")
        .safeAreaInset(edge: .top) {
            if !session.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(session.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var filteredStudents: [StudentSupportProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return session.students }

        return session.students.filter { profile in
            profile.name.localizedCaseInsensitiveContains(query) ||
            profile.className.localizedCaseInsensitiveContains(query) ||
            profile.gradeLevel.localizedCaseInsensitiveContains(query) ||
            profile.accommodations.localizedCaseInsensitiveContains(query) ||
            profile.prompts.localizedCaseInsensitiveContains(query)
        }
    }

    private func studentLookupSummary(for profile: StudentSupportProfile) -> String {
        let parts = [
            profile.className.trimmingCharacters(in: .whitespacesAndNewlines),
            GradeLevelOption.normalized(profile.gradeLevel),
            profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines),
            profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        return parts.isEmpty ? "Open student quick view" : parts.joined(separator: " • ")
    }
}

struct StudentQuickView: View {
    let profile: StudentSupportProfile
    let classDefinitions: [ClassDefinitionItem]
    let teacherContacts: [ClassStaffContact]
    let paraContacts: [ClassStaffContact]
    let onEdit: () -> Void
    let onOpenStudents: () -> Void
    let onOpenRecord: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title3.weight(.bold))

                            Text(primaryClassOrGroupLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !profile.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(GradeLevelOption.pillLabel(for: profile.gradeLevel))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GradeLevelOption.foregroundColor(for: profile.gradeLevel))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(GradeLevelOption.color(for: profile.gradeLevel), in: Capsule(style: .continuous))
                        }
                    }

                    if !linkedClassesOrGroups.isEmpty {
                        Text(linkedClassesOrGroups.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        quickMetric(title: "Groups", value: "\(linkedGroupCount)", tint: .blue)
                        quickMetric(title: "Teachers", value: "\(resolvedTeacherNames.count)", tint: .green)
                        quickMetric(title: "Paras", value: "\(resolvedParaNames.count)", tint: .orange)
                    }
                }
                .padding(.vertical, 4)
            }

            if !supportSummaryLines.isEmpty {
                Section("Supports") {
                    ForEach(supportSummaryLines, id: \.self) { line in
                        Text(line)
                    }
                }
            }

            if !profile.accommodations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Accommodations") {
                    Text(profile.accommodations)
                }
            }

            if !profile.prompts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Prompts") {
                    Text(profile.prompts)
                }
            }

            if !contactSummaryLines.isEmpty {
                Section("Contacts") {
                    ForEach(contactSummaryLines, id: \.self) { line in
                        Text(line)
                    }
                }
            }

            Section("Actions") {
                Button("Edit Student") {
                    dismiss()
                    onEdit()
                }

                Button("Open Notes") {
                    dismiss()
                    onOpenRecord()
                }

                Button("Open Students & Supports") {
                    dismiss()
                    onOpenStudents()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Student Quick View")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var linkedGroupCount: Int {
        max(linkedClassesOrGroups.count, profile.classDefinitionIDs.isEmpty ? 0 : profile.classDefinitionIDs.count)
    }

    private var primaryClassOrGroupLabel: String {
        if let first = linkedClassesOrGroups.first {
            return first
        }
        let className = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        return className.isEmpty ? "No class or group linked yet" : className
    }

    private var linkedClassesOrGroups: [String] {
        let namesFromDefinitions = classDefinitions
            .filter { profile.classDefinitionIDs.contains($0.id) || profile.classDefinitionID == $0.id }
            .map(\.displayName)
        if !namesFromDefinitions.isEmpty {
            return namesFromDefinitions.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }

        let className = profile.className.trimmingCharacters(in: .whitespacesAndNewlines)
        return className.isEmpty ? [] : [className]
    }

    private var resolvedTeacherNames: [String] {
        teacherContacts
            .filter { profile.supportTeacherIDs.contains($0.id) }
            .map(\.trimmedName)
            .filter { !$0.isEmpty }
    }

    private var resolvedParaNames: [String] {
        paraContacts
            .filter { profile.supportParaIDs.contains($0.id) }
            .map(\.trimmedName)
            .filter { !$0.isEmpty }
    }

    private var supportSummaryLines: [String] {
        var lines: [String] = []
        if !resolvedTeacherNames.isEmpty {
            lines.append("Teachers: \(resolvedTeacherNames.joined(separator: ", "))")
        }
        if !resolvedParaNames.isEmpty {
            lines.append("Paras: \(resolvedParaNames.joined(separator: ", "))")
        }
        let rooms = profile.supportRooms.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rooms.isEmpty {
            lines.append("Support Rooms: \(rooms)")
        }
        let scheduleNotes = profile.supportScheduleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scheduleNotes.isEmpty {
            lines.append("Support Schedule: \(scheduleNotes)")
        }
        return lines
    }

    private var contactSummaryLines: [String] {
        [
            labeledLine("Parent / Guardian", profile.parentNames),
            labeledLine("Parent Phone", profile.parentPhoneNumbers),
            labeledLine("Parent Email", profile.parentEmails),
            labeledLine("Student Email", profile.studentEmail)
        ].compactMap { $0 }
    }

    private func labeledLine(_ label: String, _ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : "\(label): \(trimmed)"
    }

    private func quickMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}
