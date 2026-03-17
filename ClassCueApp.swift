//
//  ClassTraxApp.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 24
//

import SwiftUI
import UserNotifications

@main
struct ClassTraxApp: App {
    init() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        NotificationManager.shared.requestAuthorization()
        NotificationCategories.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
