//
//  ClassCueLiveActivityWidget.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import WidgetKit
import SwiftUI
import ActivityKit

struct ClassCueLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(for: ClassCueActivityAttributes.self) { context in

            VStack(spacing: 6) {

                Text("ClassCue")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(context.state.className)
                    .font(.headline)

                Text(context.state.endTime, style: .timer)
                    .font(.system(size: 40, weight: .bold))
                    .monospacedDigit()
            }

        } dynamicIsland: { context in

            DynamicIsland {

                DynamicIslandExpandedRegion(.center) {

                    VStack {

                        Text(context.state.className)
                            .font(.headline)

                        Text(context.state.endTime, style: .timer)
                            .font(.title)
                            .monospacedDigit()
                    }
                }

            } compactLeading: {

                Text(context.state.className.prefix(3))

            } compactTrailing: {

                Text(context.state.endTime, style: .timer)

            } minimal: {

                Text("⏱")
            }
        }
    }
}
