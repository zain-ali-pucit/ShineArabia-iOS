import Foundation
import UIKit

struct APIUserStats: Decodable {
    let totalOrders: Int
    let completedOrders: Int
    let totalSpent: Double
    let welcomePromoEligible: Bool
    let welcomePromoUsed: Bool
    let points: Int
}

struct APIStatsResponse: Decodable {
    let success: Bool
    let data: APIUserStats?
}

struct APIProfileResponse: Decodable {
    struct DataWrapper: Decodable { let user: APIUser }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

// MARK: - UserAPIService
class UserAPIService {
    static let shared = UserAPIService()
    private let client = APIClient.shared

    // MARK: - Avatar Upload (multipart/form-data)
    func uploadAvatar(imageData: Data) async throws -> APIUser {
        guard let url = URL(string: APIConfig.baseURL + "/users/avatar") else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = TokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                ?? "Avatar upload failed (\(http.statusCode))"
            throw APIError.serverError(http.statusCode, msg)
        }

        let res = try JSONDecoder.api.decode(APIProfileResponse.self, from: data)
        guard let user = res.data?.user else {
            throw APIError.serverError(400, res.message ?? "Avatar upload failed")
        }
        return user
    }

    func updateProfile(name: String?, phone: String?, address: String?, language: String?) async throws -> APIUser {
        var body: [String: Any] = [:]
        if let v = name     { body["name"]     = v }
        if let v = phone    { body["phone"]    = v }
        if let v = address  { body["address"]  = v }
        if let v = language { body["language"] = v }

        let res: APIProfileResponse = try await client.request("/users/profile", method: "PUT", body: body)
        guard let user = res.data?.user else {
            throw APIError.serverError(400, res.message ?? "Update failed")
        }
        return user
    }

    func fetchStats() async throws -> APIUserStats {
        let res: APIStatsResponse = try await client.request("/users/stats")
        guard let stats = res.data else {
            throw APIError.serverError(500, "Stats unavailable")
        }
        return stats
    }

    func changePassword(current: String, new: String) async throws {
        let body: [String: Any] = ["currentPassword": current, "newPassword": new]
        let _: APIResponse<EmptyData> = try await client.request("/users/password", method: "PUT", body: body)
    }

    struct RedeemResponse: Decodable {
        let remainingPoints: Int
    }

    func redeemReward(points: Int, rewardName: String, address: String, latitude: Double?, longitude: Double?, notes: String?) async throws -> Int {
        var body: [String: Any] = [
            "points": points,
            "rewardName": rewardName,
            "address": address,
            "notes": notes ?? ""
        ]
        if let lat = latitude  { body["latitude"]  = lat }
        if let lng = longitude { body["longitude"] = lng }
        let res: APIResponse<RedeemResponse> = try await client.request("/users/rewards/redeem", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(500, "Redeem failed")
        }
        return data.remainingPoints
    }

    // POST /api/users/device-token — registers FCM token for push notifications
    func registerDeviceToken(_ token: String, platform: String = "ios") async throws {
        let body: [String: Any] = ["token": token, "platform": platform]
        let _: APIResponse<EmptyData> = try await client.request("/users/device-token", method: "POST", body: body)
    }

    // Call this after login to ensure the FCM token (which may have arrived before auth) is registered
    func registerPendingDeviceToken() async {
        guard let token = UserDefaults.standard.string(forKey: "fcm_token") else { return }
        try? await registerDeviceToken(token)
    }

    // MARK: - Addresses (server-side CRUD)

    struct AddressesResponse: Decodable {
        struct DataWrapper: Decodable { let addresses: [APIAddress] }
        let success: Bool
        let data: DataWrapper?
    }

    struct AddressResponse: Decodable {
        struct DataWrapper: Decodable { let address: APIAddress? }
        let success: Bool
        let data: DataWrapper?
        let message: String?
    }

    // GET /api/addresses
    func fetchAddresses() async throws -> [APIAddress] {
        let res: AddressesResponse = try await client.request("/addresses")
        return res.data?.addresses ?? []
    }

    // POST /api/addresses
    func addAddress(label: String, address: String, isDefault: Bool, latitude: Double?, longitude: Double?) async throws -> APIAddress {
        var body: [String: Any] = [
            "label":     label,
            "address":   address,
            "isDefault": isDefault,
        ]
        if let lat = latitude  { body["latitude"]  = lat }
        if let lng = longitude { body["longitude"] = lng }
        let res: AddressResponse = try await client.request("/addresses", method: "POST", body: body)
        guard let saved = res.data?.address else {
            throw APIError.serverError(400, res.message ?? "Failed to save address")
        }
        return saved
    }

    // PUT /api/addresses/:id
    func updateAddress(id: String, label: String, address: String, isDefault: Bool, latitude: Double?, longitude: Double?) async throws -> APIAddress {
        var body: [String: Any] = [
            "label":     label,
            "address":   address,
            "isDefault": isDefault,
        ]
        if let lat = latitude  { body["latitude"]  = lat }
        if let lng = longitude { body["longitude"] = lng }
        let res: AddressResponse = try await client.request("/addresses/\(id)", method: "PUT", body: body)
        guard let saved = res.data?.address else {
            throw APIError.serverError(400, res.message ?? "Failed to update address")
        }
        return saved
    }

    // DELETE /api/addresses/:id
    func deleteAddress(id: String) async throws {
        let _: APIResponse<EmptyData> = try await client.request("/addresses/\(id)", method: "DELETE")
    }
}
