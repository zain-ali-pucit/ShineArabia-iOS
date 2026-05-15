import SwiftUI

// MARK: - User
struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    var address: String
    var avatarUrl: String?
    var certificateUrl: String?
    var avatarInitials: String { String(name.prefix(2)).uppercased() }
}

// MARK: - Service Category
enum ServiceCategory: String, CaseIterable, Identifiable {
    case laundry      = "laundry"
    case cleaning     = "cleaning"
    case officeClean  = "office-cleaning"
    case shopClean    = "shop-cleaning"
    case carWash      = "carwash"
    case pest         = "pest"
    case bundle       = "bundle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .laundry:     return "🧺"
        case .cleaning:    return "🧹"
        case .officeClean: return "🏢"
        case .shopClean:   return "🏪"
        case .carWash:     return "🚗"
        case .pest:        return "🪲"
        case .bundle:      return "🎁"
        }
    }

    var title: String {
        switch self {
        case .laundry:     return "Laundry"
        case .cleaning:    return "Home Clean"
        case .officeClean: return "Office Clean"
        case .shopClean:   return "Shop Clean"
        case .carWash:     return "Car Wash"
        case .pest:        return "Pest Control"
        case .bundle:      return "Bundle"
        }
    }

    var titleAR: String {
        switch self {
        case .laundry:     return "الغسيل"
        case .cleaning:    return "تنظيف المنزل"
        case .officeClean: return "تنظيف المكتب"
        case .shopClean:   return "تنظيف المحل"
        case .carWash:     return "غسيل سيارة"
        case .pest:        return "مكافحة الحشرات"
        case .bundle:      return "الباقة"
        }
    }

    var optionsCount: String {
        switch self {
        case .laundry:     return "8 options"
        case .cleaning:    return "6 options"
        case .officeClean: return "4 options"
        case .shopClean:   return "4 options"
        case .carWash:     return "5 options"
        case .pest:        return "4 options"
        case .bundle:      return "4 plans"
        }
    }

    var color: Color {
        switch self {
        case .laundry:     return .shineCoral
        case .cleaning:    return .shineTeal
        case .officeClean: return .shineLavender   // lavender — matches DB #7B6FA0
        case .shopClean:   return .shineAmber      // amber — matches DB #D4893A
        case .carWash:     return .shineAmber
        case .pest:        return .shineLavender
        case .bundle:      return .shineCoral
        }
    }

    var softColor: Color {
        switch self {
        case .laundry:     return .shineCoralLight
        case .cleaning:    return .shineTealLight
        case .officeClean: return .shineLavLight   // lavender light — matches DB #F0EEF8
        case .shopClean:   return .shineAmberLight // amber light — matches DB #FEF3E8
        case .carWash:     return .shineAmberLight
        case .pest:        return .shineLavLight
        case .bundle:      return .shineCoralLight
        }
    }
}

// MARK: - Service Package
struct ServicePackage: Identifiable {
    let id: UUID
    let apiId: String?         // backend UUID string
    let emoji: String
    let name: String
    let nameAR: String
    let detail: String
    let detailAR: String
    let price: String
    let priceAmount: Double
    let category: ServiceCategory

    // Convenience init for SampleData (no apiId)
    init(emoji: String, name: String, nameAR: String, detail: String, detailAR: String, price: String, category: ServiceCategory) {
        self.id          = UUID()
        self.apiId       = nil
        self.emoji       = emoji
        self.name        = name
        self.nameAR      = nameAR
        self.detail      = detail
        self.detailAR    = detailAR
        self.price       = price
        self.priceAmount = 0
        self.category    = category
    }

    // Init from API response
    init(from api: APIPackage) {
        let mappedCategory = ServiceCategory(rawValue: api.categorySlug) ?? .laundry
        let isWeeklyBundle = mappedCategory == .bundle && api.nameEn.lowercased().contains("weekly")

        self.id          = UUID()
        self.apiId       = api.id
        self.emoji       = api.emoji
        self.name        = api.nameEn
        self.nameAR      = api.nameAr
        self.detail      = isWeeklyBundle ? "Clean" : api.detailEn
        self.detailAR    = isWeeklyBundle ? "تنظيف" : api.detailAr
        self.price       = api.priceDisplay
        self.priceAmount = api.priceAmount
        self.category    = mappedCategory
    }

