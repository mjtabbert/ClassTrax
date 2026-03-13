//
//  AlarmItem.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import Foundation
import SwiftUI

struct AlarmItem: Identifiable, Codable, Hashable {

    // MARK: - Nested Schedule Type

    enum ScheduleType: String, Codable, CaseIterable {

        case math
        case ela
        case science
        case socialStudies
        case prep
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
            case .prep:
                return .blue
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
            case .prep:
                return "Prep"
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
            case .prep:
                return "pencil.and.ruler.fill"
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
            case "prep":
                self = .prep
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

    init(
        id: UUID = UUID(),
        name: String,
        start: Date,
        end: Date,
        location: String,
        scheduleType: ScheduleType = .other,
        dayOfWeek: Int? = nil,
        gradeLevel: String = ""
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.location = location
        self.scheduleType = scheduleType
        self.dayOfWeekValue = dayOfWeek
        self.gradeLevelValue = gradeLevel
    }

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        className: String,
        location: String,
        gradeLevel: String = "",
        startTime: Date,
        endTime: Date,
        type: ScheduleType = .other
    ) {
        self.init(
            id: id,
            name: className,
            start: startTime,
            end: endTime,
            location: location,
            scheduleType: type,
            dayOfWeek: dayOfWeek,
            gradeLevel: gradeLevel
        )
    }

    // MARK: - Compatibility Aliases

    // Older UI files expect these names
    var className: String { name }
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
}
