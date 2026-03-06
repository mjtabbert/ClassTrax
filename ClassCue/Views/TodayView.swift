//
//  TodayView.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 24
//

import SwiftUI

struct TodayView: View {

    @Binding var alarms: [AlarmItem]
    let now: Date
    let ignoreDate: Date?

    var body: some View {

        let schedule = getDayScheduleWithTransitions()

        let activeItem = schedule.first {
            now >= $0.start && now <= $0.end
        }

        let nextItem = schedule.first {
            $0.start > now
        }

        ScrollView {

            VStack(spacing: 20) {

                header(now: now)

                if let active = activeItem {
                    ActiveTimerCard(item: active, now: now)
                        .padding(.horizontal)
                }

                if let next = nextItem {
                    NextUpSummaryCard(item: next, now: now)
                        .padding(.horizontal)
                }

                VStack(spacing: 8) {

                    ForEach(schedule) { item in
                        TimelineRow(
                            item: item,
                            now: now,
                            isHero: false
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    func header(now: Date) -> some View {

        VStack(spacing: 4) {

            Text(now.formatted(.dateTime.weekday(.wide)))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .tracking(4)

            Text(now.formatted(.dateTime.month().day()))
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(now.formatted(.dateTime.hour().minute()))
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
}
