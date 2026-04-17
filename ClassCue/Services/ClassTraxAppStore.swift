import Foundation
import Combine
import SwiftUI

@MainActor
final class ClassTraxAppStore: ObservableObject {
    @Published var selectedTabKey: String = "today"
    @Published var selectedScheduleDayRawValue: Int = 0
    @Published var focusedScheduleItemID: UUID?
    @Published var focusedTodoID: UUID?
    @Published var managePath = NavigationPath()
    @Published var requestedManageDestinationKey: String?

    func openScheduleBlock(itemID: UUID, weekdayRawValue: Int) {
        focusedScheduleItemID = itemID
        selectedScheduleDayRawValue = weekdayRawValue
        selectedTabKey = "schedule"
    }

    func resetManagePath() {
        managePath = NavigationPath()
    }

    func requestManageDestination(_ destinationKey: String) {
        requestedManageDestinationKey = destinationKey
    }
}