    // Init from bundle component (for custom bundle building)
    init(from component: APIBundleComponent) {
        self.id          = UUID()
        self.apiId       = component.id
        self.emoji       = component.emoji
        self.name        = component.nameEn
        self.nameAR      = component.nameAr
        self.detail      = component.detailEn ?? component.categoryName ?? "Bundle component"
        self.detailAR    = component.detailAr ?? component.categoryName ?? "عنصر باقة"
        self.price       = component.priceDisplay
        self.priceAmount = component.priceAmount
        self.category    = ServiceCategory(rawValue: component.categorySlug) ?? .laundry
    }
}

// MARK: - Popular Item
struct PopularItem: Identifiable {
    let id: UUID
    let apiId: String?         // backend UUID — used to pre-select the matching ServicePackage
    let emoji: String
    let name: String
    let nameAR: String
    let rating: Double
    let reviews: String
    let reviewsAR: String
    let price: String
    let unit: String
    let unitAR: String
    let badge: String?
    let badgeAR: String?
    let badgeColor: Color
    let category: ServiceCategory

    // Convenience init for SampleData
    init(emoji: String, name: String, nameAR: String, rating: Double, reviews: String, reviewsAR: String, price: String, unit: String, unitAR: String, badge: String?, badgeAR: String?, badgeColor: Color, category: ServiceCategory) {
        self.id       = UUID()
        self.apiId    = nil
        self.emoji    = emoji
        self.name     = name
        self.nameAR   = nameAR
        self.rating   = rating
        self.reviews  = reviews
        self.reviewsAR = reviewsAR
        self.price    = price
        self.unit     = unit
        self.unitAR   = unitAR
        self.badge    = badge
        self.badgeAR  = badgeAR
        self.badgeColor = badgeColor
        self.category = category
    }

    // Init from API response
    init(from api: APIPopularItem) {
        self.id       = UUID()
        self.apiId    = api.id
        self.emoji    = api.emoji
        self.name     = api.nameEn
        self.nameAR   = api.nameAr
        self.rating   = api.rating
        self.reviews  = "\(api.reviewCount) \(api.reviewCount == 1 ? "order" : "orders")"
        self.reviewsAR = "\(api.reviewCount) طلب"
        self.price    = api.priceDisplay
        self.unit     = api.priceUnitEn
        self.unitAR   = api.priceUnitAr
        self.badge    = api.badgeEn
        self.badgeAR  = api.badgeAr
        self.badgeColor = api.badgeColorHex.map { Color(hex: $0) } ?? .shineCoral
        self.category = ServiceCategory(rawValue: api.categorySlug) ?? .laundry
    }
}

// MARK: - Booking
struct Booking: Identifiable, Codable {
    let id: UUID
    let apiId: String?
    var serviceCategory: String
    var packageName: String
    var packageNameAR: String
    var scheduledDate: Date
    var address: String
    var status: BookingStatus
    var price: String
    var priceAmount: Double
    var cancelReason: String?
    var categoryIconEmoji: String?      // from API — preferred over enum fallback
    var categorySoftColorHex: String?   // from API — preferred over enum fallback
    // Assigned staff info (customer view)
    var staffId: String?
    var staffName: String?
    var staffPhone: String?
    var staffAvatarUrl: String?
    var staffAvgRating: Double?
    var staffRatingCount: Int?

    enum BookingStatus: String, Codable {
        case pending    = "pending"
        case confirmed  = "confirmed"
        case inProgress = "in_progress"
        case completed  = "completed"
        case cancelled  = "cancelled"

        var displayTitle: String {
            switch self {
            case .pending:    return "Pending"
            case .confirmed:  return "Confirmed"
            case .inProgress: return "In Progress"
            case .completed:  return "Completed"
            case .cancelled:  return "Cancelled"
            }
        }

