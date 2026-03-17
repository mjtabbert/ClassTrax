//
//  SubPlanItem.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import Foundation

struct SubPlanItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var dateKey: String
    var linkedAlarmID: UUID?
    var className: String
    var gradeLevel: String
    var location: String
    var overview: String
    var lessonPlan: String
    var materials: String
    var subNotes: String
    var includeRoster: Bool = true
    var includeSupports: Bool = true
    var includeAttendance: Bool = true
    var includeCommitments: Bool = true
    var includeDaySchedule: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        dateKey: String,
        linkedAlarmID: UUID?,
        className: String,
        gradeLevel: String,
        location: String,
        overview: String,
        lessonPlan: String,
        materials: String,
        subNotes: String,
        includeRoster: Bool = true,
        includeSupports: Bool = true,
        includeAttendance: Bool = true,
        includeCommitments: Bool = true,
        includeDaySchedule: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.linkedAlarmID = linkedAlarmID
        self.className = className
        self.gradeLevel = gradeLevel
        self.location = location
        self.overview = overview
        self.lessonPlan = lessonPlan
        self.materials = materials
        self.subNotes = subNotes
        self.includeRoster = includeRoster
        self.includeSupports = includeSupports
        self.includeAttendance = includeAttendance
        self.includeCommitments = includeCommitments
        self.includeDaySchedule = includeDaySchedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dateKey = try container.decode(String.self, forKey: .dateKey)
        linkedAlarmID = try container.decodeIfPresent(UUID.self, forKey: .linkedAlarmID)
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        gradeLevel = try container.decodeIfPresent(String.self, forKey: .gradeLevel) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        lessonPlan = try container.decodeIfPresent(String.self, forKey: .lessonPlan) ?? ""
        materials = try container.decodeIfPresent(String.self, forKey: .materials) ?? ""
        subNotes = try container.decodeIfPresent(String.self, forKey: .subNotes) ?? ""
        includeRoster = try container.decodeIfPresent(Bool.self, forKey: .includeRoster) ?? true
        includeSupports = try container.decodeIfPresent(Bool.self, forKey: .includeSupports) ?? true
        includeAttendance = try container.decodeIfPresent(Bool.self, forKey: .includeAttendance) ?? true
        includeCommitments = try container.decodeIfPresent(Bool.self, forKey: .includeCommitments) ?? true
        includeDaySchedule = try container.decodeIfPresent(Bool.self, forKey: .includeDaySchedule) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
