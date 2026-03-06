//
//  NextUpSummaryCard.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import SwiftUI

struct NextUpSummaryCard: View {

    let item: AlarmItem
    let now: Date

    var body: some View {

        VStack(spacing: 6) {

            Text("NEXT UP")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)

            Text(item.className)
                .font(.headline)

            Text(timeText)
                .font(.subheadline)
                .foregroundColor(.secondary)

        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Timing

    private var start: Date {
        item.start
    }

    private var timeText: String {

        let seconds = Int(start.timeIntervalSince(now))
        let minutes = seconds / 60

        return "Starts in \(minutes)m"
    }
}
