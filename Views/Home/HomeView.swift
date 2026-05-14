import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var vm: HomeViewModel
    @EnvironmentObject var bookingVM: BookingViewModel

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    HomeHeaderView()

                    // Default home content
                    PromoBannerView(bundle: vm.featuredBundle, isArabic: appState.isArabic) {
                        vm.openCustomBundle()
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.top, ShineSpacing.lg)

                    SectionHeader(
                        title: Loc.string("home.services", isArabic: appState.isArabic),
                        action: Loc.string("home.see_all", isArabic: appState.isArabic)
                    )
                    .padding(.top, ShineSpacing.sm)

                    ServiceCardsRow(categories: vm.categories, isLoading: vm.isLoadingCategories) { category in
                        vm.openService(category)
                    }

                    if vm.isLoadingPopular || !vm.popularItems.isEmpty {
                        SectionHeader(
                            title: Loc.string("home.popular", isArabic: appState.isArabic),
                            action: nil
                        )
                        .padding(.top, ShineSpacing.lg)

                        if vm.isLoadingPopular {
                            VStack(spacing: 14) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: ShineRadius.md)
                                        .fill(Color.shineSurface)
                                        .frame(height: 88)
                                        .shineShadowXS()
                                }
                            }
                            .padding(.horizontal, ShineSpacing.lg)
                        } else {
                            PopularListView(items: vm.popularItems) { item in
                                if let apiId = item.apiId {
                                    vm.openService(item.category, packageId: apiId)
                                } else {
                                    vm.openService(item.category)
                                }
                            }
                            .padding(.horizontal, ShineSpacing.lg)
                        }
                    }

                    SectionHeader(
                        title: Loc.string("home.how_it_works", isArabic: appState.isArabic),
                        action: nil
                    )
                    .padding(.top, ShineSpacing.lg)

                    HowItWorksView()
                        .padding(.horizontal, ShineSpacing.lg)
                }
                .padding(.bottom, 70)
            }

            // Booking confirmed toast
            if vm.showBookingConfirmed {
                VStack {
                    Spacer()
                    BookingConfirmedToast(isArabic: appState.isArabic)
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.5), value: vm.showBookingConfirmed)
            }
        }
        // Service bottom sheet
        .fullScreenCover(isPresented: $vm.showServiceSheet) {
            if let svc = vm.selectedService {
                ServiceBottomSheet(
                    category: svc,
                    packages: vm.packages,
                    customBundleComponents: vm.customBundleComponents,
                    selectedPackages: $vm.selectedPackages,
                    isArabic: appState.isArabic,
                    isLoading: vm.isLoadingPackages,
                    categoryIconEmoji: vm.selectedServiceIconEmoji
                ) {
                    guard !vm.selectedPackages.isEmpty else { return }
                    if appState.isAuthenticated {
                        Task { @MainActor in
                            await bookingVM.createMultiBooking(packages: vm.selectedPackages)
                            if bookingVM.errorMsg == nil {
                                vm.confirmBooking()
                                // Refresh points after successful booking
                                if let stats = try? await UserAPIService.shared.fetchStats() {
                                    await MainActor.run { appState.userPoints = stats.points }
                                }
                            }
                        }
                    } else {
                        vm.pendingPackagesForAuth = vm.selectedPackages
                        vm.showServiceSheet = false
                        vm.showAuthPrompt = true
                    }
                }
                .environmentObject(bookingVM)
            }
        }
        .sheet(isPresented: $vm.showAuthPrompt) {
            LoginView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $vm.showCustomBundleSheet) {
            CustomBundleBuilderView(
                isArabic: appState.isArabic,
                components: vm.customBundleComponents,
                isLoading: vm.isLoadingCleaningSubPackages
            ) { selected in
                vm.showCustomBundleSheet = false
                vm.selectedPackages = selected
                if appState.isAuthenticated {
                    Task { @MainActor in
                        await bookingVM.createMultiBooking(packages: selected, isBundle: true)
                        if bookingVM.errorMsg == nil {
                            vm.confirmBooking()
                        }
                    }
                } else {
                    vm.pendingPackagesForAuth = selected
                    vm.pendingIsBundleForAuth = true
                    vm.showAuthPrompt = true
                }
            }
            .environmentObject(bookingVM)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            guard !vm.pendingPackagesForAuth.isEmpty else { return }
            let pkgs    = vm.pendingPackagesForAuth
            let bundle  = vm.pendingIsBundleForAuth
            vm.showAuthPrompt = false
            vm.pendingPackagesForAuth = []
            vm.pendingIsBundleForAuth = false
            Task { @MainActor in
                await bookingVM.createMultiBooking(packages: pkgs, isBundle: bundle)
                if bookingVM.errorMsg == nil {
                    vm.confirmBooking()
                }
            }
        }
        .task {
            async let cats: ()     = vm.loadCategories()
            async let popular: ()  = vm.loadPopular()
            async let bundles: ()  = vm.loadBundles()
            _ = await (cats, popular, bundles)
            vm.loadCleaningSubPackages()

            if appState.isAuthenticated {
                if let stats = try? await UserAPIService.shared.fetchStats() {
                    await MainActor.run { appState.userPoints = stats.points }
                }
            }
        }
    }
}

