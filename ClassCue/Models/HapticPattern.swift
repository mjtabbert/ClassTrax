//
//  HapticPattern.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/6/26 at 3:30 PM
//  Version: ClassCue Dev Build 2
//

import Foundation

enum HapticPattern: String, Codable, CaseIterable {

    case doubleThump = "Double Thump (Success)"
    case triplePulse = "Triple Pulse (Warning)"
    case sharpClick = "Hardware Sharp Click"
    case heavyImpact = "Standard Heavy Impact"
    case lightTap = "Light Tap"
    case rigidTap = "Rigid Tap"
    case none = "None"

    enum SourceGroup: String, CaseIterable {
        case classCue = "ClassCue Haptics"
        case iPhone = "iPhone System Haptics"
        case silent = "Silent"
    }

    var sourceGroup: SourceGroup {
        switch self {
        case .doubleThump, .triplePulse:
            return .classCue
        case .sharpClick, .heavyImpact, .lightTap, .rigidTap:
            return .iPhone
        case .none:
            return .silent
        }
    }
}
