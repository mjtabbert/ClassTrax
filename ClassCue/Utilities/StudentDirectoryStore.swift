//
//  StudentDirectoryStore.swift
//  ClassTrax
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

func gradeLevelsCompatible(_ lhs: String, _ rhs: String) -> Bool {
    let left = normalizedStudentKey(GradeLevelOption.normalized(lhs))
    let right = normalizedStudentKey(GradeLevelOption.normalized(rhs))

    if left.isEmpty || right.isEmpty {
        return true
    }

    return left == right
}

func linkedClassDefinitionIDs(for profile: StudentSupportProfile) -> [UUID] {
    let ids = profile.classDefinitionIDs + (profile.classDefinitionID.map { [$0] } ?? [])
    var seen = Set<UUID>()
    return ids.filter { seen.insert($0).inserted }
}

func profileMatches(classDefinitionID: UUID, profile: StudentSupportProfile) -> Bool {
    linkedClassDefinitionIDs(for: profile).contains(classDefinitionID)
}

func linkedClassDefinitions(
    for profile: StudentSupportProfile,
    in definitions: [ClassDefinitionItem]
) -> [ClassDefinitionItem] {
    let linkedIDs = Set(linkedClassDefinitionIDs(for: profile))
    guard !linkedIDs.isEmpty else { return [] }
    return definitions.filter { linkedIDs.contains($0.id) }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
}

