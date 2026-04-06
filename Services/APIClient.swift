import Foundation

// MARK: - API Configuration
enum APIConfig {
    #if DEBUG
    static let baseURL = "https://www.shine-arabia.com/api"
    #else
    static let baseURL = "https://www.shine-arabia.com/api"
    #endif

    static var headers: [String: String] {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.accessToken {
            h["Authorization"] = "Bearer \(token)"
        }
        return h
    }
}

// MARK: - Token Store (Keychain-backed via UserDefaults for simplicity)
enum TokenStore {
    private static let accessKey  = "sa_access_token"
    private static let refreshKey = "sa_refresh_token"

    static var accessToken: String? {
        get { UserDefaults.standard.string(forKey: accessKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: accessKey) }
            else { UserDefaults.standard.removeObject(forKey: accessKey) }
        }
    }

    static var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: refreshKey) }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: refreshKey) }
            else { UserDefaults.standard.removeObject(forKey: refreshKey) }
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: accessKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case serverError(Int, String)
    case unauthorized
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .noData:               return "No data received"
        case .decodingFailed(let e):return "Decoding error: \(e.localizedDescription)"
        case .serverError(_, let m):return m
        case .unauthorized:         return "Session expired. Please log in again."
        case .networkError(let e):  return e.localizedDescription
        }
    }
}

// MARK: - Generic API Response wrapper
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let message: String?
    let data: T?
}

struct EmptyData: Decodable {}

// MARK: - API Client
class APIClient {
    static let shared = APIClient()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: Generic Request
    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        APIConfig.headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if http.statusCode == 401 {
            // Try token refresh once
            let refreshed = try? await refreshAccessToken()
            if refreshed == true {
                return try await request(endpoint, method: method, body: body)
            }
            TokenStore.clear()
            throw APIError.unauthorized
        }

        if !(200...299).contains(http.statusCode) {
            let msg = extractMessage(from: data) ?? "Request failed (\(http.statusCode))"
            throw APIError.serverError(http.statusCode, msg)
        }

        do {
            return try JSONDecoder.api.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    // MARK: Token Refresh
    private func refreshAccessToken() async throws -> Bool {
        guard let refresh = TokenStore.refreshToken,
              let url = URL(string: APIConfig.baseURL + "/auth/refresh") else {
            return false
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refresh])

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }

        struct RefreshResponse: Decodable {
            struct DataWrapper: Decodable { let accessToken: String }
            let success: Bool
            let data: DataWrapper?
        }
        if let res = try? JSONDecoder.api.decode(RefreshResponse.self, from: data),
           let token = res.data?.accessToken {
            TokenStore.accessToken = token
            return true
        }
        return false
    }

    private func extractMessage(from data: Data) -> String? {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["message"] as? String
    }
}

// MARK: - JSONDecoder + Date Strategy
extension JSONDecoder {
    static var api: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy  = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    static var api: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy  = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
