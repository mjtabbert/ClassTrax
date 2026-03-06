//
//  NotificationDelegate.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 10, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() { }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        BellFeedbackManager.shared.playSelectedBellFeedback()
        return [.banner, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
    }
}
