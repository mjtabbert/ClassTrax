import Foundation
import CoreData
import SwiftData
import CloudKit

protocol PersistedUUIDModel: PersistentModel {
    var id: UUID { get set }
}

@Model
final class PersistedAlarmItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var name: String = ""
    var start: Date = Date.distantPast
    var end: Date = Date.distantPast
    var location: String = ""
    var scheduleTypeRawValue: String = AlarmItem.ScheduleType.other.rawValue
    var dayOfWeekValue: Int?
    var gradeLevelValue: String = ""
    var classDefinitionID: UUID?
    var linkedStudentIDsRawValue: String = ""
    var warningLeadTimesRawValue: String = "5,2,1"

    init(from item: AlarmItem) {
        update(from: item)
    }

    func update(from item: AlarmItem) {
        self.id = item.id
        self.name = item.className
        self.start = item.startTime
        self.end = item.endTime
        self.location = item.location
        self.scheduleTypeRawValue = item.type.rawValue
        self.dayOfWeekValue = item.dayOfWeekValue
        self.gradeLevelValue = item.gradeLevel
        self.classDefinitionID = item.classDefinitionID
        self.linkedStudentIDsRawValue = item.linkedStudentIDs
            .map(\.uuidString)
            .joined(separator: ",")
        self.warningLeadTimesRawValue = item.warningLeadTimes
            .map(String.init)
            .joined(separator: ",")
    }

    func asAlarmItem() -> AlarmItem {
        AlarmItem(
            id: id,
            name: name,
            start: start,
            end: end,
            location: location,
            scheduleType: AlarmItem.ScheduleType(rawValue: scheduleTypeRawValue) ?? .other,
            dayOfWeek: dayOfWeekValue,
            gradeLevel: gradeLevelValue,
            classDefinitionID: classDefinitionID,
            linkedStudentIDs: linkedStudentIDsRawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) }
            ,
            warningLeadTimes: warningLeadTimesRawValue
                .split(separator: ",")
                .compactMap { Int($0) }
        )
    }
}

@Model
final class PersistedStudentSupportProfile: PersistedUUIDModel {
    var id: UUID = UUID()
    var name: String = ""
    var className: String = ""
    var gradeLevel: String = ""
    var classDefinitionID: UUID?
    var classDefinitionIDsRawValue: String = ""
    var classContextsRawValue: String = ""
    var graduationYear: String = ""
    var parentNames: String = ""
    var parentPhoneNumbers: String = ""
    var parentEmails: String = ""
    var studentEmail: String = ""
    var isSped: Bool = false
    var supportTeacherIDsRawValue: String = ""
    var supportParaIDsRawValue: String = ""
    var supportRooms: String = ""
    var supportScheduleNotes: String = ""
    var accommodations: String = ""
    var prompts: String = ""

    init(from item: StudentSupportProfile) {
        update(from: item)
    }

    func update(from item: StudentSupportProfile) {
        self.id = item.id
        self.name = item.name
        self.className = item.className
        self.gradeLevel = item.gradeLevel
        self.classDefinitionID = item.classDefinitionID
        self.classDefinitionIDsRawValue = linkedClassDefinitionIDs(for: item)
            .map(\.uuidString)
            .joined(separator: ",")
        self.classContextsRawValue = (try? String(data: JSONEncoder().encode(item.classContexts), encoding: .utf8)) ?? ""
        self.graduationYear = item.graduationYear
        self.parentNames = item.parentNames
        self.parentPhoneNumbers = item.parentPhoneNumbers
        self.parentEmails = item.parentEmails
        self.studentEmail = item.studentEmail
        self.isSped = item.isSped
        self.supportTeacherIDsRawValue = item.supportTeacherIDs
            .map(\.uuidString)
            .joined(separator: ",")
        self.supportParaIDsRawValue = item.supportParaIDs
            .map(\.uuidString)
            .joined(separator: ",")
        self.supportRooms = item.supportRooms
        self.supportScheduleNotes = item.supportScheduleNotes
        self.accommodations = item.accommodations
        self.prompts = item.prompts
    }

    func asStudentSupportProfile() -> StudentSupportProfile {
        StudentSupportProfile(
            id: id,
            name: name,
            className: className,
            gradeLevel: gradeLevel,
            classDefinitionID: classDefinitionID,
            classDefinitionIDs: classDefinitionIDsRawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) },
            classContexts: (try? JSONDecoder().decode([StudentSupportProfile.ClassContext].self, from: Data(classContextsRawValue.utf8))) ?? [],
            graduationYear: graduationYear,
            parentNames: parentNames,
            parentPhoneNumbers: parentPhoneNumbers,
            parentEmails: parentEmails,
            studentEmail: studentEmail,
            isSped: isSped,
            supportTeacherIDs: supportTeacherIDsRawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) },
            supportParaIDs: supportParaIDsRawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) },
            supportRooms: supportRooms,
            supportScheduleNotes: supportScheduleNotes,
            accommodations: accommodations,
            prompts: prompts
        )
    }
}

