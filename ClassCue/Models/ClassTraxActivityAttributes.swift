//
//  ClassTraxActivityAttributes.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 23
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct ClassTraxActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var className: String
        var room: String
        var endTime: Date
        var isHeld: Bool
        var iconName: String
        var nextClassName: String
        var nextIconName: String
    }

    var className: String
}
#else
struct ClassTraxActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var className: String
        var room: String
        var endTime: Date
        var isHeld: Bool
        var iconName: String
        var nextClassName: String
        var nextIconName: String
    }

    var className: String
}
#endif
