import Foundation

// MARK: - API DTOs for Services
struct APICategoryResponse: Decodable {
    struct DataWrapper: Decodable { let categories: [APICategory] }
    let success: Bool
    let data: DataWrapper?
}

struct APIPackagesResponse: Decodable {
    struct DataWrapper: Decodable { let packages: [APIPackage] }
    let success: Bool
    let data: DataWrapper?
}

struct APIPopularResponse: Decodable {
    struct DataWrapper: Decodable { let items: [APIPopularItem] }
    let success: Bool
    let data: DataWrapper?
}

struct APICategory: Codable, Identifiable {
    let id: String
    let slug: String
    let nameEn: String
    let nameAr: String
    let iconEmoji: String
    let colorHex: String
    let softColorHex: String
    let optionsCount: String
    let sortOrder: Int
}

struct APIPackage: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
    let detailEn: String
    let detailAr: String
    let priceDisplay: String
    let priceAmount: Double
    let priceUnit: String?
    let categorySlug: String
}

struct APIPopularItem: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
    let rating: Double
    let reviewCount: Int
    let priceDisplay: String
    let priceAmount: Double
    let priceUnitEn: String
    let priceUnitAr: String
    let badgeEn: String?
    let badgeAr: String?
    let badgeColorHex: String?
    let categorySlug: String
}

// MARK: - ServiceAPIService
class ServiceAPIService {
    static let shared = ServiceAPIService()
    private let client = APIClient.shared

    func fetchCategories() async throws -> [APICategory] {
        let res: APICategoryResponse = try await client.request("/services/categories")
        return res.data?.categories ?? []
    }

    func fetchPackages(for categorySlug: String) async throws -> [APIPackage] {
        let res: APIPackagesResponse = try await client.request("/services/packages/\(categorySlug)")
        return res.data?.packages ?? []
    }

    func fetchPopular() async throws -> [APIPopularItem] {
        let res: APIPopularResponse = try await client.request("/services/popular")
        return res.data?.items ?? []
    }

    func fetchBundles() async throws -> [APIBundle] {
        let res: APIBundlesResponse = try await client.request("/services/bundles")
        return res.data?.bundles ?? []
    }

    func search(_ query: String) async throws -> [APIPackage] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let res: APIPackagesResponse = try await client.request("/services/search?q=\(encoded)")
        return res.data?.packages ?? []
    }
}