// MARK: - Header
struct HomeHeaderView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        if appState.isArabic {
            base = hour < 12 ? "صباح الخير" : (hour < 18 ? "مساء الخير" : "مساء الخير")
        } else {
            base = hour < 12 ? "Good Morning" : (hour < 18 ? "Good Afternoon" : "Good Evening")
        }
        if let name = appState.currentUser?.name, appState.isAuthenticated {
            return "\(base), \(name) 👋"
        }
        return "\(base) 👋"
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Brand
                HStack(alignment: .bottom, spacing: 6) {
                    (Text("Shine")
                        .foregroundColor(.shineInk)
                    + Text("Arabia")
                        .foregroundColor(Color(hex: "800020")))
                        .font(ShineFont.displayBold(26))
                }
                Text(Loc.string("home.subtitle", isArabic: appState.isArabic))
                    .font(ShineFont.body(11, weight: .medium))
                    .foregroundColor(.shineInk3)
                    .kerning(0.5)
                    .textCase(.uppercase)
            }

            Spacer()

            HStack(spacing: 10) {
                LanguageToggle()
                NotificationButton()
            }
        }
        .padding(.horizontal, ShineSpacing.lg)
        .padding(.top, ShineSpacing.lg)

        // Greeting + Hero
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk3)

                (Text(Loc.string("home.hero.body", isArabic: appState.isArabic))
                + Text(Loc.string("home.hero.highlight", isArabic: appState.isArabic))
                    .foregroundColor(.shineCoral))
                    .font(ShineFont.displayBold(34))
                    .foregroundColor(.shineInk)
                    .lineSpacing(4)
            }

            Spacer()

            if appState.isAuthenticated {
                HStack(spacing: 5) {
                    Text("⭐")
                        .font(.system(size: 13))
                    Text("\(appState.userPoints)")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(Color(hex: "B45309"))
                    Text(appState.isArabic ? "نقطة" : "pts")
                        .font(ShineFont.body(11))
                        .foregroundColor(Color(hex: "B45309").opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.shineAmber.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.shineAmber.opacity(0.3), lineWidth: 1))
                .padding(.bottom, 4)
            } else {
                Button { showLogin = true } label: {
                    HStack(spacing: 5) {
                        Text(appState.isArabic ? "تسجيل الدخول" : "Sign In")
                            .font(ShineFont.body(13, weight: .semibold))
                            .foregroundColor(.shineCoral)
                        Image(systemName: appState.isArabic ? "arrow.left" : "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.shineCoral)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.shineCoral.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.shineCoral.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ShineSpacing.lg)
        .padding(.top, ShineSpacing.md)
        .sheet(isPresented: $showLogin) {
            LoginView().environmentObject(appState)
        }
    }
}

// MARK: - Promo Banner (driven by featured bundle from backend)
struct PromoBannerView: View {
    let bundle: APIBundle?
    let isArabic: Bool
    let onTap: () -> Void

    private var title: String {
        isArabic ? "شاين عربيا 360" : "ShineArabia 360"
    }

    private var subtitle: String {
        isArabic ? "تنظيف" : "Clean"
    }

    private var discountText: String {
        guard let pct = bundle?.discountPct, pct > 0 else { return "30%" }
        return "\(pct)%"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: ShineRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1C1917"), Color(hex: "2E2925"), Color(hex: "3D3530")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.shineCoral.opacity(0.25))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                    .offset(x: 80, y: -40)

                Circle()
                    .fill(Color.shineAmber.opacity(0.20))
                    .frame(width: 100, height: 100)
                    .blur(radius: 25)
                    .offset(x: -60, y: 30)

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        // Pill
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                            Text(isArabic ? "عرض محدود" : "Limited Offer")
                                .font(ShineFont.body(11, weight: .semibold))
                                .kerning(0.3)
                                .textCase(.uppercase)
                        }
                        .foregroundColor(Color(hex: "F4A799"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.shineCoral.opacity(0.2))
                        .overlay(Capsule().stroke(Color.shineCoral.opacity(0.35), lineWidth: 1))
                        .clipShape(Capsule())

                        Text(title)
                            .font(ShineFont.displayBold(22))
                            .foregroundColor(.white)
                            .lineSpacing(3)

                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(ShineFont.body(13))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                        }

                        // CTA
                        HStack(spacing: 6) {
                            Text(isArabic ? "احجز الآن" : "Book Bundle")
                                .font(ShineFont.body(14, weight: .semibold))
                            Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.shineCoral)
                        .clipShape(Capsule())
                        .shadow(color: Color.shineCoral.opacity(0.4), radius: 10, x: 0, y: 4)
                        .padding(.top, 6)
                    }

                    Spacer()

                    // Discount sticker — always 30% OFF
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .frame(width: 64, height: 64)
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 0) {
                            Text(discountText)
                                .font(ShineFont.displayBold(22))
                                .foregroundColor(Color(hex: "F4A799"))
                            Text("OFF")
                                .font(ShineFont.body(8, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .kerning(0.5)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .padding(22)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 175)
        .shineShadowMD()
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    @EnvironmentObject var appState: AppState
    let title: String
    let action: String?

    var body: some View {
        HStack(alignment: .bottom) {
            Text(title)
                .font(ShineFont.displayBold(20))
                .foregroundColor(.shineInk)
            Spacer()
            if let action = action {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        appState.selectedTab = .explore
                    }
                } label: {
                    Text(action)
                        .font(ShineFont.body(13, weight: .medium))
                        .foregroundColor(.shineCoral)
                }
            }
        }
        .padding(.horizontal, ShineSpacing.lg)
        .padding(.bottom, ShineSpacing.sm)
    }
}

