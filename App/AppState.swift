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
    case explore = "square.grid.2x2.fill"
    case orders  = "list.bullet.clipboard.fill"
    case rewards = "star.fill"
    case profile = "person.fill"

    var title: String {
        switch self {
        case .home:    return "Home"
        case .explore: return "Services"
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
    @Published var hasCompletedAppTour: Bool = UserDefaults.standard.bool(forKey: "hasCompletedAppTour") {
        didSet { UserDefaults.standard.set(hasCompletedAppTour, forKey: "hasCompletedAppTour") }
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

    // MARK: - Push notification deep-link state
    /// Set when a notification tap should deep-link to a specific booking.
    /// Cleared by the consumer (StaffView / OrdersView) once handled.
    @Published var pendingBookingDeepLink: String? = nil
    /// Bumped whenever a `booking_refresh` push arrives — staff/booking VMs
    /// observe this to reload their lists.
    @Published var bookingRefreshTick: Int = 0
    /// Recently-arrived booking IDs (set by `new_booking` push). UI can decorate
    /// these cards for ~30 s before they fade back to normal.
    @Published var newBookingIds: Set<String> = []
    /// Cached FCM token captured before login — registered after auth completes.
    var pendingFcmToken: String? = nil

    var isArabic: Bool  { language == .arabic }
    // Any internal role (admin, manager, staff) goes to the Staff panel
    var isStaff: Bool   { userRole == "admin" || userRole == "manager" || userRole == "staff" }
    // Staff must upload both avatar and certificate before using the app
    var isStaffProfileComplete: Bool {
        guard isStaff else { return true }
        return (currentUser?.avatarUrl ?? "").isEmpty == false &&
               (currentUser?.certificateUrl ?? "").isEmpty == false
    }

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

            // If the push carried structured payload data, react accordingly:
            //   - type == "booking_refresh"  → bump refresh tick
            //   - type == "new_booking"      → mark booking new + bump refresh
            let type     = note.userInfo?["type"]      as? String
            let bookingId = note.userInfo?["bookingId"] as? String
            if type == "booking_refresh" {
                self.bookingRefreshTick += 1
            }
            if type == "new_booking", let id = bookingId, !id.isEmpty {
                self.markBookingAsNew(id)
                self.bookingRefreshTick += 1
            }
        }

        // Tap → deep-link routing
        NotificationCenter.default.addObserver(
            forName: .pushNotificationTapped,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let userInfo = note.object as? [AnyHashable: Any] else { return }
            if let bookingId = userInfo["bookingId"] as? String, !bookingId.isEmpty {
                self.pendingBookingDeepLink = bookingId
                // Switch to the orders tab so the user lands on a sensible screen.
                if !self.isStaff { self.selectedTab = .orders }
            }
        }
    }

    /// Mark a booking as freshly arrived; auto-clears after `duration`.
    func markBookingAsNew(_ bookingId: String, duration: TimeInterval = 30) {
        guard !bookingId.isEmpty else { return }
        newBookingIds.insert(bookingId)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.newBookingIds.remove(bookingId)
        }
    }

    func clearPendingBookingDeepLink() {
        pendingBookingDeepLink = nil
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
