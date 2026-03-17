//
//  NotificationCategories.swift
//  ClassTrax
//
//  Created by Mike Tabbert on 3/11/26.
//


//
// NotificationCategories.swift
// ClassTrax
//

import UserNotifications

struct NotificationCategories {

    static let classCue = "CLASSTRAX_BELL"

    static func register() {

        let viewSchedule = UNNotificationAction(
            identifier: "VIEW_SCHEDULE",
            title: "View Schedule",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: classCue,
            actions: [viewSchedule],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
