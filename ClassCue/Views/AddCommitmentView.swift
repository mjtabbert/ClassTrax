//
//  AddCommitmentView.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 12, 2026
//

import SwiftUI

struct AddCommitmentView: View {

    @Binding var commitments: [CommitmentItem]

    var defaultDay: Int
    var existing: CommitmentItem? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("add_commitment_draft_v1") private var savedDraftData: Data = Data()

    @State private var title = ""
    @State private var kind = CommitmentItem.Kind.other
    @State private var weekday = WeekdayTab.today
    @State private var recurrence = CommitmentItem.Recurrence.weekly
    @State private var specificDate = Date()
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(1800)
    @State private var location = ""
    @State private var notes = ""
    @State private var showingDeleteConfirm = false

    private struct Draft: Codable, Equatable {
        var existingID: UUID?
        var title: String
        var kind: CommitmentItem.Kind
        var weekdayRawValue: Int
        var recurrence: CommitmentItem.Recurrence
        var specificDate: Date
        var start: Date
        var end: Date
        var location: String
        var notes: String
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    commitmentOverviewCard
                }

                Section("Commitment Setup") {
                    TextField("Title", text: $title)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.primaryAction)

                    Picker("Type", selection: $kind) {
                        ForEach(CommitmentItem.Kind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }

                }

                Section("When") {
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(CommitmentItem.Recurrence.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }

                    if recurrence == .weekly {
                        Picker("Day", selection: $weekday) {
                            ForEach(WeekdayTab.allCases, id: \.self) { day in
                                Text(day.title).tag(day)
                            }
                        }
                    } else {
                        DatePicker("Date", selection: $specificDate, displayedComponents: .date)
                    }
                }

                Section("Time Window") {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                }

                Section("Details & Notes") {
                    TextField("Location", text: $location)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .classTraxInputSurface(accent: ClassTraxSemanticColor.secondaryAction)
                }

                if existing != nil {
                    Section {
                        Button("Delete Commitment", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Add Commitment" : "Edit Commitment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        clearDraft()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(existing == nil ? "Add" : "Save") {
                        saveCommitment()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete this commitment?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Commitment", role: .destructive) {
                    deleteCommitment()
                }
            }
            .onAppear {
                loadExisting()
            }
            .onAppear {
                restoreDraftIfNeeded()
            }
            .onChange(of: currentDraft) { _, _ in
                persistDraft()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    persistDraft()
                }
            }
        }
    }

    private var commitmentOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existing == nil ? "Plan a commitment once." : "Refine this commitment.")
                .font(.headline.weight(.semibold))

            Text("Use recurring commitments for weekly routines, meetings, and reminders that should stay visible alongside your classroom blocks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                commitmentMetric(title: "Type", value: kind.displayName, accent: ClassTraxSemanticColor.primaryAction)
                commitmentMetric(title: "Pattern", value: recurrence.displayName, accent: ClassTraxSemanticColor.secondaryAction)
            }
        }
        .padding(16)
        .classTraxOverviewCardChrome(accent: ClassTraxSemanticColor.primaryAction)
    }

    private func commitmentMetric(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
        )
    }

    private func loadExisting() {
        if let existing {
            title = existing.title
            kind = existing.kind
            weekday = WeekdayTab(rawValue: existing.dayOfWeek) ?? .today
            recurrence = existing.recurrence
            specificDate = existing.specificDate ?? Date()
            start = existing.startTime
            end = existing.endTime
            location = existing.location
            notes = existing.notes
        } else {
            weekday = WeekdayTab(rawValue: defaultDay) ?? .today
            recurrence = .weekly
            specificDate = Date()
        }
    }

    private func saveCommitment() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEnd = end > start ? end : start.addingTimeInterval(900)
        let resolvedDayOfWeek = recurrence == .oneTime
            ? Calendar.current.component(.weekday, from: specificDate)
            : weekday.rawValue

        let item = CommitmentItem(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            kind: kind,
            dayOfWeek: resolvedDayOfWeek,
            recurrence: recurrence,
            specificDate: recurrence == .oneTime ? specificDate : nil,
            startTime: start,
            endTime: normalizedEnd,
            location: trimmedLocation,
            notes: trimmedNotes
        )

        if let existing,
           let index = commitments.firstIndex(where: { $0.id == existing.id }) {
            commitments[index] = item
        } else {
            commitments.append(item)
        }

        clearDraft()
        dismiss()
    }

    private func deleteCommitment() {
        guard let existing else { return }
        commitments.removeAll { $0.id == existing.id }
        clearDraft()
        dismiss()
    }

    private var currentDraft: Draft {
        Draft(
            existingID: existing?.id,
            title: title,
            kind: kind,
            weekdayRawValue: weekday.rawValue,
            recurrence: recurrence,
            specificDate: specificDate,
            start: start,
            end: end,
            location: location,
            notes: notes
        )
    }

    private func restoreDraftIfNeeded() {
        guard let draft = try? JSONDecoder().decode(Draft.self, from: savedDraftData) else { return }
        guard draft.existingID == existing?.id else { return }
        title = draft.title
        kind = draft.kind
        weekday = WeekdayTab(rawValue: draft.weekdayRawValue) ?? .today
        recurrence = draft.recurrence
        specificDate = draft.specificDate
        start = draft.start
        end = draft.end
        location = draft.location
        notes = draft.notes
    }

    private func persistDraft() {
        guard let encoded = try? JSONEncoder().encode(currentDraft) else { return }
        savedDraftData = encoded
    }

    private func clearDraft() {
        savedDraftData = Data()
    }
}
