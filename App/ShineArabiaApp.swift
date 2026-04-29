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

        // Request permission and register with APNs so Firebase can obtain an FCM token
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

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
        let content = notification.request.content
        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: nil,
            userInfo: makeReceivedUserInfo(content: content)
        )
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Notification tap handling
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: nil,
            userInfo: makeReceivedUserInfo(content: content)
        )
        NotificationCenter.default.post(name: .pushNotificationTapped, object: content.userInfo)
        completionHandler()
    }

    /// Builds the userInfo dict broadcast on `.pushNotificationReceived`,
    /// merging title/body with any structured fields from the FCM payload
    /// (type, bookingId, status) so AppState can react to them.
    private func makeReceivedUserInfo(content: UNNotificationContent) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [
            "title": content.title,
            "body":  content.body,
        ]
        let payload = content.userInfo
        if let type      = payload["type"]      as? String { info["type"]      = type }
        if let bookingId = payload["bookingId"] as? String { info["bookingId"] = bookingId }
        if let status    = payload["status"]    as? String { info["status"]    = status }
        return info
    }
}

// MARK: - Notification name helpers
extension Notification.Name {
    static let fcmTokenReceived        = Notification.Name("fcmTokenReceived")
    static let pushNotificationTapped  = Notification.Name("pushNotificationTapped")
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
}
