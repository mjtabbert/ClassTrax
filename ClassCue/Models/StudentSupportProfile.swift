//
//  StudentSupportProfile.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import Foundation

struct StudentSupportProfile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var className: String = ""
    var gradeLevel: String = ""
    var graduationYear: String = ""
    var parentNames: String = ""
    var parentPhoneNumbers: String = ""
    var parentEmails: String = ""
    var studentEmail: String = ""
    var accommodations: String = ""
    var prompts: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        className: String = "",
        gradeLevel: String = "",
        graduationYear: String = "",
        parentNames: String = "",
        parentPhoneNumbers: String = "",
        parentEmails: String = "",
        studentEmail: String = "",
        accommodations: String = "",
        prompts: String = ""
    ) {
        self.id = id
        self.name = name
        self.className = className
        self.gradeLevel = gradeLevel
        self.graduationYear = graduationYear
        self.parentNames = parentNames
        self.parentPhoneNumbers = parentPhoneNumbers
        self.parentEmails = parentEmails
        self.studentEmail = studentEmail
        self.accommodations = accommodations
        self.prompts = prompts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        gradeLevel = try container.decodeIfPresent(String.self, forKey: .gradeLevel) ?? ""
        graduationYear = try container.decodeIfPresent(String.self, forKey: .graduationYear) ?? ""
        parentNames = try container.decodeIfPresent(String.self, forKey: .parentNames) ?? ""
        parentPhoneNumbers = try container.decodeIfPresent(String.self, forKey: .parentPhoneNumbers) ?? ""
        parentEmails = try container.decodeIfPresent(String.self, forKey: .parentEmails) ?? ""
        studentEmail = try container.decodeIfPresent(String.self, forKey: .studentEmail) ?? ""
        accommodations = try container.decodeIfPresent(String.self, forKey: .accommodations) ?? ""
        prompts = try container.decodeIfPresent(String.self, forKey: .prompts) ?? ""
    }
}
