//
//  ScheduleHelpers.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import Foundation

struct ActiveDayOverride {
    let date: Date
    let displayName: String
    let alarms: [AlarmItem]
}

// MARK: - Date Builders

func startDateToday(hour: Int, minute: Int) -> Date {
    
    let calendar = Calendar.current
    let today = Date()
    
    var components = calendar.dateComponents([.year, .month, .day], from: today)
    components.hour = hour
    components.minute = minute
    components.second = 0
    
    return calendar.date(from: components) ?? today
}

func endDateToday(hour: Int, minute: Int) -> Date {
    
    let calendar = Calendar.current
    let today = Date()
    
    var components = calendar.dateComponents([.year, .month, .day], from: today)
    components.hour = hour
    components.minute = minute
    components.second = 0
    
    return calendar.date(from: components) ?? today
}

// MARK: - Current Class Helpers

func isCurrent(start: Date, end: Date) -> Bool {
    
    let now = Date()
    return now >= start && now <= end
}

func isCurrent(for item: AlarmItem, now: Date = Date()) -> Bool {
    return now >= item.start && now <= item.end
}

// MARK: - Day Schedule

func getDayScheduleWithTransitions() -> [AlarmItem] {
    
    return [
        AlarmItem(
            name: "Advisory",
            start: startDateToday(hour: 8, minute: 0),
            end: endDateToday(hour: 8, minute: 20),
            location: "Homeroom"
        ),
        
        AlarmItem(
            name: "WIN",
            start: startDateToday(hour: 8, minute: 25),
            end: endDateToday(hour: 9, minute: 0),
            location: "Assigned Room"
        ),
        
        AlarmItem(
            name: "Period 1",
            start: startDateToday(hour: 9, minute: 5),
            end: endDateToday(hour: 9, minute: 50),
            location: "Room 201"
        ),
        
        AlarmItem(
            name: "Period 2",
            start: startDateToday(hour: 9, minute: 55),
            end: endDateToday(hour: 10, minute: 40),
            location: "Room 204"
        ),
        
        AlarmItem(
            name: "Lunch",
            start: startDateToday(hour: 10, minute: 45),
            end: endDateToday(hour: 11, minute: 15),
            location: "Cafeteria"
        ),
        
        AlarmItem(
            name: "Period 3",
            start: startDateToday(hour: 11, minute: 20),
            end: endDateToday(hour: 12, minute: 5),
            location: "Room 210"
        ),
        
        AlarmItem(
            name: "Period 4",
            start: startDateToday(hour: 12, minute: 10),
            end: endDateToday(hour: 12, minute: 55),
            location: "Room 212"
        )
    ]
}

func resolvedDayOverride(
    for date: Date,
    overrides: [DayOverride],
    profiles: [ScheduleProfile]
) -> ActiveDayOverride? {
    let normalizedDate = Calendar.current.startOfDay(for: date)

    guard let override = overrides.first(where: {
        Calendar.current.isDate($0.date, inSameDayAs: normalizedDate)
    }) else {
        return nil
    }

    guard let profile = profiles.first(where: { $0.id == override.profileID }) else {
        return nil
    }

    let weekday = Calendar.current.component(.weekday, from: normalizedDate)

    return ActiveDayOverride(
        date: normalizedDate,
        displayName: override.displayLabel(profileName: profile.name),
        alarms: overrideAlarms(from: profile, for: weekday)
    )
}

func overrideAlarms(from profile: ScheduleProfile, for weekday: Int) -> [AlarmItem] {
    let directMatches = profile.alarms
        .filter { $0.dayOfWeek == weekday }
        .sorted { $0.startTime < $1.startTime }

    let source = directMatches.isEmpty
        ? profile.alarms.sorted { $0.startTime < $1.startTime }
        : directMatches

    return source.map { item in
        AlarmItem(
            id: item.id,
            dayOfWeek: weekday,
            className: item.className,
            location: item.location,
            gradeLevel: item.gradeLevel,
            startTime: item.startTime,
            endTime: item.endTime,
            type: item.type
        )
    }
}

func resolvedCommitments(for date: Date, from items: [CommitmentItem]) -> [CommitmentItem] {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: date)

    return items
        .filter { item in
            switch item.recurrence {
            case .weekly:
                return item.dayOfWeek == weekday
            case .oneTime:
                guard let specificDate = item.specificDate else { return false }
                return calendar.isDate(specificDate, inSameDayAs: date)
            }
        }
        .sorted { lhs, rhs in
            let lhsStart = anchoredTimeOnDate(lhs.startTime, date: date, calendar: calendar)
            let rhsStart = anchoredTimeOnDate(rhs.startTime, date: date, calendar: calendar)
            if lhsStart != rhsStart {
                return lhsStart < rhsStart
            }

            let lhsEnd = anchoredTimeOnDate(lhs.endTime, date: date, calendar: calendar)
            let rhsEnd = anchoredTimeOnDate(rhs.endTime, date: date, calendar: calendar)
            return lhsEnd < rhsEnd
        }
}

private func anchoredTimeOnDate(_ time: Date, date: Date, calendar: Calendar) -> Date {
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
    components.hour = timeComponents.hour
    components.minute = timeComponents.minute
    components.second = timeComponents.second
    return calendar.date(from: components) ?? time
}
