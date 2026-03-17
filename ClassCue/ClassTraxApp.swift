import SwiftUI
import SwiftData
import UserNotifications

@main
struct ClassTraxApp: App {
    init() {
        ClassTraxPersistence.initializeCloudKitDevelopmentSchemaIfNeeded()

        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared

        NotificationCategories.register()
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ClassTraxPersistence.sharedModelContainer)
    }
}
