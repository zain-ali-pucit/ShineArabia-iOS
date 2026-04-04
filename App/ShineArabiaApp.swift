import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
struct ShineArabiaApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure Firebase — must be first
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        return true
    }

    // MARK: - APNs → Firebase bridge
    // Pass the raw APNs token to Firebase so it can map it to an FCM token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate — FCM token ready/refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }

        // Persist locally so it survives app restarts
        UserDefaults.standard.set(fcmToken, forKey: "fcm_token")

        // Broadcast so other components can react (e.g. ManagerViewModel registers admin token)
        NotificationCenter.default.post(name: .fcmTokenReceived, object: fcmToken)

        // Register with backend (silently fails if user is not yet logged in — retried on login)
        Task {
            try? await UserAPIService.shared.registerDeviceToken(fcmToken)
        }
    }

    // MARK: - Foreground notification display
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification tap handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // Broadcast tap so views can navigate (e.g. open the Orders tab)
        NotificationCenter.default.post(name: .pushNotificationTapped, object: userInfo)
        completionHandler()
    }
}

// MARK: - Notification name helpers
extension Notification.Name {
    static let fcmTokenReceived       = Notification.Name("fcmTokenReceived")
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
