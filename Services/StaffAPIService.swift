import Foundation
import UIKit

// MARK: - Staff Profile Response DTO
struct StaffProfileResponse: Decodable {
    struct DataWrapper: Decodable { let user: APIUser }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

// MARK: - Staff Booking DTO
struct StaffBooking: Codable, Identifiable {
    let id: String
    let serviceCategory: String
    let packageNameEn: String
    let packageNameAr: String
    let scheduledDate: Date
    let address: String
    let notes: String?
    var status: String
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
    var cancelReason: String?
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

    // POST /api/staff/location
    func updateLocation(latitude: Double, longitude: Double) async throws {
        let body: [String: Any] = ["latitude": latitude, "longitude": longitude]
        let _: APIResponse<EmptyData> = try await client.request(
            "/staff/location", method: "POST", body: body
        )
    }

    // MARK: - Profile

    // GET /api/staff/profile
    func fetchProfile() async throws -> APIUser {
        let res: StaffProfileResponse = try await client.request("/staff/profile")
        guard let user = res.data?.user else {
            throw APIError.serverError(404, res.message ?? "Profile not found")
        }
        return user
    }

    // POST /api/staff/profile/avatar  (multipart/form-data)
    func uploadAvatar(imageData: Data) async throws -> APIUser {
        try await uploadFile(
            imageData,
            to:        "/staff/profile/avatar",
            fieldName: "avatar",
            fileName:  "avatar.jpg",
            mimeType:  "image/jpeg"
        )
    }

    // POST /api/staff/profile/certificate  (multipart/form-data)
    func uploadCertificate(imageData: Data, mimeType: String = "image/jpeg", fileName: String = "certificate.jpg") async throws -> APIUser {
        try await uploadFile(
            imageData,
            to:        "/staff/profile/certificate",
            fieldName: "certificate",
            fileName:  fileName,
            mimeType:  mimeType
        )
    }

    // PUT /api/staff/profile
    func updateProfile(name: String?, phone: String?) async throws -> APIUser {
        var body: [String: Any] = [:]
        if let v = name  { body["name"]  = v }
        if let v = phone { body["phone"] = v }
        let res: StaffProfileResponse = try await client.request("/staff/profile", method: "PUT", body: body)
        guard let user = res.data?.user else {
            throw APIError.serverError(400, res.message ?? "Update failed")
        }
        return user
    }

    // MARK: - Private helpers

    private func uploadFile(
        _ data: Data,
        to endpoint: String,
        fieldName: String,
        fileName: String,
        mimeType: String
    ) async throws -> APIUser {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = TokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: responseData) as? [String: Any])?["message"] as? String
                ?? "Upload failed (\(http.statusCode))"
            throw APIError.serverError(http.statusCode, msg)
        }

        let res = try JSONDecoder.api.decode(StaffProfileResponse.self, from: responseData)
        guard let user = res.data?.user else {
            throw APIError.serverError(400, res.message ?? "Upload failed")
        }
        return user
    }
}
