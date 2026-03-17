//
//  WeekdayTab.swift
//  ClassTrax
//
//  Created by Mike Tabbert on 3/11/26.
//

import Foundation

enum WeekdayTab: Int, CaseIterable, Hashable, Identifiable {

    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    var shortTitle: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    static var today: WeekdayTab {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return WeekdayTab(rawValue: weekday) ?? .monday
    }
}
