import SwiftUI

// MARK: - Tab Frame Preference Key
struct TabFrameKey: PreferenceKey {
    static var defaultValue: [TabItem: CGRect] = [:]
    static func reduce(value: inout [TabItem: CGRect], nextValue: () -> [TabItem: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Tour Step Model
private struct TourStep {
    let tab: TabItem?
    let title: String
    let titleAR: String
    let message: String
    let messageAR: String
    let icon: String
}

// MARK: - App Tour View
struct AppTourView: View {
    @EnvironmentObject var appState: AppState
    let tabFrames: [TabItem: CGRect]
    let onFinish: () -> Void

    @State private var step = 0
    @State private var appeared = false

    private let steps: [TourStep] = [
        TourStep(
            tab: nil,
            title: "Welcome to ShineArabia",  titleAR: "مرحباً بك في شاين",
            message: "Let's take a quick tour of the app.", messageAR: "دعنا نأخذك في جولة سريعة.",
            icon: "✨"
        ),
        TourStep(
            tab: .home,
            title: "Home",                    titleAR: "الرئيسية",
            message: "Browse featured services, promos, and popular picks.", messageAR: "استعرض الخدمات المميزة والعروض والأكثر طلباً.",
            icon: "🏠"
        ),
        TourStep(
            tab: .explore,
            title: "Services",               titleAR: "الخدمات",
            message: "Explore and book laundry, cleaning, car wash & more.", messageAR: "استكشف وأحجز خدمات الغسيل والتنظيف وغسيل السيارة.",
            icon: "⚡️"
        ),
        TourStep(
            tab: .orders,
            title: "Orders",                 titleAR: "طلباتي",
            message: "Track and manage all your bookings in one place.", messageAR: "تتبع وأدر جميع حجوزاتك في مكان واحد.",
            icon: "📋"
        ),
        TourStep(
            tab: .rewards,
            title: "Rewards",               titleAR: "مكافآتي",
            message: "Earn points with every booking and redeem for rewards.", messageAR: "اكسب نقاطاً مع كل حجز واستبدلها بمكافآت.",
            icon: "⭐️"
        ),
        TourStep(
            tab: .profile,
            title: "Profile",               titleAR: "حسابي",
            message: "Manage your account, addresses and preferences.", messageAR: "أدر حسابك وعناوينك وتفضيلاتك.",
            icon: "👤"
        ),
    ]

    private var current: TourStep { steps[step] }
    private var isLast: Bool      { step == steps.count - 1 }
    private var isArabic: Bool    { appState.isArabic }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Dimmed background with spotlight cutout
                dimLayer
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.35), value: step)
                    .onTapGesture { advance() }

                // Tooltip card
                if appeared {
                    tourCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, cardBottom(geo: geo))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Dim + Spotlight

    @ViewBuilder
    private var dimLayer: some View {
        if let frame = spotlightFrame {
            Color.black.opacity(0.68)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .frame(width: frame.width + 18, height: frame.height + 14)
                        .position(x: frame.midX, y: frame.midY)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        } else {
            Color.black.opacity(0.68)
        }
    }

    private var spotlightFrame: CGRect? {
        guard let tab = current.tab else { return nil }
        return tabFrames[tab]
    }

    // MARK: - Card

    private var tourCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Icon + text
            HStack(alignment: .top, spacing: 14) {
                Text(current.icon)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(Color.shineCoral.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    Text(isArabic ? current.titleAR : current.title)
                        .font(ShineFont.body(17, weight: .bold))
                        .foregroundStyle(Color.shineInk)

                    Text(isArabic ? current.messageAR : current.message)
                        .font(ShineFont.body(14))
                        .foregroundStyle(Color.shineInk2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dots + buttons
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.shineCoral : Color.shineInk3.opacity(0.25))
                            .frame(width: i == step ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.35), value: step)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    if !isLast {
                        Button(isArabic ? "تخطي" : "Skip", action: onFinish)
                            .font(ShineFont.body(14, weight: .medium))
                            .foregroundStyle(Color.shineInk3)
                    }

                    Button(action: advance) {
                        Text(isLast
                             ? (isArabic ? "ابدأ" : "Done")
                             : (isArabic ? "التالي" : "Next"))
                            .font(ShineFont.body(14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(Color.shineCoral)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(20)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.lg))
        .shadow(color: .shineInk.opacity(0.14), radius: 28, x: 0, y: 10)
    }

    // MARK: - Helpers

    private func cardBottom(geo: GeometryProxy) -> CGFloat {
        // Position card above the floating tab bar (~96pt tall + 24pt bottom padding)
        geo.safeAreaInsets.bottom + 96 + 24 + 12
    }

    private func advance() {
        if isLast {
            onFinish()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                step += 1
            }
        }
    }
}
