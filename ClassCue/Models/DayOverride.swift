//
//  DayOverride.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/7/26 at 5:05 PM
//  Version: ClassCue Dev Build 18
//

import Foundation

struct DayOverride: Identifiable, Codable, Equatable {
    
    var id = UUID()
    var date: Date
    var profileID: UUID
}
