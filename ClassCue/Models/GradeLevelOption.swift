//
//  GradeLevelOption.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import Foundation

enum GradeLevelOption: String, CaseIterable, Codable, Identifiable {
    case preK = "Pre-K"
    case kindergarten = "K"
    case first = "1st Grade"
    case second = "2nd Grade"
    case third = "3rd Grade"
    case fourth = "4th Grade"
    case fifth = "5th Grade"
    case sixth = "6th Grade"
    case seventh = "7th Grade"
    case eighth = "8th Grade"
    case ninth = "9th Grade"
    case tenth = "10th Grade"
    case eleventh = "11th Grade"
    case twelfth = "12th Grade"
    case twelvePlus = "12+"
    case other = "Other"

    var id: String { rawValue }

    static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: "")

        switch normalized {
        case "prek", "pre k", "prekindergarten", "pre kindergarten", "pk":
            return preK.rawValue
        case "k", "kindergarten":
            return kindergarten.rawValue
        case "1", "1st", "1st grade", "first", "first grade", "grade 1":
            return first.rawValue
        case "2", "2nd", "2nd grade", "second", "second grade", "grade 2":
            return second.rawValue
        case "3", "3rd", "3rd grade", "third", "third grade", "grade 3":
            return third.rawValue
        case "4", "4th", "4th grade", "fourth", "fourth grade", "grade 4":
            return fourth.rawValue
        case "5", "5th", "5th grade", "fifth", "fifth grade", "grade 5":
            return fifth.rawValue
        case "6", "6th", "6th grade", "sixth", "sixth grade", "grade 6":
            return sixth.rawValue
        case "7", "7th", "7th grade", "seventh", "seventh grade", "grade 7":
            return seventh.rawValue
        case "8", "8th", "8th grade", "eighth", "eighth grade", "grade 8":
            return eighth.rawValue
        case "9", "9th", "9th grade", "ninth", "ninth grade", "grade 9":
            return ninth.rawValue
        case "10", "10th", "10th grade", "tenth", "tenth grade", "grade 10":
            return tenth.rawValue
        case "11", "11th", "11th grade", "eleventh", "eleventh grade", "grade 11":
            return eleventh.rawValue
        case "12", "12th", "12th grade", "twelfth", "twelfth grade", "grade 12":
            return twelfth.rawValue
        case "12+", "12 plus", "post secondary", "postsecondary":
            return twelvePlus.rawValue
        case "other":
            return other.rawValue
        default:
            return trimmed
        }
    }

    static func optionsForPicker() -> [String] {
        allCases.map(\.rawValue)
    }
}
