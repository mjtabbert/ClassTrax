//
//  AlarmItem.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 24
//

import Foundation
import SwiftUI

struct AlarmItem: Identifiable, Codable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case start
        case end
        case location
        case scheduleType
        case dayOfWeekValue
        case gradeLevelValue
        case classDefinitionID
        case classDefinitionIDs
        case linkedStudentIDs
        case warningLeadTimesValue
    }

    // MARK: - Nested Schedule Type

    enum ScheduleType: String, Codable, CaseIterable {

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

        // Used by TypeBadge
        var themeColor: Color {
            switch self {
            case .math:
                return .red
            case .ela:
                return .orange
            case .science:
                return .yellow
            case .socialStudies:
                return .green
            case .assembly:
                return .pink
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
                return Color(.systemGray)
            case .blank:
                return .clear
            }
        }

        var displayName: String {
            switch self {
            case .math:
                return "Math"
            case .ela:
                return "ELA"
            case .science:
                return "Science"
            case .socialStudies:
                return "Social Studies"
            case .assembly:
                return "Assembly"
            case .prep:
                return "Prep"
            case .studyTime:
                return "Study Time"
            case .recess:
                return "Recess"
            case .lunch:
                return "Lunch"
            case .transition:
                return "Transition"
            case .other:
                return "Other"
            case .blank:
                return "Blank"
            }
        }

        var symbolName: String {
            switch self {
            case .math:
                return "function"
            case .ela:
                return "text.book.closed.fill"
            case .science:
                return "atom"
            case .socialStudies:
                return "globe.americas.fill"
            case .assembly:
                return "person.3.fill"
            case .prep:
                return "pencil.and.ruler.fill"
            case .studyTime:
                return "book.closed.fill"
            case .recess:
                return "figure.run"
            case .lunch:
                return "fork.knife"
            case .transition:
                return "arrow.left.arrow.right"
            case .other:
                return "square.grid.2x2.fill"
            case .blank:
                return "circle.dashed"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case "math":
                self = .math
            case "ela":
                self = .ela
            case "science":
                self = .science
            case "socialStudies":
                self = .socialStudies
            case "assembly":
                self = .assembly
            case "prep":
                self = .prep
            case "studyTime":
                self = .studyTime
            case "recess":
                self = .recess
            case "lunch":
                self = .lunch
            case "transition":
                self = .transition
            case "other":
                self = .other
            case "blank":
                self = .blank
            case "classPeriod":
                self = .other
            case "planning":
                self = .other
            default:
                self = .other
            }
        }

        static var alphabetizedCases: [ScheduleType] {
            allCases.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    // MARK: - Core Properties

    var id: UUID = UUID()

    var name: String
    var start: Date
    var end: Date
    var location: String

    var scheduleType: ScheduleType = .other
    var dayOfWeekValue: Int? = nil
    var gradeLevelValue: String = ""
    var classDefinitionID: UUID? = nil
    var classDefinitionIDs: [UUID] = []
    var linkedStudentIDs: [UUID] = []
    var warningLeadTimesValue: [Int] = [5, 2, 1]

    init(
        id: UUID = UUID(),
        name: String,
        start: Date,
        end: Date,
        location: String,
        scheduleType: ScheduleType = .other,
        dayOfWeek: Int? = nil,
        gradeLevel: String = "",
        classDefinitionID: UUID? = nil,
        classDefinitionIDs: [UUID] = [],
        linkedStudentIDs: [UUID] = [],
        warningLeadTimes: [Int] = [5, 2, 1]
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.location = location
        self.scheduleType = scheduleType
        self.dayOfWeekValue = dayOfWeek
        self.gradeLevelValue = gradeLevel
        let normalizedDefinitionIDs = AlarmItem.normalizedClassDefinitionIDs(primaryID: classDefinitionID, additionalIDs: classDefinitionIDs)
        self.classDefinitionID = normalizedDefinitionIDs.first
        self.classDefinitionIDs = normalizedDefinitionIDs
        self.linkedStudentIDs = linkedStudentIDs
        self.warningLeadTimesValue = AlarmItem.normalizedWarningLeadTimes(warningLeadTimes)
    }

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        className: String,
        location: String,
        gradeLevel: String = "",
        startTime: Date,
        endTime: Date,
        type: ScheduleType = .other,
        classDefinitionID: UUID? = nil,
        classDefinitionIDs: [UUID] = [],
        linkedStudentIDs: [UUID] = [],
        warningLeadTimes: [Int] = [5, 2, 1]
    ) {
        self.init(
            id: id,
            name: className,
            start: startTime,
            end: endTime,
            location: location,
            scheduleType: type,
            dayOfWeek: dayOfWeek,
            gradeLevel: gradeLevel,
            classDefinitionID: classDefinitionID,
            classDefinitionIDs: classDefinitionIDs,
            linkedStudentIDs: linkedStudentIDs,
            warningLeadTimes: warningLeadTimes
        )
    }

    // MARK: - Compatibility Aliases

    // Older UI files expect these names
    var className: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        if normalized == "nsmanagedobject" || normalized == "managedobject" {
            return ""
        }

        return trimmed
    }

    var displayClassName: String {
        let value = className
        return value.isEmpty ? "Class Not Set" : value
    }
    var startTime: Date { start }
    var endTime: Date { end }

    // Some files reference `.type`
    var type: ScheduleType { scheduleType }

    // Some files reference `.dayOfWeek`
    var dayOfWeek: Int {
        dayOfWeekValue ?? Calendar.current.component(.weekday, from: start)
    }

    // NextUpCard expects this property
    var gradeLevel: String {
        gradeLevelValue
    }

    var typeLabel: String {
        scheduleType.displayName
    }

    var accentColor: Color {
        scheduleType.themeColor
    }

    var warningLeadTimes: [Int] {
        AlarmItem.normalizedWarningLeadTimes(warningLeadTimesValue)
    }

    var linkedClassDefinitionIDs: [UUID] {
        AlarmItem.normalizedClassDefinitionIDs(primaryID: classDefinitionID, additionalIDs: classDefinitionIDs)
    }

    func matchesLinkedClassDefinition(_ definitionID: UUID?) -> Bool {
        guard let definitionID else { return false }
        return linkedClassDefinitionIDs.contains(definitionID)
    }

    func linkedInstructionalContexts(using definitions: [ClassDefinitionItem], workflowMode: TeacherWorkflowMode) -> [InstructionalContextSummary] {
        let linkedStudents = linkedStudentIDs
        let contexts = linkedClassDefinitionIDs.compactMap { linkedID in
            definitions.first(where: { $0.id == linkedID })?.instructionalContextSummary(
                for: workflowMode,
                linkedStudentIDs: linkedStudents
            )
        }

        if contexts.isEmpty {
            return [
                InstructionalContextSummary(
                    id: id,
                    title: className,
                    kind: fallbackInstructionalContextKind(for: workflowMode),
                    gradeLevel: gradeLevel,
                    location: location,
                    linkedStudentIDs: linkedStudents,
                    sourceClassDefinitionID: linkedClassDefinitionIDs.first
                )
            ]
        }

        return contexts
    }

    func linkedInstructionalContextNames(using definitions: [ClassDefinitionItem], workflowMode: TeacherWorkflowMode) -> [String] {
        linkedInstructionalContexts(using: definitions, workflowMode: workflowMode)
            .map(\.displayTitle)
    }

    func instructionalContextSummary(
        using definitions: [ClassDefinitionItem],
        workflowMode: TeacherWorkflowMode
    ) -> InstructionalContextSummary {
        let contexts = linkedInstructionalContexts(using: definitions, workflowMode: workflowMode)

        if let primarySummary = contexts.first {
            if contexts.count > 1 {
                return InstructionalContextSummary(
                    id: id,
                    title: "\(primarySummary.displayTitle) + \(contexts.count - 1) more",
                    kind: primarySummary.kind,
                    gradeLevel: primarySummary.gradeLevel,
                    location: primarySummary.location,
                    linkedStudentIDs: linkedStudentIDs,
                    sourceClassDefinitionID: primarySummary.sourceClassDefinitionID
                )
            }

            return primarySummary
        }

        return InstructionalContextSummary(
            id: id,
            title: className,
            kind: fallbackInstructionalContextKind(for: workflowMode),
            gradeLevel: gradeLevel,
            location: location,
            linkedStudentIDs: linkedStudentIDs,
            sourceClassDefinitionID: linkedClassDefinitionIDs.first
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decode(Date.self, forKey: .end)
        location = try container.decode(String.self, forKey: .location)
        scheduleType = try container.decodeIfPresent(ScheduleType.self, forKey: .scheduleType) ?? .other
        dayOfWeekValue = try container.decodeIfPresent(Int.self, forKey: .dayOfWeekValue)
        gradeLevelValue = try container.decodeIfPresent(String.self, forKey: .gradeLevelValue) ?? ""

        let primaryDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .classDefinitionID)
        let additionalDefinitionIDs = try container.decodeIfPresent([UUID].self, forKey: .classDefinitionIDs) ?? []
        let normalizedDefinitionIDs = AlarmItem.normalizedClassDefinitionIDs(primaryID: primaryDefinitionID, additionalIDs: additionalDefinitionIDs)
        classDefinitionID = normalizedDefinitionIDs.first
        classDefinitionIDs = normalizedDefinitionIDs

        linkedStudentIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedStudentIDs) ?? []
        warningLeadTimesValue = AlarmItem.normalizedWarningLeadTimes(
            try container.decodeIfPresent([Int].self, forKey: .warningLeadTimesValue) ?? [5, 2, 1]
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        try container.encode(location, forKey: .location)
        try container.encode(scheduleType, forKey: .scheduleType)
        try container.encodeIfPresent(dayOfWeekValue, forKey: .dayOfWeekValue)
        try container.encode(gradeLevelValue, forKey: .gradeLevelValue)
        try container.encodeIfPresent(classDefinitionID, forKey: .classDefinitionID)
        try container.encode(linkedClassDefinitionIDs, forKey: .classDefinitionIDs)
        try container.encode(linkedStudentIDs, forKey: .linkedStudentIDs)
        try container.encode(warningLeadTimes, forKey: .warningLeadTimesValue)
    }

    // MARK: - Timing Helpers

    var isHappeningNow: Bool {
        let now = Date()
        return now >= start && now <= end
    }

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }

    var timeRemaining: TimeInterval {
        max(0, end.timeIntervalSince(Date()))
    }

    private static func normalizedWarningLeadTimes(_ values: [Int]) -> [Int] {
        let cleaned = values
            .filter { $0 > 0 }
            .map { min($0, 180) }
        let unique = Array(Set(cleaned)).sorted(by: >)
        return unique.isEmpty ? [5, 2, 1] : unique
    }

    private func fallbackInstructionalContextKind(for workflowMode: TeacherWorkflowMode) -> InstructionalContextKind {
        switch workflowMode {
        case .classroom:
            return .classroom
        case .resourceSped:
            switch scheduleType {
            case .studyTime:
                return .intervention
            case .prep, .transition, .blank:
                return .serviceSession
            default:
                return .supportGroup
            }
        case .hybrid:
            switch scheduleType {
            case .studyTime:
                return .intervention
            case .prep, .transition:
                return .serviceSession
            default:
                return .classroom
            }
        }
    }

    private static func normalizedClassDefinitionIDs(primaryID: UUID?, additionalIDs: [UUID]) -> [UUID] {
        var ordered = [UUID]()
        if let primaryID {
            ordered.append(primaryID)
        }
        ordered.append(contentsOf: additionalIDs)

        var seen = Set<UUID>()
        return ordered.filter { id in
            guard !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
    }
}
