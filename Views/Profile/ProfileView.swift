import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var notificationsOn = true
    @State private var locationOn      = true
    @State private var userStats: APIUserStats? = nil

    private var displayUser: (initials: String, name: String, phone: String) {
        if let u = appState.currentUser {
            return (u.avatarInitials, u.name, u.phone)
        }
        return ("SA", "ShineArabia User", "")
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: ShineSpacing.lg) {
                    // Avatar card
                    VStack(spacing: ShineSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.shineCoral, .shineAmber],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.shineCoral.opacity(0.3), radius: 12, x: 0, y: 6)
                            Text(displayUser.initials)
                                .font(ShineFont.displayBold(28))
                                .foregroundColor(.white)
                        }
                        VStack(spacing: 4) {
                            Text(displayUser.name)
                                .font(ShineFont.displayBold(22))
                                .foregroundColor(.shineInk)
                            if !displayUser.phone.isEmpty {
                                Text(displayUser.phone)
                                    .font(ShineFont.body(14))
                                    .foregroundColor(.shineInk3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(ShineSpacing.xl)
                    .background(Color.shineSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.lg))
                    .shineShadowSM()
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.top, ShineSpacing.lg)

                    // Stats row
                    HStack(spacing: 14) {
                        StatCard(
                            value: userStats.map { "\($0.totalOrders)" } ?? "--",
                            label: Loc.string("profile.orders", isArabic: appState.isArabic),
                            color: .shineCoral
                        )
                        StatCard(
                            value: "4.9",
                            label: Loc.string("profile.rating", isArabic: appState.isArabic),
                            color: .shineAmber
                        )
                        StatCard(
                            value: userStats.map { "QAR \(Int($0.totalSpent))" } ?? "--",
                            label: Loc.string("profile.saved", isArabic: appState.isArabic),
                            color: .shineTeal
                        )
                    }
                    .padding(.horizontal, ShineSpacing.lg)

                    // Settings
                    ProfileSection(
                        title: Loc.string("profile.settings", isArabic: appState.isArabic)
                    ) {
                        VStack(spacing: 0) {
                            ProfileToggleRow(
                                icon: "bell.fill",
                                iconColor: .shineCoral,
                                title: Loc.string("profile.notifications", isArabic: appState.isArabic),
                                isOn: $notificationsOn
                            )
                            Divider().padding(.leading, 52)
                            ProfileToggleRow(
                                icon: "location.fill",
                                iconColor: .shineTeal,
                                title: Loc.string("profile.location", isArabic: appState.isArabic),
                                isOn: $locationOn
                            )
                            Divider().padding(.leading, 52)
                            ProfileLinkRow(
                                icon: "globe",
                                iconColor: .shineAmber,
                                title: Loc.string("profile.language", isArabic: appState.isArabic),
                                value: appState.language.label
                            )
                        }
                    }

                    // Account
                    ProfileSection(
                        title: Loc.string("profile.account", isArabic: appState.isArabic)
                    ) {
                        VStack(spacing: 0) {
                            ProfileLinkRow(icon: "person.fill",        iconColor: .shineLavender, title: Loc.string("profile.edit",      isArabic: appState.isArabic), value: "")
                            Divider().padding(.leading, 52)
                            ProfileLinkRow(icon: "creditcard.fill",    iconColor: .shineCoral,    title: Loc.string("profile.payment",   isArabic: appState.isArabic), value: "")
                            Divider().padding(.leading, 52)
                            ProfileLinkRow(icon: "location.fill",      iconColor: .shineTeal,     title: Loc.string("profile.addresses", isArabic: appState.isArabic), value: "")
                            Divider().padding(.leading, 52)
                            ProfileLinkRow(icon: "questionmark.circle.fill", iconColor: .shineAmber, title: Loc.string("profile.help", isArabic: appState.isArabic),  value: "")
                        }
                    }

                    // Sign out
                    Button {
                        Task { await appState.signOut() }
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
                    .padding(.bottom, ShineSpacing.xl)
                }
            }
        }
        .task {
            userStats = try? await UserAPIService.shared.fetchStats()
        }
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
                .font(ShineFont.displayBold(22))
                .foregroundColor(color)
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

// MARK: - Profile Toggle Row
struct ProfileToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(ShineFont.body(15))
                .foregroundColor(.shineInk)
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.shineCoral)
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }
}

// MARK: - Profile Link Row
struct ProfileLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(ShineFont.body(15))
                .foregroundColor(.shineInk)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk3)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.shineInk3.opacity(0.5))
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }
}