        var displayTitleAR: String {
            switch self {
            case .pending:    return "قيد الانتظار"
            case .confirmed:  return "مؤكد"
            case .inProgress: return "جارٍ التنفيذ"
            case .completed:  return "مكتمل"
            case .cancelled:  return "ملغى"
            }
        }

        var actionLabel: String {
            switch self {
            case .inProgress: return "Start Work"
            case .completed:  return "Mark Complete"
            case .cancelled:  return "Cancel"
            default:          return displayTitle
            }
        }

        var actionIcon: String {
            switch self {
            case .inProgress: return "play.fill"
            case .completed:  return "checkmark.seal.fill"
            case .cancelled:  return "xmark.circle.fill"
            default:          return "circle"
            }
        }

        var actionColor: Color {
            switch self {
            case .inProgress: return Color(hex: "1565C0")
            case .completed:  return Color(hex: "2E7D32")
            case .cancelled:  return .shineCoral
            default:          return .shineTeal
            }
        }
    }

    // Convenience init for local/mock creation
    init(id: UUID = UUID(), apiId: String? = nil, serviceCategory: String, packageName: String, packageNameAR: String = "", scheduledDate: Date, address: String, status: BookingStatus, price: String, priceAmount: Double = 0, cancelReason: String? = nil, categoryIconEmoji: String? = nil, categorySoftColorHex: String? = nil, staffId: String? = nil, staffName: String? = nil, staffPhone: String? = nil, staffAvatarUrl: String? = nil) {
        self.id                   = id
        self.apiId                = apiId
        self.serviceCategory      = serviceCategory
        self.packageName          = packageName
        self.packageNameAR        = packageNameAR
        self.scheduledDate        = scheduledDate
        self.address              = address
        self.status               = status
        self.price                = price
        self.priceAmount          = priceAmount
        self.cancelReason         = cancelReason
        self.categoryIconEmoji    = categoryIconEmoji
        self.categorySoftColorHex = categorySoftColorHex
        self.staffId              = staffId
        self.staffName            = staffName
        self.staffPhone           = staffPhone
        self.staffAvatarUrl       = staffAvatarUrl
    }

    // Init from API response
    init(from api: APIBooking, language: AppLanguage = .english) {
        self.id                   = UUID()
        self.apiId                = api.id
        self.serviceCategory      = api.serviceCategory
        self.packageName          = api.packageNameEn
        self.packageNameAR        = api.packageNameAr
        self.scheduledDate        = api.scheduledDate
        self.address              = api.address
        self.status               = BookingStatus(rawValue: api.status) ?? .pending
        self.price                = "QAR \(Int(api.priceAmount))"
        self.priceAmount          = api.priceAmount
        self.cancelReason         = api.cancelReason
        self.categoryIconEmoji    = api.categoryIconEmoji
        self.categorySoftColorHex = api.categorySoftColorHex
        self.staffId              = api.staffId
        self.staffName            = api.staffName
        self.staffPhone           = api.staffPhone
        self.staffAvatarUrl       = api.staffAvatarUrl
        self.staffAvgRating       = api.staffAvgRating
        self.staffRatingCount     = api.staffRatingCount
    }
}

// MARK: - Bundle DTOs

struct APIBundleComponent: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
    let detailEn: String?
    let detailAr: String?
    let priceDisplay: String
    let priceAmount: Double
    let categorySlug: String
    let categoryName: String?
    let sortOrder: Int?
}

struct APIBundle: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
    let detailEn: String
    let detailAr: String
    let priceDisplay: String
    let priceAmount: Double
    let priceUnit: String?
    let sortOrder: Int
    let isActive: Bool?
    let components: [APIBundleComponent]
    let originalTotal: Double    // sum of component prices
    let discountPct: Int         // auto-calculated on backend

    // Convenience: component names joined for subtitle
    func componentSubtitle(isArabic: Bool) -> String {
        components
            .map { isArabic ? $0.nameAr : $0.nameEn }
            .joined(separator: " + ")
    }
}

