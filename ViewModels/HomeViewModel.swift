import SwiftUI

class HomeViewModel: ObservableObject {
    @Published var selectedService: ServiceCategory? = nil
    @Published var showServiceSheet: Bool           = false
    @Published var selectedPackages: [ServicePackage] = []
    @Published var showBookingConfirmed: Bool          = false
    @Published var showAuthPrompt: Bool                = false
    @Published var pendingPackagesForAuth: [ServicePackage] = []
    @Published var isLoading: Bool                  = false
    @Published var errorMsg: String?                = nil

    // Data
    @Published var categories: [APICategory]        = []
    @Published var bundles: [APIBundle]             = []
    @Published var packages: [ServicePackage]       = []
    @Published var popularItems: [PopularItem]      = []

    /// The first active bundle — drives the home promo banner
    var featuredBundle: APIBundle? { bundles.first }

    // Loading flags (only true when no cache exists yet)
    @Published var isLoadingCategories: Bool        = false
    @Published var isLoadingPackages: Bool          = false
    @Published var isLoadingPopular: Bool           = false

    private let serviceAPI = ServiceAPIService.shared
    private let cache      = LocalCacheService.shared

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
                categories          = cached.filter { $0.slug != "bundle" }.sorted { $0.sortOrder < $1.sortOrder }
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
                    categories = fresh.filter { $0.slug != "bundle" }.sorted { $0.sortOrder < $1.sortOrder }
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
        selectedService  = ServiceCategory(rawValue: apiCategory.slug) ?? .laundry
        selectedPackages = []
        showServiceSheet = true
        loadPackages(slug: apiCategory.slug)
    }

    // MARK: - Open service sheet — from popular items or bundle promo

    func openService(_ category: ServiceCategory) {
        selectedService  = category
        selectedPackages = []
        showServiceSheet = true
        loadPackages(slug: category.rawValue)
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
