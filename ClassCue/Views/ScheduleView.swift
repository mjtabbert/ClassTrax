//
//  ScheduleView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import SwiftUI

struct ScheduleView: View {

    @Binding var alarms: [AlarmItem]

    var body: some View {

        NavigationView {

            List {

                ForEach(alarms) { item in

                    VStack(alignment: .leading, spacing: 6) {

                        HStack {

                            Text(item.className)
                                .font(.headline)

                            Spacer()

                            TypeBadge(type: item.scheduleType)
                        }

                        HStack {

                            Text(timeRange(item))
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(item.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Schedule")
        }
    }

    // MARK: - Time Formatter

    func timeRange(_ item: AlarmItem) -> String {

        let formatter = DateFormatter()
        formatter.timeStyle = .short

        let start = formatter.string(from: item.start)
        let end = formatter.string(from: item.end)

        return "\(start) – \(end)"
    }
}
