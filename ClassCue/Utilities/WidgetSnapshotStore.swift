//
//  WidgetSnapshotStore.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import Foundation

enum ClassCueSharedStore {
    static let appGroupID = "group.com.mrmike.classcue"
    static let widgetSnapshotKey = "classcue_widget_snapshot_v1"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

struct ClassCueWidgetSnapshot: Codable, Equatable {
    struct BlockSummary: Codable, Equatable {
        var className: String
        var room: String
        var gradeLevel: String
        var symbolName: String
        var startTime: Date
        var endTime: Date
        var typeName: String
    }

    var updatedAt: Date
    var current: BlockSummary?
    var next: BlockSummary?

    var isDayWrapped: Bool {
        current == nil && next == nil
    }
}

enum WidgetSnapshotStore {
    static func load() -> ClassCueWidgetSnapshot? {
        guard
            let data = ClassCueSharedStore.defaults?.data(forKey: ClassCueSharedStore.widgetSnapshotKey),
            let snapshot = try? JSONDecoder().decode(ClassCueWidgetSnapshot.self, from: data)
        else {
            return nil
        }

        return snapshot
    }

    static func save(_ snapshot: ClassCueWidgetSnapshot) {
        guard let defaults = ClassCueSharedStore.defaults,
              let data = try? JSONEncoder().encode(snapshot) else { return }

        defaults.set(data, forKey: ClassCueSharedStore.widgetSnapshotKey)
    }
}