func linkedClassNames(
    for profile: StudentSupportProfile,
    in definitions: [ClassDefinitionItem]
) -> [String] {
    let namesFromDefinitions = linkedClassDefinitions(for: profile, in: definitions)
        .map(\.name)
        .compactMap(sanitizedClassLabel)
    if !namesFromDefinitions.isEmpty {
        return namesFromDefinitions
    }

    let separators = CharacterSet(charactersIn: ",;/|\n")
    return profile.className
        .components(separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .compactMap(sanitizedClassLabel)
        .reduce(into: [String]()) { result, value in
            if !result.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

func classSummary(
    for profile: StudentSupportProfile,
    in definitions: [ClassDefinitionItem]
) -> String {
    let names = linkedClassNames(for: profile, in: definitions)
    if !names.isEmpty {
        return names.joined(separator: ", ")
    }

    return sanitizedClassLabel(profile.className) ?? ""
}

func mergedClassSummary(current: String, adding newValue: String) -> String {
    let values = (current.components(separatedBy: CharacterSet(charactersIn: ",;/|\n")) + [newValue])
        .compactMap(sanitizedClassLabel)

    var seen = Set<String>()
    let unique = values.filter { value in
        let key = normalizedClassKey(value)
        guard !key.isEmpty else { return false }
        return seen.insert(key).inserted
    }

    return unique.joined(separator: ", ")
}

func removingClassSummary(current: String, removing valueToRemove: String) -> String {
    let removalKey = normalizedClassKey(valueToRemove)
    guard !removalKey.isEmpty else { return current }

    let remaining = current
        .components(separatedBy: CharacterSet(charactersIn: ",;/|\n"))
        .compactMap(sanitizedClassLabel)
        .filter { normalizedClassKey($0) != removalKey }

    return remaining.joined(separator: ", ")
}

func updatingProfile(
    _ profile: StudentSupportProfile,
    linkedTo classDefinitionIDs: [UUID],
    definitions: [ClassDefinitionItem]
) -> StudentSupportProfile {
    let uniqueIDs = Array(Set(classDefinitionIDs))
    let primaryID = uniqueIDs.sorted { $0.uuidString < $1.uuidString }.first
    var updated = profile
    updated.classDefinitionID = primaryID
    updated.classDefinitionIDs = uniqueIDs.sorted { $0.uuidString < $1.uuidString }
    updated.className = classSummary(for: updated, in: definitions)
    return updated
}

func classContext(
    for profile: StudentSupportProfile,
    classDefinitionID: UUID
) -> StudentSupportProfile.ClassContext? {
    profile.classContexts.first { $0.classDefinitionID == classDefinitionID }
}

func updatingProfile(
    _ profile: StudentSupportProfile,
    classContext: StudentSupportProfile.ClassContext
) -> StudentSupportProfile {
    var updated = profile
    if let index = updated.classContexts.firstIndex(where: { $0.classDefinitionID == classContext.classDefinitionID }) {
        updated.classContexts[index] = classContext
    } else {
        updated.classContexts.append(classContext)
    }
    updated.classContexts.sort { $0.classDefinitionID.uuidString < $1.classDefinitionID.uuidString }
    return updated
}

func exactClassDefinitionMatch(
    name: String,
    gradeLevel: String,
    in definitions: [ClassDefinitionItem]
) -> ClassDefinitionItem? {
    let normalizedName = normalizedClassKey(name)
    let normalizedGrade = normalizedStudentKey(GradeLevelOption.normalized(gradeLevel))

    guard !normalizedName.isEmpty else { return nil }

    if !normalizedGrade.isEmpty,
       let exactGradeMatch = definitions.first(where: {
           normalizedClassKey($0.name) == normalizedName &&
           normalizedStudentKey(GradeLevelOption.normalized($0.gradeLevel)) == normalizedGrade
       }) {
        return exactGradeMatch
    }

    let nameMatches = definitions.filter {
        normalizedClassKey($0.name) == normalizedName
    }

    if let gradeAgnosticMatch = nameMatches.first(where: {
        normalizedStudentKey(GradeLevelOption.normalized($0.gradeLevel)).isEmpty
    }) {
        return gradeAgnosticMatch
    }

    if nameMatches.count == 1 {
        return nameMatches.first
    }

    return nil
}

func classDefinitionCandidates(
    name: String,
    gradeLevel: String,
    in definitions: [ClassDefinitionItem]
) -> [ClassDefinitionItem] {
    let normalizedName = normalizedClassKey(name)
    let normalizedGrade = normalizedStudentKey(GradeLevelOption.normalized(gradeLevel))

    return definitions.filter { definition in
        let definitionName = normalizedClassKey(definition.name)
        let definitionGrade = normalizedStudentKey(GradeLevelOption.normalized(definition.gradeLevel))

        if !normalizedName.isEmpty && definitionName == normalizedName {
            return true
        }

        if !normalizedGrade.isEmpty && !definitionGrade.isEmpty && definitionGrade == normalizedGrade {
            return true
        }

        return false
    }
    .sorted { lhs, rhs in
        let lhsNameMatch = normalizedClassKey(lhs.name) == normalizedName
        let rhsNameMatch = normalizedClassKey(rhs.name) == normalizedName
        if lhsNameMatch != rhsNameMatch {
            return lhsNameMatch
        }

        let lhsGradeMatch = !normalizedGrade.isEmpty &&
            normalizedStudentKey(GradeLevelOption.normalized(lhs.gradeLevel)) == normalizedGrade
        let rhsGradeMatch = !normalizedGrade.isEmpty &&
            normalizedStudentKey(GradeLevelOption.normalized(rhs.gradeLevel)) == normalizedGrade
        if lhsGradeMatch != rhsGradeMatch {
            return lhsGradeMatch
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
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

func allTeacherContacts(in contacts: [ClassStaffContact]) -> [ClassStaffContact] {
    uniqueStaffContacts(contacts)
}

func allParaContacts(in contacts: [ClassStaffContact]) -> [ClassStaffContact] {
    uniqueStaffContacts(contacts)
}

func supportSummary(
    for profile: StudentSupportProfile,
    teachers: [ClassStaffContact],
    paras: [ClassStaffContact]
) -> String {
    var parts: [String] = []

    if profile.isSped {
        parts.append("Additional Supports")
    }

    let teacherNames = resolvedStaffContacts(
        matching: profile.supportTeacherIDs,
        in: allTeacherContacts(in: teachers)
    )
    .map(\.trimmedName)
    .filter { !$0.isEmpty }

    let paraNames = resolvedStaffContacts(
        matching: profile.supportParaIDs,
        in: allParaContacts(in: paras)
    )
    .map(\.trimmedName)
    .filter { !$0.isEmpty }

    if !teacherNames.isEmpty {
        parts.append("Teachers: \(teacherNames.joined(separator: ", "))")
    }

    if !paraNames.isEmpty {
        parts.append("Paras: \(paraNames.joined(separator: ", "))")
    }

    let rooms = profile.supportRooms.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rooms.isEmpty {
        parts.append("Rooms: \(rooms)")
    }

    return parts.joined(separator: " • ")
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
        classDefinitionID: profiles.compactMap(\.classDefinitionID).first,
        classDefinitionIDs: Array(Set(profiles.flatMap(\.classDefinitionIDs) + profiles.compactMap(\.classDefinitionID))),
        classContexts: profiles.flatMap(\.classContexts).reduce(into: [StudentSupportProfile.ClassContext]()) { result, context in
            if !result.contains(where: { $0.classDefinitionID == context.classDefinitionID }) {
                result.append(context)
            }
        },
        graduationYear: mergedValue(\.graduationYear),
        parentNames: mergedValue(\.parentNames),
        parentPhoneNumbers: mergedValue(\.parentPhoneNumbers),
        parentEmails: mergedValue(\.parentEmails),
        studentEmail: mergedValue(\.studentEmail),
        isSped: profiles.contains(where: \.isSped),
        supportTeacherIDs: Array(Set(profiles.flatMap(\.supportTeacherIDs))),
        supportParaIDs: Array(Set(profiles.flatMap(\.supportParaIDs))),
        supportRooms: mergedValue(\.supportRooms),
        supportScheduleNotes: mergedValue(\.supportScheduleNotes),
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
        className: sanitizedClassLabel(preferred(existing.className, incoming.className)) ?? "",
        gradeLevel: preferred(existing.gradeLevel, incoming.gradeLevel),
        classDefinitionID: incoming.classDefinitionID ?? existing.classDefinitionID,
        classDefinitionIDs: Array(Set(existing.classDefinitionIDs + incoming.classDefinitionIDs + [existing.classDefinitionID, incoming.classDefinitionID].compactMap { $0 })),
        classContexts: (existing.classContexts + incoming.classContexts).reduce(into: [StudentSupportProfile.ClassContext]()) { result, context in
            if let index = result.firstIndex(where: { $0.classDefinitionID == context.classDefinitionID }) {
                result[index] = context
            } else {
                result.append(context)
            }
        },
        graduationYear: preferred(existing.graduationYear, incoming.graduationYear),
        parentNames: preferred(existing.parentNames, incoming.parentNames),
        parentPhoneNumbers: preferred(existing.parentPhoneNumbers, incoming.parentPhoneNumbers),
        parentEmails: preferred(existing.parentEmails, incoming.parentEmails),
        studentEmail: preferred(existing.studentEmail, incoming.studentEmail),
        isSped: existing.isSped || incoming.isSped,
        supportTeacherIDs: Array(Set(existing.supportTeacherIDs + incoming.supportTeacherIDs)),
        supportParaIDs: Array(Set(existing.supportParaIDs + incoming.supportParaIDs)),
        supportRooms: preferred(existing.supportRooms, incoming.supportRooms),
        supportScheduleNotes: preferred(existing.supportScheduleNotes, incoming.supportScheduleNotes),
        accommodations: preferred(existing.accommodations, incoming.accommodations),
        prompts: preferred(existing.prompts, incoming.prompts)
    )
}

private func uniqueStaffContacts(_ contacts: [ClassStaffContact]) -> [ClassStaffContact] {
    var seen = Set<UUID>()

    return contacts
        .filter { !($0.trimmedName.isEmpty && $0.emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        .filter { contact in
            seen.insert(contact.id).inserted
        }
        .sorted { lhs, rhs in
            lhs.trimmedName.localizedCaseInsensitiveCompare(rhs.trimmedName) == .orderedAscending
        }
}

private func resolvedStaffContacts(
    matching ids: [UUID],
    in contacts: [ClassStaffContact]
) -> [ClassStaffContact] {
    let idSet = Set(ids)
    return contacts.filter { idSet.contains($0.id) }
}

private func sanitizedClassLabel(_ rawValue: String) -> String? {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let normalized = trimmed
        .lowercased()
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: " ", with: "")

    if normalized == "nsmanagedobject" ||
        normalized == "managedobject" ||
        normalized.contains("nsmanagedobject") ||
        normalized.contains("managedobject") {
        return nil
    }

    return trimmed
}
