//
//  ScheduleProfile.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import Foundation

struct ScheduleProfile: Identifiable, Codable, Equatable {

    var id: UUID = UUID()
    var name: String
    var alarms: [AlarmItem]

}
