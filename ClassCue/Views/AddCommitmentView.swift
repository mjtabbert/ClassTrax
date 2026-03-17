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

    @State private var title = ""
    @State private var kind = CommitmentItem.Kind.other
    @State private var weekday = WeekdayTab.today
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(1800)
    @State private var location = ""
    @State private var notes = ""
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Commitment") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $kind) {
                        ForEach(CommitmentItem.Kind.allCases, id: \.self) { kind in
                            Label(kind.displayName, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }

                    Picker("Day", selection: $weekday) {
                        ForEach(WeekdayTab.allCases, id: \.self) { day in
                            Text(day.title).tag(day)
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute)
                }

                Section("Details") {
                    TextField("Location", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCommitment()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        }
    }

    private func loadExisting() {
        if let existing {
            title = existing.title
            kind = existing.kind
            weekday = WeekdayTab(rawValue: existing.dayOfWeek) ?? .today
            start = existing.startTime
            end = existing.endTime
            location = existing.location
            notes = existing.notes
        } else {
            weekday = WeekdayTab(rawValue: defaultDay) ?? .today
        }
    }

    private func saveCommitment() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEnd = end > start ? end : start.addingTimeInterval(900)

        let item = CommitmentItem(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            kind: kind,
            dayOfWeek: weekday.rawValue,
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

        dismiss()
    }

    private func deleteCommitment() {
        guard let existing else { return }
        commitments.removeAll { $0.id == existing.id }
        dismiss()
    }
}
