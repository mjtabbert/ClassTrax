//
//  SoundPattern.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 24
//

import Foundation
import AudioToolbox

enum SoundPattern: String, CaseIterable, Codable {

    case classicAlarm = "Classic Bell"
    case softChime = "Soft Chime"
    case sharpBell = "Sharp Bell"
    case systemChime = "System Chime"
    case systemGlass = "System Glass"
    case systemAlert = "System Alert"
    case defaultPhone = "iPhone Default"
    case none = "None"

    enum SourceGroup: String, CaseIterable {
        case classCue = "Class Trax Sounds"
        case iPhone = "iPhone System Sounds"
        case silent = "Silent"
    }

    var displayName: String {
        rawValue
    }

    var sourceGroup: SourceGroup {
        switch self {
        case .classicAlarm, .softChime, .sharpBell:
            return .classCue
        case .systemChime, .systemGlass, .systemAlert, .defaultPhone:
            return .iPhone
        case .none:
            return .silent
        }
    }

    // System sound used for quick feedback
    var systemID: SystemSoundID {
        switch self {

        case .classicAlarm:
            return 1005   // classic system tone

        case .softChime:
            return 1016   // soft chime

        case .sharpBell:
            return 1022   // sharper alert

        case .systemChime:
            return 1016

        case .systemGlass:
            return 1104

        case .systemAlert:
            return 1007

        case .defaultPhone:
            return 1005

        case .none:
            return 0
        }
    }

    var soundFile: String? {
        switch self {

        case .classicAlarm:
            return "classic_bell_optimized.caf"

        case .softChime:
            return "soft_chime_optimized.caf"

        case .sharpBell:
            return "sharp_bell_optimized.caf"

        case .systemChime, .systemGlass, .systemAlert, .defaultPhone:
            return nil

        case .none:
            return nil
        }
    }

    static func fromStoredPreference(_ rawValue: String) -> SoundPattern {
        SoundPattern(rawValue: rawValue) ?? .classicAlarm
    }
}
