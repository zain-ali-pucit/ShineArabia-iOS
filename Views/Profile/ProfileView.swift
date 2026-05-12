import SwiftUI
import UserNotifications
import UIKit

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var locationService = LocationService.shared

    // Notification state
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined

    // User data
    @State private var userStats: APIUserStats?
    @State private var isLoadingStats = false

    // Navigation
    @State private var showAddresses = false
    @State private var showEditProfile = false
    @State private var showChangePassword = false
    @State private var showSignOutConfirm = false

    // ── Computed helpers ────────────────────────────────────────────────
    private var displayUser: (initials: String, name: String, phone: String) {
        if let u = appState.currentUser {
            return (u.avatarInitials, u.name, u.phone)
        }
        return ("SA", "ShineArabia User", "")
    }

    private var notifOn: Bool {
        notifStatus == .authorized || notifStatus == .provisional
    }

    private var locationOn: Bool {
        locationService.isAuthorized
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
            authenticatedProfile
        }
        .task {
            await checkNotifStatus()
            await loadStats()
        }
        .sheet(isPresented: $showAddresses) {
            AddressesView().environmentObject(appState)
        }
        .sheet(isPresented: $showEditProfile) {
            if let user = appState.currentUser {
                EditProfileView(user: user).environmentObject(appState)
            }
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .confirmationDialog(
            appState.isArabic ? "تسجيل الخروج" : "Sign Out",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button(appState.isArabic ? "تسجيل الخروج" : "Sign Out", role: .destructive) {
                Task {
                    await appState.signOut()
                    await MainActor.run { appState.selectedTab = .home }
                }
            }
            Button(appState.isArabic ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(appState.isArabic ? "هل أنت متأكد أنك تريد تسجيل الخروج؟" : "Are you sure you want to sign out?")
        }
    }

    // MARK: - Authenticated profile

    private var authenticatedProfile: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ShineSpacing.lg) {

                // ── Avatar card ──────────────────────────────────────────
                Button { showEditProfile = true } label: {
                    VStack(spacing: ShineSpacing.md) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatarView(user: appState.currentUser, size: 84)

                            ZStack {
                                Circle()
                                    .fill(Color.shineCoral)
                                    .frame(width: 26, height: 26)
                                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 4, y: 4)
                        }

                        VStack(spacing: 4) {
                            Text(displayUser.name)
                                .font(ShineFont.displayBold(24))
                                .foregroundColor(.shineInk)
                            if !displayUser.phone.isEmpty {
                                Text(displayUser.phone)
                                    .font(ShineFont.body(14))
                                    .foregroundColor(.shineInk3)
                            }
                            Text("Tap to edit profile")
                                .font(ShineFont.body(11))
                                .foregroundColor(.shineCoral.opacity(0.8))
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ShineSpacing.xl)
                    .background(Color.shineSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.lg))
                    .shineShadowSM()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.lg)

                // ── Reward Points card ───────────────────────────────────
                let pts = userStats.map { $0.points } ?? (isLoadingStats ? nil : appState.userPoints)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        appState.selectedTab = .rewards
                    }
                } label: {
                    RewardPointsCard(
                        points: pts,
                        isLoading: isLoadingStats,
                        isArabic: appState.isArabic
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, ShineSpacing.lg)

                // ── Stats row ────────────────────────────────────────────
                HStack(spacing: 14) {
                    StatCard(
                        value: userStats.map { "\($0.totalOrders)" } ?? (isLoadingStats ? "…" : "--"),
                        label: Loc.string("profile.orders", isArabic: appState.isArabic),
                        color: .shineCoral
                    )
                    StatCard(
                        value: "4.9 ★",
                        label: Loc.string("profile.rating", isArabic: appState.isArabic),
                        color: .shineAmber
                    )
                    StatCard(
                        value: userStats.map { "QAR \(Int($0.totalSpent))" } ?? (isLoadingStats ? "…" : "--"),
                        label: Loc.string("profile.saved", isArabic: appState.isArabic),
                        color: .shineTeal
                    )
                }
                .padding(.horizontal, ShineSpacing.lg)

                // ── Settings section ─────────────────────────────────────
                ProfileSection(
                    title: Loc.string("profile.settings", isArabic: appState.isArabic)
                ) {
                    VStack(spacing: 0) {
                        // Notifications toggle
                        ProfileActionRow(
                            icon: "bell.fill",
                            iconColor: .shineCoral,
                            title: Loc.string("profile.notifications", isArabic: appState.isArabic),
                            subtitle: notifOn
                                ? (appState.isArabic ? "مفعّل" : "Enabled")
                                : (appState.isArabic ? "معطّل" : "Disabled"),
                            isOn: notifOn
                        ) {
                            handleNotificationToggle()
                        }

                        Divider().padding(.leading, 52)

                        // Location toggle
                        ProfileActionRow(
                            icon: "location.fill",
                            iconColor: .shineTeal,
                            title: Loc.string("profile.location", isArabic: appState.isArabic),
                            subtitle: locationService.isDenied
                                ? (appState.isArabic ? "مرفوض – افتح الإعدادات" : "Denied – open Settings")
                                : locationOn
                                    ? (appState.isArabic ? "مفعّل" : "Enabled")
                                    : (appState.isArabic ? "معطّل" : "Disabled"),
                            isOn: locationOn
                        ) {
                            handleLocationToggle()
                        }

                        Divider().padding(.leading, 52)

                        // Language
                        Button {
                            withAnimation(.spring(response: 0.35)) {
                                appState.language = appState.isArabic ? .english : .arabic
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ProfileIconBox(icon: "globe", color: .shineAmber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Loc.string("profile.language", isArabic: appState.isArabic))
                                        .font(ShineFont.body(15))
                                        .foregroundColor(.shineInk)
                                    Text(appState.language.label)
                                        .font(ShineFont.body(12))
                                        .foregroundColor(.shineInk3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.shineInk3.opacity(0.5))
                            }
                            .padding(.horizontal, ShineSpacing.md)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // ── Account section ──────────────────────────────────────
                ProfileSection(
                    title: Loc.string("profile.account", isArabic: appState.isArabic)
                ) {
                    VStack(spacing: 0) {
                        Button { showEditProfile = true } label: {
                            ProfileLinkRow(icon: "person.fill",
                                           iconColor: .shineLavender,
                                           title: Loc.string("profile.edit", isArabic: appState.isArabic))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        Button { showAddresses = true } label: {
                            ProfileLinkRow(icon: "location.fill",
                                           iconColor: .shineTeal,
                                           title: Loc.string("profile.addresses", isArabic: appState.isArabic))
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        Button { showChangePassword = true } label: {
                            ProfileLinkRow(icon: "lock.fill",
                                           iconColor: .shineCoral,
                                           title: appState.isArabic ? "تغيير كلمة المرور" : "Change Password")
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 52)
                        ProfileLinkRow(icon: "questionmark.circle.fill",
                                       iconColor: .shineAmber,
                                       title: Loc.string("profile.help", isArabic: appState.isArabic))
                    }
                }

                // ── Sign out ─────────────────────────────────────────────
                Button {
                    showSignOutConfirm = true
                } label: {
                    Text(Loc.string("profile.signout", isArabic: appState.isArabic))
                        .font(ShineFont.body(15, weight: .medium))
                        .foregroundColor(.shineCoral)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.shineCoralLight)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                }
                .padding(.horizontal, ShineSpacing.lg)
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Actions

    private func handleNotificationToggle() {
        switch notifStatus {
        case .notDetermined:
            Task {
                let granted = (try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                await checkNotifStatus()
                if granted {
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    // Register pending FCM token if available
                    await UserAPIService.shared.registerPendingDeviceToken()
                }
            }
        default:
            // Already determined — user must go to Settings to change
            openSettings()
        }
    }

    private func handleLocationToggle() {
        if locationService.isNotDetermined {
            locationService.requestPermission()
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func checkNotifStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notifStatus = settings.authorizationStatus }
    }

    private func loadStats() async {
        await MainActor.run { isLoadingStats = true }
        let stats = try? await UserAPIService.shared.fetchStats()
        await MainActor.run {
            userStats         = stats
            isLoadingStats    = false
            appState.userPoints = stats?.points ?? appState.userPoints
        }
    }
}

// MARK: - Reward Points Card

struct RewardPointsCard: View {
    let points: Int?
    let isLoading: Bool
    let isArabic: Bool

    private var pointsValue: Int { points ?? 0 }

    private var pointsText: String {
        guard let p = points else { return isLoading ? "…" : "--" }
        return "\(p)"
    }

    private var currentTier: RewardTier? {
        rewardTiers.filter { pointsValue >= $0.points }.last
    }

    private var nextTier: RewardTier? {
        rewardTiers.first { pointsValue < $0.points }
    }

    private var progressToNextTier: Double {
        guard let next = nextTier else { return 1.0 }
        let prevPoints = rewardTiers.filter { $0.points <= pointsValue }.last?.points ?? 0
        let range = Double(next.points - prevPoints)
        let current = Double(pointsValue - prevPoints)
        return min(max(current / range, 0), 1)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ShineRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1C1917"), Color(hex: "3D2C1E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.shineAmber.opacity(0.25))
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .offset(x: 100, y: -20)

            VStack(alignment: .leading, spacing: 12) {
                // Points + trophy row
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("⭐")
                                .font(.system(size: 14))
                            Text(isArabic ? "نقاط المكافآت" : "Reward Points")
                                .font(ShineFont.body(12, weight: .semibold))
                                .foregroundColor(Color(hex: "F4C97A"))
                                .kerning(0.3)
                                .textCase(.uppercase)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(pointsText)
                                .font(ShineFont.displayBold(38))
                                .foregroundColor(.white)
                            Text(isArabic ? "نقطة" : "pts")
                                .font(ShineFont.body(14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.bottom, 4)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.shineAmber.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .frame(width: 60, height: 60)
                        Circle()
                            .fill(Color.shineAmber.opacity(0.08))
                            .frame(width: 60, height: 60)
                        Text(currentTier?.icon ?? "🏆")
                            .font(.system(size: 28))
                    }
                }

                // Unlocked reward badge
                if let tier = currentTier {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "F4C97A"))
                        Text(isArabic ? "مفعّل: \(tier.rewardAR)" : "Unlocked: \(tier.reward)")
                            .font(ShineFont.body(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.shineAmber.opacity(0.15))
                    .clipShape(Capsule())
                }

                // Progress to next tier
                if let next = nextTier {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(isArabic ? "التالي: \(next.rewardAR)" : "Next: \(next.reward)")
                                .font(ShineFont.body(11))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                            Spacer()
                            Text(isArabic ? "\(next.points - pointsValue) نقطة" : "\(next.points - pointsValue) pts away")
                                .font(ShineFont.body(10, weight: .semibold))
                                .foregroundColor(Color(hex: "F4C97A").opacity(0.85))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "F4C97A"), Color(hex: "E8A020")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progressToNextTier, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                } else {
                    Text(isArabic ? "وصلت إلى أعلى مستوى! 🎉" : "Maximum tier reached! 🎉")
                        .font(ShineFont.body(11, weight: .medium))
                        .foregroundColor(Color(hex: "F4C97A"))
                }

                // Tap hint
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.35))
                        Text(isArabic ? "فتح تبويب المكافآت" : "Open Rewards tab")
                            .font(ShineFont.body(10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                        Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .shineShadowMD()
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(ShineFont.displayBold(20))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(ShineFont.body(11))
                .foregroundColor(.shineInk3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
        .shineShadowXS()
    }
}

// MARK: - Profile Section

struct ProfileSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ShineSpacing.sm) {
            Text(title)
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, ShineSpacing.lg)

            content
                .background(Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                .shineShadowXS()
                .padding(.horizontal, ShineSpacing.lg)
        }
    }
}

