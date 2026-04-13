import SwiftUI

struct RewardsView: View {
    @EnvironmentObject var appState: AppState

    @State private var bookingTier: RewardTier? = nil
    @State private var userStats: APIUserStats?
    @State private var isLoadingStats = false

    private var points: Int {
        userStats?.points ?? appState.userPoints
    }
    private var isArabic: Bool { appState.isArabic }

    private var currentTier: RewardTier? {
        rewardTiers.filter { points >= $0.points }.last
    }
    private var nextTier: RewardTier? {
        rewardTiers.first { points < $0.points }
    }
    private var progressToNextTier: Double {
        guard let next = nextTier else { return 1.0 }
        let prev = rewardTiers.filter { $0.points <= points }.last?.points ?? 0
        let range = Double(next.points - prev)
        let current = Double(points - prev)
        return min(max(current / range, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    pointsHeader
                    VStack(spacing: ShineSpacing.lg) {
                        progressCard
                        servicesSection
                        howToEarnSection
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.top, ShineSpacing.lg)
                    .padding(.bottom, 110)
                }
            }
        }
        .task { await loadStats() }
        .sheet(item: $bookingTier) { tier in
            RewardBookingSheet(tier: tier, isArabic: isArabic)
                .environmentObject(appState)
        }
    }

    // MARK: - Points Header

    private var pointsHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1C1917"), Color(hex: "3D2C1E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.shineAmber.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 55)
                .offset(x: 110, y: -30)

            Circle()
                .fill(Color.shineCoral.opacity(0.14))
                .frame(width: 160, height: 160)
                .blur(radius: 45)
                .offset(x: -90, y: 30)

            VStack(spacing: 10) {
                Text(isArabic ? "مكافآتي" : "My Rewards")
                    .font(ShineFont.body(12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(1.2)
                    .textCase(.uppercase)
                    .padding(.top, 60)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isLoadingStats ? "…" : "\(points)")
                        .font(ShineFont.displayBold(68))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: points)
                    Text(isArabic ? "نقطة" : "pts")
                        .font(ShineFont.body(20, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 8)
                }

                if let tier = currentTier {
                    HStack(spacing: 6) {
                        Text(tier.icon).font(.system(size: 13))
                        Text(isArabic ? tier.rewardAR : tier.reward)
                            .font(ShineFont.body(12, weight: .semibold))
                            .foregroundColor(Color(hex: "1C1917"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color(hex: "F4C97A"))
                    .clipShape(Capsule())
                } else {
                    Text(isArabic ? "اجمع ٥٠ نقطة لأول مكافأة" : "Earn 50 pts to unlock your first reward")
                        .font(ShineFont.body(12))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 240)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 14) {
            if let next = nextTier {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isArabic ? "المكافأة التالية" : "NEXT REWARD")
                            .font(ShineFont.body(10, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .kerning(0.6)
                        HStack(spacing: 6) {
                            Text(next.icon).font(.system(size: 16))
                            Text(isArabic ? next.rewardAR : next.reward)
                                .font(ShineFont.body(15, weight: .semibold))
                                .foregroundColor(.shineInk)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(isArabic ? "متبقي" : "NEEDED")
                            .font(ShineFont.body(10, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .kerning(0.6)
                        Text(isArabic ? "\(next.points - points) نقطة" : "\(next.points - points) pts")
                            .font(ShineFont.displayBold(20))
                            .foregroundColor(.shineAmber)
                    }
                }

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.shineBorder).frame(height: 8)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "F4C97A"), Color.shineAmber],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, geo.size.width * progressToNextTier), height: 8)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progressToNextTier)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(points) \(isArabic ? "نقطة" : "pts")")
                            .font(ShineFont.body(11)).foregroundColor(.shineInk3)
                        Spacer()
                        Text("\(next.points) \(isArabic ? "نقطة" : "pts")")
                            .font(ShineFont.body(11)).foregroundColor(.shineInk3)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Text("🎉").font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isArabic ? "وصلت أعلى مستوى!" : "Maximum tier reached!")
                            .font(ShineFont.body(15, weight: .semibold)).foregroundColor(.shineInk)
                        Text(isArabic ? "جميع المكافآت متاحة للاستبدال" : "All rewards are available to redeem")
                            .font(ShineFont.body(13)).foregroundColor(.shineInk3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(ShineSpacing.md)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowXS()
    }

    // MARK: - Services Section

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: ShineSpacing.sm) {
            Text(isArabic ? "الخدمات المتاحة" : "AVAILABLE SERVICES")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)

            VStack(spacing: 10) {
                ForEach(rewardTiers) { tier in
                    let unlocked = points >= tier.points
                    RewardServiceCard(
                        tier: tier,
                        unlocked: unlocked,
                        isCurrent: currentTier?.points == tier.points,
                        isArabic: isArabic
                    ) {
                        bookingTier = tier
                    }
                }
            }
        }
    }

    // MARK: - How to Earn Section

    private var howToEarnSection: some View {
        VStack(alignment: .leading, spacing: ShineSpacing.sm) {
            Text(isArabic ? "كيف تجمع النقاط" : "HOW TO EARN POINTS")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)

            VStack(spacing: 0) {
                EarnRow(icon: "checkmark.circle.fill", color: .shineTeal,
                        title: isArabic ? "أكمل طلبًا" : "Complete an order",
                        value: isArabic ? "+١٠ نقاط" : "+10 pts")
                Divider().padding(.leading, 52)
                EarnRow(icon: "star.fill", color: .shineAmber,
                        title: isArabic ? "اترك تقييمًا" : "Leave a review",
                        value: isArabic ? "+٥ نقاط" : "+5 pts")
                Divider().padding(.leading, 52)
                EarnRow(
                    icon: "person.2.fill",
                    color: .shineLavender,
                    title: isArabic ? "ادعُ صديقًا" : "Refer a friend",
                    value: isArabic ? "+٢٥ نقطة" : "+25 pts",
                    destination: APIConfig.shineArabiaReferFriendURL,
                    isArabic: isArabic
                )
            }
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .shineShadowXS()
        }
    }

    // MARK: - Load Stats

    private func loadStats() async {
        await MainActor.run { isLoadingStats = true }
        let stats = try? await UserAPIService.shared.fetchStats()
        await MainActor.run {
            userStats = stats
            isLoadingStats = false
            if let pts = stats?.points { appState.userPoints = pts }
        }
    }
}

