import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var homeVM    = HomeViewModel()
    @StateObject private var bookingVM = BookingViewModel()
    @State private var pendingTab: TabItem? = nil
    @State private var tabFrames: [TabItem: CGRect] = [:]
    @State private var showTour = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content — full screen, tab bar floats above
            Group {
                switch appState.selectedTab {
                case .home:    HomeView().environmentObject(homeVM).environmentObject(bookingVM)
                case .explore: ExploreView().environmentObject(homeVM).environmentObject(bookingVM)
                case .orders:  OrdersView().environmentObject(bookingVM)
                case .rewards: RewardsView()
                case .profile: ProfileView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 96)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating pill tab bar
            ShineTabBar(onAuthRequired: { tab in pendingTab = tab })
                .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.shineBG)
        .onPreferenceChange(TabFrameKey.self) { tabFrames = $0 }
        .overlay {
            if showTour {
                AppTourView(tabFrames: tabFrames) {
                    withAnimation(.easeInOut(duration: 0.3)) { showTour = false }
                    appState.hasCompletedAppTour = true
                }
                .environmentObject(appState)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showTour)
        .onAppear {
            guard !appState.hasCompletedAppTour else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showTour = true
            }
        }
        .sheet(isPresented: Binding(
            get: { pendingTab != nil },
            set: { if !$0 { pendingTab = nil } }
        )) {
            LoginView().environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            guard let destination = pendingTab else { return }
            pendingTab = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                appState.selectedTab = destination
            }
        }
    }
}

// MARK: - Floating Pill Tab Bar
struct ShineTabBar: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var tabAnimation
    let onAuthRequired: (TabItem) -> Void

    private let authProtectedTabs: Set<TabItem> = [.profile, .orders, .rewards]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                ShineTabItem(
                    tab: tab,
                    isSelected: appState.selectedTab == tab,
                    isArabic: appState.isArabic,
                    showBadge: tab == .orders,
                    namespace: tabAnimation
                ) {
                    if authProtectedTabs.contains(tab) && !appState.isAuthenticated {
                        onAuthRequired(tab)
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            appState.selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(Color.shineSurface)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.shineBorder.opacity(0.8), lineWidth: 0.5)
                }
        }
        .shadow(color: .shineInk.opacity(0.10), radius: 20, x: 0, y: 6)
        .padding(.horizontal, 32)
    }
}

// MARK: - Tab Item
struct ShineTabItem: View {
    let tab: TabItem
    let isSelected: Bool
    let isArabic: Bool
    let showBadge: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: tab.rawValue)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.shineCoral : Color.shineInk3)
                        .frame(width: 50, height: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Color.shineCoralLight)
                                    .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                            }
                        }

                    Text(isArabic ? tab.titleAR : tab.title)
                        .font(ShineFont.body(10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.shineCoral : Color.shineInk3)
                        .opacity(isSelected ? 1 : 0.7)
                }

                // Badge dot
                if showBadge {
                    Circle()
                        .fill(Color.shineCoral)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                        .offset(x: -4, y: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: TabFrameKey.self,
                        value: [tab: geo.frame(in: .global)]
                    )
                }
            )
        }
        .buttonStyle(.plain)
    }
}
