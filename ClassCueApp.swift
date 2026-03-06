//
//  ClassCueApp.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import SwiftUI
import UserNotifications

@main
struct ClassCueApp: App {
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
