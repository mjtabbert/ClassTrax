import Foundation
import WatchConnectivity
import Combine

struct ClassTraxWatchSnapshot: Codable, Equatable {
    struct StudentSummary: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var gradeLevel: String
        var attendanceStatusRawValue: String?
        var behaviorRatingRawValue: String?
    }

    struct BlockSummary: Codable, Equatable {
        var id: UUID
        var className: String
        var room: String
        var gradeLevel: String
        var symbolName: String
        var startTime: Date
        var endTime: Date
        var typeName: String
        var isHeld: Bool
        var bellSkipped: Bool
    }

    var updatedAt: Date
    var current: BlockSummary?
    var next: BlockSummary?
    var currentRoster: [StudentSummary]
    var ignoreUntil: Date?

    var isDayWrapped: Bool {
        current == nil && next == nil
    }

    var isStale: Bool {
        Date().timeIntervalSince(updatedAt) > 60 * 5
    }
}

@MainActor
final class WatchSnapshotStore: NSObject, ObservableObject {
    static let shared = WatchSnapshotStore()

    @Published private(set) var snapshot: ClassTraxWatchSnapshot?
    @Published private(set) var commandFeedback: String?

    private let contextKey = "classtrax_watch_snapshot"
    private let cacheKey = "classtrax_watch_snapshot_cache"
    private let actionKey = "action"
    private let itemIDKey = "itemID"
    private let studentIDKey = "studentID"
    private let studentNameKey = "studentName"
    private let studentGradeLevelKey = "studentGradeLevel"
    private let classNameKey = "className"
    private let classGradeLevelKey = "classGradeLevel"
    private let blockStartTimeKey = "blockStartTime"
    private let blockEndTimeKey = "blockEndTime"
    private let statusKey = "status"
    private let ratingKey = "rating"
    private let minutesKey = "minutes"

    override init() {
        super.init()
        snapshot = loadCachedSnapshot()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        session.activate()

        if !session.receivedApplicationContext.isEmpty {
            apply(context: session.receivedApplicationContext)
        }
    }

    private func apply(context: [String: Any]) {
        guard
            let data = context[contextKey] as? Data,
            let decoded = try? JSONDecoder().decode(ClassTraxWatchSnapshot.self, from: data)
        else {
            return
        }

        snapshot = decoded
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCachedSnapshot() -> ClassTraxWatchSnapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode(ClassTraxWatchSnapshot.self, from: data)
        else {
            return nil
        }

        return decoded
    }

    func toggleHold(for itemID: UUID) {
        sendCommand(action: "toggleHold", itemID: itemID)
    }

    func extend(itemID: UUID, minutes: Int) {
        sendCommand(action: "extend", itemID: itemID, minutes: minutes)
    }

    func skipBell(for itemID: UUID) {
        sendCommand(action: "skipBell", itemID: itemID)
    }

    func snoozeBell(minutes: Int) {
        sendCommand(action: "snoozeBell", minutes: minutes)
    }

    func clearSnooze() {
        sendCommand(action: "clearSnooze")
    }

    func markAttendance(
        block: ClassTraxWatchSnapshot.BlockSummary,
        student: ClassTraxWatchSnapshot.StudentSummary,
        status: String
    ) {
        sendCommand(
            action: "markAttendance",
            itemID: block.id,
            studentID: student.id,
            studentName: student.name,
            studentGradeLevel: student.gradeLevel,
            className: block.className,
            classGradeLevel: block.gradeLevel,
            blockStartTime: block.startTime,
            blockEndTime: block.endTime,
            status: status,
            feedback: "\(status) sent"
        )
    }

    func logBehavior(
        block: ClassTraxWatchSnapshot.BlockSummary,
        student: ClassTraxWatchSnapshot.StudentSummary,
        rating: String
    ) {
        sendCommand(
            action: "logBehavior",
            itemID: block.id,
            studentID: student.id,
            studentName: student.name,
            className: block.className,
            rating: rating,
            feedback: "Behavior sent"
        )
    }

    private func sendCommand(
        action: String,
        itemID: UUID? = nil,
        studentID: UUID? = nil,
        studentName: String? = nil,
        studentGradeLevel: String? = nil,
        className: String? = nil,
        classGradeLevel: String? = nil,
        blockStartTime: Date? = nil,
        blockEndTime: Date? = nil,
        status: String? = nil,
        rating: String? = nil,
        minutes: Int? = nil,
        feedback: String? = nil
    ) {
        guard WCSession.isSupported() else { return }

        let payload: [String: Any] = {
            var value: [String: Any] = [actionKey: action]
            if let itemID {
                value[itemIDKey] = itemID.uuidString
            }
            if let studentID {
                value[studentIDKey] = studentID.uuidString
            }
            if let studentName {
                value[studentNameKey] = studentName
            }
            if let studentGradeLevel {
                value[studentGradeLevelKey] = studentGradeLevel
            }
            if let className {
                value[classNameKey] = className
            }
            if let classGradeLevel {
                value[classGradeLevelKey] = classGradeLevel
            }
            if let blockStartTime {
                value[blockStartTimeKey] = blockStartTime
            }
            if let blockEndTime {
                value[blockEndTimeKey] = blockEndTime
            }
            if let status {
                value[statusKey] = status
            }
            if let rating {
                value[ratingKey] = rating
            }
            if let minutes {
                value[minutesKey] = minutes
            }
            return value
        }()

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(
                payload,
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        let message = (reply["message"] as? String) ?? feedback ?? "Sent to iPhone"
                        self?.showFeedback(message)
                    }
                },
                errorHandler: { [weak self] _ in
                    Task { @MainActor in
                        self?.showFeedback("Unable to reach iPhone")
                    }
                }
            )
        } else {
            session.transferUserInfo(payload)
            showFeedback("Queued for iPhone")
        }
    }

    private func showFeedback(_ message: String) {
        commandFeedback = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.commandFeedback == message {
                self?.commandFeedback = nil
            }
        }
    }
}

extension WatchSnapshotStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if !session.receivedApplicationContext.isEmpty {
            Task { @MainActor in
                self.apply(context: session.receivedApplicationContext)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.apply(context: applicationContext)
        }
    }
}
