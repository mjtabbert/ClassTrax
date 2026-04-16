//
//  StudentSupportProfile.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import Foundation

struct StudentSupportProfile: Identifiable, Codable, Equatable {
    struct ClassContext: Identifiable, Codable, Equatable {
        var classDefinitionID: UUID
        var behaviorNotes: String = ""
        var effortNotes: String = ""
        var classNotes: String = ""
        var behaviorQuickNotes: [String: String] = [:]

        var id: UUID { classDefinitionID }

        init(
            classDefinitionID: UUID,
            behaviorNotes: String = "",
            effortNotes: String = "",
            classNotes: String = "",
            behaviorQuickNotes: [String: String] = [:]
        ) {
            self.classDefinitionID = classDefinitionID
            self.behaviorNotes = behaviorNotes
            self.effortNotes = effortNotes
            self.classNotes = classNotes
            self.behaviorQuickNotes = behaviorQuickNotes
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            classDefinitionID = try container.decode(UUID.self, forKey: .classDefinitionID)
            behaviorNotes = try container.decodeIfPresent(String.self, forKey: .behaviorNotes) ?? ""
            effortNotes = try container.decodeIfPresent(String.self, forKey: .effortNotes) ?? ""
            classNotes = try container.decodeIfPresent(String.self, forKey: .classNotes) ?? ""
            behaviorQuickNotes = try container.decodeIfPresent([String: String].self, forKey: .behaviorQuickNotes) ?? [:]
        }
    }

    var id: UUID = UUID()
    var name: String
    var className: String = ""
    var gradeLevel: String = ""
    var classDefinitionID: UUID? = nil
    var classDefinitionIDs: [UUID] = []
    var classContexts: [ClassContext] = []
    var graduationYear: String = ""
    var parentNames: String = ""
    var parentPhoneNumbers: String = ""
    var parentEmails: String = ""
    var studentEmail: String = ""
    var isSped: Bool = false
    var supportTeacherIDs: [UUID] = []
    var supportParaIDs: [UUID] = []
    var supportRooms: String = ""
    var supportScheduleNotes: String = ""
    var accommodations: String = ""
    var prompts: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        className: String = "",
        gradeLevel: String = "",
        classDefinitionID: UUID? = nil,
        classDefinitionIDs: [UUID] = [],
        classContexts: [ClassContext] = [],
        graduationYear: String = "",
        parentNames: String = "",
        parentPhoneNumbers: String = "",
        parentEmails: String = "",
        studentEmail: String = "",
        isSped: Bool = false,
        supportTeacherIDs: [UUID] = [],
        supportParaIDs: [UUID] = [],
        supportRooms: String = "",
        supportScheduleNotes: String = "",
        accommodations: String = "",
        prompts: String = ""
    ) {
        self.id = id
        self.name = name
        self.className = className
        self.gradeLevel = gradeLevel
        self.classDefinitionID = classDefinitionID
        self.classDefinitionIDs = classDefinitionIDs
        self.classContexts = classContexts
        self.graduationYear = graduationYear
        self.parentNames = parentNames
        self.parentPhoneNumbers = parentPhoneNumbers
        self.parentEmails = parentEmails
        self.studentEmail = studentEmail
        self.isSped = isSped
        self.supportTeacherIDs = supportTeacherIDs
        self.supportParaIDs = supportParaIDs
        self.supportRooms = supportRooms
        self.supportScheduleNotes = supportScheduleNotes
        self.accommodations = accommodations
        self.prompts = prompts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        gradeLevel = try container.decodeIfPresent(String.self, forKey: .gradeLevel) ?? ""
        classDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .classDefinitionID)
        classDefinitionIDs = try container.decodeIfPresent([UUID].self, forKey: .classDefinitionIDs) ?? []
        if classDefinitionIDs.isEmpty, let classDefinitionID {
            classDefinitionIDs = [classDefinitionID]
        }
        classContexts = try container.decodeIfPresent([ClassContext].self, forKey: .classContexts) ?? []
        graduationYear = try container.decodeIfPresent(String.self, forKey: .graduationYear) ?? ""
        parentNames = try container.decodeIfPresent(String.self, forKey: .parentNames) ?? ""
        parentPhoneNumbers = try container.decodeIfPresent(String.self, forKey: .parentPhoneNumbers) ?? ""
        parentEmails = try container.decodeIfPresent(String.self, forKey: .parentEmails) ?? ""
        studentEmail = try container.decodeIfPresent(String.self, forKey: .studentEmail) ?? ""
        isSped = try container.decodeIfPresent(Bool.self, forKey: .isSped) ?? false
        supportTeacherIDs = try container.decodeIfPresent([UUID].self, forKey: .supportTeacherIDs) ?? []
        supportParaIDs = try container.decodeIfPresent([UUID].self, forKey: .supportParaIDs) ?? []
        supportRooms = try container.decodeIfPresent(String.self, forKey: .supportRooms) ?? ""
        supportScheduleNotes = try container.decodeIfPresent(String.self, forKey: .supportScheduleNotes) ?? ""
        accommodations = try container.decodeIfPresent(String.self, forKey: .accommodations) ?? ""
        prompts = try container.decodeIfPresent(String.self, forKey: .prompts) ?? ""
    }
}
