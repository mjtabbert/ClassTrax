//
//  HapticPattern.swift
//  ClassCue
//
//  Created by Mr. Mike on 3/6/26 at 3:30 PM
//  Version: ClassCue Dev Build 2
//

import Foundation

enum HapticPattern: String, Codable, CaseIterable {
    
    case doubleThump = "Double Thump (Success)"
    case triplePulse = "Triple Pulse (Warning)"
    case sharpClick = "Hardware Sharp Click"
    case heavyImpact = "Standard Heavy Impact"
    case none = "None"
}
