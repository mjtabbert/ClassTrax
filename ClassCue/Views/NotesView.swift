import SwiftUI

struct NotesView: View {
    @AppStorage("notes_v1") private var notesText: String = ""

    @State private var showingShareSheet = false
    @State private var exportText = ""
    @FocusState private var isEditorFocused: Bool
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $notesText)
                    .padding(12)
                    .focused($isEditorFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear") {
                            showClearConfirm = true
                        }
                        .foregroundColor(.red)
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportText = classCueNotesExportText(notes: notesText)
                        showingShareSheet = true
                    }

                    if isEditorFocused {
                        Button("Done") {
                            isEditorFocused = false
                        }
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done") {
                        isEditorFocused = false
                    }
                }
            }
            .confirmationDialog(
                "Clear all notes?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Notes", role: .destructive) {
                    notesText = ""
                }

                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [exportText])
            }
        }
    }
}

func classCueNotesExportText(notes: String) -> String {
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateStyle = .long
    dateOnlyFormatter.timeStyle = .none

    let timeOnlyFormatter = DateFormatter()
    timeOnlyFormatter.dateStyle = .none
    timeOnlyFormatter.timeStyle = .short

    let now = Date()

    return """
    Class Cue Notes Export
    \(dateOnlyFormatter.string(from: now))
    \(timeOnlyFormatter.string(from: now))

    \(notes)
    """
}
