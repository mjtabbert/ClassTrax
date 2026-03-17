//
//  ScheduleList.swift
//  ClassTrax
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassTrax Dev Build 25
//

import SwiftUI

struct ScheduleList: View {

    let schedule: [AlarmItem]
    let now: Date

    private var activeItemID: AlarmItem.ID? {
        schedule.first(where: {
            now >= $0.start && now <= $0.end
        })?.id
    }

    var body: some View {

        ScrollViewReader { proxy in

            ScrollView {

                LazyVStack(spacing: 10) {

                    ForEach(schedule) { item in

                        TimelineRow(
                            item: item,
                            now: now,
                            isHero: false
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal)
            }

            .onAppear {

                scrollToCurrent(proxy: proxy)
            }

            .onChange(of: activeItemID) {

                scrollToCurrent(proxy: proxy)
            }
        }
    }

    func scrollToCurrent(proxy: ScrollViewProxy) {

        if let active = schedule.first(where: {
            now >= $0.start && now <= $0.end
        }) {

            withAnimation {

                proxy.scrollTo(active.id, anchor: .center)
            }
        }
    }
}