@Model
final class PersistedClassDefinitionItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var name: String = ""
    var scheduleKindRawValue: String = ClassDefinitionItem.ScheduleKind.other.rawValue
    var gradeLevel: String = ""
    var defaultLocation: String = ""
    var teacherContactsRawValue: String = ""
    var paraContactsRawValue: String = ""

    init(from item: ClassDefinitionItem) {
        update(from: item)
    }

    func update(from item: ClassDefinitionItem) {
        self.id = item.id
        self.name = item.name
        self.scheduleKindRawValue = item.scheduleKind.rawValue
        self.gradeLevel = item.gradeLevel
        self.defaultLocation = item.defaultLocation
        self.teacherContactsRawValue = (try? String(data: JSONEncoder().encode(item.teacherContacts), encoding: .utf8)) ?? ""
        self.paraContactsRawValue = (try? String(data: JSONEncoder().encode(item.paraContacts), encoding: .utf8)) ?? ""
    }

    func asClassDefinitionItem() -> ClassDefinitionItem {
        ClassDefinitionItem(
            id: id,
            name: name,
            scheduleType: ClassDefinitionItem.ScheduleKind(rawValue: scheduleKindRawValue) ?? .other,
            gradeLevel: gradeLevel,
            defaultLocation: defaultLocation,
            teacherContacts: (try? JSONDecoder().decode([ClassStaffContact].self, from: Data(teacherContactsRawValue.utf8))) ?? [],
            paraContacts: (try? JSONDecoder().decode([ClassStaffContact].self, from: Data(paraContactsRawValue.utf8))) ?? []
        )
    }
}

@Model
final class PersistedSupportStaffMember: PersistedUUIDModel {
    var id: UUID = UUID()
    var roleRawValue: String = SupportStaffRole.teacher.rawValue
    var name: String = ""
    var room: String = ""
    var cell: String = ""
    var extensionNumber: String = ""
    var emailAddress: String = ""
    var subject: String = ""

    init(role: SupportStaffRole, contact: ClassStaffContact) {
        update(role: role, contact: contact)
    }

    func update(role: SupportStaffRole, contact: ClassStaffContact) {
        self.id = contact.id
        self.roleRawValue = role.rawValue
        self.name = contact.name
        self.room = contact.room
        self.cell = contact.cell
        self.extensionNumber = contact.extensionNumber
        self.emailAddress = contact.emailAddress
        self.subject = contact.subject
    }

    func asStaffContact() -> ClassStaffContact {
        ClassStaffContact(
            id: id,
            name: name,
            room: room,
            cell: cell,
            extensionNumber: extensionNumber,
            emailAddress: emailAddress,
            subject: subject
        )
    }
}

@Model
final class PersistedCommitmentItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var title: String = ""
    var kindRawValue: String = CommitmentItem.Kind.other.rawValue
    var dayOfWeek: Int = 1
    var recurrenceRawValue: String = CommitmentItem.Recurrence.weekly.rawValue
    var specificDate: Date?
    var startTime: Date = Date.distantPast
    var endTime: Date = Date.distantPast
    var location: String = ""
    var notes: String = ""

    init(from item: CommitmentItem) {
        update(from: item)
    }

    func update(from item: CommitmentItem) {
        self.id = item.id
        self.title = item.title
        self.kindRawValue = item.kind.rawValue
        self.dayOfWeek = item.dayOfWeek
        self.recurrenceRawValue = item.recurrence.rawValue
        self.specificDate = item.specificDate
        self.startTime = item.startTime
        self.endTime = item.endTime
        self.location = item.location
        self.notes = item.notes
    }

    func asCommitmentItem() -> CommitmentItem {
        CommitmentItem(
            id: id,
            title: title,
            kind: CommitmentItem.Kind(rawValue: kindRawValue) ?? .other,
            dayOfWeek: dayOfWeek,
            recurrence: CommitmentItem.Recurrence(rawValue: recurrenceRawValue) ?? .weekly,
            specificDate: specificDate,
            startTime: startTime,
            endTime: endTime,
            location: location,
            notes: notes
        )
    }
}

@Model
final class PersistedTodoItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var task: String = ""
    var isCompleted: Bool = false
    var priorityRawValue: String = TodoItem.Priority.none.rawValue
    var dueDate: Date?
    var categoryRawValue: String = TodoItem.Category.prep.rawValue
    var bucketRawValue: String = TodoItem.Bucket.today.rawValue
    var workspaceRawValue: String = TodoItem.Workspace.school.rawValue
    var linkedContext: String = ""
    var studentOrGroup: String = ""
    var classLink: String = ""
    var studentGroupLink: String = ""
    var studentLink: String = ""
    var followUpNote: String = ""
    var reminderRawValue: String = TodoItem.Reminder.none.rawValue

    init(from item: TodoItem) {
        update(from: item)
    }

    func update(from item: TodoItem) {
        self.id = item.id
        self.task = item.task
        self.isCompleted = item.isCompleted
        self.priorityRawValue = item.priority.rawValue
        self.dueDate = item.dueDate
        self.categoryRawValue = item.category.rawValue
        self.bucketRawValue = item.bucket.rawValue
        self.workspaceRawValue = item.workspace.rawValue
        self.linkedContext = item.linkedContext
        self.studentOrGroup = item.studentOrGroup
        self.classLink = item.classLink
        self.studentGroupLink = item.studentGroupLink
        self.studentLink = item.studentLink
        self.followUpNote = item.followUpNote
        self.reminderRawValue = item.reminder.rawValue
    }

    func asTodoItem() -> TodoItem {
        TodoItem(
            id: id,
            task: task,
            isCompleted: isCompleted,
            priority: TodoItem.Priority(rawValue: priorityRawValue) ?? .none,
            dueDate: dueDate,
            category: TodoItem.Category(rawValue: categoryRawValue) ?? .prep,
            bucket: TodoItem.Bucket(rawValue: bucketRawValue) ?? .today,
            workspace: TodoItem.Workspace(rawValue: workspaceRawValue) ?? .school,
            linkedContext: linkedContext,
            studentOrGroup: studentOrGroup,
            classLink: classLink,
            studentGroupLink: studentGroupLink,
            studentLink: studentLink,
            followUpNote: followUpNote,
            reminder: TodoItem.Reminder(rawValue: reminderRawValue) ?? .none
        )
    }
}

