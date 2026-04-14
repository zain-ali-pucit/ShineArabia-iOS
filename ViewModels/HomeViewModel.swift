import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var selectedService: ServiceCategory? = nil
    @Published var showServiceSheet: Bool           = false
    @Published var selectedPackages: [ServicePackage] = []
    @Published var showBookingConfirmed: Bool          = false
    @Published var showAuthPrompt: Bool                = false
    @Published var pendingPackagesForAuth: [ServicePackage] = []
    @Published var showCustomBundleSheet: Bool         = false
    @Published var isLoading: Bool                  = false
    @Published var errorMsg: String?                = nil

    // Data
    @Published var categories: [APICategory]        = []
    @Published var bundles: [APIBundle]             = []
    @Published var packages: [ServicePackage]       = []
    @Published var popularItems: [PopularItem]      = []

    // Cleaning packages for all three sub-types (home + office + shop)
    @Published var homeCleaningPackages: [ServicePackage]   = []
    @Published var officeCleaningPackages: [ServicePackage] = []
    @Published var shopCleaningPackages: [ServicePackage]   = []
    @Published var isLoadingCleaningSubPackages: Bool       = false

    /// The first active bundle — drives the home promo banner
    var featuredBundle: APIBundle? { bundles.first }

    /// All cleaning packages combined — used to populate the Custom Bundle builder.
    var customBundleComponents: [ServicePackage] {
        homeCleaningPackages + officeCleaningPackages + shopCleaningPackages
    }

    // Loading flags (only true when no cache exists yet)
    @Published var isLoadingCategories: Bool        = false
    @Published var isLoadingPackages: Bool          = false
    @Published var isLoadingPopular: Bool           = false

    private let serviceAPI = ServiceAPIService.shared
    private let cache      = LocalCacheService.shared
    private let disabledCategorySlugs: Set<String> = [
        ServiceCategory.pest.rawValue,
        ServiceCategory.laundry.rawValue,
        ServiceCategory.carWash.rawValue
    ]

    // MARK: - Bundles  (cache-first → background refresh)

    func loadBundles() async {
        if let cached = cache.loadBundles() {
            await MainActor.run { bundles = cached }
        }
        do {
            let fresh   = try await serviceAPI.fetchBundles()
            let changed = cache.updateBundlesIfChanged(fresh)
            if changed || bundles.isEmpty {
                await MainActor.run { bundles = fresh }
            }
        } catch { /* keep cached */ }
    }

    // MARK: - Categories  (cache-first → background refresh)

    func loadCategories() async {
        // 1. Show cached data instantly — no spinner if cache exists
        if let cached = cache.loadCategories() {
            await MainActor.run {
                categories          = sortCategoriesForDisplay(cached)
                isLoadingCategories = false
            }
        } else {
            await MainActor.run { isLoadingCategories = true }
        }

        // 2. Fetch from server; update UI + cache only when something changed
        do {
            let fresh = try await serviceAPI.fetchCategories()
            let changed = cache.updateCategoriesIfChanged(fresh)
            if changed || categories.isEmpty {
                await MainActor.run {
                    categories = sortCategoriesForDisplay(fresh)
                }
            }
        } catch { /* server unreachable — cached data is already shown */ }

        await MainActor.run { isLoadingCategories = false }
    }

    // MARK: - Popular items  (cache-first → background refresh)
    // Driven by most-ordered packages. Empty = section hidden in UI.

    func loadPopular() async {
        // 1. Show cached data instantly
        if let cached = cache.loadPopularItems(), !cached.isEmpty {
            await MainActor.run {
                popularItems = cached.map { PopularItem(from: $0) }
            }
        } else {
            await MainActor.run { isLoadingPopular = true }
        }

        // 2. Fetch fresh from server
        do {
            let fresh   = try await serviceAPI.fetchPopular()
            let changed = cache.updatePopularItemsIfChanged(fresh)
            if changed || popularItems.isEmpty {
                await MainActor.run {
                    popularItems = fresh.map { PopularItem(from: $0) }
                }
            }
        } catch { /* keep cached */ }

        await MainActor.run { isLoadingPopular = false }
    }

    // MARK: - Open service sheet — from backend category card

    func openService(_ apiCategory: APICategory) {
        if apiCategory.slug == ServiceCategory.bundle.rawValue { openCustomBundle(); return }
        guard !disabledCategorySlugs.contains(apiCategory.slug) else { return }
        selectedService  = ServiceCategory(rawValue: apiCategory.slug) ?? .laundry
        selectedPackages = []
        showServiceSheet = true
        loadPackages(slug: apiCategory.slug)
        if apiCategory.slug == ServiceCategory.cleaning.rawValue {
            loadCleaningSubPackages()
        }
    }

    // MARK: - Open service sheet — from popular items or bundle promo

    func openService(_ category: ServiceCategory) {
        if category == .bundle { openCustomBundle(); return }
        guard !disabledCategorySlugs.contains(category.rawValue) else { return }
        selectedService  = category
        selectedPackages = []
        showServiceSheet = true
        loadPackages(slug: category.rawValue)
        if category == .cleaning {
            loadCleaningSubPackages()
        }
    }

    // MARK: - Open custom bundle builder directly

    func openCustomBundle() {
        selectedPackages = []
        showCustomBundleSheet = true
        if customBundleComponents.isEmpty {
            loadCleaningSubPackages()
        }
    }

    // MARK: - Cleaning sub-category packages (cache-first → background refresh)

    private var isCleaningRefreshInFlight = false

    func loadCleaningSubPackages() {
        // 1. Show cached data instantly
        if let cached = cache.loadPackages(slug: ServiceCategory.cleaning.rawValue) {
            homeCleaningPackages = cached.map { ServicePackage(from: $0) }
        }
        if let cached = cache.loadPackages(slug: ServiceCategory.officeClean.rawValue) {
            officeCleaningPackages = cached.map { ServicePackage(from: $0) }
        }
        if let cached = cache.loadPackages(slug: ServiceCategory.shopClean.rawValue) {
            shopCleaningPackages = cached.map { ServicePackage(from: $0) }
        }

        isLoadingCleaningSubPackages = homeCleaningPackages.isEmpty || officeCleaningPackages.isEmpty || shopCleaningPackages.isEmpty

        // 2. Background refresh — skip if a fetch is already in flight
        guard !isCleaningRefreshInFlight else { return }
        isCleaningRefreshInFlight = true

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.refreshSubPackages(slug: ServiceCategory.cleaning.rawValue) }
                group.addTask { await self.refreshSubPackages(slug: ServiceCategory.officeClean.rawValue) }
                group.addTask { await self.refreshSubPackages(slug: ServiceCategory.shopClean.rawValue) }
            }
            await MainActor.run {
                isLoadingCleaningSubPackages  = false
                isCleaningRefreshInFlight     = false
            }
        }
    }

    private func refreshSubPackages(slug: String) async {
        do {
            let fresh   = try await serviceAPI.fetchPackages(for: slug)
            let changed = cache.updatePackagesIfChanged(fresh, slug: slug)
            let mapped  = fresh.map { ServicePackage(from: $0) }
            await MainActor.run {
                if slug == ServiceCategory.cleaning.rawValue {
                    if changed || homeCleaningPackages.isEmpty { homeCleaningPackages = mapped }
                } else if slug == ServiceCategory.officeClean.rawValue {
                    if changed || officeCleaningPackages.isEmpty { officeCleaningPackages = mapped }
                } else if slug == ServiceCategory.shopClean.rawValue {
                    if changed || shopCleaningPackages.isEmpty { shopCleaningPackages = mapped }
                }
            }
        } catch { }
    }

    private func sortCategoriesForDisplay(_ source: [APICategory]) -> [APICategory] {
        let visibleSlugs: [String: Int] = [
            ServiceCategory.cleaning.rawValue:   1,
            ServiceCategory.officeClean.rawValue: 2,
            ServiceCategory.shopClean.rawValue:   3
        ]

        return source
            .filter { visibleSlugs[$0.slug] != nil }
            .sorted { lhs, rhs in
                let lhsRank = visibleSlugs[lhs.slug] ?? 100
                let rhsRank = visibleSlugs[rhs.slug] ?? 100
                return lhsRank < rhsRank
            }
    }

    // MARK: - Packages  (cache-first → background refresh)

    private func loadPackages(slug: String) {
        // 1. Show cached packages instantly — no spinner if cache exists
        if let cached = cache.loadPackages(slug: slug) {
            packages          = cached.map { ServicePackage(from: $0) }
            isLoadingPackages = false
        } else {
            packages          = []
            isLoadingPackages = true
        }

        // 2. Background refresh
        Task {
            do {
                let fresh   = try await serviceAPI.fetchPackages(for: slug)
                let changed = cache.updatePackagesIfChanged(fresh, slug: slug)
                if changed || packages.isEmpty {
                    await MainActor.run {
                        packages = fresh.map { ServicePackage(from: $0) }
                    }
                }
            } catch {
                // If no cache and fetch failed, fall back to sample data
                if packages.isEmpty {
                    let fallback = SampleData.packages[ServiceCategory(rawValue: slug) ?? .laundry] ?? []
                    await MainActor.run { packages = fallback }
                }
            }
            await MainActor.run { isLoadingPackages = false }
        }
    }

    // MARK: - Booking helpers

    func togglePackage(_ pkg: ServicePackage) {
        if let idx = selectedPackages.firstIndex(where: { $0.id == pkg.id }) {
            selectedPackages.remove(at: idx)
        } else {
            selectedPackages.append(pkg)
        }
    }

    func confirmBooking() {
        showServiceSheet     = false
        showBookingConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showBookingConfirmed = false
        }
    }
}
