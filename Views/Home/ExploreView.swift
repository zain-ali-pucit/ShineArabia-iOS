import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var vm: HomeViewModel
    @EnvironmentObject var bookingVM: BookingViewModel

    var allServices: [APICategory] {
        vm.categories.filter { $0.slug != "bundle" }
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text(Loc.string("explore.title", isArabic: appState.isArabic))
                        .font(ShineFont.displayBold(28))
                        .foregroundColor(.shineInk)
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.top, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.lg)

                    // Section label
                    Text(Loc.string("explore.all_services", isArabic: appState.isArabic))
                        .font(ShineFont.body(11, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.md)

                    // Service grid
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 14
                    ) {
                        if vm.isLoadingCategories {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: ShineRadius.md)
                                    .fill(Color.shineSurface)
                                    .frame(height: 140)
                                    .shineShadowSM()
                            }
                        } else {
                            ForEach(allServices) { svc in
                                ExploreServiceTile(category: svc, isArabic: appState.isArabic) {
                                    vm.openService(svc)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.bottom, ShineSpacing.xl)

                    // Pricing pills
                    if !vm.popularItems.isEmpty {
                        Text(Loc.string("explore.quick_pricing", isArabic: appState.isArabic))
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .padding(.horizontal, ShineSpacing.lg)
                            .padding(.bottom, ShineSpacing.md)

                        PricingPillsRow(items: vm.popularItems) { category in
                            vm.openService(category)
                        }
                        .padding(.bottom, ShineSpacing.xl)
                    }
                }
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
        .sheet(isPresented: $vm.showServiceSheet) {
            if let svc = vm.selectedService {
                ServiceBottomSheet(
                    category: svc,
                    packages: vm.packages,
                    selectedPackages: $vm.selectedPackages,
                    isArabic: appState.isArabic,
                    isLoading: vm.isLoadingPackages
                ) {
                    guard !vm.selectedPackages.isEmpty else { return }
                    if appState.isAuthenticated {
                        Task { @MainActor in
                            await bookingVM.createMultiBooking(packages: vm.selectedPackages)
                            if bookingVM.errorMsg == nil {
                                vm.confirmBooking()
                            }
                        }
                    } else {
                        vm.pendingPackagesForAuth = vm.selectedPackages
                        vm.showServiceSheet = false
                        vm.showAuthPrompt = true
                    }
                }
                .environmentObject(bookingVM)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
            }
        }
        // Auth prompt sheet (shown when unauthenticated user tries to book)
        .sheet(isPresented: $vm.showAuthPrompt) {
            LoginView()
                .environmentObject(appState)
        }
        // After login, resume the pending booking
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
            guard !vm.pendingPackagesForAuth.isEmpty else { return }
            let pkgs = vm.pendingPackagesForAuth
            vm.showAuthPrompt = false
            vm.pendingPackagesForAuth = []
            Task { @MainActor in
                await bookingVM.createMultiBooking(packages: pkgs)
                if bookingVM.errorMsg == nil {
                    vm.confirmBooking()
                }
            }
        }
    }
}

// MARK: - Explore Service Tile
struct ExploreServiceTile: View {
    let category: APICategory
    let isArabic: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(category.softColor)
                        .frame(width: 56, height: 56)
                    Text(category.icon).font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(isArabic ? category.titleAR : category.title)
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(category.optionsCount)
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk3)
                }
                HStack {
                    Text(Loc.string("explore.book", isArabic: isArabic))
                        .font(ShineFont.body(12, weight: .semibold))
                        .foregroundColor(category.color)
                    Spacer()
                    Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(category.color)
                }
            }
            .padding(16)
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .shineShadowSM()
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Pricing Pills (driven by popular items from backend)
struct PricingPillsRow: View {
    @EnvironmentObject var appState: AppState
    @State private var selected = 0

    let items: [PopularItem]
    let onSelect: (ServiceCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(items.prefix(5).enumerated()), id: \.offset) { i, item in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selected = i }
                        onSelect(item.category)
                    } label: {
                        HStack(spacing: 8) {
                            Text(item.emoji).font(.system(size: 15))
                            Text(appState.isArabic ? item.nameAR : item.name)
                                .font(ShineFont.body(13, weight: .medium))
                                .foregroundColor(selected == i ? .white : .shineInk)
                            Text(item.price)
                                .font(ShineFont.body(13, weight: .semibold))
                                .foregroundColor(selected == i ? .white.opacity(0.8) : .shineCoral)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selected == i ? Color.shineInk : Color.shineSurface)
                        .clipShape(Capsule())
                        .shineShadowXS()
                        .overlay(
                            Capsule().stroke(
                                selected == i ? Color.clear : Color.shineBorder,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ShineSpacing.lg)
        }
    }
}
