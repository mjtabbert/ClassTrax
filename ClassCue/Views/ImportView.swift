//
//  ImportView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import SwiftUI

struct ImportView: View {

    @Binding var alarms: [AlarmItem]

    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false
    @State private var errorMessage = ""
    @State private var importedCount = 0

    var body: some View {

        VStack(spacing: 20) {

            Text("Import Schedule CSV")
                .font(.title)
                .fontWeight(.bold)

            Button("Import Example CSV") {
                importCSV()
            }
            .buttonStyle(.borderedProminent)

        }
        .padding()
        .alert("Import Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Import Complete", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(importedCount) items imported.")
        }
    }

    // MARK: - CSV Import

    private func importCSV() {

        guard let url = Bundle.main.url(forResource: "schedule", withExtension: "csv") else {
            errorMessage = "CSV file not found."
            showErrorAlert = true
            return
        }

        do {

            let data = try String(contentsOf: url)
            let rows = data.components(separatedBy: "\n")

            var newItems: [AlarmItem] = []

            let formatter24 = DateFormatter()
            formatter24.dateFormat = "HH:mm"

            let formatter12 = DateFormatter()
            formatter12.dateFormat = "h:mm a"

            for (index, row) in rows.enumerated() {

                if index == 0 { continue } // Skip header

                let parts = row.components(separatedBy: ",")

                if parts.count < 6 { continue }

                let className = parts[1]
                let location = parts[3]

                let start =
                    formatter24.date(from: parts[4]) ??
                    formatter12.date(from: parts[4])

                let end =
                    formatter24.date(from: parts[5]) ??
                    formatter12.date(from: parts[5])

                guard let startTime = start,
                      let endTime = end else {
                    continue
                }

                let type = scheduleType(from: parts.count > 6 ? parts[6] : "")

                // NEW AlarmItem initializer
                let item = AlarmItem(
                    name: className,
                    start: startTime,
                    end: endTime,
                    location: location,
                    scheduleType: type
                )

                newItems.append(item)
            }

            alarms = newItems

            NotificationManager.shared.refreshNotifications(for: alarms)

            importedCount = newItems.count
            showSuccessAlert = true

        } catch {

            errorMessage = "Failed to read CSV."
            showErrorAlert = true
        }
    }

    // MARK: - Schedule Type Parser

    private func scheduleType(from string: String) -> AlarmItem.ScheduleType {

        switch string.lowercased() {

        case "prep":
            return .prep

        case "planning":
            return .planning

        case "recess":
            return .recess

        case "lunch":
            return .lunch

        case "transition":
            return .transition

        default:
            return .classPeriod
        }
    }
}
