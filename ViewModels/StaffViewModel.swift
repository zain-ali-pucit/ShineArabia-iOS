import Foundation
import UIKit
import UserNotifications
import CoreLocation

@MainActor
class StaffViewModel: NSObject, ObservableObject {

    // MARK: - Published state
    @Published var bookings: [StaffBooking]    = []
    @Published var isLoading                   = false
    @Published var errorMessage: String?       = nil
    @Published var selectedFilter: String?     = nil   // nil = All
    @Published var hasNewBooking               = false // drives notification bell badge

    @Published var staffLocation: CLLocation? = nil
    var userRole: String?
    var currentStaffId: String?
    var currentStaffName: String?

    // MARK: - Private
    private var pollingTask: Task<Void, Never>?
    private var lastKnownCount = -1
    private var notificationObservers: [NSObjectProtocol] = []
    private var locationManager: CLLocationManager?

    override init() { super.init() }

    private var isAdminRole: Bool { userRole == "admin" || userRole == "manager" }

    // MARK: - Filter options
    var filters: [(label: String, value: String?)] {
        var result: [(label: String, value: String?)] = [
            ("All",         nil),
            ("Pending",     "pending"),
            ("In Progress", "in_progress"),
            ("Completed",   "completed"),
        ]
        if isAdminRole { result.append(("Cancelled", "cancelled")) }
        return result
    }

    // MARK: - Filtered view
    var filteredBookings: [StaffBooking] {
        let base = isAdminRole ? bookings : bookings.filter { $0.status != "cancelled" }
        guard let filter = selectedFilter else { return base }
        return base.filter { $0.status == filter }
    }

    // MARK: - Fetch
    func fetchBookings() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await StaffAPIService.shared.fetchBookings()
            bookings = fetched

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

    // MARK: - Update Status
    func updateStatus(bookingId: String, newStatus: Booking.BookingStatus) async {
        do {
            let staffId = (newStatus == .inProgress || newStatus == .completed) ? currentStaffId : nil
            try await StaffAPIService.shared.updateBookingStatus(id: bookingId, status: newStatus.rawValue, staffId: staffId)
            await fetchBookings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelWithReason(bookingId: String, reason: String) async {
        do {
            try await StaffAPIService.shared.updateBookingStatus(id: bookingId, status: "cancelled", cancelReason: reason)
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
                try? await Task.sleep(nanoseconds: 30_000_000_000)
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

    // MARK: - Location Tracking
    func startLocationTracking() {
        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        mgr.distanceFilter = 50
        locationManager = mgr
        let status = mgr.authorizationStatus
        if status == .notDetermined {
            mgr.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            mgr.startUpdatingLocation()
        }
    }

    func stopLocationTracking() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
    }

    // MARK: - Push notification permission
    func requestNotificationPermission() {
        guard notificationObservers.isEmpty else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()
            }
            if let token = UserDefaults.standard.string(forKey: "fcm_token") {
                Task { try? await StaffAPIService.shared.registerDeviceToken(token) }
            }
        }

        let fcmObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? String else { return }
            Task { try? await StaffAPIService.shared.registerDeviceToken(token) }
        }

        let pushObserver = NotificationCenter.default.addObserver(
            forName: .pushNotificationReceived,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in await self?.fetchBookings() }
        }

        notificationObservers = [fcmObserver, pushObserver]
    }

    // MARK: - Local notification fallback
    private func scheduleLocalNotification(newBookingCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = newBookingCount == 1 ? "New Booking!" : "\(newBookingCount) New Bookings!"
        content.body  = newBookingCount == 1
            ? "A new booking has been assigned."
            : "\(newBookingCount) new bookings are waiting."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - CLLocationManagerDelegate
extension StaffViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.staffLocation = loc }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
