//
//  TodoItem.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 3:05 PM
//  Version: ClassCue Dev Build 11.1
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
    var linkedContext: String = ""
    var studentOrGroup: String = ""
    var followUpNote: String = ""
    var reminder: Reminder = .none

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

    init(
        id: UUID = UUID(),
        task: String,
        isCompleted: Bool = false,
        priority: Priority = .none,
        dueDate: Date? = nil,
        category: Category = .prep,
        bucket: Bucket = .today,
        linkedContext: String = "",
        studentOrGroup: String = "",
        followUpNote: String = "",
        reminder: Reminder = .none
    ) {
        self.id = id
        self.task = task
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.category = category
        self.bucket = bucket
        self.linkedContext = linkedContext
        self.studentOrGroup = studentOrGroup
        self.followUpNote = followUpNote
        self.reminder = reminder
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
        linkedContext = try container.decodeIfPresent(String.self, forKey: .linkedContext) ?? ""
        studentOrGroup = try container.decodeIfPresent(String.self, forKey: .studentOrGroup) ?? ""
        followUpNote = try container.decodeIfPresent(String.self, forKey: .followUpNote) ?? ""
        reminder = try container.decodeIfPresent(Reminder.self, forKey: .reminder) ?? .none
    }
}
