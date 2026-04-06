import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var searchText: String               = ""
    @Published var selectedService: ServiceCategory? = nil
    @Published var showServiceSheet: Bool           = false
    @Published var selectedPackage: ServicePackage? = nil
    @Published var showBookingConfirmed: Bool       = false
    @Published var showAuthPrompt: Bool             = false
    @Published var pendingPackageForAuth: ServicePackage? = nil
    @Published var isLoading: Bool                  = false
    @Published var errorMsg: String?                = nil

    // Data
    @Published var categories: [APICategory]        = []
    @Published var packages: [ServicePackage]       = []
    @Published var popularItems: [PopularItem]      = SampleData.popularItems
    @Published var searchResults: [ServicePackage]  = []

    // Loading flags (only true when no cache exists yet)
    @Published var isSearching: Bool                = false
    @Published var isLoadingCategories: Bool        = false
    @Published var isLoadingPackages: Bool          = false

    private let serviceAPI = ServiceAPIService.shared
    private let cache      = LocalCacheService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupSearch()
    }

    // MARK: - Search (debounced)

    private func setupSearch() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    self.searchResults = []
                    self.isSearching   = false
                    return
                }
                self.isSearching = true
                Task {
                    do {
                        let results = try await self.serviceAPI.search(trimmed)
                        await MainActor.run {
                            self.searchResults = results.map { ServicePackage(from: $0) }
                            self.isSearching   = false
                        }
                    } catch {
                        await MainActor.run { self.isSearching = false }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Categories  (cache-first → background refresh)

    func loadCategories() async {
        // 1. Show cached data instantly — no spinner if cache exists
        if let cached = cache.loadCategories() {
            await MainActor.run {
                categories          = cached.sorted { $0.sortOrder < $1.sortOrder }
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
                    categories = fresh.sorted { $0.sortOrder < $1.sortOrder }
                }
            }
        } catch { /* server unreachable — cached data is already shown */ }

        await MainActor.run { isLoadingCategories = false }
    }

    // MARK: - Popular items  (cache-first → background refresh)

    func loadPopular() async {
        // 1. Load from cache
        if let cached = cache.loadPopularItems() {
            await MainActor.run {
                popularItems = cached.map { PopularItem(from: $0) }
            }
        }

        // 2. Background refresh
        do {
            let fresh   = try await serviceAPI.fetchPopular()
            let changed = cache.updatePopularItemsIfChanged(fresh)
            if changed || popularItems.isEmpty {
                await MainActor.run {
                    popularItems = fresh.map { PopularItem(from: $0) }
                }
            }
        } catch { /* keep cached */ }
    }

    // MARK: - Open service sheet — from backend category card

    func openService(_ apiCategory: APICategory) {
        selectedService  = ServiceCategory(rawValue: apiCategory.slug) ?? .laundry
        selectedPackage  = nil
        showServiceSheet = true
        loadPackages(slug: apiCategory.slug)
    }

    // MARK: - Open service sheet — from popular items, search results, or bundle promo

    func openService(_ category: ServiceCategory) {
        selectedService  = category
        selectedPackage  = nil
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

    func selectPackage(_ pkg: ServicePackage) {
        selectedPackage = pkg
    }

    func confirmBooking() {
        showServiceSheet     = false
        showBookingConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showBookingConfirmed = false
        }
    }
}
