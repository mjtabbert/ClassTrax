//
//  SoundPattern.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import Foundation
import AudioToolbox

enum SoundPattern: String, CaseIterable, Codable {

    case classicAlarm = "Classic Bell"
    case softChime = "Soft Chime"
    case sharpBell = "Sharp Bell"
    case none = "None"

    var displayName: String {
        rawValue
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

        case .none:
            return nil
        }
    }

    static func fromStoredPreference(_ rawValue: String) -> SoundPattern {
        SoundPattern(rawValue: rawValue) ?? .classicAlarm
    }
}
