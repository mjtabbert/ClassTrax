//
//  ClassCueActivityAttributes.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import ActivityKit
import Foundation

struct ClassCueActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var className: String
        var endTime: Date
    }

    var className: String
}
