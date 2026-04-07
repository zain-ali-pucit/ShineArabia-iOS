import Foundation

// MARK: - Admin Booking DTO
// Shape returned by GET /api/admin/bookings (includes customer info via JOIN)
struct AdminBooking: Codable, Identifiable {
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
    // Customer info (from JOIN with users table)
    let userId: String?
    let customerName: String?
    let customerEmail: String?
    let customerPhone: String?

    var bookingStatus: Booking.BookingStatus {
        Booking.BookingStatus(rawValue: status) ?? .pending
    }

    // Valid next statuses the manager can transition to
    var allowedNextStatuses: [Booking.BookingStatus] {
        switch bookingStatus {
        case .pending:    return [.confirmed, .cancelled]
        case .confirmed:  return [.inProgress, .cancelled]
        case .inProgress: return [.completed, .cancelled]
        case .completed:  return []
        case .cancelled:  return []
        }
    }
}

// MARK: - Response wrappers
struct AdminBookingsResponse: Decodable {
    struct DataWrapper: Decodable {
        let bookings: [AdminBooking]
        let pagination: APIPagination?
    }
    let success: Bool
    let data: DataWrapper?
}

// MARK: - ManagerAPIService
class ManagerAPIService {
    static let shared = ManagerAPIService()
    private let client = APIClient.shared

    // GET /api/admin/bookings
    func fetchAllBookings(status: String? = nil, page: Int = 1) async throws -> [AdminBooking] {
        var endpoint = "/admin/bookings?page=\(page)&limit=50"
        if let s = status { endpoint += "&status=\(s)" }
        let res: AdminBookingsResponse = try await client.request(endpoint)
        return res.data?.bookings ?? []
    }

    // PUT /api/admin/bookings/:id/status
    func updateBookingStatus(id: String, status: String) async throws {
        let body: [String: Any] = ["status": status]
        let _: APIResponse<EmptyData> = try await client.request(
            "/admin/bookings/\(id)/status", method: "PUT", body: body
        )
    }

    // GET /api/admin/bundles
    func fetchBundles() async throws -> [APIBundle] {
        let res: AdminBundlesResponse = try await client.request("/admin/bundles")
        return res.data?.bundles ?? []
    }

    // GET /api/admin/services/packages/non-bundle — all non-bundle packages for picker
    func fetchNonBundlePackages() async throws -> [AdminPackageItem] {
        let res: AdminNonBundlePackagesResponse = try await client.request("/admin/services/packages/non-bundle")
        return res.data?.packages ?? []
    }

    // POST /api/admin/bundles — assign component packages to a bundle
    func saveBundle(bundlePackageId: String, componentIds: [String]) async throws -> APIBundle {
        let body: [String: Any] = [
            "bundle_package_id": bundlePackageId,
            "component_ids": componentIds
        ]
        struct Wrapper: Decodable {
            struct D: Decodable { let bundle: APIBundle }
            let success: Bool; let data: D?
        }
        let res: Wrapper = try await client.request("/admin/bundles", method: "POST", body: body)
        guard let bundle = res.data?.bundle else { throw APIError.noData }
        return bundle
    }

    // PUT /api/admin/bundles/:id — update components (and optionally price)
    func updateBundle(bundlePackageId: String, componentIds: [String], priceAmount: Double? = nil, priceDisplay: String? = nil) async throws -> APIBundle {
        var body: [String: Any] = ["component_ids": componentIds]
        if let p = priceAmount  { body["price_amount"]  = p }
        if let d = priceDisplay { body["price_display"] = d }
        struct Wrapper: Decodable {
            struct D: Decodable { let bundle: APIBundle }
            let success: Bool; let data: D?
        }
        let res: Wrapper = try await client.request("/admin/bundles/\(bundlePackageId)", method: "PUT", body: body)
        guard let bundle = res.data?.bundle else { throw APIError.noData }
        return bundle
    }

    // DELETE /api/admin/bundles/:id — clear bundle component linkages
    func clearBundle(bundlePackageId: String) async throws {
        let _: APIResponse<EmptyData> = try await client.request("/admin/bundles/\(bundlePackageId)", method: "DELETE", body: nil)
    }

    // POST /api/admin/devices  — stores APNs device token
    func registerDeviceToken(_ token: String) async throws {
        let body: [String: Any] = ["token": token, "platform": "ios"]
        let _: APIResponse<EmptyData> = try await client.request(
            "/admin/devices", method: "POST", body: body
        )
    }
}
