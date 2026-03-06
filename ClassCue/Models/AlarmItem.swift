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

        case classPeriod
        case prep
        case planning
        case recess
        case lunch
        case transition

        // Used by TypeBadge
        var themeColor: Color {
            switch self {
            case .classPeriod:
                return .blue
            case .prep:
                return .purple
            case .planning:
                return .orange
            case .recess:
                return .green
            case .lunch:
                return .red
            case .transition:
                return .gray
            }
        }

        var displayName: String {
            switch self {
            case .classPeriod:
                return "Class Period"
            case .prep:
                return "Prep"
            case .planning:
                return "Planning"
            case .recess:
                return "Recess"
            case .lunch:
                return "Lunch"
            case .transition:
                return "Transition"
            }
        }
    }

    // MARK: - Core Properties

    var id: UUID = UUID()

    var name: String
    var start: Date
    var end: Date
    var location: String

    var scheduleType: ScheduleType = .classPeriod
    var dayOfWeekValue: Int? = nil
    var gradeLevelValue: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        start: Date,
        end: Date,
        location: String,
        scheduleType: ScheduleType = .classPeriod,
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
        type: ScheduleType = .classPeriod
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
