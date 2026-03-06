//
//  NotificationManager.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Updated: March 11 2026
//  Build: ClassCue Dev Build 24
//

import Foundation
import UserNotifications
import ActivityKit

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: Authorization

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in

            if let error {
                print("Notification permission error:", error.localizedDescription)
            }

            print("Notifications granted:", granted)
        }
    }

    // MARK: Refresh Schedule Notifications

    func refreshNotifications(for alarms: [AlarmItem]) {

        removeClassCueNotifications {
            self.scheduleNotifications(for: alarms)
        }
    }

    private func removeClassCueNotifications(completion: @escaping () -> Void) {

        center.getPendingNotificationRequests { requests in

            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("classcue.") }

            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            completion()
        }
    }

    // MARK: Schedule

    private func scheduleNotifications(for alarms: [AlarmItem]) {

        for alarm in alarms {

            scheduleOneMinuteWarning(for: alarm)
            scheduleStartNotification(for: alarm)
            scheduleEndNotification(for: alarm)
        }
    }

    // MARK: Warning

    private func scheduleOneMinuteWarning(for alarm: AlarmItem) {

        guard alarm.type != .transition else { return }

        guard let date = Calendar.current.date(byAdding: .minute, value: -1, to: alarm.startTime) else { return }

        var components = Calendar.current.dateComponents([.hour,.minute], from: date)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = "🔔 ClassCue"
        content.subtitle = "\(alarm.className) in 1 minute"

        content.body = formattedTimeRange(alarm)

        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(SystemSounds.warning)
        )

        content.categoryIdentifier = "CLASSCUE_BELL"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classcue.warning.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: Start

    private func scheduleStartNotification(for alarm: AlarmItem) {

        var components = Calendar.current.dateComponents([.hour,.minute], from: alarm.startTime)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = "🔔 ClassCue"
        content.subtitle = "\(alarm.className) Starting"

        content.body = formattedTimeRange(alarm)

        content.sound = selectedNotificationSound()

        content.categoryIdentifier = "CLASSCUE_BELL"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classcue.start.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: End

    private func scheduleEndNotification(for alarm: AlarmItem) {

        var components = Calendar.current.dateComponents([.hour,.minute], from: alarm.endTime)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = "🔔 ClassCue"
        content.subtitle = "\(alarm.className) Ending"

        content.body = "Next block starting"

        content.sound = selectedNotificationSound()

        content.categoryIdentifier = "CLASSCUE_BELL"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classcue.end.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: Helpers

    private func selectedNotificationSound() -> UNNotificationSound? {

        let raw = UserDefaults.standard.string(forKey: "pref_sound")
            ?? SoundPattern.classicAlarm.rawValue

        return BellSound.fromStoredPreference(raw).notificationSound
    }

    private func formattedTimeRange(_ alarm: AlarmItem) -> String {

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: alarm.startTime)
        let end = formatter.string(from: alarm.endTime)

        return "\(start) – \(end)"
    }

    private func systemWeekday(from appDay: Int) -> Int {

        switch appDay {

        case 1: return 2
        case 2: return 3
        case 3: return 4
        case 4: return 5
        case 5: return 6
        case 6: return 7
        case 7: return 1

        default: return 2
        }
    }
}