// MARK: - Reward Service Card

private struct RewardServiceCard: View {
    let tier: RewardTier
    let unlocked: Bool
    let isCurrent: Bool
    let isArabic: Bool
    let onBook: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(unlocked
                          ? Color.shineAmber.opacity(0.13)
                          : Color.shineInk3.opacity(0.06))
                    .frame(width: 56, height: 56)
                Text(tier.icon)
                    .font(.system(size: 26))
                    .opacity(unlocked ? 1 : 0.3)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isArabic ? tier.rewardAR : tier.reward)
                        .font(ShineFont.body(15, weight: unlocked ? .semibold : .regular))
                        .foregroundColor(unlocked ? .shineInk : .shineInk3)
                    if unlocked {
                        Text(isArabic ? "مفعّل" : "Active")
                            .font(ShineFont.body(9, weight: .bold))
                            .foregroundColor(Color(hex: "1C1917"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "F4C97A"))
                            .clipShape(Capsule())
                    }
                }
                Text(isArabic ? tier.detailAR : tier.detail)
                    .font(ShineFont.body(12))
                    .foregroundColor(unlocked ? .shineInk2 : .shineInk3.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: unlocked ? "star.fill" : "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(unlocked ? .shineAmber : .shineInk3.opacity(0.4))
                    Text(unlocked
                         ? (isArabic ? "مكتسب" : "Unlocked")
                         : (isArabic ? "يحتاج \(tier.points) نقطة" : "\(tier.points) pts required"))
                        .font(ShineFont.body(11, weight: .medium))
                        .foregroundColor(unlocked ? .shineAmber : .shineInk3.opacity(0.5))
                }
            }

            Spacer(minLength: 6)

            // Action
            if unlocked {
                Button(action: onBook) {
                    Text(isArabic ? "احجز" : "Book")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 68, height: 36)
                        .background(Color.shineCoral)
                        .clipShape(Capsule())
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.shineInk3.opacity(0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.shineInk3.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 12)
        .background(
            isCurrent
                ? Color.shineAmber.opacity(0.05)
                : Color.shineSurface
        )
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShineRadius.md)
                .strokeBorder(
                    isCurrent ? Color.shineAmber.opacity(0.35) : Color.shineBorder.opacity(0.6),
                    lineWidth: isCurrent ? 1.5 : 0.5
                )
        )
        .shineShadowXS()
        .opacity(unlocked ? 1 : 0.72)
    }
}

// MARK: - Earn Row

private struct EarnRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var destination: URL? = nil
    var isArabic: Bool = false

    private var rowContent: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            Text(title)
                .font(ShineFont.body(14))
                .foregroundColor(.shineInk)
            Spacer()
            Text(value)
                .font(ShineFont.body(13, weight: .semibold))
                .foregroundColor(.shineAmber)
            if destination != nil {
                Image(systemName: isArabic ? "arrow.left" : "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.shineInk3)
            }
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }

    var body: some View {
        if let url = destination {
            Link(destination: url) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }
}

// MARK: - Reward Booking Sheet

