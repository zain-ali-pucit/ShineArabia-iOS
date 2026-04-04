import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var splashFinished = false

    var body: some View {
        ZStack {
            if splashFinished {
                Group {
                    if appState.isManager {
                        // Manager users see only the booking management screen
                        ManagerView()
                            .transition(.opacity)
                    } else if !appState.hasCompletedOnboarding {
                        OnboardingView()
                            .transition(.opacity)
                    } else {
                        MainTabView()
                            .transition(.opacity)
                    }
                }
                .arabicLayout(appState.isArabic)
                .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
                .animation(.easeInOut(duration: 0.25), value: appState.isArabic)
                .transition(.opacity)
            } else {
                SplashView(isFinished: $splashFinished)
                    .transition(.opacity)
            }
        }
        .dismissKeyboardOnTap()
        .animation(.easeInOut(duration: 0.4), value: splashFinished)
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notif in
            if let apiUser = notif.object as? APIUser {
                appState.currentUser     = apiUser.toUser()
                appState.isAuthenticated = true
                appState.userRole        = apiUser.role
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            appState.currentUser     = nil
            appState.isAuthenticated = false
        }
        .task {
            // Restore session on cold start
            guard TokenStore.accessToken != nil else { return }
            do {
                let user = try await AuthService.shared.fetchMe()
                appState.currentUser     = user.toUser()
                appState.isAuthenticated = true
                appState.userRole        = user.role
            } catch {
                TokenStore.clear()
                appState.isAuthenticated = false
            }
        }
    }
}
