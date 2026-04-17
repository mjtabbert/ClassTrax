import SwiftUI
import SwiftData
import UIKit

struct NotesView: View {
    enum NotesMode: String, CaseIterable {
        case all
        case general
        case personal
        case classNotes
        case studentNotes

        var title: String {
            switch self {
            case .all:
                return "All"
            case .general:
                return "School Log"
            case .personal:
                return "Personal"
            case .classNotes:
                return "Class Log"
            case .studentNotes:
                return "Student Notes"
            }
        }

        var preferredKind: FollowUpNoteItem.Kind {
            switch self {
            case .all:
                return .generalNote
            case .general:
                return .generalNote
            case .personal:
                return .personalNote
            case .classNotes:
                return .classNote
            case .studentNotes:
                return .studentNote
            }
        }

        var exportTitle: String {
            switch self {
            case .all:
                return "Class Trax Notes Overview Export"
            case .general:
                return "Class Trax School Log Export"
            case .personal:
                return "Class Trax Personal Notes Export"
            case .classNotes:
                return "Class Trax Class Notes Export"
            case .studentNotes:
                return "Class Trax Student Notes Export"
            }
        }
    }

    @Binding var studentProfiles: [StudentSupportProfile]
    @Binding var classDefinitions: [ClassDefinitionItem]
    @Binding var teacherContacts: [ClassStaffContact]
    @Binding var paraContacts: [ClassStaffContact]
    let suggestedContexts: [String]
    let suggestedStudents: [String]
    let onRefresh: @MainActor () -> Void
    let openTodayTab: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("notes_v1") private var notesText: String = ""
    @AppStorage("personal_notes_v1") private var personalNotesText: String = ""
    @AppStorage("follow_up_notes_v1_data") private var savedFollowUpNotes: Data = Data()
    @AppStorage("notes_v2_migrated") private var didMigrateLegacyTextNotes = false
    @AppStorage("today_quick_note_draft_v1") private var todayQuickNoteDraft = ""
    @AppStorage("today_quick_note_draft_token_v1") private var todayQuickNoteDraftToken: Double = 0

    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showClearConfirm = false
    @State private var notesMode: NotesMode = .general
    @State private var selectedContextFilter = ""
    @State private var selectedStudentFilter = ""
    @State private var showingAddFollowUp = false
    @State private var addPreferredKind: FollowUpNoteItem.Kind?
    @State private var editingFollowUp: FollowUpNoteItem?
    @State private var showingStudentDirectory = false
    @State private var showingExportComposer = false
    @State private var expandedClassSections = Set<String>()
    @State private var expandedStudentSections = Set<String>()
    @State private var pendingInitialNoteText = ""
    @State private var handledQuickNoteDraftToken: Double = 0

