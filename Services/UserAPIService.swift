import Foundation

struct APIUserStats: Decodable {
    let totalOrders: Int
    let completedOrders: Int
    let totalSpent: Double
    let welcomePromoEligible: Bool
    let welcomePromoUsed: Bool
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
}
