import Foundation
import UIKit
import UserNotifications

@MainActor
class ManagerViewModel: ObservableObject {

    // MARK: - Published state
    @Published var bookings: [AdminBooking]     = []
    @Published var isLoading                    = false
    @Published var errorMessage: String?        = nil
    @Published var selectedFilter: String?      = nil   // nil = All
    @Published var hasNewBooking                = false // drives notification bell badge

    // MARK: - Bundle management
    @Published var bundles: [APIBundle]                = []
    @Published var availablePackages: [AdminPackageItem] = []  // non-bundle packages for picker
    @Published var isBundleLoading                     = false
    @Published var bundleError: String?                = nil
    @Published var showBundleEditor                    = false
    @Published var editingBundle: APIBundle?           = nil    // nil = creating new
    @Published var selectedComponentIds: Set<String>   = []

    // MARK: - Private
    private var pollingTask: Task<Void, Never>?
    private var lastKnownCount = -1  // -1 means first load (don't notify on first fetch)
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Filter options (nil = All)
    let filters: [(label: String, value: String?)] = [
        ("All",         nil),
        ("Pending",     "pending"),
        ("Confirmed",   "confirmed"),
        ("In Progress", "in_progress"),
        ("Completed",   "completed"),
        ("Cancelled",   "cancelled"),
    ]

    // MARK: - Filtered view
    var filteredBookings: [AdminBooking] {
        guard let filter = selectedFilter else { return bookings }
        return bookings.filter { $0.status == filter }
    }

    // MARK: - Fetch
    func fetchBookings() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await ManagerAPIService.shared.fetchAllBookings()
            bookings = fetched

            // Fire a local notification when new bookings arrive (after first load)
            if lastKnownCount >= 0 && fetched.count > lastKnownCount {
                let newCount = fetched.count - lastKnownCount
                hasNewBooking = true
                scheduleLocalNotification(newBookingCount: newCount)
            }
            lastKnownCount = fetched.count
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Reschedule
    func rescheduleBooking(bookingId: String, date: Date) async {
        do {
            try await ManagerAPIService.shared.rescheduleBooking(id: bookingId, scheduledDate: date)
            await fetchBookings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update Status
    func updateStatus(bookingId: String, newStatus: Booking.BookingStatus) async {
        do {
            try await ManagerAPIService.shared.updateBookingStatus(id: bookingId, status: newStatus.rawValue)
            // Refresh the list immediately after the update
            await fetchBookings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Polling (30 s interval while screen is visible)
    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 s
                if Task.isCancelled { break }
                await fetchBookings()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
    }

    // MARK: - Push notification permission
    func requestNotificationPermission() {
        // Guard against duplicate observer registration on re-appear
        guard notificationObservers.isEmpty else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
            // If an FCM token already arrived (stored before permission was granted), register it now
            if let token = UserDefaults.standard.string(forKey: "fcm_token") {
                Task {
                    try? await ManagerAPIService.shared.registerDeviceToken(token)
                }
            }
        }

        // Listen for FCM token refreshes while this view is active
        let fcmObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? String else { return }
            Task {
                try? await ManagerAPIService.shared.registerDeviceToken(token)
            }
        }

        // Refresh booking list when a push notification arrives (new booking, status change, etc.)
        let pushObserver = NotificationCenter.default.addObserver(
            forName: .pushNotificationReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchBookings()
            }
        }

        notificationObservers = [fcmObserver, pushObserver]
    }

    // MARK: - Bundle CRUD

    func loadBundles() async {
        isBundleLoading = true
        bundleError = nil
        do {
            bundles = try await ManagerAPIService.shared.fetchBundles()
        } catch {
            bundleError = error.localizedDescription
        }
        isBundleLoading = false
    }

    func loadAvailablePackages() async {
        do {
            availablePackages = try await ManagerAPIService.shared.fetchNonBundlePackages()
        } catch {}
    }

    /// Open the editor for an existing bundle
    func startEditing(_ bundle: APIBundle) {
        editingBundle        = bundle
        selectedComponentIds = Set(bundle.components.map { $0.id })
        showBundleEditor     = true
    }

    /// Open the editor to configure components for a new bundle package
    func startCreating(_ bundlePackage: APIBundle) {
        editingBundle        = bundlePackage
        selectedComponentIds = []
        showBundleEditor     = true
    }

    func toggleComponent(_ id: String) {
        if selectedComponentIds.contains(id) {
            selectedComponentIds.remove(id)
        } else {
            selectedComponentIds.insert(id)
        }
    }

    /// Auto-calculated discount for the current selection
    func calculatedDiscount(bundlePrice: Double) -> Int {
        let total = availablePackages
            .filter { selectedComponentIds.contains($0.id) }
            .reduce(0.0) { $0 + $1.priceAmount }
        guard total > 0 else { return 0 }
        return max(0, Int(((total - bundlePrice) / total * 100).rounded()))
    }

    func saveBundle(bundlePackageId: String, priceAmount: Double?, priceDisplay: String?) async {
        guard !selectedComponentIds.isEmpty else {
            bundleError = "Select at least one component package."
            return
        }
        isBundleLoading = true
        bundleError = nil
        do {
            let ids = Array(selectedComponentIds)
            if editingBundle?.components.isEmpty == false {
                _ = try await ManagerAPIService.shared.updateBundle(
                    bundlePackageId: bundlePackageId,
                    componentIds: ids,
                    priceAmount: priceAmount,
                    priceDisplay: priceDisplay
                )
            } else {
                _ = try await ManagerAPIService.shared.saveBundle(
                    bundlePackageId: bundlePackageId,
                    componentIds: ids
                )
            }
            showBundleEditor = false
            await loadBundles()
        } catch {
            bundleError = error.localizedDescription
        }
        isBundleLoading = false
    }

    func clearBundle(bundlePackageId: String) async {
        do {
            try await ManagerAPIService.shared.clearBundle(bundlePackageId: bundlePackageId)
            await loadBundles()
        } catch {
            bundleError = error.localizedDescription
        }
    }

    // MARK: - Local notification (fallback when APNs certs not configured)
    private func scheduleLocalNotification(newBookingCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = newBookingCount == 1 ? "New Booking!" : "\(newBookingCount) New Bookings!"
        content.body  = newBookingCount == 1
            ? "A customer has just scheduled a new booking."
            : "\(newBookingCount) customers have just scheduled new bookings."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