struct APIBundlesResponse: Decodable {
    struct DataWrapper: Decodable { let bundles: [APIBundle] }
    let success: Bool
    let data: DataWrapper?
}

// Non-bundle packages for admin picker
struct AdminPackageItem: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
    let priceDisplay: String
    let priceAmount: Double
    let categorySlug: String
    let categoryName: String
}

struct AdminNonBundlePackagesResponse: Decodable {
    struct DataWrapper: Decodable { let packages: [AdminPackageItem] }
    let success: Bool
    let data: DataWrapper?
}

struct AdminBundlesResponse: Decodable {
    struct DataWrapper: Decodable { let bundles: [APIBundle] }
    let success: Bool
    let data: DataWrapper?
}

// MARK: - APICategory UI Helpers
extension APICategory {
    var color: Color     { Color(hex: colorHex) }
    var softColor: Color { Color(hex: softColorHex) }
    var icon: String     { iconEmoji }
    var title: String    { nameEn }
    var titleAR: String  { nameAr }
}

// MARK: - APIUser → User conversion
extension APIUser {
    func toUser() -> User {
        User(
            id:             UUID(uuidString: id) ?? UUID(),
            name:           name,
            email:          email,
            phone:          phone          ?? "",
            address:        address        ?? "",
            avatarUrl:      avatarUrl,
            certificateUrl: certificateUrl
        )
    }
}

// MARK: - Reward Tier

struct RewardTier: Identifiable {
    let id = UUID()
    let points: Int
    let reward: String
    let rewardAR: String
    let icon: String
    let detail: String
    let detailAR: String
}

let rewardTiers: [RewardTier] = [
    // 100 pts — Regular cleaning services
    RewardTier(points: 100, reward: "Regular Clean",       rewardAR: "تنظيف عادي",
               icon: "🏠", detail: "Standard home cleaning session",      detailAR: "جلسة تنظيف منزلية عادية"),
    RewardTier(points: 100, reward: "Basic Office Clean",  rewardAR: "تنظيف مكتب أساسي",
               icon: "🏢", detail: "Essential office cleaning service",   detailAR: "خدمة تنظيف مكتبية أساسية"),
    RewardTier(points: 100, reward: "Small Shop Clean",    rewardAR: "تنظيف محل صغير",
               icon: "🏪", detail: "Cleaning for small retail spaces",    detailAR: "تنظيف المحلات التجارية الصغيرة"),

    // 300 pts — Deep cleaning services
    RewardTier(points: 300, reward: "Deep Clean",          rewardAR: "تنظيف عميق",
               icon: "✨", detail: "Thorough deep cleaning for homes",    detailAR: "تنظيف عميق شامل للمنازل"),
    RewardTier(points: 300, reward: "Deep Office Clean",   rewardAR: "تنظيف مكتب عميق",
               icon: "🏢", detail: "Deep cleaning for office spaces",     detailAR: "تنظيف عميق للمساحات المكتبية"),
    RewardTier(points: 300, reward: "Standard Shop Clean", rewardAR: "تنظيف محل معياري",
               icon: "🏪", detail: "Standard cleaning for shops",         detailAR: "تنظيف معياري للمحلات التجارية"),

    // 600 pts — Premium cleaning packages
    RewardTier(points: 600, reward: "Villa Package",       rewardAR: "باقة فيلا",
               icon: "🏡", detail: "Complete cleaning for villas",        detailAR: "تنظيف شامل للفلل"),
    RewardTier(points: 600, reward: "Full-Floor Package",  rewardAR: "باقة طابق كامل",
               icon: "🏗️", detail: "Full floor or large apartment clean",  detailAR: "تنظيف طابق كامل أو شقة كبيرة"),
    RewardTier(points: 600, reward: "Deep Shop Clean",     rewardAR: "تنظيف محل عميق",
               icon: "🛒", detail: "Deep cleaning for large retail shops", detailAR: "تنظيف عميق للمحلات التجارية الكبيرة"),
]

