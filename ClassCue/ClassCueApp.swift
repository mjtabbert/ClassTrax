import SwiftUI
import UserNotifications

@main
struct ClassCueApp: App {
    init() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared

        NotificationCategories.register()
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
