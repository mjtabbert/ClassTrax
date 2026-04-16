import Foundation
import SwiftUI

struct BehaviorSegmentOption: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
}

struct BehaviorLogItem: Identifiable, Codable, Equatable {
    enum BehaviorKind: String, CaseIterable, Codable, Equatable, Identifiable {
        case onTask
        case respectful
        case safeBody

        var id: String { rawValue }

        var title: String {
            switch self {
            case .onTask:
                return "On Task"
            case .respectful:
                return "Respectful"
            case .safeBody:
                return "Safe Body"
            }
        }

        var shortLabel: String {
            switch self {
            case .onTask:
                return "OT"
            case .respectful:
                return "Resp"
            case .safeBody:
                return "Safe"
            }
        }
    }

    enum Rating: String, CaseIterable, Codable, Equatable, Identifiable {
        case onTask
        case neutral
        case needsSupport

        var id: String { rawValue }

        var title: String {
            switch self {
            case .onTask:
                return "On Task"
            case .neutral:
                return "Neutral"
            case .needsSupport:
                return "Needs Support"
            }
        }

        var colorLabel: String {
            switch self {
            case .onTask:
                return "Green"
            case .neutral:
                return "Yellow"
            case .needsSupport:
                return "Red"
            }
        }

        var emoji: String {
            switch self {
            case .onTask:
                return "🙂"
            case .neutral:
                return "😐"
            case .needsSupport:
                return "☹️"
            }
        }

        var tint: Color {
            switch self {
            case .onTask:
                return .green
            case .neutral:
                return .yellow
            case .needsSupport:
                return .red
            }
        }
    }

    let id: UUID
    let studentID: UUID
    let studentName: String
    let timestamp: Date
    let behavior: BehaviorKind
    let rating: Rating
    let blockID: UUID?
    let classDefinitionID: UUID?
    let segmentTitle: String
    let note: String

    init(
        id: UUID = UUID(),
        studentID: UUID,
        studentName: String,
        timestamp: Date = Date(),
        behavior: BehaviorKind = .onTask,
        rating: Rating,
        blockID: UUID? = nil,
        classDefinitionID: UUID? = nil,
        segmentTitle: String = "",
        note: String = ""
    ) {
        self.id = id
        self.studentID = studentID
        self.studentName = studentName
        self.timestamp = timestamp
        self.behavior = behavior
        self.rating = rating
        self.blockID = blockID
        self.classDefinitionID = classDefinitionID
        self.segmentTitle = segmentTitle
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        studentID = try container.decode(UUID.self, forKey: .studentID)
        studentName = try container.decode(String.self, forKey: .studentName)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        behavior = try container.decodeIfPresent(BehaviorKind.self, forKey: .behavior) ?? .onTask
        rating = try container.decode(Rating.self, forKey: .rating)
        blockID = try container.decodeIfPresent(UUID.self, forKey: .blockID)
        classDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .classDefinitionID)
        segmentTitle = try container.decodeIfPresent(String.self, forKey: .segmentTitle) ?? ""
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

extension BehaviorLogItem {
    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var noteSummary: String? {
        guard !trimmedNote.isEmpty else { return nil }

        let lines = trimmedNote
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let notesIndex = lines.firstIndex(where: { $0.lowercased().hasPrefix("notes:") }) {
            let notesLine = lines[notesIndex]
            let inlineNotes = notesLine.dropFirst("Notes:".count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !inlineNotes.isEmpty {
                return inlineNotes
            }

            let trailingNotes = lines[(notesIndex + 1)...].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trailingNotes.isEmpty {
                return trailingNotes
            }
        }

        return lines.last
    }

    var noteContextTags: [String] {
        guard !trimmedNote.isEmpty else { return [] }

        let prefixes = ["Trigger:", "Antecedent:", "Intervention:", "Follow-Up:"]
        let lines = trimmedNote
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        return lines.compactMap { line in
            guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else { return nil }
            let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            let normalizedPrefix = prefix == "Antecedent:" ? "Trigger:" : prefix
            return "\(normalizedPrefix.dropLast()) \(value)"
        }
    }

    var triggerSummary: String? {
        noteContextValue(forPrefixes: ["Trigger:", "Antecedent:"])
    }

    var interventionSummary: String? {
        noteContextValue(forPrefixes: ["Intervention:"])
    }

    var followUpSummary: String? {
        noteContextValue(forPrefixes: ["Follow-Up:"])
    }

    private func noteContextValue(forPrefixes prefixes: [String]) -> String? {
        guard !trimmedNote.isEmpty else { return nil }

        let lines = trimmedNote
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines {
            guard let prefix = prefixes.first(where: { line.hasPrefix($0) }) else { continue }
            let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return value
            }
        }

        return nil
    }
}
