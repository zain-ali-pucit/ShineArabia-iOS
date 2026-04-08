import Foundation

// MARK: - Auth DTOs
struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
    let phone: String?
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AuthResponse: Decodable {
    struct DataWrapper: Decodable {
        let user: APIUser
        let accessToken: String
        let refreshToken: String
    }
    let success: Bool
    let data: DataWrapper?
    let message: String?
}

struct MeResponse: Decodable {
    struct DataWrapper: Decodable { let user: APIUser }
    let success: Bool
    let data: DataWrapper?
}

// MARK: - API User model (backend shape)
struct APIUser: Codable {
    let id: String
    let name: String
    let email: String
    let phone: String?
    let address: String?
    let avatarUrl: String?
    let language: String?
    let role: String?       // "customer", "admin", or "manager"
}

// MARK: - AuthService
class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared

    func register(name: String, email: String, password: String, phone: String?) async throws -> APIUser {
        let body: [String: Any] = [
            "name":     name,
            "email":    email,
            "password": password,
            "phone":    phone ?? "",
        ]
        let res: AuthResponse = try await client.request("/auth/register", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(400, res.message ?? "Registration failed")
        }
        TokenStore.accessToken  = data.accessToken
        TokenStore.refreshToken = data.refreshToken
        return data.user
    }

    func login(email: String, password: String) async throws -> APIUser {
        let body: [String: Any] = ["email": email, "password": password]
        let res: AuthResponse = try await client.request("/auth/login", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(401, res.message ?? "Login failed")
        }
        TokenStore.accessToken  = data.accessToken
        TokenStore.refreshToken = data.refreshToken
        return data.user
    }

    func logout() async {
        let body: [String: Any] = ["refreshToken": TokenStore.refreshToken ?? ""]
        _ = try? await client.request("/auth/logout", method: "POST", body: body) as APIResponse<EmptyData>
        TokenStore.clear()
    }

    func fetchMe() async throws -> APIUser {
        let res: MeResponse = try await client.request("/auth/me")
        guard let user = res.data?.user else {
            throw APIError.serverError(404, "User not found")
        }
        return user
    }

    // MARK: - Social Auth

    func signInWithApple(identityToken: String, email: String?, fullName: String?) async throws -> APIUser {
        var body: [String: Any] = ["identityToken": identityToken]
        if let email { body["email"] = email }
        if let fullName { body["fullName"] = fullName }
        let res: AuthResponse = try await client.request("/auth/apple", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(401, res.message ?? "Apple sign in failed")
        }
        TokenStore.accessToken  = data.accessToken
        TokenStore.refreshToken = data.refreshToken
        return data.user
    }

    func signInWithGoogle(idToken: String) async throws -> APIUser {
        let body: [String: Any] = ["idToken": idToken]
        let res: AuthResponse = try await client.request("/auth/google", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(401, res.message ?? "Google sign in failed")
        }
        TokenStore.accessToken  = data.accessToken
        TokenStore.refreshToken = data.refreshToken
        return data.user
    }

    func signInWithFacebook(accessToken: String) async throws -> APIUser {
        let body: [String: Any] = ["accessToken": accessToken]
        let res: AuthResponse = try await client.request("/auth/facebook", method: "POST", body: body)
        guard let data = res.data else {
            throw APIError.serverError(401, res.message ?? "Facebook sign in failed")
        }
        TokenStore.accessToken  = data.accessToken
        TokenStore.refreshToken = data.refreshToken
        return data.user
    }
}
