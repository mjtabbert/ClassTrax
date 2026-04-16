//
//  WidgetSnapshotStore.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import Foundation

enum ClassTraxSharedStore {
    static let appGroupID = "group.com.mrmike.classtrax"
    static let widgetSnapshotKey = "classtrax_widget_snapshot_v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

struct ClassTraxWidgetSnapshot: Codable, Equatable {
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

    static func == (lhs: ClassTraxWidgetSnapshot, rhs: ClassTraxWidgetSnapshot) -> Bool {
        lhs.current == rhs.current &&
        lhs.next == rhs.next &&
        lhs.currentRoster == rhs.currentRoster &&
        lhs.ignoreUntil == rhs.ignoreUntil
    }
}

enum WidgetSnapshotStore {
    static func load() -> ClassTraxWidgetSnapshot? {
        guard
            let data = ClassTraxSharedStore.defaults?.data(forKey: ClassTraxSharedStore.widgetSnapshotKey),
            let snapshot = try? JSONDecoder().decode(ClassTraxWidgetSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    static func save(_ snapshot: ClassTraxWidgetSnapshot) {
        guard let defaults = ClassTraxSharedStore.defaults,
              let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: ClassTraxSharedStore.widgetSnapshotKey)
    }
}
