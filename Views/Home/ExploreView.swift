import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var vm: HomeViewModel
    @EnvironmentObject var bookingVM: BookingViewModel

    var allServices: [APICategory] {
        vm.categories.filter { $0.slug != "bundle" }
    }

    var filteredServices: [APICategory] {
        let q = vm.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allServices }
        return allServices.filter {
            $0.nameEn.lowercased().contains(q) || $0.nameAr.contains(q)
        }
    }

    var isSearching: Bool {
        !vm.searchText.trimmingCharacters(in: .whitespaces).isEmpty
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

                    // Search
                    SearchBarView(text: $vm.searchText)
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.vertical, ShineSpacing.lg)

                    // Section label
                    Text(isSearching
                         ? (appState.isArabic ? "الفئات المطابقة" : "Matching Categories")
                         : Loc.string("explore.all_services", isArabic: appState.isArabic))
                        .font(ShineFont.body(11, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.md)

                    if filteredServices.isEmpty && isSearching {
                        // No matching categories
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2")
                                .foregroundColor(.shineInk3)
                            Text(appState.isArabic ? "لا توجد فئات مطابقة" : "No matching categories")
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineInk3)
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.md)
                    } else {
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
                                ForEach(filteredServices) { svc in
                                    ExploreServiceTile(category: svc, isArabic: appState.isArabic) {
                                        vm.openService(svc)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.xl)
                    }

                    // Package search results from API
                    if isSearching {
                        SearchResultsSection { category in
                            vm.openService(category)
                        }
                        .padding(.bottom, ShineSpacing.xl)
                    }

                    // Pricing pills — only visible when not searching and popular items are loaded
                    if !isSearching && !vm.popularItems.isEmpty {
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
                    selectedPackage: $vm.selectedPackage,
                    isArabic: appState.isArabic,
                    isLoading: vm.isLoadingPackages
                ) {
                    guard let pkg = vm.selectedPackage else { return }
                    if appState.isAuthenticated {
                        Task { @MainActor in
                            await bookingVM.createBooking(package: pkg)
                            if bookingVM.errorMsg == nil {
                                vm.confirmBooking()
                            }
                        }
                    } else {
                        vm.pendingPackageForAuth = pkg
                        vm.showServiceSheet = false
                        vm.showAuthPrompt = true
                    }
                }
                .environmentObject(bookingVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            guard let pkg = vm.pendingPackageForAuth else { return }
            vm.showAuthPrompt = false
            vm.pendingPackageForAuth = nil
            Task { @MainActor in
                await bookingVM.createBooking(package: pkg)
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