@Model
final class PersistedFollowUpNoteItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var kindRawValue: String = FollowUpNoteItem.Kind.classNote.rawValue
    var context: String = ""
    var studentOrGroup: String = ""
    var note: String = ""
    var createdAt: Date = Date.distantPast

    init(from item: FollowUpNoteItem) {
        update(from: item)
    }

    func update(from item: FollowUpNoteItem) {
        self.id = item.id
        self.kindRawValue = item.kind.rawValue
        self.context = item.context
        self.studentOrGroup = item.studentOrGroup
        self.note = item.note
        self.createdAt = item.createdAt
    }

    func asFollowUpNoteItem() -> FollowUpNoteItem {
        FollowUpNoteItem(
            id: id,
            kind: FollowUpNoteItem.Kind(rawValue: kindRawValue) ?? .classNote,
            context: context,
            studentOrGroup: studentOrGroup,
            note: note,
            createdAt: createdAt
        )
    }
}

@Model
final class PersistedSubPlanItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var dateKey: String = ""
    var linkedAlarmID: UUID?
    var className: String = ""
    var gradeLevel: String = ""
    var location: String = ""
    var overview: String = ""
    var lessonPlan: String = ""
    var materials: String = ""
    var subNotes: String = ""
    var returnNotes: String = ""
    var includeRoster: Bool = true
    var includeSupports: Bool = true
    var includeAttendance: Bool = true
    var includeCommitments: Bool = true
    var includeDaySchedule: Bool = true
    var includeSubProfile: Bool = true
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(from item: SubPlanItem) {
        update(from: item)
    }

    func update(from item: SubPlanItem) {
        self.id = item.id
        self.dateKey = item.dateKey
        self.linkedAlarmID = item.linkedAlarmID
        self.className = item.className
        self.gradeLevel = item.gradeLevel
        self.location = item.location
        self.overview = item.overview
        self.lessonPlan = item.lessonPlan
        self.materials = item.materials
        self.subNotes = item.subNotes
        self.returnNotes = item.returnNotes
        self.includeRoster = item.includeRoster
        self.includeSupports = item.includeSupports
        self.includeAttendance = item.includeAttendance
        self.includeCommitments = item.includeCommitments
        self.includeDaySchedule = item.includeDaySchedule
        self.includeSubProfile = item.includeSubProfile
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
    }

    func asSubPlanItem() -> SubPlanItem {
        SubPlanItem(
            id: id,
            dateKey: dateKey,
            linkedAlarmID: linkedAlarmID,
            className: className,
            gradeLevel: gradeLevel,
            location: location,
            overview: overview,
            lessonPlan: lessonPlan,
            materials: materials,
            subNotes: subNotes,
            returnNotes: returnNotes,
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeAttendance: includeAttendance,
            includeCommitments: includeCommitments,
            includeDaySchedule: includeDaySchedule,
            includeSubProfile: includeSubProfile,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class PersistedDailySubPlanItem: PersistedUUIDModel {
    var id: UUID = UUID()
    var dateKey: String = ""
    var morningNotes: String = ""
    var sharedMaterials: String = ""
    var dismissalNotes: String = ""
    var emergencyNotes: String = ""
    var returnNotes: String = ""
    var includeAttendance: Bool = true
    var includeRoster: Bool = true
    var includeSupports: Bool = true
    var includeCommitments: Bool = true
    var includeSubProfile: Bool = true
    var selectedBlockIDsRawValue: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(from item: DailySubPlanItem) {
        update(from: item)
    }

    func update(from item: DailySubPlanItem) {
        self.id = item.id
        self.dateKey = item.dateKey
        self.morningNotes = item.morningNotes
        self.sharedMaterials = item.sharedMaterials
        self.dismissalNotes = item.dismissalNotes
        self.emergencyNotes = item.emergencyNotes
        self.returnNotes = item.returnNotes
        self.includeAttendance = item.includeAttendance
        self.includeRoster = item.includeRoster
        self.includeSupports = item.includeSupports
        self.includeCommitments = item.includeCommitments
        self.includeSubProfile = item.includeSubProfile
        self.selectedBlockIDsRawValue = item.selectedBlockIDs
            .map(\.uuidString)
            .joined(separator: ",")
        self.createdAt = item.createdAt
        self.updatedAt = item.updatedAt
    }

    func asDailySubPlanItem() -> DailySubPlanItem {
        DailySubPlanItem(
            id: id,
            dateKey: dateKey,
            morningNotes: morningNotes,
            sharedMaterials: sharedMaterials,
            dismissalNotes: dismissalNotes,
            emergencyNotes: emergencyNotes,
            returnNotes: returnNotes,
            includeAttendance: includeAttendance,
            includeRoster: includeRoster,
            includeSupports: includeSupports,
            includeCommitments: includeCommitments,
            includeSubProfile: includeSubProfile,
            selectedBlockIDs: selectedBlockIDsRawValue
                .split(separator: ",")
                .compactMap { UUID(uuidString: String($0)) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class PersistedAttendanceRecord: PersistedUUIDModel {
    var id: UUID = UUID()
    var dateKey: String = ""
    var className: String = ""
    var gradeLevel: String = ""
    var studentName: String = ""
    var studentID: UUID?
    var classDefinitionID: UUID?
    var blockID: UUID?
    var blockStartTime: Date?
    var blockEndTime: Date?
    var statusRawValue: String = AttendanceRecord.Status.present.rawValue
    var absentHomework: String = ""

    init(from item: AttendanceRecord) {
        update(from: item)
    }

    func update(from item: AttendanceRecord) {
        self.id = item.id
        self.dateKey = item.dateKey
        self.className = item.className
        self.gradeLevel = item.gradeLevel
        self.studentName = item.studentName
        self.studentID = item.studentID
        self.classDefinitionID = item.classDefinitionID
        self.blockID = item.blockID
        self.blockStartTime = item.blockStartTime
        self.blockEndTime = item.blockEndTime
        self.statusRawValue = item.status.rawValue
        self.absentHomework = item.absentHomework
    }

    func asAttendanceRecord() -> AttendanceRecord {
        AttendanceRecord(
            id: id,
            dateKey: dateKey,
            className: className,
            gradeLevel: gradeLevel,
            studentName: studentName,
            studentID: studentID,
            classDefinitionID: classDefinitionID,
            blockID: blockID,
            blockStartTime: blockStartTime,
            blockEndTime: blockEndTime,
            status: AttendanceRecord.Status(rawValue: statusRawValue) ?? .present,
            absentHomework: absentHomework
        )
    }
}

@Model
final class PersistedScheduleProfile: PersistedUUIDModel {
    var id: UUID = UUID()
    var name: String = ""
    var alarmsJSONString: String = "[]"

    init(from item: ScheduleProfile) {
        update(from: item)
    }

    func update(from item: ScheduleProfile) {
        self.id = item.id
        self.name = item.name
        if
            let data = try? JSONEncoder().encode(item.alarms),
            let json = String(data: data, encoding: .utf8)
        {
            self.alarmsJSONString = json
        } else {
            self.alarmsJSONString = "[]"
        }
    }

    func asScheduleProfile() -> ScheduleProfile {
        let alarmsData = alarmsJSONString.data(using: .utf8) ?? Data("[]".utf8)
        return ScheduleProfile(
            id: id,
            name: name,
            alarms: (try? JSONDecoder().decode([AlarmItem].self, from: alarmsData)) ?? []
        )
    }
}

@Model
final class PersistedDayOverride: PersistedUUIDModel {
    var id: UUID = UUID()
    var date: Date = Date.distantPast
    var profileID: UUID = UUID()
    var kindRawValue: String = DayOverride.OverrideKind.custom.rawValue

    init(from item: DayOverride) {
        update(from: item)
    }

    func update(from item: DayOverride) {
        self.id = item.id
        self.date = item.date
        self.profileID = item.profileID
        self.kindRawValue = item.kind.rawValue
    }

    func asDayOverride() -> DayOverride {
        DayOverride(
            id: id,
            date: date,
            profileID: profileID,
            kind: DayOverride.OverrideKind(rawValue: kindRawValue) ?? .custom
        )
    }
}

@Model
final class PersistedSubPlanProfile: PersistedUUIDModel {
    var id: UUID = UUID()
    var teacherName: String = ""
    var room: String = ""
    var contactEmail: String = ""
    var contactPhone: String = ""
    var schoolFrontOfficeContact: String = ""
    var neighboringTeacher: String = ""
    var emergencyDrillProcedures: String = ""
    var emergencyDrillFileLink: String = ""
    var passwordsAccessNotes: String = ""
    var appCredentialsJSON: String = ""
    var phoneExtensions: String = ""
    var staticNotes: String = ""

    init(from item: SubPlanProfile) {
        update(from: item)
    }

    func update(from item: SubPlanProfile) {
        id = item.id
        teacherName = item.teacherName
        room = item.room
        contactEmail = item.contactEmail
        contactPhone = item.contactPhone
        schoolFrontOfficeContact = item.schoolFrontOfficeContact
        neighboringTeacher = item.neighboringTeacher
        emergencyDrillProcedures = item.emergencyDrillProcedures
        emergencyDrillFileLink = item.emergencyDrillFileLink
        passwordsAccessNotes = item.passwordsAccessNotes
        appCredentialsJSON = Self.encodeCredentials(item.appCredentials)
        phoneExtensions = item.phoneExtensions
        staticNotes = item.staticNotes
    }

    func asSubPlanProfile() -> SubPlanProfile {
        SubPlanProfile(
            id: id,
            teacherName: teacherName,
            room: room,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            schoolFrontOfficeContact: schoolFrontOfficeContact,
            neighboringTeacher: neighboringTeacher,
            emergencyDrillProcedures: emergencyDrillProcedures,
            emergencyDrillFileLink: emergencyDrillFileLink,
            passwordsAccessNotes: passwordsAccessNotes,
            appCredentials: Self.decodeCredentials(appCredentialsJSON),
            phoneExtensions: phoneExtensions,
            staticNotes: staticNotes
        )
    }

    private static func encodeCredentials(_ credentials: [SubPlanProfile.AppCredential]) -> String {
        guard
            let data = try? JSONEncoder().encode(credentials),
            let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    private static func decodeCredentials(_ rawValue: String) -> [SubPlanProfile.AppCredential] {
        guard
            !rawValue.isEmpty,
            let data = rawValue.data(using: .utf8),
            let credentials = try? JSONDecoder().decode([SubPlanProfile.AppCredential].self, from: data)
        else {
            return []
        }
        return credentials
    }
}

struct FirstPersistenceSliceSnapshot {
    var alarms: [AlarmItem]
    var studentProfiles: [StudentSupportProfile]
    var classDefinitions: [ClassDefinitionItem]
    var teacherContacts: [ClassStaffContact]
    var paraContacts: [ClassStaffContact]
    var commitments: [CommitmentItem]
}

struct SecondPersistenceSliceSnapshot {
    var todos: [TodoItem]
    var followUpNotes: [FollowUpNoteItem]
    var subPlans: [SubPlanItem]
    var dailySubPlans: [DailySubPlanItem]
}

struct ThirdPersistenceSliceSnapshot {
    var attendanceRecords: [AttendanceRecord]
    var profiles: [ScheduleProfile]
    var overrides: [DayOverride]
}

enum ClassTraxPersistence {
    enum ContainerMode: String {
        case cloudKit = "CloudKit"
        case localFallback = "Local Fallback"
    }

    static let firstSliceMigrationKey = "swiftdata_first_slice_migration_v1"
    static let secondSliceMigrationKey = "swiftdata_second_slice_migration_v1"
    static let thirdSliceMigrationKey = "swiftdata_third_slice_migration_v1"
    static let cloudKitContainerIdentifier = "iCloud.com.mrmike.classtrax"
    static let cloudKitSchemaInitializationKey = "swiftdata_cloudkit_schema_initialized_classtrax_v2"
    static let cloudKitLastEventSummaryKey = "cloudkit_last_event_summary_v1"
    static let cloudKitLastEventTimestampKey = "cloudkit_last_event_timestamp_v1"
    static private(set) var activeContainerMode: ContainerMode = .localFallback
    static private(set) var lastContainerStatusMessage = "Container not initialized yet."
    static private(set) var lastSchemaInitializationMessage = "Schema initializer not run yet."
    static private(set) var lastCloudKitEventSummary = UserDefaults.standard.string(forKey: cloudKitLastEventSummaryKey) ?? "No CloudKit sync events observed yet."
    static private(set) var lastCloudKitEventTimestamp = UserDefaults.standard.double(forKey: cloudKitLastEventTimestampKey)
    static private var cloudKitEventObserver: NSObjectProtocol?

    static let persistedEntityTypes: [any PersistentModel.Type] = [
        PersistedAlarmItem.self,
        PersistedStudentSupportProfile.self,
        PersistedClassDefinitionItem.self,
        PersistedCommitmentItem.self,
        PersistedTodoItem.self,
        PersistedFollowUpNoteItem.self,
        PersistedSubPlanItem.self,
        PersistedDailySubPlanItem.self,
        PersistedAttendanceRecord.self,
        PersistedScheduleProfile.self,
        PersistedDayOverride.self,
        PersistedSubPlanProfile.self
    ]

    static func describe(error: Error) -> String {
        let nsError = error as NSError
        var details = "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"

        if let failureReason = nsError.localizedFailureReason, !failureReason.isEmpty {
            details += " Failure reason: \(failureReason)"
        }

        if let recoverySuggestion = nsError.localizedRecoverySuggestion, !recoverySuggestion.isEmpty {
            details += " Recovery: \(recoverySuggestion)"
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            details += " Underlying: \(underlying.domain) (\(underlying.code)): \(underlying.localizedDescription)"
        }

        let usefulUserInfo = nsError.userInfo
            .filter { key, _ in
                let keyString = String(describing: key)
                return keyString != NSUnderlyingErrorKey
            }
            .map { key, value in
                "\(key)=\(value)"
            }
            .sorted()

        if !usefulUserInfo.isEmpty {
            details += " UserInfo: \(usefulUserInfo.joined(separator: "; "))"
        }

        return details
    }

    static func describeCloudKitError(_ error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == CKErrorDomain,
           let ckError = error as? CKError,
           ckError.code == .partialFailure,
           let partialErrors = ckError.partialErrorsByItemID,
           let firstPartialError = partialErrors.first {
            let itemDescription: String
            if let recordID = firstPartialError.key as? CKRecord.ID {
                itemDescription = recordID.recordName
            } else {
                itemDescription = String(describing: firstPartialError.key)
            }

            return "Partial failure on \(itemDescription): \(describe(error: firstPartialError.value))"
        }

        return describe(error: error)
    }

    static func registerCloudKitEventObserver() {
        guard cloudKitEventObserver == nil else { return }

        cloudKitEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }

            let status = event.succeeded ? "Succeeded" : "Failed"
            let eventType: String
            switch event.type {
            case .setup:
                eventType = "Setup"
            case .import:
                eventType = "Import"
            case .export:
                eventType = "Export"
            @unknown default:
                eventType = "Unknown"
            }

            let message: String
            if let error = event.error {
                message = "\(eventType) \(status): \(describeCloudKitError(error))"
            } else {
                message = "\(eventType) \(status)"
            }

            lastCloudKitEventSummary = message
            let timestamp = (event.endDate ?? event.startDate).timeIntervalSince1970
            lastCloudKitEventTimestamp = timestamp
            UserDefaults.standard.set(message, forKey: cloudKitLastEventSummaryKey)
            UserDefaults.standard.set(timestamp, forKey: cloudKitLastEventTimestampKey)
        }
    }

    static let sharedModelContainer: ModelContainer = {
        do {
            let cloudConfiguration = ModelConfiguration(
                "ClassTrax",
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            do {
                let container = try ModelContainer(
                    for:
                        PersistedAlarmItem.self,
                        PersistedStudentSupportProfile.self,
                        PersistedClassDefinitionItem.self,
                        PersistedSupportStaffMember.self,
                        PersistedCommitmentItem.self,
                        PersistedTodoItem.self,
                        PersistedFollowUpNoteItem.self,
                        PersistedSubPlanItem.self,
                        PersistedDailySubPlanItem.self,
                        PersistedAttendanceRecord.self,
                        PersistedScheduleProfile.self,
                        PersistedDayOverride.self,
                        PersistedSubPlanProfile.self,
                    configurations: cloudConfiguration
                )
                activeContainerMode = .cloudKit
                lastContainerStatusMessage = "Using CloudKit container \(cloudKitContainerIdentifier)."
                return container
            } catch {
                let message = "CloudKit-backed SwiftData container unavailable. Falling back to local store: \(describe(error: error))"
                NSLog("%@", message)

                let localConfiguration = ModelConfiguration(
                    "ClassTrax",
                    cloudKitDatabase: .none
                )
                let container = try ModelContainer(
                    for:
                        PersistedAlarmItem.self,
                        PersistedStudentSupportProfile.self,
                        PersistedClassDefinitionItem.self,
                        PersistedSupportStaffMember.self,
                        PersistedCommitmentItem.self,
                        PersistedTodoItem.self,
                        PersistedFollowUpNoteItem.self,
                        PersistedSubPlanItem.self,
                        PersistedDailySubPlanItem.self,
                        PersistedAttendanceRecord.self,
                        PersistedScheduleProfile.self,
                        PersistedDayOverride.self,
                        PersistedSubPlanProfile.self,
                    configurations: localConfiguration
                )
                activeContainerMode = .localFallback
                lastContainerStatusMessage = message
                return container
            }
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }()

    static func initializeCloudKitDevelopmentSchemaIfNeeded() {
#if DEBUG
        if UserDefaults.standard.bool(forKey: cloudKitSchemaInitializationKey) {
            lastSchemaInitializationMessage = "CloudKit development schema was already initialized."
            return
        }

        let configuration = ModelConfiguration(
            "ClassTrax",
            cloudKitDatabase: .private(cloudKitContainerIdentifier)
        )

        do {
            try autoreleasepool {
                let description = NSPersistentStoreDescription(url: configuration.url)
                description.shouldAddStoreAsynchronously = false
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: cloudKitContainerIdentifier
                )

                guard let model = NSManagedObjectModel.makeManagedObjectModel(for: persistedEntityTypes) else {
                    throw NSError(
                        domain: "ClassTraxPersistence",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to create managed object model for CloudKit schema initialization."]
                    )
                }

                let container = NSPersistentCloudKitContainer(
                    name: "ClassTrax",
                    managedObjectModel: model
                )
                container.persistentStoreDescriptions = [description]

                var loadError: Error?
                container.loadPersistentStores { _, error in
                    loadError = error
                }

                if let loadError {
                    throw loadError
                }

                try container.initializeCloudKitSchema()

                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
            }

            UserDefaults.standard.set(true, forKey: cloudKitSchemaInitializationKey)
            lastSchemaInitializationMessage = "CloudKit development schema initialized successfully."
        } catch {
            let message = "CloudKit schema initialization failed: \(describe(error: error))"
            NSLog("%@", message)
            lastSchemaInitializationMessage = message
        }
#endif
    }

    @MainActor
    static func importFirstSliceIfNeeded(
        legacyAlarms: [AlarmItem],
        legacyStudentProfiles: [StudentSupportProfile],
        legacyClassDefinitions: [ClassDefinitionItem],
        legacyCommitments: [CommitmentItem],
        into context: ModelContext
    ) {
        let hasImported = UserDefaults.standard.bool(forKey: firstSliceMigrationKey)
        if hasImported { return }

        let hasLegacyData = !legacyAlarms.isEmpty || !legacyStudentProfiles.isEmpty || !legacyClassDefinitions.isEmpty || !legacyCommitments.isEmpty
        if !hasLegacyData {
            UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
            return
        }

        replaceAll(PersistedClassDefinitionItem.self, in: context, with: legacyClassDefinitions.map(PersistedClassDefinitionItem.init))
        replaceAll(PersistedStudentSupportProfile.self, in: context, with: legacyStudentProfiles.map(PersistedStudentSupportProfile.init))
        replaceAll(PersistedAlarmItem.self, in: context, with: legacyAlarms.map(PersistedAlarmItem.init))
        replaceAll(PersistedCommitmentItem.self, in: context, with: legacyCommitments.map(PersistedCommitmentItem.init))
        save(context)

        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func loadFirstSlice(from context: ModelContext) -> FirstPersistenceSliceSnapshot {
        let classes = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedClassDefinitionItem>(
            sortBy: [SortDescriptor(\.name), SortDescriptor(\.gradeLevel)]
        ))) ?? [], in: context)
        let students = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedStudentSupportProfile>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? [], in: context)
        let supportStaff = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedSupportStaffMember>(
            sortBy: [SortDescriptor(\.roleRawValue), SortDescriptor(\.name)]
        ))) ?? [], in: context)
        let alarms = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedAlarmItem>(
            sortBy: [SortDescriptor(\.dayOfWeekValue), SortDescriptor(\.start)]
        ))) ?? [], in: context)
        let commitments = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedCommitmentItem>(
            sortBy: [SortDescriptor(\.dayOfWeek), SortDescriptor(\.startTime)]
        ))) ?? [], in: context)

        return FirstPersistenceSliceSnapshot(
            alarms: alarms.map { $0.asAlarmItem() },
            studentProfiles: students.map { $0.asStudentSupportProfile() },
            classDefinitions: classes.map { $0.asClassDefinitionItem() },
            teacherContacts: supportStaff
                .filter { $0.roleRawValue == SupportStaffRole.teacher.rawValue }
                .map { $0.asStaffContact() },
            paraContacts: supportStaff
                .filter { $0.roleRawValue == SupportStaffRole.para.rawValue }
                .map { $0.asStaffContact() },
            commitments: commitments.map { $0.asCommitmentItem() }
        )
    }

    @MainActor
    static func saveFirstSlice(
        alarms: [AlarmItem],
        studentProfiles: [StudentSupportProfile],
        classDefinitions: [ClassDefinitionItem],
        teacherContacts: [ClassStaffContact],
        paraContacts: [ClassStaffContact],
        commitments: [CommitmentItem],
        into context: ModelContext
    ) {
        syncModels(PersistedClassDefinitionItem.self, values: classDefinitions, in: context, create: PersistedClassDefinitionItem.init, update: { $0.update(from: $1) })
        syncModels(PersistedStudentSupportProfile.self, values: studentProfiles, in: context, create: PersistedStudentSupportProfile.init, update: { $0.update(from: $1) })
        let staffValues = teacherContacts.map { (role: SupportStaffRole.teacher, contact: $0) } + paraContacts.map { (role: SupportStaffRole.para, contact: $0) }
        syncModels(
            PersistedSupportStaffMember.self,
            values: staffValues,
            in: context,
            create: { PersistedSupportStaffMember(role: $0.role, contact: $0.contact) },
            update: { $0.update(role: $1.role, contact: $1.contact) },
            identifier: { $0.contact.id }
        )
        syncModels(PersistedAlarmItem.self, values: alarms, in: context, create: PersistedAlarmItem.init, update: { $0.update(from: $1) })
        syncModels(PersistedCommitmentItem.self, values: commitments, in: context, create: PersistedCommitmentItem.init, update: { $0.update(from: $1) })
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func saveFirstSliceAlarms(_ alarms: [AlarmItem], into context: ModelContext) {
        syncModels(
            PersistedAlarmItem.self,
            values: alarms,
            in: context,
            create: PersistedAlarmItem.init,
            update: { $0.update(from: $1) }
        )
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func saveFirstSliceStudentProfiles(_ studentProfiles: [StudentSupportProfile], into context: ModelContext) {
        syncModels(
            PersistedStudentSupportProfile.self,
            values: studentProfiles,
            in: context,
            create: PersistedStudentSupportProfile.init,
            update: { $0.update(from: $1) }
        )
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func saveFirstSliceClassDefinitions(_ classDefinitions: [ClassDefinitionItem], into context: ModelContext) {
        syncModels(
            PersistedClassDefinitionItem.self,
            values: classDefinitions,
            in: context,
            create: PersistedClassDefinitionItem.init,
            update: { $0.update(from: $1) }
        )
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func saveFirstSliceSupportStaff(
        teacherContacts: [ClassStaffContact],
        paraContacts: [ClassStaffContact],
        into context: ModelContext
    ) {
        let staffValues = teacherContacts.map { (role: SupportStaffRole.teacher, contact: $0) }
            + paraContacts.map { (role: SupportStaffRole.para, contact: $0) }
        syncModels(
            PersistedSupportStaffMember.self,
            values: staffValues,
            in: context,
            create: { PersistedSupportStaffMember(role: $0.role, contact: $0.contact) },
            update: { $0.update(role: $1.role, contact: $1.contact) },
            identifier: { $0.contact.id }
        )
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func saveFirstSliceCommitments(_ commitments: [CommitmentItem], into context: ModelContext) {
        syncModels(
            PersistedCommitmentItem.self,
            values: commitments,
            in: context,
            create: PersistedCommitmentItem.init,
            update: { $0.update(from: $1) }
        )
        save(context)
        UserDefaults.standard.set(true, forKey: firstSliceMigrationKey)
    }

    @MainActor
    static func importSecondSliceIfNeeded(
        legacyTodos: [TodoItem],
        legacyFollowUpNotes: [FollowUpNoteItem],
        legacySubPlans: [SubPlanItem],
        legacyDailySubPlans: [DailySubPlanItem],
        into context: ModelContext
    ) {
        let hasImported = UserDefaults.standard.bool(forKey: secondSliceMigrationKey)
        if hasImported { return }

        let hasLegacyData = !legacyTodos.isEmpty || !legacyFollowUpNotes.isEmpty || !legacySubPlans.isEmpty || !legacyDailySubPlans.isEmpty
        if !hasLegacyData {
            UserDefaults.standard.set(true, forKey: secondSliceMigrationKey)
            return
        }

        replaceAll(PersistedTodoItem.self, in: context, with: legacyTodos.map(PersistedTodoItem.init))
        replaceAll(PersistedFollowUpNoteItem.self, in: context, with: legacyFollowUpNotes.map(PersistedFollowUpNoteItem.init))
        replaceAll(PersistedSubPlanItem.self, in: context, with: legacySubPlans.map(PersistedSubPlanItem.init))
        replaceAll(PersistedDailySubPlanItem.self, in: context, with: legacyDailySubPlans.map(PersistedDailySubPlanItem.init))
        save(context)

        UserDefaults.standard.set(true, forKey: secondSliceMigrationKey)
    }

    @MainActor
    static func loadSecondSlice(from context: ModelContext) -> SecondPersistenceSliceSnapshot {
        let todos = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedTodoItem>(
            sortBy: [SortDescriptor(\.task)]
        ))) ?? [], in: context)
        let followUpNotes = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedFollowUpNoteItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? [], in: context)
        let subPlans = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedSubPlanItem>(
            sortBy: [SortDescriptor(\.dateKey), SortDescriptor(\.updatedAt, order: .reverse)]
        ))) ?? [], in: context)
        let dailySubPlans = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedDailySubPlanItem>(
            sortBy: [SortDescriptor(\.dateKey), SortDescriptor(\.updatedAt, order: .reverse)]
        ))) ?? [], in: context)

        return SecondPersistenceSliceSnapshot(
            todos: todos.map { $0.asTodoItem() },
            followUpNotes: followUpNotes.map { $0.asFollowUpNoteItem() },
            subPlans: subPlans.map { $0.asSubPlanItem() },
            dailySubPlans: dailySubPlans.map { $0.asDailySubPlanItem() }
        )
    }

    @MainActor
    static func saveSecondSlice(
        todos: [TodoItem],
        followUpNotes: [FollowUpNoteItem],
        subPlans: [SubPlanItem],
        dailySubPlans: [DailySubPlanItem],
        into context: ModelContext
    ) {
        syncModels(PersistedTodoItem.self, values: todos, in: context, create: PersistedTodoItem.init, update: { $0.update(from: $1) })
        syncModels(PersistedFollowUpNoteItem.self, values: followUpNotes, in: context, create: PersistedFollowUpNoteItem.init, update: { $0.update(from: $1) })
        syncModels(PersistedSubPlanItem.self, values: subPlans, in: context, create: PersistedSubPlanItem.init, update: { $0.update(from: $1) })
        syncModels(PersistedDailySubPlanItem.self, values: dailySubPlans, in: context, create: PersistedDailySubPlanItem.init, update: { $0.update(from: $1) })
        save(context)
        UserDefaults.standard.set(true, forKey: secondSliceMigrationKey)
    }

    @MainActor
    static func loadFollowUpNotes(from context: ModelContext) -> [FollowUpNoteItem] {
        let notes = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedFollowUpNoteItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))) ?? [], in: context)
        return notes.map { $0.asFollowUpNoteItem() }
    }

    @MainActor
    static func saveFollowUpNotes(_ notes: [FollowUpNoteItem], into context: ModelContext) {
        syncModels(PersistedFollowUpNoteItem.self, values: notes, in: context, create: PersistedFollowUpNoteItem.init, update: { $0.update(from: $1) })
        save(context)
        UserDefaults.standard.set(true, forKey: secondSliceMigrationKey)
    }

    @MainActor
    static func importThirdSliceIfNeeded(
        legacyAttendanceRecords: [AttendanceRecord],
        legacyProfiles: [ScheduleProfile],
        legacyOverrides: [DayOverride],
        into context: ModelContext
    ) {
        let hasImported = UserDefaults.standard.bool(forKey: thirdSliceMigrationKey)
        if hasImported { return }

        let hasLegacyData = !legacyAttendanceRecords.isEmpty || !legacyProfiles.isEmpty || !legacyOverrides.isEmpty
        if !hasLegacyData {
            UserDefaults.standard.set(true, forKey: thirdSliceMigrationKey)
            return
        }

        replaceAll(PersistedAttendanceRecord.self, in: context, with: legacyAttendanceRecords.map(PersistedAttendanceRecord.init))
        replaceAll(PersistedScheduleProfile.self, in: context, with: legacyProfiles.map(PersistedScheduleProfile.init))
        replaceAll(PersistedDayOverride.self, in: context, with: legacyOverrides.map(PersistedDayOverride.init))
        save(context)

        UserDefaults.standard.set(true, forKey: thirdSliceMigrationKey)
    }

    @MainActor
    static func loadThirdSlice(from context: ModelContext) -> ThirdPersistenceSliceSnapshot {
        let attendanceRecords = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedAttendanceRecord>(
            sortBy: [SortDescriptor(\.dateKey, order: .reverse), SortDescriptor(\.className), SortDescriptor(\.studentName)]
        ))) ?? [], in: context)
        let profiles = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedScheduleProfile>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? [], in: context)
        let overrides = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedDayOverride>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? [], in: context)

        return ThirdPersistenceSliceSnapshot(
            attendanceRecords: attendanceRecords.map { $0.asAttendanceRecord() },
            profiles: profiles.map { $0.asScheduleProfile() },
            overrides: overrides.map { $0.asDayOverride() }
        )
    }

    @MainActor
    static func saveThirdSlice(
        attendanceRecords: [AttendanceRecord],
        profiles: [ScheduleProfile],
        overrides: [DayOverride],
        into context: ModelContext
    ) {
        syncModels(PersistedAttendanceRecord.self, values: attendanceRecords, in: context, create: PersistedAttendanceRecord.init, update: { $0.update(from: $1) })
        syncModels(PersistedScheduleProfile.self, values: profiles, in: context, create: PersistedScheduleProfile.init, update: { $0.update(from: $1) })
        syncModels(PersistedDayOverride.self, values: overrides, in: context, create: PersistedDayOverride.init, update: { $0.update(from: $1) })
        save(context)
        UserDefaults.standard.set(true, forKey: thirdSliceMigrationKey)
    }

    @MainActor
    static func loadSubPlanProfile(from context: ModelContext) -> SubPlanProfile {
        let profiles = deduplicatedModels((try? context.fetch(FetchDescriptor<PersistedSubPlanProfile>())) ?? [], in: context)
        return profiles.first?.asSubPlanProfile() ?? SubPlanProfile()
    }

    @MainActor
    static func saveSubPlanProfile(_ profile: SubPlanProfile, into context: ModelContext) {
        syncModels(
            PersistedSubPlanProfile.self,
            values: [profile],
            in: context,
            create: PersistedSubPlanProfile.init,
            update: { $0.update(from: $1) }
        )
        save(context)
    }

    @MainActor
    private static func replaceAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext, with models: [T]) {
        let descriptor = FetchDescriptor<T>()
        let existing = (try? context.fetch(descriptor)) ?? []
        for item in existing {
            context.delete(item)
        }
        for model in models {
            context.insert(model)
        }
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            let message = "Failed to save SwiftData migration slice: \(describe(error: error))"
            NSLog("%@", message)
            lastContainerStatusMessage = message
        }
    }

    @MainActor
    private static func deduplicatedModels<T: PersistedUUIDModel>(_ models: [T], in context: ModelContext) -> [T] {
        var seen = Set<UUID>()
        var unique: [T] = []

        for model in models {
            if seen.insert(model.id).inserted {
                unique.append(model)
            } else {
                context.delete(model)
            }
        }

        if unique.count != models.count {
            save(context)
        }

        return unique
    }

    @MainActor
    private static func syncModels<T: PersistedUUIDModel, Value>(
        _ type: T.Type,
        values: [Value],
        in context: ModelContext,
        create: (Value) -> T,
        update: (T, Value) -> Void,
        identifier: (Value) -> UUID = { value in
            guard let identifiable = value as? any Identifiable else {
                preconditionFailure("syncModels default identifier requires Identifiable values.")
            }
            guard let id = identifiable.id as? UUID else {
                preconditionFailure("syncModels default identifier requires UUID-backed Identifiable values.")
            }
            return id
        }
    ) {
        let descriptor = FetchDescriptor<T>()
        let existing = deduplicatedModels((try? context.fetch(descriptor)) ?? [], in: context)
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIDs = Set(values.map(identifier))

        for model in existing where !incomingIDs.contains(model.id) {
            context.delete(model)
        }

        for value in values {
            let id = identifier(value)
            if let persisted = existingByID[id] {
                update(persisted, value)
            } else {
                context.insert(create(value))
            }
        }
    }
}
