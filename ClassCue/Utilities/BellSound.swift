//
//  BellSound.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassTrax Dev Build 23
//

import Foundation
import UserNotifications
import AudioToolbox

enum BellSound {
    case classicBell
    case softChime
    case sharpBell
    case systemChime
    case systemGlass
    case systemAlert
    case defaultPhone
    case none

    static func fromStoredPreference(_ rawValue: String) -> BellSound {
        switch rawValue {
        case "Classic Bell":
            return .classicBell

        case "Soft Chime":
            return .softChime

        case "Sharp Bell":
            return .sharpBell

        case "System Chime":
            return .systemChime

        case "System Glass":
            return .systemGlass

        case "System Alert":
            return .systemAlert

        case "iPhone Default":
            return .defaultPhone

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

        case .systemChime, .systemGlass, .systemAlert, .defaultPhone:
            return nil

        case .none:
            return nil
        }
    }

    var systemID: SystemSoundID {
        switch self {
        case .classicBell:
            return 1005
        case .softChime:
            return 1016
        case .sharpBell:
            return 1022
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

    var notificationSound: UNNotificationSound? {
        if let fileName {
            return UNNotificationSound(named: UNNotificationSoundName(fileName))
        }

        switch self {
        case .systemChime, .systemGlass, .systemAlert, .defaultPhone:
            return .default
        case .none:
            return nil
        case .classicBell, .softChime, .sharpBell:
            return nil
        }
    }
}
