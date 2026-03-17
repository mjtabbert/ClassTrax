//
//  NotificationManager.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Updated: March 11 2026
//  Build: ClassTrax Dev Build 24
//

import Foundation
import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    private let center = UNUserNotificationCenter.current()

    private var schoolQuietHoursEnabled: Bool {
        UserDefaults.standard.bool(forKey: "school_quiet_hours_enabled")
    }

    private var schoolQuietHour: Int {
        UserDefaults.standard.integer(forKey: "school_quiet_hour")
    }

    private var schoolQuietMinute: Int {
        UserDefaults.standard.integer(forKey: "school_quiet_minute")
    }

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

    func refreshNotifications(
        for alarms: [AlarmItem],
        activeOverrideSchedule: [AlarmItem]? = nil,
        activeOverrideDate: Date? = nil,
        overrides: [DayOverride] = [],
        profiles: [ScheduleProfile] = []
    ) {

        removeClassTraxNotifications {
            let regularAlarms: [AlarmItem]

            if let activeOverrideDate {
                let overrideWeekday = Calendar.current.component(.weekday, from: activeOverrideDate)
                regularAlarms = alarms.filter { $0.dayOfWeek != overrideWeekday }
            } else {
                regularAlarms = alarms
            }

            self.scheduleNotifications(for: regularAlarms)

            if let activeOverrideSchedule, let activeOverrideDate {
                self.scheduleOverrideNotifications(for: activeOverrideSchedule, on: activeOverrideDate)
            }

            self.scheduleUpcomingOverrideNotifications(overrides: overrides, profiles: profiles)
        }
    }

    private func removeClassTraxNotifications(completion: @escaping () -> Void) {

        center.getPendingNotificationRequests { requests in

            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix("classtrax.") }

            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            completion()
        }
    }

    // MARK: Schedule

    private func scheduleNotifications(for alarms: [AlarmItem]) {

        for alarm in alarms {

            scheduleWarning(for: alarm, minutesBefore: 5)
            scheduleWarning(for: alarm, minutesBefore: 2)
            scheduleWarning(for: alarm, minutesBefore: 1)
            scheduleStartNotification(for: alarm)
            scheduleEndNotification(for: alarm)
        }
    }

    private func scheduleOverrideNotifications(for alarms: [AlarmItem], on date: Date) {
        for alarm in alarms {
            scheduleOneOffWarning(for: alarm, minutesBefore: 5, on: date)
            scheduleOneOffWarning(for: alarm, minutesBefore: 2, on: date)
            scheduleOneOffWarning(for: alarm, minutesBefore: 1, on: date)
            scheduleOneOffStartNotification(for: alarm, on: date)
            scheduleOneOffEndNotification(for: alarm, on: date)
        }
    }

    private func scheduleUpcomingOverrideNotifications(
        overrides: [DayOverride],
        profiles: [ScheduleProfile]
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let horizon = Calendar.current.date(byAdding: .day, value: 21, to: today) ?? today

        let upcomingOverrides = overrides
            .filter { $0.date > today && $0.date <= horizon }
            .sorted { $0.date < $1.date }

        for override in upcomingOverrides {
            guard let profile = profiles.first(where: { $0.id == override.profileID }) else { continue }
            let weekday = Calendar.current.component(.weekday, from: override.date)
            let alarms = overrideAlarms(from: profile, for: weekday)
            scheduleOverrideNotifications(for: alarms, on: override.date)
        }
    }

    // MARK: Warning

    private func scheduleWarning(for alarm: AlarmItem, minutesBefore: Int) {

        guard alarm.type != .transition else { return }
        guard alarm.type != .blank else { return }

        guard let date = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: alarm.startTime) else { return }
        guard !shouldSuppressForQuietHours(date) else { return }

        var components = Calendar.current.dateComponents([.hour,.minute], from: date)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = warningTitle(minutesBefore: minutesBefore)
        content.subtitle = warningSubtitle(for: alarm, minutesBefore: minutesBefore)

        content.body = warningBody(for: alarm, minutesBefore: minutesBefore)

        content.sound = UNNotificationSound(
            named: UNNotificationSoundName(SystemSounds.warning)
        )

        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classtrax.warning.\(minutesBefore).\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func scheduleOneOffWarning(for alarm: AlarmItem, minutesBefore: Int, on date: Date) {
        guard alarm.type != .transition else { return }
        guard alarm.type != .blank else { return }
        guard let warningDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: anchoredDate(alarm.startTime, on: date)) else {
            return
        }
        guard warningDate > Date() else { return }
        guard !shouldSuppressForQuietHours(warningDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = warningTitle(minutesBefore: minutesBefore)
        content.subtitle = warningSubtitle(for: alarm, minutesBefore: minutesBefore)
        content.body = warningBody(for: alarm, minutesBefore: minutesBefore)
        content.sound = UNNotificationSound(named: UNNotificationSoundName(SystemSounds.warning))
        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: warningDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "classtrax.override.warning.\(minutesBefore).\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: Start

    private func scheduleStartNotification(for alarm: AlarmItem) {
        guard !shouldSuppressForQuietHours(alarm.startTime) else { return }

        var components = Calendar.current.dateComponents([.hour,.minute], from: alarm.startTime)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = "🔔 Class Trax"
        content.subtitle = "\(alarm.className) Starting"

        content.body = formattedTimeRange(alarm)

        content.sound = selectedNotificationSound()

        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classtrax.start.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func scheduleOneOffStartNotification(for alarm: AlarmItem, on date: Date) {
        let startDate = anchoredDate(alarm.startTime, on: date)
        guard startDate > Date() else { return }
        guard !shouldSuppressForQuietHours(startDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔔 Class Trax"
        content.subtitle = "\(alarm.className) Starting"
        content.body = formattedTimeRange(alarm)
        content.sound = selectedNotificationSound()
        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "classtrax.override.start.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: End

    private func scheduleEndNotification(for alarm: AlarmItem) {
        guard !shouldSuppressForQuietHours(alarm.endTime) else { return }

        var components = Calendar.current.dateComponents([.hour,.minute], from: alarm.endTime)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = "🔔 Class Trax"
        content.subtitle = "\(alarm.className) Ending"

        content.body = "Next block starting"

        content.sound = selectedNotificationSound()

        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 0.9

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "classtrax.end.\(alarm.id)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func scheduleOneOffEndNotification(for alarm: AlarmItem, on date: Date) {
        let endDate = anchoredDate(alarm.endTime, on: date)
        guard endDate > Date() else { return }
        guard !shouldSuppressForQuietHours(endDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔔 Class Trax"
        content.subtitle = "\(alarm.className) Ending"
        content.body = "Next block starting"
        content.sound = selectedNotificationSound()
        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 0.9

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: endDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "classtrax.override.end.\(alarm.id)",
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

    private func warningTitle(minutesBefore: Int) -> String {
        switch minutesBefore {
        case 5:
            return "🟡 5 Minute Warning"
        case 2:
            return "🟠 2 Minute Warning"
        default:
            return "🔴 1 Minute Warning"
        }
    }

    private func warningSubtitle(for alarm: AlarmItem, minutesBefore: Int) -> String {
        "\(alarm.className) starts in \(minutesBefore) minute\(minutesBefore == 1 ? "" : "s")"
    }

    private func warningBody(for alarm: AlarmItem, minutesBefore: Int) -> String {
        let roomText = alarm.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : " • \(alarm.location)"

        return "\(formattedTimeRange(alarm))\(roomText)"
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

    private func anchoredDate(_ time: Date, on day: Date) -> Date {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func shouldSuppressForQuietHours(_ date: Date) -> Bool {
        guard schoolQuietHoursEnabled else { return false }

        let quietStart = Calendar.current.date(
            bySettingHour: schoolQuietHour,
            minute: schoolQuietMinute,
            second: 0,
            of: date
        ) ?? date

        return date >= quietStart
    }
}
