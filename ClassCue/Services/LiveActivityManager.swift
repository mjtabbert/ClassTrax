//
//  LiveActivityManager.swift
//  ClassCue
//
//  Developer: Mr. Mike
//  Last Updated: March 11, 2026
//  Build: ClassCue Dev Build 23
//

import Foundation
import ActivityKit

class LiveActivityManager {

    static var currentActivity: Activity<ClassCueActivityAttributes>?

    // MARK: - Start Activity

    static func start(className: String, endTime: Date) {

        let attributes = ClassCueActivityAttributes(
            className: className
        )

        let state = ClassCueActivityAttributes.ContentState(
            className: className,
            endTime: endTime
        )

        let content = ActivityContent(
            state: state,
            staleDate: endTime
        )

        currentActivity = try? Activity.request(
            attributes: attributes,
            content: content
        )
    }

    // MARK: - Update Activity

    static func update(className: String, endTime: Date) {

        Task {

            let updatedState = ClassCueActivityAttributes.ContentState(
                className: className,
                endTime: endTime
            )

            await currentActivity?.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: endTime
                )
            )
        }
    }

    // MARK: - Stop Activity

    static func stop() {

        Task {

            await currentActivity?.end(
                nil,
                dismissalPolicy: .immediate
            )

            currentActivity = nil
        }
    }
}
