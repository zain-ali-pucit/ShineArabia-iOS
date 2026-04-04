import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var searchText: String          = ""
    @Published var selectedService: ServiceCategory? = nil
    @Published var showServiceSheet: Bool      = false
    @Published var selectedPackage: ServicePackage? = nil
    @Published var showBookingConfirmed: Bool  = false
    @Published var showAuthPrompt: Bool        = false
    @Published var pendingPackageForAuth: ServicePackage? = nil
    @Published var isLoading: Bool             = false
    @Published var errorMsg: String?           = nil

    // API-backed data
    @Published var packages: [ServicePackage]  = []
    @Published var popularItems: [PopularItem] = SampleData.popularItems
    @Published var searchResults: [ServicePackage] = []
    @Published var isSearching: Bool           = false

    let services: [ServiceCategory] = [.laundry, .cleaning, .carWash, .pest]

    private let serviceAPI = ServiceAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Auto-trigger search with 300ms debounce whenever searchText changes
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

    // MARK: Load popular items from API
    func loadPopular() async {
        do {
            let items = try await serviceAPI.fetchPopular()
            await MainActor.run {
                popularItems = items.map { PopularItem(from: $0) }
            }
        } catch {
            // Keep sample data on failure — silent fallback
        }
    }

    // MARK: Open service sheet and load packages
    func openService(_ category: ServiceCategory) {
        selectedService  = category
        selectedPackage  = nil
        packages         = SampleData.packages[category] ?? []  // show instantly
        showServiceSheet = true

        // Load from API in background
        Task {
            do {
                let apiPackages = try await serviceAPI.fetchPackages(for: category.rawValue)
                await MainActor.run {
                    if !apiPackages.isEmpty {
                        packages = apiPackages.map { ServicePackage(from: $0) }
                    }
                }
            } catch {
                // Keep sample data on failure
            }
        }
    }

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
