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

    struct DebugSnapshot {
        var authorizationStatus: String
        var alertSetting: String
        var soundSetting: String
        var badgeSetting: String
        var pendingRequestCount: Int
        var classTraxPendingCount: Int
        var nextClassTraxIdentifier: String
        var nextClassTraxTrigger: String
    }

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

    private var schedulePauseUntil: Date? {
        let rawValue = UserDefaults.standard.double(forKey: "ignore_until_v1")
        guard rawValue > Date().timeIntervalSince1970 else { return nil }
        return Date(timeIntervalSince1970: rawValue)
    }

    private var warningFiveSoundPreference: String {
        UserDefaults.standard.string(forKey: "pref_warning_sound_5min") ?? SoundPattern.softChime.rawValue
    }

    private var warningTwoSoundPreference: String {
        UserDefaults.standard.string(forKey: "pref_warning_sound_2min") ?? SoundPattern.systemGlass.rawValue
    }

    private var warningOneSoundPreference: String {
        UserDefaults.standard.string(forKey: "pref_warning_sound_1min") ?? SoundPattern.sharpBell.rawValue
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

    func debugSnapshot() async -> DebugSnapshot {
        let settings = await center.notificationSettings()
        let requests = await pendingRequests()
        let classTraxRequests = requests.filter { $0.identifier.hasPrefix("classtrax.") }
        let sortedClassTraxRequests = classTraxRequests.sorted { lhs, rhs in
            nextTriggerDate(for: lhs) < nextTriggerDate(for: rhs)
        }

        let nextRequest = sortedClassTraxRequests.first

        return DebugSnapshot(
            authorizationStatus: describeAuthorizationStatus(settings.authorizationStatus),
            alertSetting: describeNotificationSetting(settings.alertSetting),
            soundSetting: describeNotificationSetting(settings.soundSetting),
            badgeSetting: describeNotificationSetting(settings.badgeSetting),
            pendingRequestCount: requests.count,
            classTraxPendingCount: classTraxRequests.count,
            nextClassTraxIdentifier: nextRequest?.identifier ?? "None",
            nextClassTraxTrigger: formattedTriggerDate(for: nextRequest)
        )
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func describeAuthorizationStatus(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private func describeNotificationSetting(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }

    private func nextTriggerDate(for request: UNNotificationRequest) -> Date {
        triggerDate(for: request.trigger) ?? .distantFuture
    }

    private func formattedTriggerDate(for request: UNNotificationRequest?) -> String {
        guard let request, let nextDate = triggerDate(for: request.trigger) else {
            return "None"
        }

        return nextDate.formatted()
    }

    private func triggerDate(for trigger: UNNotificationTrigger?) -> Date? {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }

        return nil
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
            guard self.schedulePauseUntil == nil else { return }

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

            for (index, minutesBefore) in alarm.warningLeadTimes.enumerated() {
                scheduleWarning(for: alarm, minutesBefore: minutesBefore, warningIndex: index)
            }
            scheduleStartNotification(for: alarm)
            scheduleEndNotification(for: alarm)
        }
    }

    private func scheduleOverrideNotifications(for alarms: [AlarmItem], on date: Date) {
        for alarm in alarms {
            for (index, minutesBefore) in alarm.warningLeadTimes.enumerated() {
                scheduleOneOffWarning(for: alarm, minutesBefore: minutesBefore, warningIndex: index, on: date)
            }
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
            scheduleOverrideSummaryNotifications(for: override, profile: profile, alarms: alarms)
        }
    }

    private func scheduleOverrideSummaryNotifications(
        for override: DayOverride,
        profile: ScheduleProfile,
        alarms: [AlarmItem]
    ) {
        scheduleOverrideSummaryNotification(
            identifierSuffix: "preview",
            title: "Class Trax Schedule Update",
            subtitle: "\(override.kind.displayName) Tomorrow",
            body: overrideSummaryBody(for: override, profile: profile, alarms: alarms),
            on: override.date,
            daysOffset: -1,
            hour: 15,
            minute: 30
        )

        scheduleOverrideSummaryNotification(
            identifierSuffix: "today",
            title: "Today's Schedule Override",
            subtitle: override.displayLabel(profileName: profile.name),
            body: overrideSummaryBody(for: override, profile: profile, alarms: alarms),
            on: override.date,
            daysOffset: 0,
            hour: 6,
            minute: 15
        )
    }

    private func scheduleOverrideSummaryNotification(
        identifierSuffix: String,
        title: String,
        subtitle: String,
        body: String,
        on overrideDate: Date,
        daysOffset: Int,
        hour: Int,
        minute: Int
    ) {
        guard let triggerDateBase = Calendar.current.date(byAdding: .day, value: daysOffset, to: overrideDate),
              let triggerDate = Calendar.current.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: triggerDateBase
              ) else {
            return
        }

        guard triggerDate > Date() else { return }
        guard !shouldSuppressForQuietHours(triggerDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = selectedNotificationSound()
        content.categoryIdentifier = "CLASSTRAX_BELL"
        content.interruptionLevel = .active
        content.relevanceScore = 0.8

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "classtrax.override.summary.\(identifierSuffix).\(Calendar.current.startOfDay(for: overrideDate).timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: Warning

    private func scheduleWarning(for alarm: AlarmItem, minutesBefore: Int, warningIndex: Int) {

        guard alarm.type != .transition else { return }
        guard alarm.type != .blank else { return }

        guard let date = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: alarm.endTime) else { return }
        guard !shouldSuppressForQuietHours(date) else { return }

        var components = Calendar.current.dateComponents([.hour,.minute], from: date)

        components.weekday = systemWeekday(from: alarm.dayOfWeek)

        let content = UNMutableNotificationContent()

        content.title = warningTitle(minutesBefore: minutesBefore)
        content.subtitle = warningSubtitle(for: alarm, minutesBefore: minutesBefore)

        content.body = warningBody(for: alarm)

        content.sound = selectedWarningSound(warningIndex: warningIndex)

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

    private func scheduleOneOffWarning(for alarm: AlarmItem, minutesBefore: Int, warningIndex: Int, on date: Date) {
        guard alarm.type != .transition else { return }
        guard alarm.type != .blank else { return }
        guard let warningDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: anchoredDate(alarm.endTime, on: date)) else {
            return
        }
        guard warningDate > Date() else { return }
        guard !shouldSuppressForQuietHours(warningDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = warningTitle(minutesBefore: minutesBefore)
        content.subtitle = warningSubtitle(for: alarm, minutesBefore: minutesBefore)
        content.body = warningBody(for: alarm)
        content.sound = selectedWarningSound(warningIndex: warningIndex)
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

    private func selectedWarningSound(warningIndex: Int) -> UNNotificationSound? {
        let rawValue: String
        switch warningIndex {
        case 0:
            rawValue = warningFiveSoundPreference
        case 1:
            rawValue = warningTwoSoundPreference
        default:
            rawValue = warningOneSoundPreference
        }

        return BellSound.fromStoredPreference(rawValue).notificationSound
    }

    private func formattedTimeRange(_ alarm: AlarmItem) -> String {

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: alarm.startTime)
        let end = formatter.string(from: alarm.endTime)

        return "\(start) – \(end)"
    }

    private func warningTitle(minutesBefore: Int) -> String {
        "\(minutesBefore) Minute Warning"
    }

    private func warningSubtitle(for alarm: AlarmItem, minutesBefore: Int) -> String {
        "\(alarm.className) ends in \(minutesBefore) minute\(minutesBefore == 1 ? "" : "s")"
    }

    private func warningBody(for alarm: AlarmItem) -> String {
        let roomText = alarm.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ""
            : " • \(alarm.location)"

        return "\(formattedTimeRange(alarm))\(roomText)"
    }

    private func overrideSummaryBody(for override: DayOverride, profile: ScheduleProfile, alarms: [AlarmItem]) -> String {
        let firstClass = alarms.first?.className.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let firstStart = alarms.first.map { anchoredDate($0.startTime, on: override.date).formatted(date: .omitted, time: .shortened) } ?? ""
        let blockCount = alarms.filter { $0.type != .transition && $0.type != .blank }.count

        var parts: [String] = [profile.name]
        if !firstClass.isEmpty && !firstStart.isEmpty {
            parts.append("Starts with \(firstClass) at \(firstStart)")
        }
        if blockCount > 0 {
            parts.append("\(blockCount) block\(blockCount == 1 ? "" : "s") planned")
        }

        return parts.joined(separator: " • ")
    }

    private func systemWeekday(from appDay: Int) -> Int {
        guard (1...7).contains(appDay) else { return 1 }
        return appDay
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
