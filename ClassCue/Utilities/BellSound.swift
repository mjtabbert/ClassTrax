//
//  BellSound.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation
import UserNotifications

enum BellSound {
    case classicBell
    case softChime
    case sharpBell
    case none

    static func fromStoredPreference(_ rawValue: String) -> BellSound {
        switch rawValue {
        case "Classic Bell":
            return .classicBell

        case "Soft Chime":
            return .softChime

        case "Sharp Bell":
            return .sharpBell

        case "None":
            return .none

        default:
            return .classicBell
        }
    }

    var fileName: String? {
        switch self {
        case .classicBell:
            return "classic_bell_optimized.caf"

        case .softChime:
            return "soft_chime_optimized.caf"

        case .sharpBell:
            return "sharp_bell_optimized.caf"

        case .none:
            return nil
        }
    }

    var notificationSound: UNNotificationSound? {
        guard let fileName else { return nil }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}
