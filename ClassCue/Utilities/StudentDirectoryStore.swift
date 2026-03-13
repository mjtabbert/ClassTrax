//
//  StudentDirectoryStore.swift
//  ClassCue
//
//  Created by Codex on 3/13/26.
//

import Foundation

func normalizedStudentDirectory(_ names: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for name in names {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }

        let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard seen.insert(key).inserted else { continue }

        result.append(trimmed)
    }

    return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

func decodeStudentDirectory(from data: Data) -> [String] {
    guard let decoded = try? JSONDecoder().decode([String].self, from: data) else {
        return []
    }

    return normalizedStudentDirectory(decoded)
}

func encodeStudentDirectory(_ names: [String]) -> Data {
    let normalized = normalizedStudentDirectory(names)
    return (try? JSONEncoder().encode(normalized)) ?? Data()
}

func normalizedStudentKey(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
}

func normalizedClassKey(_ value: String) -> String {
    let folded = normalizedStudentKey(value).lowercased()
    let scalars = folded.unicodeScalars.map { scalar -> Character in
        CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
    }

    return String(scalars)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

func classKeyCandidates(for value: String) -> Set<String> {
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return [] }

    var candidates: Set<String> = [normalizedClassKey(raw)]
    let separators = CharacterSet(charactersIn: ",;/|\n")

    let parts = raw
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    for part in parts {
        candidates.insert(normalizedClassKey(part))
    }

    return candidates.filter { !$0.isEmpty }
}

func classNamesMatch(scheduleClassName: String, profileClassName: String) -> Bool {
    let scheduleKeys = classKeyCandidates(for: scheduleClassName)
    let profileKeys = classKeyCandidates(for: profileClassName)

    guard !scheduleKeys.isEmpty, !profileKeys.isEmpty else { return false }
    if !scheduleKeys.isDisjoint(with: profileKeys) { return true }

    guard let schedulePrimary = scheduleKeys.first else { return false }
    return profileKeys.contains { key in
        key.contains(schedulePrimary) || schedulePrimary.contains(key)
    }
}

func duplicateStudentProfileGroups(in profiles: [StudentSupportProfile]) -> [[StudentSupportProfile]] {
    let grouped = Dictionary(grouping: profiles) { profile in
        normalizedStudentKey(profile.name)
    }

    return grouped.values
        .filter { $0.count > 1 }
        .sorted { lhs, rhs in
            guard let left = lhs.first?.name, let right = rhs.first?.name else { return false }
            return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
}

func mergedStudentProfile(from profiles: [StudentSupportProfile]) -> StudentSupportProfile? {
    guard let first = profiles.first else { return nil }

    func mergedValue(_ keyPath: KeyPath<StudentSupportProfile, String>) -> String {
        profiles
            .map { $0[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    return StudentSupportProfile(
        id: first.id,
        name: first.name.trimmingCharacters(in: .whitespacesAndNewlines),
        className: mergedValue(\.className),
        gradeLevel: mergedValue(\.gradeLevel),
        graduationYear: mergedValue(\.graduationYear),
        parentNames: mergedValue(\.parentNames),
        parentPhoneNumbers: mergedValue(\.parentPhoneNumbers),
        parentEmails: mergedValue(\.parentEmails),
        studentEmail: mergedValue(\.studentEmail),
        accommodations: mergedValue(\.accommodations),
        prompts: mergedValue(\.prompts)
    )
}

func mergedStudentProfile(existing: StudentSupportProfile, incoming: StudentSupportProfile) -> StudentSupportProfile {
    func preferred(_ current: String, _ updated: String) -> String {
        let currentValue = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedValue = updated.trimmingCharacters(in: .whitespacesAndNewlines)
        return updatedValue.isEmpty ? currentValue : updatedValue
    }

    return StudentSupportProfile(
        id: existing.id,
        name: preferred(existing.name, incoming.name),
        className: preferred(existing.className, incoming.className),
        gradeLevel: preferred(existing.gradeLevel, incoming.gradeLevel),
        graduationYear: preferred(existing.graduationYear, incoming.graduationYear),
        parentNames: preferred(existing.parentNames, incoming.parentNames),
        parentPhoneNumbers: preferred(existing.parentPhoneNumbers, incoming.parentPhoneNumbers),
        parentEmails: preferred(existing.parentEmails, incoming.parentEmails),
        studentEmail: preferred(existing.studentEmail, incoming.studentEmail),
        accommodations: preferred(existing.accommodations, incoming.accommodations),
        prompts: preferred(existing.prompts, incoming.prompts)
    )
}
