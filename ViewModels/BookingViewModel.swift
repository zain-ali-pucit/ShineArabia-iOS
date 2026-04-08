import SwiftUI
import Combine

class BookingViewModel: ObservableObject {
    @Published var bookings: [Booking]  = []
    @Published var selectedDate: Date   = BookingViewModel.defaultBookingDate()
    @Published var address: String      = ""
    @Published var notes: String        = ""
    @Published var promoCode: String         = ""
    @Published var promoDiscount: Double      = 0
    @Published var isSubmitting: Bool         = false
    @Published var bookingSuccess: Bool       = false
    @Published var isLoading: Bool            = false
    @Published var errorMsg: String?          = nil
    @Published var welcomePromoEligible: Bool = false
    @Published var welcomePromoApplied: Bool  = false

    private let bookingAPI = BookingAPIService.shared
    private let userAPI    = UserAPIService.shared

    // MARK: Load user bookings from API
    func loadBookings() async {
        await MainActor.run { isLoading = true }
        do {
            async let apiBookings = bookingAPI.fetchBookings()
            async let stats       = userAPI.fetchStats()
            let (fetchedBookings, fetchedStats) = try await (apiBookings, stats)
            await MainActor.run {
                bookings             = fetchedBookings.map { Booking(from: $0) }
                welcomePromoEligible = fetchedStats.welcomePromoEligible
                isLoading            = false
                errorMsg             = nil
            }
        } catch let err as APIError {
            await MainActor.run {
                errorMsg  = err.errorDescription
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMsg  = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: Create multi-package booking via API
    func createMultiBooking(packages: [ServicePackage]) async {
        let deliveryAddress = address.trimmingCharacters(in: .whitespaces)
        await MainActor.run { isSubmitting = true; errorMsg = nil }

        let apiIds = packages.compactMap { $0.apiId }

        do {
            if !apiIds.isEmpty {
                let apiBookings = try await bookingAPI.createMultiBooking(
                    packageIds:    apiIds,
                    scheduledDate: selectedDate,
                    address:       deliveryAddress,
                    notes:         notes.isEmpty ? nil : notes,
                    promoCode:     promoCode.isEmpty ? nil : promoCode
                )
                await MainActor.run {
                    let newBookings = apiBookings.map { Booking(from: $0) }
                    bookings.insert(contentsOf: newBookings, at: 0)
                    welcomePromoApplied  = apiBookings.first?.welcomePromoApplied == true
                    welcomePromoEligible = false
                    isSubmitting         = false
                    bookingSuccess       = true
                }
            } else {
                // Offline / sample data fallback — create one local booking per package
                let newBookings = packages.map { pkg in
                    Booking(
                        serviceCategory: pkg.category.rawValue,
                        packageName:     pkg.name,
                        scheduledDate:   selectedDate,
                        address:         deliveryAddress,
                        status:          .confirmed,
                        price:           pkg.price
                    )
                }
                await MainActor.run {
                    bookings.insert(contentsOf: newBookings, at: 0)
                    isSubmitting   = false
                    bookingSuccess = true
                }
            }
        } catch let err as APIError {
            await MainActor.run {
                errorMsg     = err.errorDescription
                isSubmitting = false
            }
        } catch {
            await MainActor.run {
                errorMsg     = error.localizedDescription
                isSubmitting = false
            }
        }
    }

    // MARK: Reschedule booking via API
    func rescheduleBooking(id: UUID, newDate: Date) async {
        guard let booking = bookings.first(where: { $0.id == id }),
              let apiId = booking.apiId else { return }
        await MainActor.run { errorMsg = nil }
        do {
            let updated = try await bookingAPI.rescheduleBooking(id: apiId, newDate: newDate)
            await MainActor.run {
                if let idx = bookings.firstIndex(where: { $0.id == id }) {
                    bookings[idx].scheduledDate = updated.scheduledDate
                }
            }
        } catch let err as APIError {
            await MainActor.run { errorMsg = err.errorDescription }
        } catch {
            await MainActor.run { errorMsg = error.localizedDescription }
        }
    }

    // MARK: Cancel booking via API
    func cancelBooking(id: UUID) {
        guard let booking = bookings.first(where: { $0.id == id }),
              let apiId = booking.apiId else {
            // Local fallback
            if let idx = bookings.firstIndex(where: { $0.id == id }) {
                bookings[idx].status = .cancelled
            }
            return
        }

        Task {
            do {
                _ = try await bookingAPI.cancelBooking(id: apiId)
                await MainActor.run {
                    if let idx = bookings.firstIndex(where: { $0.id == id }) {
                        bookings[idx].status = .cancelled
                    }
                }
            } catch let err as APIError {
                await MainActor.run { errorMsg = err.errorDescription }
            } catch {
                await MainActor.run { errorMsg = error.localizedDescription }
            }
        }
    }

    // MARK: Validate promo code
    // totalAmount: sum of all selected packages. Discount is applied to this total.
    func validatePromo(packageId: String, totalAmount: Double) async {
        guard !promoCode.isEmpty else {
            await MainActor.run { promoDiscount = 0 }
            return
        }
        do {
            let result = try await bookingAPI.validatePromo(code: promoCode, packageId: packageId)
            let discount: Double
            if result.discountType == "percentage" {
                discount = totalAmount * (result.discountValue / 100)
            } else {
                discount = min(result.discountValue, totalAmount)
            }
            await MainActor.run { promoDiscount = discount }
        } catch {
            await MainActor.run { promoDiscount = 0 }
        }
    }

    // MARK: Helpers
    static func defaultBookingDate() -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day! += 1
        comps.hour   = 10
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date().addingTimeInterval(86400)
    }

    // MARK: Computed
    var activeBookings: [Booking] {
        bookings.filter { $0.status != .completed && $0.status != .cancelled }
    }
    var pastBookings: [Booking] {
        bookings.filter { $0.status == .completed || $0.status == .cancelled }
    }
}