// MARK: - Service Cards Row (horizontal scroll)
struct ServiceCardsRow: View {
    @EnvironmentObject var appState: AppState
    let categories: [APICategory]
    let isLoading: Bool
    let onTap: (APICategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                if isLoading {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: ShineRadius.lg)
                            .fill(Color.shineSurface)
                            .frame(width: 148, height: 195)
                            .shineShadowSM()
                    }
                } else {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                        ServiceCard(
                            category: cat,
                            isArabic: appState.isArabic,
                            isDisabled: false,
                            animationDelay: Double(index) * 0.07
                        ) {
                            onTap(cat)
                        }
                    }
                }
            }
            .padding(.horizontal, ShineSpacing.lg)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Service Card (148pt wide, matches HTML)
struct ServiceCard: View {
    let category: APICategory
    let isArabic: Bool
    let isDisabled: Bool
    let animationDelay: Double
    let onTap: () -> Void

    @State private var appeared = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                // Background blob
                Circle()
                    .fill(category.color.opacity(0.08))
                    .frame(width: 90, height: 90)
                    .offset(x: 20, y: 20)

                VStack(alignment: .leading, spacing: 0) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(category.softColor)
                            .frame(width: 52, height: 52)
                        Text(category.icon)
                            .font(.system(size: 24))
                    }
                    .padding(.bottom, 14)

                    Text(isArabic ? category.titleAR : category.title)
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk)
                        .lineLimit(2)

                    Text(category.optionsCount)
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk3)
                        .padding(.top, 4)

                    if isDisabled {
                        Text(isArabic ? "قريباً" : "Coming Soon")
                            .font(ShineFont.body(10, weight: .semibold))
                            .foregroundColor(.shineCoral)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.shineCoral.opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Arrow
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(category.softColor)
                            .frame(width: 28, height: 28)
                        Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(category.color)
                    }
                }
                .padding(18)
                .frame(width: 148, height: 195)
                .background(Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.lg))
                .shineShadowSM()
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .opacity(isDisabled ? 0.6 : 1)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay)) {
                appeared = true
            }
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Popular List
struct PopularListView: View {
    @EnvironmentObject var appState: AppState
    let items: [PopularItem]
    let onTap: (PopularItem) -> Void

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                PopularCard(item: item, animationDelay: Double(index) * 0.08) {
                    onTap(item)
                }
            }
        }
    }
}

