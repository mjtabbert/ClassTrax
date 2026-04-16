import Foundation

#if os(iOS)
import WatchConnectivity

final class WatchSessionSyncManager: NSObject {
    static let shared = WatchSessionSyncManager()

    private let snapshotContextKey = "classtrax_watch_snapshot"
    private let actionKey = "action"
    private let itemIDKey = "itemID"
    private let studentIDKey = "studentID"
    private let statusKey = "status"
    private let ratingKey = "rating"
    private let minutesKey = "minutes"
    private let studentNameKey = "studentName"
    private let studentGradeLevelKey = "studentGradeLevel"
    private let classNameKey = "className"
    private let classGradeLevelKey = "classGradeLevel"
    private let blockStartTimeKey = "blockStartTime"
    private let blockEndTimeKey = "blockEndTime"
    private let savedAttendanceKey = "attendance_v1_data"
    private let savedBehaviorLogsKey = "behavior_logs_v1_data"

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        session.activate()
    }

    func sync(snapshot: ClassTraxWidgetSnapshot) {
        guard WCSession.isSupported() else { return }
        activate()

        guard let data = try? JSONEncoder().encode(snapshot) else { return }

        do {
            try WCSession.default.updateApplicationContext([snapshotContextKey: data])
        } catch {
            #if DEBUG
            print("Watch sync failed:", error.localizedDescription)
            #endif
        }
    }

    @MainActor
    private func handleCommand(_ message: [String: Any]) -> String {
        guard let action = message[actionKey] as? String else { return "Missing action" }

        let itemID: UUID? = {
            guard let itemIDRaw = message[itemIDKey] as? String else { return nil }
            return UUID(uuidString: itemIDRaw)
        }()

        let studentID: UUID? = {
            guard let studentIDRaw = message[studentIDKey] as? String else { return nil }
            return UUID(uuidString: studentIDRaw)
        }()

        switch action {
        case "toggleHold":
            guard let itemID else { return "Missing block" }
            SessionControlStore.toggleHold(itemID: itemID, now: Date())
            return "Hold updated"
        case "extend":
            guard let itemID else { return "Missing block" }
            let minutes = message[minutesKey] as? Int ?? 1
            SessionControlStore.extend(itemID: itemID, byMinutes: minutes)
            return "Added \(minutes) min"
        case "skipBell":
            guard let itemID else { return "Missing block" }
            SessionControlStore.skipBell(itemID: itemID)
            return "Bell skipped"
        case "snoozeBell":
            let minutes = message[minutesKey] as? Int ?? 15
            ScheduleSnoozeStore.setPause(until: Date().addingTimeInterval(TimeInterval(minutes * 60)))
            return "Snoozed \(minutes) min"
        case "clearSnooze":
            ScheduleSnoozeStore.setPause(until: nil)
            return "Snooze cleared"
        case "markAttendance":
            guard
                let itemID,
                let studentID,
                let rawStatus = message[statusKey] as? String,
                let status = AttendanceRecord.Status(rawValue: rawStatus)
            else {
                return "Attendance data missing"
            }
            return updateAttendance(itemID: itemID, studentID: studentID, status: status, message: message)
        case "logBehavior":
            guard
                let itemID,
                let studentID,
                let rawRating = message[ratingKey] as? String,
                let rating = BehaviorLogItem.Rating(rawValue: rawRating)
            else {
                return "Behavior data missing"
            }
            return logBehavior(itemID: itemID, studentID: studentID, rating: rating, message: message)
        default:
            return "Unsupported action"
        }
    }

    @MainActor
    private func updateAttendance(itemID: UUID, studentID: UUID, status: AttendanceRecord.Status, message: [String: Any]) -> String {
        guard
            let studentName = message[studentNameKey] as? String,
            let className = message[classNameKey] as? String,
            let blockStartTime = message[blockStartTimeKey] as? Date,
            let blockEndTime = message[blockEndTimeKey] as? Date
        else {
            return "Attendance data missing"
        }

        let studentGradeLevel = (message[studentGradeLevelKey] as? String) ?? ""
        let classGradeLevel = (message[classGradeLevelKey] as? String) ?? ""
        let dateKey = AttendanceRecord.dateKey(for: Date())
        let matchKey = attendanceMatchKey(studentID: studentID, studentName: studentName)
        var records = AttendanceRecord.pruneToCurrentWeek(loadAttendanceRecords())
        records.removeAll { record in
            let matchesBlock = record.blockID == itemID || (
                record.blockStartTime == blockStartTime &&
                record.blockEndTime == blockEndTime
            )

            return record.isAttendanceEntry &&
                record.dateKey == dateKey &&
                matchesBlock &&
                attendanceMatchKey(studentID: record.studentID, studentName: record.studentName) == matchKey
        }

        records.append(
            AttendanceRecord(
                dateKey: dateKey,
                className: className,
                gradeLevel: GradeLevelOption.normalized(studentGradeLevel.isEmpty ? classGradeLevel : studentGradeLevel),
                studentName: studentName,
                studentID: studentID,
                classDefinitionID: nil,
                blockID: itemID,
                blockStartTime: blockStartTime,
                blockEndTime: blockEndTime,
                status: status
            )
        )

        let normalizedRecords = AttendanceRecord.pruneToCurrentWeek(records)
        UserDefaults.standard.set((try? JSONEncoder().encode(normalizedRecords)) ?? Data(), forKey: savedAttendanceKey)
        return "\(studentName): \(status.rawValue)"
    }

    @MainActor
    private func logBehavior(itemID: UUID, studentID: UUID, rating: BehaviorLogItem.Rating, message: [String: Any]) -> String {
        guard
            let studentName = message[studentNameKey] as? String,
            let className = message[classNameKey] as? String
        else {
            return "Behavior data missing"
        }

        let now = Date()
        let segmentTitle = className.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var logs = loadBehaviorLogs()
        let matchingIndex = logs.firstIndex(where: { log in
            log.studentID == studentID &&
            log.behavior == .onTask &&
            Calendar.current.isDate(log.timestamp, inSameDayAs: now) &&
            normalizedSegmentTitle(log.segmentTitle) == normalizedSegmentTitle(segmentTitle)
        })

        if let matchingIndex {
            if logs[matchingIndex].rating == rating {
                logs.remove(at: matchingIndex)
            } else {
                logs[matchingIndex] = BehaviorLogItem(
                    id: logs[matchingIndex].id,
                    studentID: studentID,
                    studentName: studentName,
                    timestamp: now,
                    behavior: .onTask,
                    rating: rating,
                    blockID: itemID,
                    classDefinitionID: nil,
                    segmentTitle: segmentTitle,
                    note: logs[matchingIndex].note
                )
            }
        } else {
            logs.insert(
                BehaviorLogItem(
                    studentID: studentID,
                    studentName: studentName,
                    timestamp: now,
                    behavior: .onTask,
                    rating: rating,
                    blockID: itemID,
                    classDefinitionID: nil,
                    segmentTitle: segmentTitle
                ),
                at: 0
            )
        }

        saveBehaviorLogs(logs)
        return "\(studentName): \(rating.colorLabel)"
    }

    private func loadBehaviorLogs() -> [BehaviorLogItem] {
        guard
            let data = UserDefaults.standard.data(forKey: savedBehaviorLogsKey),
            let logs = try? JSONDecoder().decode([BehaviorLogItem].self, from: data)
        else {
            return []
        }

        return logs.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveBehaviorLogs(_ logs: [BehaviorLogItem]) {
        let normalizedLogs = logs.sorted { $0.timestamp > $1.timestamp }
        UserDefaults.standard.set((try? JSONEncoder().encode(normalizedLogs)) ?? Data(), forKey: savedBehaviorLogsKey)
    }

    private func loadAttendanceRecords() -> [AttendanceRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: savedAttendanceKey),
            let records = try? JSONDecoder().decode([AttendanceRecord].self, from: data)
        else {
            return []
        }

        return records
    }

    private func attendanceMatchKey(studentID: UUID?, studentName: String) -> String? {
        if let studentID {
            return studentID.uuidString.lowercased()
        }

        let normalizedName = normalizedStudentKey(studentName)
        return normalizedName.isEmpty ? nil : "name:\(normalizedName)"
    }

    private func normalizedStudentKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func normalizedSegmentTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension WatchSessionSyncManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            _ = handleCommand(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            let result = handleCommand(message)
            replyHandler(["message": result])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            _ = handleCommand(userInfo)
        }
    }
}
#else
final class WatchSessionSyncManager {
    static let shared = WatchSessionSyncManager()

    func activate() {
    }

    func sync(snapshot: ClassTraxWidgetSnapshot) {
    }
}
#endif
