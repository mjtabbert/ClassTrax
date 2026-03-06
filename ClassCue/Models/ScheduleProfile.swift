//
//  ScheduleProfile.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation

struct ScheduleProfile: Identifiable, Codable, Equatable {

    var id: UUID = UUID()
    var name: String
    var alarms: [AlarmItem]

}
