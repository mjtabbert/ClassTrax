//
//  TodoItem.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 3:05 PM
//  Version: ClassCue Dev Build 11.1
//

import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    
    var id = UUID()
    var task: String
    var isCompleted: Bool = false
    var priority: Priority = .none
    var dueDate: Date? = nil
    
    enum Priority: String, Codable, CaseIterable {
        
        case high = "High"
        case med = "Med"
        case low = "Low"
        case none = "None"
        
        var color: Color {
            switch self {
            case .high: return .red
            case .med: return .orange
            case .low: return .blue
            case .none: return .gray
            }
        }
    }
}