    init(
        studentProfiles: Binding<[StudentSupportProfile]>,
        classDefinitions: Binding<[ClassDefinitionItem]>,
        teacherContacts: Binding<[ClassStaffContact]>,
        paraContacts: Binding<[ClassStaffContact]>,
        suggestedContexts: [String] = [],
        suggestedStudents: [String] = [],
        onRefresh: @escaping @MainActor () -> Void,
        openTodayTab: @escaping () -> Void
    ) {
        _studentProfiles = studentProfiles
        _classDefinitions = classDefinitions
        _teacherContacts = teacherContacts
        _paraContacts = paraContacts
        self.suggestedContexts = suggestedContexts
        self.suggestedStudents = suggestedStudents
        self.onRefresh = onRefresh
        self.openTodayTab = openTodayTab
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                notesOverviewCard
                    .padding(.horizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                .background(notesHeaderBackground)

                currentModeView
            }
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(notesBackground)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        openTodayTab()
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel("Today")

                    if notesMode != .all && !currentModeNotes.isEmpty {
                        Button("Clear") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        if !currentModeNotes.isEmpty {
                            Button("Export", systemImage: "square.and.arrow.up") {
                                showingExportComposer = true
                            }
                        }

                        Button("Students", systemImage: "person.3") {
                            showingStudentDirectory = true
                        }

                        Button("Refresh", systemImage: "arrow.clockwise") {
                            onRefresh()
                        }

                        Button("Sub Plans", systemImage: "doc.text") {
                            openTodayTab()
                        }
                    } label: {
                        toolbarIconButton(systemImage: "ellipsis", title: "Actions")
                    }

                    Button {
                        presentAddNote()
                    } label: {
                        toolbarCapsuleLabel(
                            title: "Add",
                            systemImage: "plus"
                        )
                    }
                }
            }
            .confirmationDialog(
                "Clear all notes?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Notes", role: .destructive) {
                    clearCurrentNotes()
                }

                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingShareSheet) {
                NotesShareSheet(activityItems: shareItems)
            }
            .sheet(isPresented: $showingAddFollowUp) {
                AddFollowUpNoteView(
                    notes: followUpNotesBinding,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    preferredKind: addPreferredKind,
                    initialNoteText: pendingInitialNoteText
                )
            }
            .sheet(item: $editingFollowUp) { note in
                AddFollowUpNoteView(
                    notes: followUpNotesBinding,
                    suggestedContexts: suggestedContexts,
                    suggestedStudents: suggestedStudents,
                    preferredKind: nil,
                    existing: note
                )
            }
            .sheet(isPresented: $showingStudentDirectory) {
                NavigationStack {
                    StudentDirectoryView(
                        profiles: $studentProfiles,
                        classDefinitions: $classDefinitions,
                        teacherContacts: $teacherContacts,
                        paraContacts: $paraContacts
                    )
                }
            }
            .sheet(isPresented: $showingExportComposer) {
                NotesExportComposerView(
                    notes: currentModeNotes,
                    title: notesMode.exportTitle
                ) { items in
                    shareItems = items
                    showingShareSheet = true
                }
            }
            .onAppear {
                migrateLegacyTextNotesIfNeeded()
                mergeLegacyTextNotesIfNeeded()
                consumeTodayQuickNoteDraftIfNeeded()
            }
            .onChange(of: todayQuickNoteDraftToken) { _, _ in
                consumeTodayQuickNoteDraftIfNeeded()
            }
            .onChange(of: notesText) { _, _ in
                mergeLegacyTextNotesIfNeeded()
            }
            .onChange(of: personalNotesText) { _, _ in
                mergeLegacyTextNotesIfNeeded()
            }
        }
    }

    private var notesHeaderSummary: String {
        switch notesMode {
        case .all:
            return "Review school logs, personal notes, class notes, and student notes together."
        case .general:
            return "Capture school-day reminders, meetings, and running school log entries."
        case .personal:
            return "Keep personal notes available without mixing them into school notes."
        case .classNotes:
            return "Keep class notes grouped so the right class or group stays attached."
        case .studentNotes:
            return "Track student-specific notes and next steps in one place."
        }
    }

    private var notesModeBadge: some View {
        Text(notesMode.title.uppercased())
            .font(.caption2.weight(.black))
            .foregroundStyle(ClassTraxSemanticColor.secondaryAction)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(ClassTraxSemanticColor.secondaryAction.opacity(0.12)))
    }

    private var notesOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.title3.weight(.bold))

                    Text(notesHeaderSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                notesModeBadge
            }

            HStack(spacing: 8) {
                notesMetric(title: "Visible", value: "\(currentModeNotes.count)", accent: .teal)
                notesMetric(title: "Classes", value: "\(classNoteContexts.count)", accent: .blue)
                notesMetric(title: "Students", value: "\(studentNoteStudents.count)", accent: .orange)
            }

            compactNotesModeMenu
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.secondaryAction)
    }

    private var notesHeaderBackground: some View {
        LinearGradient(
            colors: [
                Color.teal.opacity(0.08),
                Color(.secondarySystemGroupedBackground).opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var notesBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.teal.opacity(0.04),
                Color.blue.opacity(0.03),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var compactNotesModeMenu: some View {
        Menu {
            Picker("View", selection: $notesMode) {
                ForEach(NotesMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.caption.weight(.semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("View")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notesMode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .classTraxCardChrome(accent: ClassTraxSemanticColor.secondaryAction, cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private func toolbarCapsuleLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(ClassTraxSemanticColor.secondaryAction)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(ClassTraxSemanticColor.secondaryAction.opacity(0.10)))
    }

    @ViewBuilder
    private func toolbarIconButton(systemImage: String, title: String) -> some View {
        if prefersExpandedToolbar {
            toolbarCapsuleLabel(title: title, systemImage: systemImage)
        } else {
            ZStack {
                Circle()
                    .fill(ClassTraxSemanticColor.secondaryAction.opacity(0.10))
                    .frame(width: 30, height: 30)

                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClassTraxSemanticColor.secondaryAction)
            }
        }
    }

    private var prefersExpandedToolbar: Bool {
        horizontalSizeClass != .compact
    }

    @ViewBuilder
    private var currentModeView: some View {
        switch notesMode {
        case .all:
            allNotesOverviewView
        case .general:
            basicNotesView(
                notes: notes(for: .generalNote),
                emptyTitle: "No School Log Yet",
                emptySystemImage: "building.2.crop.circle",
                emptyDescription: "Tap + to create a school log entry."
            )
        case .personal:
            basicNotesView(
                notes: notes(for: .personalNote),
                emptyTitle: "No Personal Notes Yet",
                emptySystemImage: "person.crop.circle.badge.plus",
                emptyDescription: "Tap + to create a personal note."
            )
        case .classNotes:
            classFollowUpView
        case .studentNotes:
            studentNotesView
        }
    }

    private func basicNotesView(
        notes: [FollowUpNoteItem],
        emptyTitle: String,
        emptySystemImage: String,
        emptyDescription: String
    ) -> some View {
        List {
            Section {
                Color.clear
                    .frame(height: 2)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }

            if notes.isEmpty {
                Section {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: emptySystemImage,
                        description: Text(emptyDescription)
                    )
                }
            } else {
                ForEach(notes) { note in
                    noteRow(note)
                }
                .onDelete { offsets in
                    deleteFollowUpNotes(at: offsets, from: notes)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func noteRow(_ note: FollowUpNoteItem) -> some View {
        Button {
            editingFollowUp = note
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(note.kind.title)
                    .font(.subheadline.weight(.semibold))

                Text(note.note)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(5)

                let metadata = noteMetadata(note)
                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var currentModeNotes: [FollowUpNoteItem] {
        switch notesMode {
        case .all:
            return followUpNotes.sorted { $0.createdAt > $1.createdAt }
        case .general:
            return notes(for: .generalNote)
        case .personal:
            return notes(for: .personalNote)
        case .classNotes:
            return followUpNotes
                .filter { $0.kind == .classNote }
                .filter { selectedContextFilter.isEmpty || $0.context == selectedContextFilter }
                .sorted { $0.createdAt > $1.createdAt }
        case .studentNotes:
            return followUpNotes
                .filter { $0.kind == .studentNote || $0.kind == .parentContact }
                .filter { selectedStudentFilter.isEmpty || $0.studentOrGroup == selectedStudentFilter }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var classNoteContexts: [String] {
        let values = followUpNotes
            .filter { $0.kind == .classNote }
            .map { $0.context.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.reduce(into: [String]()) { partialResult, value in
            if !partialResult.contains(value) {
                partialResult.append(value)
            }
        }
    }

    private var studentNoteStudents: [String] {
        let values = followUpNotes
            .filter { $0.kind == .studentNote || $0.kind == .parentContact }
            .map { $0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.reduce(into: [String]()) { partialResult, value in
            if !partialResult.contains(value) {
                partialResult.append(value)
            }
        }
    }

    @ViewBuilder
    private func notesMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private func notes(for kind: FollowUpNoteItem.Kind) -> [FollowUpNoteItem] {
        followUpNotes
            .filter { $0.kind == kind }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func noteMetadata(_ note: FollowUpNoteItem) -> String {
        var parts: [String] = []

        let context = note.context.trimmingCharacters(in: .whitespacesAndNewlines)
        let student = note.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)

        if !context.isEmpty {
            parts.append(context)
        }

        if !student.isEmpty {
            parts.append(student)
        }

        parts.append("Follow up \(note.followUpDate.formatted(date: .abbreviated, time: .omitted))")
        parts.append(note.createdAt.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " • ")
    }

    private func presentAddNote() {
        addPreferredKind = notesMode == .all ? nil : notesMode.preferredKind
        pendingInitialNoteText = ""
        showingAddFollowUp = true
    }

    private func presentAddNote(kind: FollowUpNoteItem.Kind) {
        addPreferredKind = kind
        pendingInitialNoteText = ""
        showingAddFollowUp = true
    }

    private var allNotesOverviewView: some View {
        List {
            Section("Add Notes") {
                Button {
                    presentAddNote(kind: .generalNote)
                } label: {
                    quickActionRow(
                        title: "New School Log Entry",
                        detail: "Capture a building-wide reminder or general school note",
                        systemImage: "building.2"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    presentAddNote(kind: .personalNote)
                } label: {
                    quickActionRow(
                        title: "New Personal Entry",
                        detail: "Save a private reminder that stays separate from school notes",
                        systemImage: "person"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    presentAddNote(kind: .classNote)
                } label: {
                    quickActionRow(
                        title: "New Class Note",
                        detail: "Attach a note to one class period or group",
                        systemImage: "text.book.closed"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    presentAddNote(kind: .studentNote)
                } label: {
                    quickActionRow(
                        title: "New Student Note",
                        detail: "Capture a student-specific note or parent contact",
                        systemImage: "person.text.rectangle"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    openTodayTab()
                } label: {
                    quickActionRow(
                        title: "Open Sub Plans",
                        detail: "Jump back to Today and continue building the substitute packet",
                        systemImage: "doc.text"
                    )
                }
                .buttonStyle(.plain)
            }

            Section("Overview") {
                overviewModeRow(
                    title: "All Notes",
                    value: "\(followUpNotes.count)",
                    systemImage: "tray.full",
                    targetMode: .all
                )
                overviewModeRow(
                    title: "School",
                    value: "\(notes(for: .generalNote).count)",
                    systemImage: "building.2",
                    targetMode: .general
                )
                overviewModeRow(
                    title: "Personal",
                    value: "\(notes(for: .personalNote).count)",
                    systemImage: "person",
                    targetMode: .personal
                )
                overviewModeRow(
                    title: "Class",
                    value: "\(followUpNotes.filter { $0.kind == .classNote }.count)",
                    systemImage: "text.book.closed",
                    targetMode: .classNotes
                )
                overviewModeRow(
                    title: "Student / Contact",
                    value: "\(followUpNotes.filter { $0.kind == .studentNote || $0.kind == .parentContact }.count)",
                    systemImage: "person.text.rectangle",
                    targetMode: .studentNotes
                )
            }

            if followUpNotes.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "square.and.pencil",
                        description: Text("Tap + to create a note, or submit a quick note from Today.")
                    )
                }
            } else {
                Section("Recent Notes") {
                    ForEach(followUpNotes.sorted { $0.createdAt > $1.createdAt }) { note in
                        overviewNoteRow(note)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func consumeTodayQuickNoteDraftIfNeeded() {
        let trimmedDraft = todayQuickNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard todayQuickNoteDraftToken > handledQuickNoteDraftToken else { return }
        guard !trimmedDraft.isEmpty else {
            handledQuickNoteDraftToken = todayQuickNoteDraftToken
            return
        }

        handledQuickNoteDraftToken = todayQuickNoteDraftToken
        notesMode = .general
        addPreferredKind = nil
        pendingInitialNoteText = trimmedDraft
        showingAddFollowUp = true
        todayQuickNoteDraft = ""
    }

    private func clearCurrentNotes() {
        let kindsToRemove: Set<FollowUpNoteItem.Kind>
        switch notesMode {
        case .all:
            kindsToRemove = Set(FollowUpNoteItem.Kind.allCases)
        case .general:
            kindsToRemove = [.generalNote]
        case .personal:
            kindsToRemove = [.personalNote]
        case .classNotes:
            kindsToRemove = [.classNote]
        case .studentNotes:
            kindsToRemove = [.studentNote, .parentContact]
        }

        var updated = followUpNotes
        updated.removeAll { kindsToRemove.contains($0.kind) }
        persistFollowUpNotes(updated)
    }

    private func overviewNoteRow(_ note: FollowUpNoteItem) -> some View {
        Button {
            jumpToNote(note)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.kind.title)
                        .font(.subheadline.weight(.semibold))

                    Text(note.note)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)

                    let metadata = noteMetadata(note)
                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func jumpToNote(_ note: FollowUpNoteItem) {
        switch note.kind {
        case .generalNote:
            notesMode = .general
            selectedContextFilter = ""
            selectedStudentFilter = ""
        case .personalNote:
            notesMode = .personal
            selectedContextFilter = ""
            selectedStudentFilter = ""
        case .classNote:
            notesMode = .classNotes
            selectedContextFilter = note.context
            selectedStudentFilter = ""
            if !note.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                expandedClassSections.insert(note.context)
            }
        case .studentNote, .parentContact:
            notesMode = .studentNotes
            selectedStudentFilter = note.studentOrGroup
            selectedContextFilter = ""
            if !note.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                expandedStudentSections.insert(note.studentOrGroup)
            }
        }
    }

    private var classFollowUpView: some View {
        let groups = followUpGroups

        return List {
            Section("Overview") {
                noteOverviewRow(
                    title: "Classes with Notes",
                    value: "\(groups.count)",
                    systemImage: "building.2"
                )
                noteOverviewRow(
                    title: "Visible Entries",
                    value: "\(groups.reduce(0) { $0 + $1.notes.count })",
                    systemImage: "square.and.pencil"
                )

                HStack {
                    Button("Expand All") {
                        expandedClassSections = Set(groups.map(\.context))
                    }
                    .disabled(groups.isEmpty)

                    Spacer()

                    Button("Collapse All") {
                        expandedClassSections.removeAll()
                    }
                    .disabled(groups.isEmpty)
                }

                if !selectedContextFilter.isEmpty {
                    Button("Clear Class Filter") {
                        selectedContextFilter = ""
                    }
                }

                if !classDefinitions.isEmpty {
                    noteOverviewRow(
                        title: "Saved Classes",
                        value: "\(classDefinitions.count)",
                        systemImage: "text.book.closed"
                    )
                }
            }

            if !groups.isEmpty {
                Section("Snapshot") {
                    let densestGroup = groups.max { $0.notes.count < $1.notes.count }
                    let activeFilter = selectedContextFilter.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let densestGroup {
                        LabeledContent("Most Entries") {
                            Text(densestGroup.context)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if !activeFilter.isEmpty {
                        LabeledContent("Active Filter") {
                            Text(activeFilter)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            if !suggestedContexts.isEmpty {
                Section("Filter") {
                    Picker("Class / Group", selection: $selectedContextFilter) {
                        Text("All Classes / Groups").tag("")
                        ForEach(suggestedContexts, id: \.self) { context in
                            Text(context).tag(context)
                        }
                    }
                }
            }

            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Class Notes Yet",
                        systemImage: "square.and.pencil",
                        description: Text("Tap + to create a class note.")
                    )
                }
            } else {
                ForEach(groups, id: \.context) { group in
                    Section {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedClassSections.contains(group.context) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedClassSections.insert(group.context)
                                    } else {
                                        expandedClassSections.remove(group.context)
                                    }
                                }
                            )
                        ) {
                            if !group.notes.isEmpty {
                                ForEach(group.notes) { note in
                                    noteRow(note)
                                }
                                .onDelete { offsets in
                                    deleteFollowUpNotes(at: offsets, from: group.notes)
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(group.context)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(group.notes.count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }

                                if let latest = group.notes.first?.createdAt {
                                    Text("Latest entry: \(latest.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let classSummary = classSummary(for: group.context) {
                                    Text(classSummary)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }

                                if let latestPreview = notePreviewText(group.notes.first?.note) {
                                    Text(latestPreview)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var studentNotesView: some View {
        let groups = studentNoteGroups

        return List {
            Section("Overview") {
                noteOverviewRow(
                    title: "Students with Notes",
                    value: "\(groups.count)",
                    systemImage: "person.2"
                )
                noteOverviewRow(
                    title: "Visible Entries",
                    value: "\(groups.reduce(0) { $0 + $1.notes.count })",
                    systemImage: "text.bubble"
                )

                HStack {
                    Button("Expand All") {
                        expandedStudentSections = Set(groups.map(\.student))
                    }
                    .disabled(groups.isEmpty)

                    Spacer()

                    Button("Collapse All") {
                        expandedStudentSections.removeAll()
                    }
                    .disabled(groups.isEmpty)
                }

                if !selectedStudentFilter.isEmpty {
                    Button("Clear Student Filter") {
                        selectedStudentFilter = ""
                    }
                }

                noteOverviewRow(
                    title: "Rostered Students",
                    value: "\(studentProfiles.count)",
                    systemImage: "person.3"
                )
            }

            if !groups.isEmpty {
                Section("Snapshot") {
                    let densestGroup = groups.max { $0.notes.count < $1.notes.count }
                    let activeFilter = selectedStudentFilter.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let densestGroup {
                        LabeledContent("Most Entries") {
                            Text(densestGroup.student)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if !activeFilter.isEmpty {
                        LabeledContent("Active Filter") {
                            Text(activeFilter)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }

            if !suggestedStudents.isEmpty {
                Section("Filter") {
                    Picker("Student or Group", selection: $selectedStudentFilter) {
                        Text("All Students").tag("")
                        ForEach(suggestedStudents, id: \.self) { student in
                            Text(student).tag(student)
                        }
                    }
                }
            }

            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Student Notes Yet",
                        systemImage: "person.text.rectangle",
                        description: Text("Tap + to create a student note or parent contact.")
                    )
                }
            } else {
                ForEach(groups, id: \.student) { group in
                    Section {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedStudentSections.contains(group.student) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedStudentSections.insert(group.student)
                                    } else {
                                        expandedStudentSections.remove(group.student)
                                    }
                                }
                            )
                        ) {
                            if let context = group.context, !context.isEmpty {
                                Text(context)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            ForEach(group.notes) { note in
                                noteRow(note)
                            }
                            .onDelete { offsets in
                                deleteFollowUpNotes(at: offsets, from: group.notes)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(group.student)
                                        .fontWeight(.semibold)

                                    if let matchedStudent = studentProfile(named: group.student) {
                                        gradePill(matchedStudent.gradeLevel)
                                    }

                                    Spacer()

                                    Text("\(group.notes.count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }

                                if let latest = group.notes.first?.createdAt {
                                    Text("Latest entry: \(latest.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let matchedStudent = studentProfile(named: group.student) {
                                    let summaryParts = [
                                        matchedStudent.className.trimmingCharacters(in: .whitespacesAndNewlines),
                                        matchedStudent.prompts.trimmingCharacters(in: .whitespacesAndNewlines),
                                        matchedStudent.accommodations.trimmingCharacters(in: .whitespacesAndNewlines)
                                    ]
                                    .filter { !$0.isEmpty }

                                    if let firstSummary = summaryParts.first {
                                        Text(firstSummary)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var followUpGroups: [(context: String, notes: [FollowUpNoteItem])] {
        let notesByContext = Dictionary(grouping: followUpNotes.filter {
            $0.kind == .classNote &&
            !$0.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.context }

        let contexts = Set(notesByContext.keys).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return contexts
            .filter { selectedContextFilter.isEmpty || $0 == selectedContextFilter }
            .map { context in
                let notes = (notesByContext[context] ?? []).sorted { $0.createdAt > $1.createdAt }
                return (context: context, notes: notes)
            }
    }

    private var followUpNotes: [FollowUpNoteItem] {
        guard !savedFollowUpNotes.isEmpty else { return [] }
        return (try? JSONDecoder().decode([FollowUpNoteItem].self, from: savedFollowUpNotes)) ?? []
    }

    private var studentNoteGroups: [(student: String, context: String?, notes: [FollowUpNoteItem])] {
        let grouped = Dictionary(grouping: followUpNotes.filter {
            ($0.kind == .studentNote || $0.kind == .parentContact) &&
            !$0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) { $0.studentOrGroup }

        return grouped
            .map { student, notes in
                let sortedNotes = notes.sorted { $0.createdAt > $1.createdAt }
                let context = sortedNotes.first?.context.trimmingCharacters(in: .whitespacesAndNewlines)
                return (student: student, context: context?.isEmpty == true ? nil : context, notes: sortedNotes)
            }
            .filter { selectedStudentFilter.isEmpty || $0.student == selectedStudentFilter }
            .sorted { $0.student.localizedCaseInsensitiveCompare($1.student) == .orderedAscending }
    }

    private var followUpNotesBinding: Binding<[FollowUpNoteItem]> {
        Binding(
            get: { followUpNotes },
            set: { newValue in
                persistFollowUpNotes(newValue)
            }
        )
    }

    private func deleteFollowUpNotes(at offsets: IndexSet, from groupNotes: [FollowUpNoteItem]) {
        let ids = offsets.map { groupNotes[$0].id }
        var updated = followUpNotes
        updated.removeAll { ids.contains($0.id) }
        persistFollowUpNotes(updated)
    }

    private func noteOverviewRow(title: String, value: String, systemImage: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.headline)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func overviewModeRow(title: String, value: String, systemImage: String, targetMode: NotesMode) -> some View {
        Button {
            notesMode = targetMode
            selectedContextFilter = ""
            selectedStudentFilter = ""
        } label: {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func quickActionRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private func classSummary(for context: String) -> String? {
        let normalized = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        guard let matchedClass = classDefinitions.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(normalized) == .orderedSame
        }) else {
            return nil
        }

        let parts = [
            matchedClass.gradeLevel.trimmingCharacters(in: .whitespacesAndNewlines),
            matchedClass.typeDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            matchedClass.defaultLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func notePreviewText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func persistFollowUpNotes(_ notes: [FollowUpNoteItem]) {
        savedFollowUpNotes = (try? JSONEncoder().encode(notes)) ?? Data()
        syncLegacyNoteTextStorage(from: notes, schoolNotesText: &notesText, personalNotesText: &personalNotesText)
    }

    private func migrateLegacyTextNotesIfNeeded() {
        if didMigrateLegacyTextNotes {
            syncLegacyNoteTextStorage(from: followUpNotes, schoolNotesText: &notesText, personalNotesText: &personalNotesText)
            return
        }

        var updated = followUpNotes
        let trimmedSchoolNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPersonalNotes = personalNotesText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedSchoolNotes.isEmpty && !updated.contains(where: { $0.kind == .generalNote }) {
            updated.insert(
                FollowUpNoteItem(
                    kind: .generalNote,
                    context: "",
                    studentOrGroup: "",
                    note: trimmedSchoolNotes,
                    followUpDate: Date()
                ),
                at: 0
            )
        }

        if !trimmedPersonalNotes.isEmpty && !updated.contains(where: { $0.kind == .personalNote }) {
            updated.insert(
                FollowUpNoteItem(
                    kind: .personalNote,
                    context: "",
                    studentOrGroup: "",
                    note: trimmedPersonalNotes,
                    followUpDate: Date()
                ),
                at: 0
            )
        }

        if updated != followUpNotes {
            persistFollowUpNotes(updated)
        } else {
            syncLegacyNoteTextStorage(from: updated, schoolNotesText: &notesText, personalNotesText: &personalNotesText)
        }

        didMigrateLegacyTextNotes = true
    }

    private func mergeLegacyTextNotesIfNeeded() {
        let trimmedSchoolNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPersonalNotes = personalNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = followUpNotes
        var didChange = false

        didChange = mergeLegacyTextNote(
            kind: .generalNote,
            noteText: trimmedSchoolNotes,
            into: &updated
        ) || didChange

        didChange = mergeLegacyTextNote(
            kind: .personalNote,
            noteText: trimmedPersonalNotes,
            into: &updated
        ) || didChange

        if didChange {
            persistFollowUpNotes(updated)
        }
    }

    private func mergeLegacyTextNote(
        kind: FollowUpNoteItem.Kind,
        noteText: String,
        into notes: inout [FollowUpNoteItem]
    ) -> Bool {
        if let index = notes.firstIndex(where: {
            $0.kind == kind &&
            $0.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            guard !noteText.isEmpty, notes[index].note != noteText else { return false }
            notes[index].note = noteText
            return true
        }

        guard !noteText.isEmpty else { return false }
        notes.insert(
            FollowUpNoteItem(
                kind: kind,
                context: "",
                studentOrGroup: "",
                note: noteText,
                followUpDate: Date()
            ),
            at: 0
        )
        return true
    }

    private func studentProfile(named name: String) -> StudentSupportProfile? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        return studentProfiles.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private func gradePill(_ gradeLevel: String) -> some View {
        Text(GradeLevelOption.pillLabel(for: gradeLevel))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(GradeLevelOption.foregroundColor(for: gradeLevel))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(GradeLevelOption.color(for: gradeLevel))
            )
    }
}

private struct NotesExportComposerView: View {
    enum ExportScope: String, CaseIterable {
        case current
        case currentPlusSelected
        case all

        var title: String {
            switch self {
            case .current:
                return "Current Note"
            case .currentPlusSelected:
                return "Current + Others"
            case .all:
                return "All Notes"
            }
        }
    }

    enum ExportFormat: String, CaseIterable {
        case text
        case pdf

        var title: String {
            rawValue.uppercased()
        }
    }

    let notes: [FollowUpNoteItem]
    let title: String
    let onExport: ([Any]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentNoteID: UUID
    @State private var exportScope: ExportScope = .current
    @State private var exportFormat: ExportFormat = .text
    @State private var selectedOtherIDs: Set<UUID> = []

    init(notes: [FollowUpNoteItem], title: String, onExport: @escaping ([Any]) -> Void) {
        self.notes = notes
        self.title = title
        self.onExport = onExport
        _currentNoteID = State(initialValue: notes.first?.id ?? UUID())
    }

    var body: some View {
        NavigationStack {
            Form {
                if !notes.isEmpty {
                    Section("Current Note") {
                        Picker("Current", selection: $currentNoteID) {
                            ForEach(notes) { note in
                                Text(exportSummary(for: note)).tag(note.id)
                            }
                        }
                    }

                    Section("Include") {
                        Picker("Scope", selection: $exportScope) {
                            ForEach(ExportScope.allCases, id: \.self) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }

                        if exportScope == .currentPlusSelected {
                            ForEach(otherNotes) { note in
                                Toggle(isOn: binding(for: note.id)) {
                                    Text(exportSummary(for: note))
                                }
                            }
                        }
                    }

                    Section("Format") {
                        Picker("Export As", selection: $exportFormat) {
                            ForEach(ExportFormat.allCases, id: \.self) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Export Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        export()
                    }
                    .disabled(notes.isEmpty)
                }
            }
        }
    }

    private var currentNote: FollowUpNoteItem? {
        notes.first(where: { $0.id == currentNoteID }) ?? notes.first
    }

    private var otherNotes: [FollowUpNoteItem] {
        guard let currentNote else { return [] }
        return notes.filter { $0.id != currentNote.id }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedOtherIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    selectedOtherIDs.insert(id)
                } else {
                    selectedOtherIDs.remove(id)
                }
            }
        )
    }

    private func export() {
        let selectedNotes = selectedNotesForExport()
        let exportText = classCueNotesExportText(notes: notesExportBody(for: selectedNotes), title: title)

        switch exportFormat {
        case .text:
            onExport([exportText])
        case .pdf:
            if let pdfURL = makeNotesPDF(title: title, body: exportText) {
                onExport([pdfURL])
            } else {
                onExport([exportText])
            }
        }

        dismiss()
    }

    private func selectedNotesForExport() -> [FollowUpNoteItem] {
        switch exportScope {
        case .current:
            return currentNote.map { [$0] } ?? []
        case .currentPlusSelected:
            guard let currentNote else { return [] }
            let extras = notes.filter { selectedOtherIDs.contains($0.id) }
            return [currentNote] + extras
        case .all:
            return notes
        }
    }

    private func exportSummary(for note: FollowUpNoteItem) -> String {
        let trimmed = note.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? note.kind.title
        let cleaned = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? note.kind.title : String(cleaned.prefix(40))
    }
}

private struct NotesShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

func classCueNotesExportText(notes: String, title: String = "Class Trax Notes Export") -> String {
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateStyle = .long
    dateOnlyFormatter.timeStyle = .none

    let timeOnlyFormatter = DateFormatter()
    timeOnlyFormatter.dateStyle = .none
    timeOnlyFormatter.timeStyle = .short

    let now = Date()

    return """
    \(title)
    \(dateOnlyFormatter.string(from: now))
    \(timeOnlyFormatter.string(from: now))

    \(notes)
    """
}

func notesExportBody(for notes: [FollowUpNoteItem]) -> String {
    notes.map { note in
        var lines = [note.kind.title]

        let context = note.context.trimmingCharacters(in: .whitespacesAndNewlines)
        if !context.isEmpty {
            lines.append("Class / Group: \(context)")
        }

        let student = note.studentOrGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        if !student.isEmpty {
            lines.append("Student/Group: \(student)")
        }

        lines.append("Follow-Up: \(note.followUpDate.formatted(date: .abbreviated, time: .omitted))")
        lines.append("Created: \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
        lines.append("")
        lines.append(note.note)

        return lines.joined(separator: "\n")
    }
    .joined(separator: "\n\n---\n\n")
}

func syncLegacyNoteTextStorage(
    from notes: [FollowUpNoteItem],
    schoolNotesText: inout String,
    personalNotesText: inout String
) {
    schoolNotesText = legacyNoteText(from: notes, kind: .generalNote)
    personalNotesText = legacyNoteText(from: notes, kind: .personalNote)
}

private func legacyNoteText(from notes: [FollowUpNoteItem], kind: FollowUpNoteItem.Kind) -> String {
    notes
        .filter { $0.kind == kind }
        .sorted { $0.createdAt > $1.createdAt }
        .map(\.note)
        .joined(separator: "\n\n")
}

func decodeFollowUpNotes(from data: Data) -> [FollowUpNoteItem] {
    guard !data.isEmpty else { return [] }
    return (try? JSONDecoder().decode([FollowUpNoteItem].self, from: data)) ?? []
}

func decodeFollowUpNotesFromDefaults() -> [FollowUpNoteItem] {
    decodeFollowUpNotes(from: UserDefaults.standard.data(forKey: "follow_up_notes_v1_data") ?? Data())
}

private func makeNotesPDF(title: String, body: String) -> URL? {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(title.replacingOccurrences(of: " ", with: "_"))-\(UUID().uuidString).pdf")

    let text = "\(title)\n\n\(body)"
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 14),
        .paragraphStyle: paragraph
    ]

    let attributed = NSAttributedString(string: text, attributes: attributes)
    let printableRect = CGRect(x: 36, y: 36, width: 540, height: 720)

    do {
        try renderer.writePDF(to: url) { context in
            var range = NSRange(location: 0, length: attributed.length)

            while range.location < attributed.length {
                context.beginPage()
                range = drawAttributedString(attributed, in: printableRect, range: range)
            }
        }
        return url
    } catch {
        return nil
    }
}

private func drawAttributedString(_ string: NSAttributedString, in rect: CGRect, range: NSRange) -> NSRange {
    let framesetter = CTFramesetterCreateWithAttributedString(string)
    guard let context = UIGraphicsGetCurrentContext() else {
        return range
    }
    let pageBounds = UIGraphicsGetPDFContextBounds()
    let coreTextRect = CGRect(
        x: rect.minX,
        y: pageBounds.height - rect.maxY,
        width: rect.width,
        height: rect.height
    )
    let path = CGPath(rect: coreTextRect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(range.location, range.length), path, nil)
    context.saveGState()
    context.textMatrix = .identity
    context.translateBy(x: 0, y: pageBounds.height)
    context.scaleBy(x: 1, y: -1)
    CTFrameDraw(frame, context)
    context.restoreGState()
    let visibleRange = CTFrameGetVisibleStringRange(frame)
    return NSRange(location: range.location + visibleRange.length, length: string.length - range.location - visibleRange.length)
}
