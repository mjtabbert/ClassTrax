//
//  DayOverride.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 5:05 PM
//  Version: ClassTrax Dev Build 18
//

import Foundation

struct DayOverride: Identifiable, Codable, Equatable {

    enum OverrideKind: String, Codable, CaseIterable {
        case custom
        case earlyRelease
        case lateStart
        case assemblyDay
        case testingDay
        case minimumDay

        var displayName: String {
            switch self {
            case .custom:
                return "Custom Override"
            case .earlyRelease:
                return "Early Release"
            case .lateStart:
                return "Late Start"
            case .assemblyDay:
                return "Assembly Day"
            case .testingDay:
                return "Testing Day"
            case .minimumDay:
                return "Minimum Day"
            }
        }
    }

    var id = UUID()
    var date: Date
    var profileID: UUID
    var kind: OverrideKind = .custom

    init(
        id: UUID = UUID(),
        date: Date,
        profileID: UUID,
        kind: OverrideKind = .custom
    ) {
        self.id = id
        self.date = date
        self.profileID = profileID
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        kind = try container.decodeIfPresent(OverrideKind.self, forKey: .kind) ?? .custom
    }

    func displayLabel(profileName: String) -> String {
        kind == .custom ? profileName : "\(kind.displayName) • \(profileName)"
    }
}
