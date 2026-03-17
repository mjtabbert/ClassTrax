//
//  AttendanceRecord.swift
//  ClassTrax
//
//  Created by Codex on 3/13/26.
//

import Foundation

struct AttendanceRecord: Identifiable, Codable, Equatable {
    enum Status: String, Codable, CaseIterable, Identifiable {
        case present = "Present"
        case absent = "Absent"
        case tardy = "Tardy"
        case excused = "Excused"

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var dateKey: String
    var className: String
    var gradeLevel: String
    var studentName: String
    var status: Status

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
