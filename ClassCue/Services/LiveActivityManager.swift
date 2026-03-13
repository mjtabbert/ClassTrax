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

    private static var resolvedActivity: Activity<ClassCueActivityAttributes>? {
        if let currentActivity {
            return currentActivity
        }

        let existing = Activity<ClassCueActivityAttributes>.activities.first
        currentActivity = existing
        return existing
    }

    // MARK: - Start Activity

    static func start(
        className: String,
        room: String,
        endTime: Date,
        isHeld: Bool,
        iconName: String,
        nextClassName: String,
        nextIconName: String
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = ClassCueActivityAttributes(
            className: className
        )

        let state = ClassCueActivityAttributes.ContentState(
            className: className,
            room: room,
            endTime: endTime,
            isHeld: isHeld,
            iconName: iconName,
            nextClassName: nextClassName,
            nextIconName: nextIconName
        )

        let content = ActivityContent(
            state: state,
            staleDate: endTime
        )

        if resolvedActivity != nil {
            update(
                className: className,
                room: room,
                endTime: endTime,
                isHeld: isHeld,
                iconName: iconName,
                nextClassName: nextClassName,
                nextIconName: nextIconName
            )
            return
        }

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content
            )
        } catch {
            print("Live Activity start failed:", error.localizedDescription)
        }
    }

    // MARK: - Update Activity

    static func update(
        className: String,
        room: String,
        endTime: Date,
        isHeld: Bool,
        iconName: String,
        nextClassName: String,
        nextIconName: String
    ) {

        Task {
            guard let activity = resolvedActivity else { return }

            let updatedState = ClassCueActivityAttributes.ContentState(
                className: className,
                room: room,
                endTime: endTime,
                isHeld: isHeld,
                iconName: iconName,
                nextClassName: nextClassName,
                nextIconName: nextIconName
            )

            await activity.update(
                ActivityContent(
                    state: updatedState,
                    staleDate: endTime
                )
            )
        }
    }

    static func sync(
        className: String,
        room: String,
        endTime: Date,
        isHeld: Bool,
        iconName: String,
        nextClassName: String,
        nextIconName: String
    ) {
        if resolvedActivity == nil {
            start(
                className: className,
                room: room,
                endTime: endTime,
                isHeld: isHeld,
                iconName: iconName,
                nextClassName: nextClassName,
                nextIconName: nextIconName
            )
        } else {
            update(
                className: className,
                room: room,
                endTime: endTime,
                isHeld: isHeld,
                iconName: iconName,
                nextClassName: nextClassName,
                nextIconName: nextIconName
            )
        }
    }

    // MARK: - Stop Activity

    static func stop() {

        Task {
            for activity in Activity<ClassCueActivityAttributes>.activities {
                await activity.end(
                    nil,
                    dismissalPolicy: .immediate
                )
            }

            currentActivity = nil
        }
    }
}
