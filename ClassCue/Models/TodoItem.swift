//
//  TodoItem.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 3:05 PM
//  Version: ClassTrax Dev Build 11.1
//

import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {

    var id = UUID()
    var task: String
    var isCompleted: Bool = false
    var priority: Priority = .none
    var dueDate: Date? = nil
    var category: Category = .prep
    var bucket: Bucket = .today
    var workspace: Workspace = .school
    var linkedContext: String = ""
    var studentOrGroup: String = ""
    var classLink: String = ""
    var studentGroupLink: String = ""
    var studentLink: String = ""
    var followUpNote: String = ""
    var reminder: Reminder = .none
    var recurrence: Recurrence = .none
    var recurrenceWeekday: RecurrenceWeekday? = nil
    var recurrenceLastCompletedDateKey: String? = nil

    enum Priority: String, Codable, CaseIterable {

        case high = "High"
        case med = "Med"
        case low = "Low"
        case none = "None"

        var color: Color {
            switch self {
            case .high: return .red
            case .med: return .orange
            case .low: return .blue
            case .none: return .gray
            }
        }
    }

    enum Category: String, Codable, CaseIterable {
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
            case .prep: return "Prep"
            case .grading: return "Grading"
            case .parentContact: return "Parent Contact"
            case .copies: return "Copies"
            case .meetingFollowUp: return "Meeting Follow-Up"
            case .admin: return "Admin"
            case .classroom: return "Classroom"
            case .other: return "Other"
            }
        }

        var systemImage: String {
            switch self {
            case .prep: return "backpack.fill"
            case .grading: return "checkmark.rectangle.stack.fill"
            case .parentContact: return "phone.fill"
            case .copies: return "doc.on.doc.fill"
            case .meetingFollowUp: return "person.2.fill"
            case .admin: return "tray.full.fill"
            case .classroom: return "studentdesk"
            case .other: return "square.grid.2x2.fill"
            }
        }

        var tint: Color {
            switch self {
            case .prep: return .blue
            case .grading: return .green
            case .parentContact: return .pink
            case .copies: return .orange
            case .meetingFollowUp: return .purple
            case .admin: return .teal
            case .classroom: return .indigo
            case .other: return .gray
            }
        }
    }

    enum Bucket: String, Codable, CaseIterable {
        case today
        case tomorrow
        case thisWeek
        case later

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .thisWeek: return "This Week"
            case .later: return "Later"
            }
        }
    }

    enum Workspace: String, Codable, CaseIterable {
        case school
        case personal

        var displayName: String {
            switch self {
            case .school: return "School"
            case .personal: return "Personal"
            }
        }

        var systemImage: String {
            switch self {
            case .school: return "building.2.fill"
            case .personal: return "house.fill"
            }
        }

        var tint: Color {
            switch self {
            case .school: return .blue
            case .personal: return .green
            }
        }
    }

    enum Reminder: String, Codable, CaseIterable {
        case none
        case afterSchool
        case tomorrowMorning

        var displayName: String {
            switch self {
            case .none: return "None"
            case .afterSchool: return "After School"
            case .tomorrowMorning: return "Tomorrow Morning"
            }
        }

        var systemImage: String {
            switch self {
            case .none: return "bell.slash"
            case .afterSchool: return "sunset.fill"
            case .tomorrowMorning: return "sunrise.fill"
            }
        }

        var tint: Color {
            switch self {
            case .none: return .secondary
            case .afterSchool: return .indigo
            case .tomorrowMorning: return .orange
            }
        }
    }

    enum Recurrence: String, Codable, CaseIterable {
        case none
        case daily
        case weekdays
        case weekly

        var displayName: String {
            switch self {
            case .none: return "None"
            case .daily: return "Daily"
            case .weekdays: return "Weekdays"
            case .weekly: return "Weekly"
            }
        }
    }

    enum RecurrenceWeekday: Int, Codable, CaseIterable {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7

        var displayName: String {
            switch self {
            case .sunday: return "Sunday"
            case .monday: return "Monday"
            case .tuesday: return "Tuesday"
            case .wednesday: return "Wednesday"
            case .thursday: return "Thursday"
            case .friday: return "Friday"
            case .saturday: return "Saturday"
            }
        }
    }

    init(
        id: UUID = UUID(),
        task: String,
        isCompleted: Bool = false,
        priority: Priority = .none,
        dueDate: Date? = nil,
        category: Category = .prep,
        bucket: Bucket = .today,
        workspace: Workspace = .school,
        linkedContext: String = "",
        studentOrGroup: String = "",
        classLink: String = "",
        studentGroupLink: String = "",
        studentLink: String = "",
        followUpNote: String = "",
        reminder: Reminder = .none,
        recurrence: Recurrence = .none,
        recurrenceWeekday: RecurrenceWeekday? = nil,
        recurrenceLastCompletedDateKey: String? = nil
    ) {
        self.id = id
        self.task = task
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.category = category
        self.bucket = bucket
        self.workspace = workspace
        let normalizedClassLink = classLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStudentGroup = studentGroupLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStudentLink = studentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLegacyContext = linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLegacyStudent = studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        self.classLink = normalizedClassLink.isEmpty ? normalizedLegacyContext : normalizedClassLink
        self.studentGroupLink = normalizedStudentGroup
        self.studentLink = normalizedStudentLink
        self.linkedContext = self.classLink
        self.studentOrGroup = !self.studentLink.isEmpty
            ? self.studentLink
            : (!self.studentGroupLink.isEmpty ? self.studentGroupLink : normalizedLegacyStudent)
        self.followUpNote = followUpNote
        self.reminder = reminder
        self.recurrence = recurrence
        self.recurrenceWeekday = recurrence == .weekly ? recurrenceWeekday : nil
        self.recurrenceLastCompletedDateKey = recurrenceLastCompletedDateKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        task = try container.decode(String.self, forKey: .task)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .none
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .prep
        bucket = try container.decodeIfPresent(Bucket.self, forKey: .bucket) ?? .today
        workspace = try container.decodeIfPresent(Workspace.self, forKey: .workspace) ?? .school
        linkedContext = try container.decodeIfPresent(String.self, forKey: .linkedContext) ?? ""
        studentOrGroup = try container.decodeIfPresent(String.self, forKey: .studentOrGroup) ?? ""
        classLink = try container.decodeIfPresent(String.self, forKey: .classLink) ?? linkedContext
        studentGroupLink = try container.decodeIfPresent(String.self, forKey: .studentGroupLink) ?? ""
        studentLink = try container.decodeIfPresent(String.self, forKey: .studentLink) ?? ""
        if studentLink.isEmpty && studentGroupLink.isEmpty {
            studentLink = studentOrGroup
        }
        followUpNote = try container.decodeIfPresent(String.self, forKey: .followUpNote) ?? ""
        reminder = try container.decodeIfPresent(Reminder.self, forKey: .reminder) ?? .none
        recurrence = try container.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
        recurrenceWeekday = try container.decodeIfPresent(RecurrenceWeekday.self, forKey: .recurrenceWeekday)
        recurrenceLastCompletedDateKey = try container.decodeIfPresent(String.self, forKey: .recurrenceLastCompletedDateKey)
        if recurrence != .weekly {
            recurrenceWeekday = nil
        }
    }

    var effectiveClassLink: String {
        let explicit = classLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        return linkedContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveStudentGroupLink: String {
        studentGroupLink.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var effectiveStudentLink: String {
        let explicit = studentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        if effectiveStudentGroupLink.isEmpty {
            return studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    var effectiveStudentOrGroup: String {
        let student = effectiveStudentLink
        if !student.isEmpty { return student }
        let group = effectiveStudentGroupLink
        if !group.isEmpty { return group }
        return studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func recurs(on date: Date, calendar: Calendar = .current) -> Bool {
        switch recurrence {
        case .none:
            return false
        case .daily:
            return true
        case .weekdays:
            return !calendar.isDateInWeekend(date)
        case .weekly:
            guard let recurrenceWeekday else { return false }
            return calendar.component(.weekday, from: date) == recurrenceWeekday.rawValue
        }
    }

    var recurrenceSummary: String {
        switch recurrence {
        case .none:
            return ""
        case .daily:
            return "Repeats Daily"
        case .weekdays:
            return "Repeats Weekdays"
        case .weekly:
            if let recurrenceWeekday {
                return "Repeats Weekly (\(recurrenceWeekday.displayName))"
            }
            return "Repeats Weekly"
        }
    }
}
