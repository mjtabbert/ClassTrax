import Foundation
import UserNotifications

struct ScheduleBlock: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var gradeLevel: String?
    var location: String?
    var startTime: Date
    var endTime: Date
    var isTransition: Bool

    init(
        id: UUID = UUID(),
        title: String,
        gradeLevel: String? = nil,
        location: String? = nil,
        startTime: Date,
        endTime: Date,
        isTransition: Bool = false
    ) {
        self.id = id
        self.title = title
        self.gradeLevel = gradeLevel
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.isTransition = isTransition
    }
}

final class NotificationScheduler {

    static let shared = NotificationScheduler()

    private init() {}

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
                return
            }
            print("Notification permission granted: \(granted)")
        }
    }

    func clearAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func clearDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    func rebuildNotifications(from blocks: [ScheduleBlock]) {
        clearAllPendingNotifications()

        let futureBlocks = blocks.filter {
            $0.startTime > Date() || $0.endTime > Date()
        }

        for block in futureBlocks {
            scheduleStartNotification(for: block)
            scheduleEndNotification(for: block)
        }
    }

    func scheduleStartNotification(for block: ScheduleBlock) {
        guard block.startTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = block.isTransition ? "Transition Time" : "\(block.title) Starting"
        content.body = block.isTransition
            ? "Your transition is starting now."
            : "It’s time for \(block.title)."
        content.sound = .default

        let interval = block.startTime.timeIntervalSinceNow
        guard interval > 1 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: startIdentifier(for: block),
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling start notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleEndNotification(for block: ScheduleBlock) {
        guard block.endTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = block.isTransition ? "Transition Ending" : "\(block.title) Ending"
        content.body = block.isTransition
            ? "Your transition is ending now."
            : "\(block.title) is ending now."
        content.sound = .default

        let interval = block.endTime.timeIntervalSinceNow
        guard interval > 1 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: endIdentifier(for: block),
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling end notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleOneMinuteWarning(for block: ScheduleBlock) {
        let warningDate = block.startTime.addingTimeInterval(-60)
        guard warningDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(block.title) in 1 minute"
        content.body = "Wrap up and get ready."
        content.sound = .default

        let interval = warningDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(
            identifier: warningIdentifier(for: block),
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                print("Error scheduling warning notification: \(error.localizedDescription)")
            }
        }
    }

    private func startIdentifier(for block: ScheduleBlock) -> String {
        "classtrax.start.\(block.id.uuidString)"
    }

    private func endIdentifier(for block: ScheduleBlock) -> String {
        "classtrax.end.\(block.id.uuidString)"
    }

    private func warningIdentifier(for block: ScheduleBlock) -> String {
        "classtrax.warning.\(block.id.uuidString)"
    }
}//
//  NotificationScheduler.swift
//  ClassTrax
//
//  Created by Mike Tabbert on 3/10/26.
//
