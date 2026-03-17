//
//  DailySubPlanItem.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import Foundation

struct DailySubPlanItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var dateKey: String
    var morningNotes: String
    var sharedMaterials: String
    var dismissalNotes: String
    var emergencyNotes: String
    var includeAttendance: Bool = true
    var includeRoster: Bool = true
    var includeSupports: Bool = true
    var includeCommitments: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        dateKey: String,
        morningNotes: String,
        sharedMaterials: String,
        dismissalNotes: String,
        emergencyNotes: String,
        includeAttendance: Bool = true,
        includeRoster: Bool = true,
        includeSupports: Bool = true,
        includeCommitments: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.morningNotes = morningNotes
        self.sharedMaterials = sharedMaterials
        self.dismissalNotes = dismissalNotes
        self.emergencyNotes = emergencyNotes
        self.includeAttendance = includeAttendance
        self.includeRoster = includeRoster
        self.includeSupports = includeSupports
        self.includeCommitments = includeCommitments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dateKey = try container.decode(String.self, forKey: .dateKey)
        morningNotes = try container.decodeIfPresent(String.self, forKey: .morningNotes) ?? ""
        sharedMaterials = try container.decodeIfPresent(String.self, forKey: .sharedMaterials) ?? ""
        dismissalNotes = try container.decodeIfPresent(String.self, forKey: .dismissalNotes) ?? ""
        emergencyNotes = try container.decodeIfPresent(String.self, forKey: .emergencyNotes) ?? ""
        includeAttendance = try container.decodeIfPresent(Bool.self, forKey: .includeAttendance) ?? true
        includeRoster = try container.decodeIfPresent(Bool.self, forKey: .includeRoster) ?? true
        includeSupports = try container.decodeIfPresent(Bool.self, forKey: .includeSupports) ?? true
        includeCommitments = try container.decodeIfPresent(Bool.self, forKey: .includeCommitments) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
