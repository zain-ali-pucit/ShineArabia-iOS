import Foundation

// MARK: - API DTOs for Bookings
struct APIBooking: Codable, Identifiable {
    let id: String
    let serviceCategory: String
    let packageNameEn: String
    let packageNameAr: String
    let scheduledDate: Date
    let address: String
    let notes: String?
    let status: String
    let priceAmount: Double
    let discountAmount: Double
    let createdAt: Date
    let welcomePromoApplied: Bool?
    let cancelReason: String?
    let categoryIconEmoji: String?      // API-provided icon (avoids hardcoding)
    let categorySoftColorHex: String?   // API-provided background colour
}

struct APIBookingsResponse: Decodable {
    struct DataWrapper: Decodable {
        let bookings: [APIBooking]
        let pagination: APIPagination?
    }
    let success: Bool
    let data: DataWrapper?
}

struct APISingleBookingResponse: Decodable {
    struct DataWrapper: Decodable { let booking: APIBooking }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

struct APIMultiBookingResponse: Decodable {
    struct DataWrapper: Decodable { let bookings: [APIBooking] }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

struct APIPagination: Decodable {
    let total: Int
    let page: Int
    let limit: Int
}

struct PromoValidateResponse: Decodable {
    struct DataWrapper: Decodable {
        let code: String
        let discountType: String
        let discountValue: Double
        let discountAmount: Double
        let originalAmount: Double
        let finalAmount: Double
    }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

// MARK: - BookingAPIService
class BookingAPIService {
    static let shared = BookingAPIService()
    private let client = APIClient.shared

    func createBooking(packageId: String, scheduledDate: Date, address: String, notes: String?, promoCode: String?, latitude: Double? = nil, longitude: Double? = nil) async throws -> APIBooking {
        var body: [String: Any] = [
            "packageId":     packageId,
            "scheduledDate": ISO8601DateFormatter().string(from: scheduledDate),
            "address":       address,
        ]
        if let notes = notes, !notes.isEmpty { body["notes"] = notes }
        if let promo = promoCode, !promo.isEmpty { body["promoCode"] = promo }
        if let lat = latitude  { body["latitude"]  = lat }
        if let lng = longitude { body["longitude"] = lng }

        let res: APISingleBookingResponse = try await client.request("/bookings", method: "POST", body: body)
        guard let booking = res.data?.booking else {
            throw APIError.serverError(400, res.message ?? "Booking failed")
        }
        return booking
    }

    func fetchBookings(status: String? = nil, page: Int = 1) async throws -> [APIBooking] {
        var endpoint = "/bookings?page=\(page)&limit=20"
        if let s = status { endpoint += "&status=\(s)" }
        let res: APIBookingsResponse = try await client.request(endpoint)
        return res.data?.bookings ?? []
    }

    func rescheduleBooking(id: String, newDate: Date) async throws -> APIBooking {
        let body: [String: Any] = [
            "scheduledDate": ISO8601DateFormatter().string(from: newDate)
        ]
        let res: APISingleBookingResponse = try await client.request("/bookings/\(id)/reschedule", method: "PUT", body: body)
        guard let booking = res.data?.booking else {
            throw APIError.serverError(400, res.message ?? "Reschedule failed")
        }
        return booking
    }

    func cancelBooking(id: String) async throws -> APIBooking {
        let res: APISingleBookingResponse = try await client.request("/bookings/\(id)/cancel", method: "PUT")
        guard let booking = res.data?.booking else {
            throw APIError.serverError(400, res.message ?? "Cancel failed")
        }
        return booking
    }

    func createMultiBooking(packageIds: [String], scheduledDate: Date, address: String, notes: String?, promoCode: String?, latitude: Double? = nil, longitude: Double? = nil) async throws -> [APIBooking] {
        var body: [String: Any] = [
            "packageIds":    packageIds,
            "scheduledDate": ISO8601DateFormatter().string(from: scheduledDate),
            "address":       address,
        ]
        if let notes = notes, !notes.isEmpty { body["notes"] = notes }
        if let promo = promoCode, !promo.isEmpty { body["promoCode"] = promo }
        if let lat = latitude  { body["latitude"]  = lat }
        if let lng = longitude { body["longitude"] = lng }

        let res: APIMultiBookingResponse = try await client.request("/bookings/multi", method: "POST", body: body)
        guard let bookings = res.data?.bookings else {
            throw APIError.serverError(400, res.message ?? "Booking failed")
        }
        return bookings
    }

    func validatePromo(code: String, packageId: String) async throws -> PromoValidateResponse.DataWrapper {
        let body: [String: Any] = ["code": code, "packageId": packageId]
        let res: PromoValidateResponse = try await client.request("/promo/validate", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(400, res.message ?? "Invalid promo code")
        }
        return data
    }
}
