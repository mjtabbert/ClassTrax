//
//  ScheduleHelpers.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation

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
