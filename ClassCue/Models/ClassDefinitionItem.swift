import Foundation
import SwiftUI

enum TeacherWorkflowMode: String, CaseIterable, Identifiable, Codable {
    case classroom
    case resourceSped = "resource_sped"
    case hybrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classroom:
            return "Classroom"
        case .resourceSped:
            return "Resource / SPED"
        case .hybrid:
            return "Hybrid"
        }
    }

    var shortLabel: String {
        switch self {
        case .classroom:
            return "Classroom"
        case .resourceSped:
            return "Resource"
        case .hybrid:
            return "Hybrid"
        }
    }

    var settingsSummary: String {
        switch self {
        case .classroom:
            return "Best for one primary class at a time, whole-group attendance, and class-first flow."
        case .resourceSped:
            return "Best for overlapping groups, support sessions, and student-first service workflows."
        case .hybrid:
            return "Balances class-first and student-first workflows for mixed teaching days."
        }
    }

    var todayModeDescription: String {
        switch self {
        case .classroom:
            return "Today is tuned for class-first teaching flow."
        case .resourceSped:
            return "Today is tuned for support groups and service sessions."
        case .hybrid:
            return "Today stays flexible for mixed classroom and support work."
        }
    }
}

enum InstructionalContextKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case classroom
    case supportGroup
    case intervention
    case serviceSession
    case individualSupport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classroom:
            return "Class"
        case .supportGroup:
            return "Support Group"
        case .intervention:
            return "Intervention"
        case .serviceSession:
            return "Service Session"
        case .individualSupport:
            return "Individual Support"
        }
    }
}

struct InstructionalContextSummary: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var kind: InstructionalContextKind
    var gradeLevel: String
    var location: String
    var linkedStudentIDs: [UUID]
    var sourceClassDefinitionID: UUID?

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? kind.displayName : trimmed
    }
}

struct ClassStaffContact: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var room: String = ""
    var cell: String = ""
    var extensionNumber: String = ""
    var emailAddress: String = ""
    var subject: String = ""
    var tags: String = ""

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

        static var alphabetizedCases: [ScheduleKind] {
            allCases.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
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
        switch scheduleKind {
        case .math:
            return .red
        case .ela:
            return .orange
        case .science:
            return .yellow
        case .socialStudies:
            return .green
        case .assembly:
            return Color(red: 0.47, green: 0.33, blue: 0.86)
        case .prep:
            return .blue
        case .studyTime:
            return .teal
        case .recess:
            return .indigo
        case .lunch:
            return .purple
        case .transition:
            return Color(.systemGray4)
        case .other:
            return .mint
        case .blank:
            return .clear
        }
    }

    func instructionalContextKind(for workflowMode: TeacherWorkflowMode) -> InstructionalContextKind {
        switch workflowMode {
        case .classroom:
            return .classroom
        case .resourceSped:
            switch scheduleKind {
            case .studyTime:
                return .intervention
            case .prep, .transition, .blank:
                return .serviceSession
            default:
                return .supportGroup
            }
        case .hybrid:
            switch scheduleKind {
            case .studyTime:
                return .intervention
            case .prep, .transition:
                return .serviceSession
            default:
                return .classroom
            }
        }
    }

    func instructionalContextSummary(
        for workflowMode: TeacherWorkflowMode,
        linkedStudentIDs: [UUID] = []
    ) -> InstructionalContextSummary {
        InstructionalContextSummary(
            id: id,
            title: name,
            kind: instructionalContextKind(for: workflowMode),
            gradeLevel: gradeLevel,
            location: defaultLocation,
            linkedStudentIDs: linkedStudentIDs,
            sourceClassDefinitionID: id
        )
    }
}