// MARK: - Saved Address

struct SavedAddress: Identifiable, Codable, Equatable {
    let id: UUID
    var label: AddressLabel
    var address: String
    var isDefault: Bool
    var latitude: Double?
    var longitude: Double?

    enum AddressLabel: String, Codable, CaseIterable {
        case home  = "home"
        case work  = "work"
        case other = "other"

        var icon: String {
            switch self {
            case .home:  return "house.fill"
            case .work:  return "briefcase.fill"
            case .other: return "mappin.circle.fill"
            }
        }
        var title: String {
            switch self {
            case .home:  return "Home"
            case .work:  return "Work"
            case .other: return "Other"
            }
        }
        var titleAR: String {
            switch self {
            case .home:  return "المنزل"
            case .work:  return "العمل"
            case .other: return "أخرى"
            }
        }
        var color: Color {
            switch self {
            case .home:  return .shineCoral
            case .work:  return .shineTeal
            case .other: return .shineAmber
            }
        }
    }

    init(id: UUID = UUID(), label: AddressLabel, address: String, isDefault: Bool = false, latitude: Double? = nil, longitude: Double? = nil) {
        self.id        = id
        self.label     = label
        self.address   = address
        self.isDefault = isDefault
        self.latitude  = latitude
        self.longitude = longitude
    }

    /// Build a local SavedAddress from a server-side APIAddress. Uses the
    /// server's UUID string as the SwiftUI `id` so the same row stays stable
    /// across reloads and the local UUID can also be used as the server id
    /// for subsequent PUT / DELETE calls (via `id.uuidString`).
    init?(from api: APIAddress) {
        guard let uuid = UUID(uuidString: api.id) else { return nil }
        let label = AddressLabel(rawValue: api.label.lowercased()) ?? .other
        self.id        = uuid
        self.label     = label
        self.address   = api.address
        self.isDefault = api.isDefault
        self.latitude  = api.latitude
        self.longitude = api.longitude
    }
}

// MARK: - Address Store

@MainActor
class AddressStore: ObservableObject {
    static let shared = AddressStore()

    @Published var addresses: [SavedAddress] = []
    // Latest user-visible error / success message. Screens observe these and
    // present an alert / toast, then call clearError() / clearSuccess() so
    // the next failure or save isn't masked by the previous one.
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let udKey = "shine_saved_addresses"
    private let api = UserAPIService.shared

    nonisolated init() {
        Task { @MainActor in self.loadCache() }
    }

    func clearError()   { errorMessage = nil }
    func clearSuccess() { successMessage = nil }

    var defaultAddress: SavedAddress? {
        addresses.first { $0.isDefault } ?? addresses.first
    }

    /// Fetches the canonical address list from the backend and replaces the
    /// local cache. Safe to call repeatedly (idempotent).
    func reload() async {
        do {
            let remote = try await api.fetchAddresses()
            self.addresses = remote.compactMap { SavedAddress(from: $0) }
            saveCache()
        } catch {
            // Keep the local cache so the screen still has something to show
            // when the user is offline / the server is down.
        }
    }

