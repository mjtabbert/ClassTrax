import Foundation
import SwiftUI

struct ClassStaffContact: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var room: String = ""
    var cell: String = ""
    var extensionNumber: String = ""
    var emailAddress: String = ""
    var subject: String = ""

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SupportStaffRole: String, Codable, CaseIterable, Identifiable {
    case teacher
    case para

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teacher: return "Teacher"
        case .para: return "Para"
        }
    }

    var pluralTitle: String {
        switch self {
        case .teacher: return "Teachers"
        case .para: return "Paras"
        }
    }
}

struct ClassDefinitionItem: Identifiable, Codable, Equatable, Hashable {
    enum ScheduleKind: String, Codable, CaseIterable {
        case math
        case ela
        case science
        case socialStudies
        case assembly
        case prep
        case studyTime
        case recess
        case lunch
        case transition
        case other
        case blank

        var displayName: String {
            switch self {
            case .math: return "Math"
            case .ela: return "ELA"
            case .science: return "Science"
            case .socialStudies: return "Social Studies"
            case .assembly: return "Assembly"
            case .prep: return "Prep"
            case .studyTime: return "Study Time"
            case .recess: return "Recess"
            case .lunch: return "Lunch"
            case .transition: return "Transition"
            case .other: return "Other"
            case .blank: return "Blank"
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var scheduleKind: ScheduleKind
    var gradeLevel: String
    var defaultLocation: String
    var teacherContacts: [ClassStaffContact]
    var paraContacts: [ClassStaffContact]

    init(
        id: UUID = UUID(),
        name: String,
        scheduleType: ScheduleKind = .other,
        gradeLevel: String = "",
        defaultLocation: String = "",
        teacherContacts: [ClassStaffContact] = [],
        paraContacts: [ClassStaffContact] = []
    ) {
        self.id = id
        self.name = name
        self.scheduleKind = scheduleType
        self.gradeLevel = gradeLevel
        self.defaultLocation = defaultLocation
        self.teacherContacts = teacherContacts
        self.paraContacts = paraContacts
    }

    var displayName: String {
        let parts = [
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }
        return parts.isEmpty ? "Untitled Class" : parts.joined(separator: " - ")
    }

    var typeDisplayName: String {
        scheduleKind.displayName
    }

    var symbolName: String {
        switch scheduleKind {
        case .math: return "function"
        case .ela: return "text.book.closed.fill"
        case .science: return "atom"
        case .socialStudies: return "globe.americas.fill"
        case .assembly: return "person.3.fill"
        case .prep: return "pencil.and.ruler.fill"
        case .studyTime: return "book.closed.fill"
        case .recess: return "figure.run"
        case .lunch: return "fork.knife"
        case .transition: return "arrow.left.arrow.right"
        case .other: return "square.grid.2x2.fill"
        case .blank: return "circle.dashed"
        }
    }

    var themeColor: Color {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let letter = trimmedName
            .uppercased()
            .unicodeScalars
            .first(where: { CharacterSet.letters.contains($0) }),
              letter.value >= 65,
              letter.value <= 90 else {
            switch scheduleKind {
            case .transition: return Color(.systemGray4)
            case .other: return Color(.systemGray)
            case .blank: return .clear
            default: return .blue
            }
        }

        let clampedIndex = max(0, min(25, Int(letter.value) - 65))
        let progress = Double(clampedIndex) / 25.0
        let hue = 0.0 + (0.78 - 0.0) * progress
        return Color(hue: hue, saturation: 0.84, brightness: 0.92)
    }
}
