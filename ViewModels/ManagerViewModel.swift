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

    // MARK: - Private
    private var pollingTask: Task<Void, Never>?
    private var lastKnownCount = -1  // -1 means first load (don't notify on first fetch)

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
    }

    // MARK: - Push notification permission
    func requestNotificationPermission() {
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

        // Also listen for FCM token refreshes while this view is active
        NotificationCenter.default.addObserver(
            forName: .fcmTokenReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let token = notification.object as? String else { return }
            Task {
                try? await ManagerAPIService.shared.registerDeviceToken(token)
            }
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