    /// Adds an address. Optimistically appends to the local list, then sends
    /// to the server in the background and reloads so the row picks up the
    /// server-assigned UUID + canonical fields.
    func add(_ address: SavedAddress) {
        var a = address
        if addresses.isEmpty { a.isDefault = true }
        addresses.append(a)
        saveCache()
        print("[AddressStore] add → label=\(a.label.rawValue) address=\"\(a.address)\" isDefault=\(a.isDefault) lat=\(a.latitude as Any) lng=\(a.longitude as Any)")
        Task { @MainActor in
            do {
                _ = try await api.addAddress(
                    label:     a.label.rawValue,
                    address:   a.address,
                    isDefault: a.isDefault,
                    latitude:  a.latitude,
                    longitude: a.longitude
                )
                print("[AddressStore] add OK")
                successMessage = "Address saved"
                await reload()
            } catch {
                print("[AddressStore] add FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                // Roll back the optimistic insert so the user isn't fooled into
                // thinking it persisted — keeps local and server state in sync.
                addresses.removeAll { $0.id == a.id }
                saveCache()
            }
        }
    }

    /// Removes an address. Optimistic local removal + backend DELETE.
    func remove(_ address: SavedAddress) {
        let wasDefault = address.isDefault
        addresses.removeAll { $0.id == address.id }
        if wasDefault, !addresses.isEmpty {
            addresses[0].isDefault = true
        }
        saveCache()
        Task { @MainActor in
            do {
                try await api.deleteAddress(id: address.id.uuidString)
                print("[AddressStore] delete OK")
                await reload()
            } catch {
                print("[AddressStore] delete FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                await reload()  // pull canonical list so the row reappears
            }
        }
    }

    /// Promotes one address to default. Server-side PUT clears other defaults
    /// automatically (see addresses.js).
    func setDefault(_ address: SavedAddress) {
        for i in addresses.indices {
            addresses[i].isDefault = (addresses[i].id == address.id)
        }
        saveCache()
        Task { @MainActor in
            do {
                _ = try await api.updateAddress(
                    id:        address.id.uuidString,
                    label:     address.label.rawValue,
                    address:   address.address,
                    isDefault: true,
                    latitude:  address.latitude,
                    longitude: address.longitude
                )
                print("[AddressStore] setDefault OK")
                await reload()
            } catch {
                print("[AddressStore] setDefault FAILED: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                await reload()
            }
        }
    }

    // MARK: - Local cache (UserDefaults)

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(addresses) else { return }
        UserDefaults.standard.set(data, forKey: udKey)
    }

    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: udKey),
              let decoded = try? JSONDecoder().decode([SavedAddress].self, from: data)
        else { return }
        addresses = decoded
    }
}

// MARK: - Reviews / Ratings

struct APIReview: Decodable {
    let rating: Int
    let comment: String?
    let reviewerName: String?
    let createdAt: String?
}

struct StaffRatingData: Decodable {
    let averageRating: Double
    let totalCount: Int
    let reviews: [APIReview]?
}

struct APIMyReview: Decodable {
    let id: String
    let rating: Int
    let comment: String?
    let createdAt: String?
}

struct StaffMyRatingData: Decodable {
    let averageRating: Double
    let totalCount: Int
}

struct StaffReviewItem: Decodable, Identifiable {
    let id: String
    let rating: Int
    let comment: String?
    let createdAt: String
    let serviceName: String?
}

struct ReviewPagination: Decodable {
    let total: Int
    let page: Int
    let limit: Int
}

struct StaffMyReviewsData: Decodable {
    let averageRating: Double
    let totalCount: Int
    let reviews: [StaffReviewItem]
    let pagination: ReviewPagination
}

// MARK: - API Address (server-side)

