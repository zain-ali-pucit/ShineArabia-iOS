import SwiftUI
import Combine
import UserNotifications

// MARK: - App Notification
struct AppNotification: Identifiable {
    let id   = UUID()
    let title: String
    let body: String
    let date: Date
    var isRead: Bool = false
}

// MARK: - App Language
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case arabic  = "ar"

    var isRTL: Bool   { self == .arabic }
    var label: String { self == .english ? "EN" : "عر" }
}

// MARK: - Tab Items
enum TabItem: String, CaseIterable {
    case home    = "house.fill"
    case explore = "magnifyingglass"
    case orders  = "list.bullet.clipboard.fill"
    case rewards = "star.fill"
    case profile = "person.fill"

    var title: String {
        switch self {
        case .home:    return "Home"
        case .explore: return "Explore"
        case .orders:  return "Orders"
        case .rewards: return "Rewards"
        case .profile: return "Profile"
        }
    }
    var titleAR: String {
        switch self {
        case .home:    return "الرئيسية"
        case .explore: return "استكشاف"
        case .orders:  return "طلباتي"
        case .rewards: return "مكافآتي"
        case .profile: return "حسابي"
        }
    }
}

// MARK: - AppState
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var language: AppLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .english {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }
    @Published var selectedTab: TabItem         = .home
    @Published var currentUser: User?           = nil
    @Published var activeBooking: Booking?      = nil
    @Published var isAuthenticated: Bool        = TokenStore.accessToken != nil
    @Published var userRole: String?            = nil   // "customer" | "admin"
    @Published var userPoints: Int              = 0

    // MARK: - In-App Notifications
    @Published var notifications: [AppNotification] = []
    var unreadCount: Int { notifications.filter { !$0.isRead }.count }

    var isArabic: Bool  { language == .arabic }
    var isManager: Bool { userRole == "admin" }

    init() {
        NotificationCenter.default.addObserver(
            forName: .pushNotificationReceived,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let title = note.userInfo?["title"] as? String,
                  let body  = note.userInfo?["body"]  as? String else { return }
            self.notifications.insert(
                AppNotification(title: title, body: body, date: Date()),
                at: 0
            )
        }
    }

    func markAllNotificationsRead() {
        for i in notifications.indices { notifications[i].isRead = true }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func signOut() async {
        await AuthService.shared.logout()
        await MainActor.run {
            isAuthenticated = false
            currentUser     = nil
            userRole        = nil
            userPoints      = 0
        }
    }
}