// MARK: - Profile Icon Box

struct ProfileIconBox: View {
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
        }
    }
}

// MARK: - Profile Action Row (toggle behaviour)
// Tapping the entire row calls `action`. The pill shows on/off state.

struct ProfileActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ProfileIconBox(icon: icon, color: iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ShineFont.body(15))
                        .foregroundColor(.shineInk)
                    Text(subtitle)
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                }

                Spacer()

                // iOS-style toggle pill (visual only — interaction is whole row)
                Capsule()
                    .fill(isOn ? Color.shineCoral : Color.shineInk3.opacity(0.3))
                    .frame(width: 44, height: 26)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .offset(x: isOn ? 9 : -9)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isOn)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Avatar View (image or initials fallback)

struct ProfileAvatarView: View {
    let user: User?
    let size: CGFloat

    var body: some View {
        if let urlStr = user?.avatarUrl, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.shineSurface, lineWidth: 3))
                        .shadow(color: Color.shineCoral.opacity(0.25), radius: 14, x: 0, y: 6)
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.shineCoral, .shineAmber],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: size, height: size)
                .shadow(color: Color.shineCoral.opacity(0.3), radius: 14, x: 0, y: 6)
            Text(user?.avatarInitials ?? "SA")
                .font(ShineFont.displayBold(size * 0.36))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Profile Link Row

struct ProfileLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            ProfileIconBox(icon: icon, color: iconColor)

            Text(title)
                .font(ShineFont.body(15))
                .foregroundColor(.shineInk)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.shineInk3.opacity(0.5))
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }
}