struct APIAddress: Codable, Identifiable {
    let id: String
    let label: String
    let address: String
    let isDefault: Bool
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Sample Data
struct SampleData {
    static let packages: [ServiceCategory: [ServicePackage]] = [
        .laundry: [
            ServicePackage(emoji:"👕", name:"Wash & Fold",    nameAR:"غسيل وطي",       detail:"Per kg · 24h turnaround",       detailAR:"لكل كغ · التسليم خلال ٢٤ ساعة", price:"QAR 12/kg", category:.laundry),
            ServicePackage(emoji:"👔", name:"Dry Cleaning",   nameAR:"تنظيف جاف",      detail:"Per item · delicate care",      detailAR:"لكل قطعة · عناية خاصة",        price:"QAR 25/item",category:.laundry),
            ServicePackage(emoji:"🛏️", name:"Bedding Set",    nameAR:"مفروشات",        detail:"Sheets, pillow covers",         detailAR:"ملاءات وأغطية وسائد",          price:"QAR 65/set", category:.laundry),
            ServicePackage(emoji:"⚡", name:"Express 6h",     nameAR:"اكسبريس ٦ ساعات",detail:"Priority wash & delivery",      detailAR:"غسيل وتوصيل سريع",             price:"QAR 18/kg", category:.laundry),
        ],
        .cleaning: [
            ServicePackage(emoji:"🧹", name:"Regular Clean",  nameAR:"تنظيف عادي",     detail:"2–3 hrs · up to 2 rooms",       detailAR:"٢–٣ ساعات · غرفتان",           price:"QAR 149",   category:.cleaning),
            ServicePackage(emoji:"✨", name:"Deep Clean",      nameAR:"تنظيف عميق",     detail:"4–5 hrs · full home",           detailAR:"٤–٥ ساعات · المنزل كاملاً",    price:"QAR 299",   category:.cleaning),
            ServicePackage(emoji:"🏠", name:"Villa Package",   nameAR:"باقة فيلا",      detail:"Full day · all rooms",          detailAR:"يوم كامل · جميع الغرف",        price:"QAR 349",   category:.cleaning),
            ServicePackage(emoji:"🪟", name:"Window Cleaning", nameAR:"تنظيف نوافذ",    detail:"Interior & exterior",           detailAR:"من الداخل والخارج",             price:"QAR 99",    category:.cleaning),
            ServicePackage(emoji:"📅", name:"Weekly Service",  nameAR:"خدمة أسبوعية",   detail:"3 days a week",                 detailAR:"٣ أيام في الأسبوع",             price:"QAR 500",   category:.cleaning),
        ],
        .officeClean: [
            ServicePackage(emoji:"🧹", name:"Basic Office Clean",    nameAR:"تنظيف مكتب أساسي",   detail:"Up to 100 sqm · 2–3 hrs",    detailAR:"حتى ١٠٠ م² · ٢–٣ ساعات",  price:"QAR 199",    category:.officeClean),
            ServicePackage(emoji:"✨", name:"Deep Office Clean",      nameAR:"تنظيف مكتب عميق",    detail:"Up to 200 sqm · 4–5 hrs",    detailAR:"حتى ٢٠٠ م² · ٤–٥ ساعات",  price:"QAR 349",    category:.officeClean),
            ServicePackage(emoji:"🏢", name:"Full-Floor Package",     nameAR:"باقة الطابق كاملاً", detail:"Large spaces · full day",     detailAR:"مساحات كبيرة · يوم كامل",  price:"QAR 599",    category:.officeClean),
            ServicePackage(emoji:"📅", name:"Weekly Office Contract", nameAR:"عقد أسبوعي",          detail:"Once a week · fixed crew",   detailAR:"مرة أسبوعياً · فريق ثابت", price:"QAR 799/mo", category:.officeClean),
        ],
        .shopClean: [
            ServicePackage(emoji:"🧺", name:"Small Shop Clean",      nameAR:"تنظيف محل صغير",   detail:"Up to 50 sqm · 1–2 hrs",      detailAR:"حتى ٥٠ م² · ١–٢ ساعة",    price:"QAR 129",    category:.shopClean),
            ServicePackage(emoji:"🏪", name:"Standard Shop Clean",   nameAR:"تنظيف محل قياسي",  detail:"Up to 150 sqm · 3–4 hrs",     detailAR:"حتى ١٥٠ م² · ٣–٤ ساعات",  price:"QAR 249",    category:.shopClean),
            ServicePackage(emoji:"✨", name:"Deep Shop Clean",        nameAR:"تنظيف محل عميق",   detail:"Full interior & surfaces",     detailAR:"داخل كامل وجميع الأسطح",   price:"QAR 399",    category:.shopClean),
            ServicePackage(emoji:"📆", name:"Monthly Shop Contract",  nameAR:"عقد شهري للمحل",   detail:"4 visits/month · fixed team",  detailAR:"٤ زيارات/شهر · فريق ثابت", price:"QAR 699/mo", category:.shopClean),
        ],
        .carWash: [
            ServicePackage(emoji:"🚿", name:"Exterior Wash",  nameAR:"غسيل خارجي",     detail:"Quick wash & dry",              detailAR:"غسيل وتجفيف سريع",             price:"QAR 45",    category:.carWash),
            ServicePackage(emoji:"🧽", name:"Interior Clean",  nameAR:"تنظيف داخلي",   detail:"Vacuum & wipe down",            detailAR:"شفط وتلميع",                    price:"QAR 65",    category:.carWash),
            ServicePackage(emoji:"✨", name:"Full Detail",     nameAR:"تلميع كامل",     detail:"Inside + outside",              detailAR:"داخلي وخارجي",                  price:"QAR 119",   category:.carWash),
            ServicePackage(emoji:"🚙", name:"SUV Package",     nameAR:"باقة SUV",       detail:"Large vehicles",                detailAR:"للمركبات الكبيرة",              price:"QAR 149",   category:.carWash),
        ],
        .pest: [
            ServicePackage(emoji:"🦟", name:"Mosquito Treatment",nameAR:"رش البعوض",   detail:"Full home spray",               detailAR:"رش المنزل كاملاً",              price:"QAR 199",   category:.pest),
            ServicePackage(emoji:"🪳", name:"Cockroach Control", nameAR:"مكافحة الصراصير",detail:"Gel + spray combo",          detailAR:"جل + رش",                       price:"QAR 249",   category:.pest),
            ServicePackage(emoji:"🐭", name:"Rodent Control",    nameAR:"مكافحة القوارض",detail:"Traps & sealing",             detailAR:"فخاخ وسد المنافذ",              price:"QAR 299",   category:.pest),
            ServicePackage(emoji:"🛡️", name:"Annual Contract",   nameAR:"عقد سنوي",    detail:"Quarterly visits",              detailAR:"زيارات ربع سنوية",              price:"QAR 799/yr",category:.pest),
        ],
        .bundle: [
            ServicePackage(emoji:"📅", name:"Weekly Bundle",    nameAR:"باقة أسبوعية",  detail:"Laundry + Car",                 detailAR:"غسيل + سيارة",                 price:"QAR 399",   category:.bundle),
            ServicePackage(emoji:"🗓️", name:"Bi-weekly",        nameAR:"كل أسبوعين",   detail:"Every 2 weeks",                 detailAR:"مرة كل أسبوعين",               price:"QAR 449",   category:.bundle),
            ServicePackage(emoji:"📆", name:"Monthly",          nameAR:"شهرية",         detail:"Once a month",                  detailAR:"مرة في الشهر",                  price:"QAR 799",   category:.bundle),
            ServicePackage(emoji:"💎", name:"Premium Annual",   nameAR:"بريميوم سنوي",  detail:"Best value · all services",     detailAR:"أفضل قيمة",                    price:"QAR 5,999/yr",category:.bundle),
        ],
    ]

    static let popularItems: [PopularItem] = [
        PopularItem(emoji:"🧺", name:"Wash & Fold",    nameAR:"غسيل وطي",  rating:4.9, reviews:"(2.3k reviews)", reviewsAR:"(٢٣٠٠ تقييم)", price:"12", unit:"QAR/kg",  unitAR:"ر.ق/كغ", badge:"Hot",  badgeAR:"رائج", badgeColor:.shineCoral,  category:.laundry),
        PopularItem(emoji:"✨", name:"Deep Cleaning",  nameAR:"تنظيف عميق",rating:4.8, reviews:"(1.8k reviews)", reviewsAR:"(١٨٠٠ تقييم)", price:"299",unit:"QAR",      unitAR:"ر.ق",    badge:"New",  badgeAR:"جديد", badgeColor:.shineTeal,   category:.cleaning),
        PopularItem(emoji:"🚿", name:"Full Detail",    nameAR:"تلميع كامل", rating:4.7, reviews:"(940 reviews)",  reviewsAR:"(٩٤٠ تقييم)",  price:"119",unit:"QAR",      unitAR:"ر.ق",    badge:nil,    badgeAR:nil,    badgeColor:.shineAmber,  category:.carWash),
    ]
}