// MARK: - Popular Card
struct PopularCard: View {
    @EnvironmentObject var appState: AppState
    let item: PopularItem
    let animationDelay: Double
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: ShineRadius.sm)
                        .fill(item.category.softColor)
                        .frame(width: 56, height: 56)
                    Text(item.emoji)
                        .font(.system(size: 26))
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.isArabic ? item.nameAR : item.name)
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                    HStack(spacing: 8) {
                        if item.rating > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.shineAmber)
                                Text(String(format: "%.1f", item.rating))
                                    .font(ShineFont.body(12, weight: .semibold))
                                    .foregroundColor(.shineAmber)
                            }
                        }
                        Text(appState.isArabic ? item.reviewsAR : item.reviews)
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineInk3)
                    }
                }

                Spacer()

                // Price
                Text(item.price)
                    .font(ShineFont.displayBold(20))
                    .foregroundColor(.shineInk)
            }
            .padding(16)
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .shineShadowXS()
            .overlay(alignment: .topTrailing) {
                if let badge = appState.isArabic ? item.badgeAR : item.badge {
                    Text(badge)
                        .font(ShineFont.body(10, weight: .semibold))
                        .foregroundColor(item.badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.badgeColor.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay)) {
                appeared = true
            }
        }
    }
}

// MARK: - How It Works
struct HowItWorksView: View {
    @EnvironmentObject var appState: AppState

    let steps: [(icon: String, titleKey: String, descKey: String)] = [
        ("📱", "hiw.choose.title",   "hiw.choose.desc"),
        ("📅", "hiw.schedule.title", "hiw.schedule.desc"),
        ("🏠", "hiw.arrive.title",   "hiw.arrive.desc"),
        ("⭐", "hiw.enjoy.title",    "hiw.enjoy.desc"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                VStack(spacing: 8) {
                    Text(String(format: "%02d", index + 1))
                        .font(ShineFont.displayBold(36))
                        .foregroundColor(.shineCoral.opacity(0.2))
                        .frame(height: 36)
                    Text(step.icon)
                        .font(.system(size: 22))
                    Text(Loc.string(step.titleKey, isArabic: appState.isArabic))
                        .font(ShineFont.body(12, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(Loc.string(step.descKey, isArabic: appState.isArabic))
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                .shineShadowXS()
            }
        }
    }
}

// MARK: - Booking Confirmed Toast
struct BookingConfirmedToast: View {
    let isArabic: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.shineTeal)
            VStack(alignment: .leading, spacing: 2) {
                Text(isArabic ? "✅ تم تأكيد الحجز!" : "✅ Booking confirmed!")
                    .font(ShineFont.body(14, weight: .semibold))
                    .foregroundColor(.shineInk)
                Text(isArabic ? "سنتواصل معك قريباً." : "We'll be in touch shortly.")
                    .font(ShineFont.body(12))
                    .foregroundColor(.shineInk3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowLG()
    }
}

