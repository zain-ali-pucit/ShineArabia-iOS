import SwiftUI
import Combine

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
    case profile = "person.fill"

    var title: String {
        switch self {
        case .home:    return "Home"
        case .explore: return "Explore"
        case .orders:  return "Orders"
        case .profile: return "Profile"
        }
    }
    var titleAR: String {
        switch self {
        case .home:    return "الرئيسية"
        case .explore: return "استكشاف"
        case .orders:  return "طلباتي"
        case .profile: return "حسابي"
        }
    }
}

// MARK: - AppState
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var language: AppLanguage        = .english
    @Published var selectedTab: TabItem         = .home
    @Published var currentUser: User?           = nil
    @Published var activeBooking: Booking?      = nil
    @Published var isAuthenticated: Bool        = TokenStore.accessToken != nil
    @Published var userRole: String?            = nil   // "customer" | "admin"

    var isArabic: Bool  { language == .arabic }
    var isManager: Bool { userRole == "admin" }

    func signOut() async {
        await AuthService.shared.logout()
        await MainActor.run {
            isAuthenticated = false
            currentUser     = nil
            userRole        = nil
        }
    }
}
