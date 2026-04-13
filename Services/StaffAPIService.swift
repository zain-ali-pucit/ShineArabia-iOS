import Foundation

// MARK: - Staff Booking DTO
struct StaffBooking: Codable, Identifiable {
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
    let updatedAt: Date?
    let latitude: Double?
    let longitude: Double?
    let userId: String?
    let customerName: String?
    let customerEmail: String?
    let customerPhone: String?
    let cancelReason: String?
    let completedByStaffId: String?
    let completedByStaffName: String?
    let completedAt: Date?

    var bookingStatus: Booking.BookingStatus {
        Booking.BookingStatus(rawValue: status) ?? .pending
    }

    // All valid next statuses staff can transition to
    var allowedNextStatuses: [Booking.BookingStatus] {
        switch bookingStatus {
        case .pending:    return [.inProgress]
        case .inProgress: return [.completed, .cancelled]
        case .completed:  return []
        case .cancelled:  return []
        default:          return []
        }
    }
}

struct StaffBookingsResponse: Decodable {
    struct DataWrapper: Decodable {
        let bookings: [StaffBooking]
    }
    let success: Bool
    let data: DataWrapper?
}

// MARK: - StaffAPIService
class StaffAPIService {
    static let shared = StaffAPIService()
    private let client = APIClient.shared

    // GET /api/staff/bookings
    func fetchBookings(status: String? = nil, page: Int = 1) async throws -> [StaffBooking] {
        var endpoint = "/staff/bookings?page=\(page)&limit=50"
        if let s = status { endpoint += "&status=\(s)" }
        let res: StaffBookingsResponse = try await client.request(endpoint)
        return res.data?.bookings ?? []
    }

    // PUT /api/staff/bookings/:id/status
    func updateBookingStatus(id: String, status: String, cancelReason: String? = nil, staffId: String? = nil) async throws {
        var body: [String: Any] = ["status": status]
        if let reason = cancelReason, !reason.isEmpty { body["cancelReason"] = reason }
        if let staffId = staffId { body["staffId"] = staffId }
        let _: APIResponse<EmptyData> = try await client.request(
            "/staff/bookings/\(id)/status", method: "PUT", body: body
        )
    }

    // POST /api/staff/devices
    func registerDeviceToken(_ token: String) async throws {
        let body: [String: Any] = ["token": token, "platform": "ios"]
        let _: APIResponse<EmptyData> = try await client.request(
            "/staff/devices", method: "POST", body: body
        )
    }
}
