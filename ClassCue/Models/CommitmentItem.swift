//
//  CommitmentItem.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import Foundation
import SwiftUI

struct CommitmentItem: Identifiable, Codable, Equatable {

    enum Kind: String, Codable, CaseIterable {
        case duty
        case meeting
        case conference
        case plc
        case coverage
        case reminder
        case other

        var displayName: String {
            switch self {
            case .duty:
                return "Duty"
            case .meeting:
                return "Meeting"
            case .conference:
                return "Conference"
            case .plc:
                return "PLC"
            case .coverage:
                return "Coverage"
            case .reminder:
                return "Reminder"
            case .other:
                return "Other"
            }
        }

        var systemImage: String {
            switch self {
            case .duty:
                return "figure.walk"
            case .meeting:
                return "person.2.fill"
            case .conference:
                return "bubble.left.and.bubble.right.fill"
            case .plc:
                return "rectangle.3.group.bubble.left.fill"
            case .coverage:
                return "person.crop.rectangle.stack.fill"
            case .reminder:
                return "bell.badge.fill"
            case .other:
                return "briefcase.fill"
            }
        }

        var tint: Color {
            switch self {
            case .duty:
                return .orange
            case .meeting:
                return .blue
            case .conference:
                return .pink
            case .plc:
                return .indigo
            case .coverage:
                return .teal
            case .reminder:
                return .yellow
            case .other:
                return .gray
            }
        }
    }

    var id = UUID()
    var title: String
    var kind: Kind = .other
    var dayOfWeek: Int
    var startTime: Date
    var endTime: Date
    var location: String = ""
    var notes: String = ""
}
