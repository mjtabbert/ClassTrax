//
//  AppInfo.swift
//  ClassTrax
//
//  Created by Mr. Mike on 3/7/26 at 6:25 PM
//  Version: ClassTrax Dev Build 22
//

import Foundation

enum AppInfo {
    
    static let appName = "Class Trax"
    static let displayName = "Class Trax"
    static let developerName = "Mr. Mike"
    
    static let marketingVersion = "0.9"
    static let buildNumber = "22"
    static let versionLabel = "Version \(marketingVersion) (\(buildNumber))"
    
    static let supportEmail = "support@classtrax.app"
    static let appTagline = "Teacher schedule and timer system"
    
    static let launchChecklist: [String] = [
        "Confirm app name and display name",
        "Add finished app icon set in Assets",
        "Review tab labels and screen titles",
        "Test alerts on a real iPhone",
        "Test notifications in background",
        "Test CSV import and export",
        "Test profiles and day overrides",
        "Proofread About and Settings screens",
        "Set version and build for release",
        "Prepare TestFlight beta notes"
    ]
    
    static var exportText: String {
        """
        \(appName)
        \(appTagline)
        Developer: \(developerName)
        \(versionLabel)
        Support: \(supportEmail)
        Generated: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }
    
    static var checklistExportText: String {
        let lines = launchChecklist.enumerated().map { index, item in
            "\(index + 1). \(item)"
        }.joined(separator: "\n")
        
        return """
        \(appName) Launch Readiness Checklist
        
        \(lines)
        
        Generated: \(Date().formatted(date: .abbreviated, time: .shortened))
        """
    }
}
