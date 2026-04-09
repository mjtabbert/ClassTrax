import SwiftUI
import SwiftData
import UserNotifications

@main
struct ClassTraxApp: App {
    init() {
        WatchSessionSyncManager.shared.activate()

        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared

        NotificationCategories.register()
        ClassTraxPersistence.registerCloudKitEventObserver()
        ClassTraxPersistence.refreshCloudKitDiagnosticsStatus()
        Task {
            NotificationManager.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ClassTraxPersistence.sharedModelContainer)
    }
}
