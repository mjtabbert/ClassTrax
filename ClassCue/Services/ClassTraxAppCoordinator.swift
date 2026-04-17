import Foundation

struct ClassTraxAppCoordinator {
    struct TabSelectionPlan {
        let resetScheduleDayToToday: Bool
        let refreshCloudBackedStore: Bool
        let syncRuntimeState: Bool
    }

    enum LaunchPlan {
        case syncOnly(ignoreUntil: Double)
        case bootstrap(ignoreUntil: Double)
    }

    struct CloudRefreshPlan {
        let shouldRefresh: Bool
        let bypassLocalMutationPause: Bool
    }

    func launchPlan(
        hasBootstrappedInitialData: Bool,
        synchronizedIgnoreUntil: Double
    ) -> LaunchPlan {
        if hasBootstrappedInitialData {
            return .syncOnly(ignoreUntil: synchronizedIgnoreUntil)
        }
        return .bootstrap(ignoreUntil: synchronizedIgnoreUntil)
    }

    func tabSelectionPlan(
        isScheduleTab: Bool,
        isSettingsTab: Bool
    ) -> TabSelectionPlan {
        TabSelectionPlan(
            resetScheduleDayToToday: isScheduleTab,
            refreshCloudBackedStore: !isSettingsTab,
            syncRuntimeState: !isSettingsTab
        )
    }

    func cloudRefreshPlan(
        force: Bool,
        bypassLocalMutationPause: Bool,
        now: Date,
        lastCloudBackedRefreshAt: Date,
        lastLocalMutationAt: Date,
        minimumRefreshInterval: TimeInterval,
        localMutationRefreshPauseSeconds: TimeInterval
    ) -> CloudRefreshPlan {
        if !force, now.timeIntervalSince(lastCloudBackedRefreshAt) < minimumRefreshInterval {
            return CloudRefreshPlan(shouldRefresh: false, bypassLocalMutationPause: bypassLocalMutationPause)
        }
        if !bypassLocalMutationPause,
           now.timeIntervalSince(lastLocalMutationAt) < localMutationRefreshPauseSeconds {
            return CloudRefreshPlan(shouldRefresh: false, bypassLocalMutationPause: bypassLocalMutationPause)
        }
        return CloudRefreshPlan(shouldRefresh: true, bypassLocalMutationPause: bypassLocalMutationPause)
    }

    func shouldRefreshForCloudKitEvent(
        isCloudKitMode: Bool,
        timestamp: Double,
        summary: String,
        lastCloudBackedRefreshAt: Date
    ) -> Bool {
        guard isCloudKitMode, timestamp > 0 else { return false }
        let eventDate = Date(timeIntervalSince1970: timestamp)
        guard eventDate > lastCloudBackedRefreshAt else { return false }

        let normalizedSummary = summary.lowercased()
        return normalizedSummary.contains("import succeeded") ||
            normalizedSummary.contains("setup succeeded")
    }

    func shouldRunCloudSyncRefreshTick(
        isCloudKitMode: Bool,
        isSettingsTab: Bool,
        isStudentsTab: Bool,
        now: Date,
        lastLocalMutationAt: Date,
        localMutationRefreshPauseSeconds: TimeInterval
    ) -> Bool {
        guard isCloudKitMode else { return false }
        guard !isSettingsTab, !isStudentsTab else { return false }
        return now.timeIntervalSince(lastLocalMutationAt) >= localMutationRefreshPauseSeconds
    }
}