struct RewardBookingSheet: View {
    let tier: RewardTier
    let isArabic: Bool

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared

    @State private var address: String = ""
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var note: String = ""
    @State private var isSubmitting = false
    @State private var isConfirmed = false

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            if isConfirmed {
                confirmedView
            } else {
                bookingForm
            }
        }
    }

    // MARK: Booking Form

    private var bookingForm: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.shineBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, ShineSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(spacing: ShineSpacing.lg) {

                    // Service preview card
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.shineAmber.opacity(0.12))
                                .frame(width: 64, height: 64)
                            Text(tier.icon).font(.system(size: 30))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isArabic ? tier.rewardAR : tier.reward)
                                .font(ShineFont.displayBold(20))
                                .foregroundColor(.shineInk)
                            Text(isArabic ? tier.detailAR : tier.detail)
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineInk3)
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.shineAmber)
                                Text(isArabic ? "مكافأة مجانية · \(tier.points) نقطة" : "Free reward · \(tier.points) pts")
                                    .font(ShineFont.body(11, weight: .medium))
                                    .foregroundColor(.shineAmber)
                            }
                        }
                        Spacer()
                    }
                    .padding(ShineSpacing.md)
                    .background(Color.shineSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                    .shineShadowXS()

                    // Address field
                    AddressInputSection(
                        isArabic: isArabic,
                        address: $address,
                        latitude: $latitude,
                        longitude: $longitude,
                        locationService: locationService
                    )
                    .environmentObject(appState)

                    // Note field
                    VStack(alignment: .leading, spacing: ShineSpacing.sm) {
                        Text(isArabic ? "ملاحظات (اختياري)" : "NOTES (OPTIONAL)")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .kerning(0.8)

                        TextField(
                            isArabic ? "أي تعليمات خاصة..." : "Any special instructions...",
                            text: $note,
                            axis: .vertical
                        )
                        .font(ShineFont.body(14))
                        .foregroundColor(.shineInk)
                        .lineLimit(3, reservesSpace: true)
                        .padding(ShineSpacing.md)
                        .background(Color.shineSurface)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: ShineRadius.sm)
                                .strokeBorder(Color.shineBorder, lineWidth: 1)
                        )
                    }

                    // Points deduction notice
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.shineAmber)
                        Text(isArabic
                             ? "سيتم خصم \(tier.points) نقطة من رصيدك عند تأكيد الحجز"
                             : "\(tier.points) pts will be deducted from your balance on confirmation")
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineInk2)
                    }
                    .padding(12)
                    .background(Color.shineAmberLight)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.xl)
            }

            // Confirm button
            Button {
                confirmBooking()
            } label: {
                ZStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isArabic ? "تأكيد الحجز" : "Confirm Booking")
                            .font(ShineFont.body(16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(address.trimmingCharacters(in: .whitespaces).isEmpty
                             ? Color.shineInk3.opacity(0.3)
                             : Color.shineCoral)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            }
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
            .padding(.horizontal, ShineSpacing.lg)
            .padding(.bottom, ShineSpacing.xl)
        }
    }

    // MARK: Confirmed View

    private var confirmedView: some View {
        VStack(spacing: ShineSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.shineTeal.opacity(0.1))
                    .frame(width: 110, height: 110)
                Text("✅")
                    .font(.system(size: 52))
            }

            VStack(spacing: 8) {
                Text(isArabic ? "تم الحجز بنجاح!" : "Booking Confirmed!")
                    .font(ShineFont.displayBold(28))
                    .foregroundColor(.shineInk)
                Text(isArabic
                     ? "سنتواصل معك قريبًا لتحديد الموعد المناسب"
                     : "We'll contact you shortly to schedule your appointment")
                    .font(ShineFont.body(14))
                    .foregroundColor(.shineInk3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 6) {
                Text(tier.icon).font(.system(size: 14))
                Text(isArabic ? tier.rewardAR : tier.reward)
                    .font(ShineFont.body(13, weight: .semibold))
                    .foregroundColor(Color(hex: "1C1917"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "F4C97A"))
            .clipShape(Capsule())

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(isArabic ? "إغلاق" : "Done")
                    .font(ShineFont.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.shineCoral)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            }
            .padding(.horizontal, ShineSpacing.lg)
            .padding(.bottom, ShineSpacing.xl)
        }
    }

    private func confirmBooking() {
        isSubmitting = true
        Task {
            do {
                let remaining = try await UserAPIService.shared.redeemReward(
                    points: tier.points,
                    rewardName: tier.reward,
                    address: address,
                    notes: note.isEmpty ? nil : note
                )
                await MainActor.run {
                    isSubmitting = false
                    withAnimation(.spring(response: 0.4)) {
                        isConfirmed = true
                        appState.userPoints = remaining
                    }
                }
            } catch {
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}
