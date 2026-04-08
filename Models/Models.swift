import SwiftUI

// MARK: - User
struct User: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    var address: String
    var avatarInitials: String { String(name.prefix(2)).uppercased() }
}

// MARK: - Service Category
enum ServiceCategory: String, CaseIterable, Identifiable {
    case laundry   = "laundry"
    case cleaning  = "cleaning"
    case carWash   = "carwash"
    case pest      = "pest"
    case bundle    = "bundle"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .laundry:  return "🧺"
        case .cleaning: return "🧹"
        case .carWash:  return "🚗"
        case .pest:     return "🪲"
        case .bundle:   return "🎁"
        }
    }

    var title: String {
        switch self {
        case .laundry:  return "Laundry"
        case .cleaning: return "Home Clean"
        case .carWash:  return "Car Wash"
        case .pest:     return "Pest Control"
        case .bundle:   return "Bundle"
        }
    }

    var titleAR: String {
        switch self {
        case .laundry:  return "الغسيل"
        case .cleaning: return "تنظيف المنزل"
        case .carWash:  return "غسيل سيارة"
        case .pest:     return "مكافحة الحشرات"
        case .bundle:   return "الباقة"
        }
    }

    var optionsCount: String {
        switch self {
        case .laundry:  return "8 options"
        case .cleaning: return "6 options"
        case .carWash:  return "5 options"
        case .pest:     return "4 options"
        case .bundle:   return "4 plans"
        }
    }

    var color: Color {
        switch self {
        case .laundry:  return .shineCoral
        case .cleaning: return .shineTeal
        case .carWash:  return .shineAmber
        case .pest:     return .shineLavender
        case .bundle:   return .shineCoral
        }
    }

    var softColor: Color {
        switch self {
        case .laundry:  return .shineCoralLight
        case .cleaning: return .shineTealLight
        case .carWash:  return .shineAmberLight
        case .pest:     return .shineLavLight
        case .bundle:   return .shineCoralLight
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
        self.id          = UUID()
        self.apiId       = api.id
        self.emoji       = api.emoji
        self.name        = api.nameEn
        self.nameAR      = api.nameAr
        self.detail      = api.detailEn
        self.detailAR    = api.detailAr
        self.price       = api.priceDisplay
        self.priceAmount = api.priceAmount
        self.category    = ServiceCategory(rawValue: api.categorySlug) ?? .laundry
    }
}

// MARK: - Popular Item
struct PopularItem: Identifiable {
    let id: UUID
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
        self.emoji    = api.emoji
        self.name     = api.nameEn
        self.nameAR   = api.nameAr
        self.rating   = api.rating
        self.reviews  = "\(api.reviewCount) orders"
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
    }

    // Convenience init for local/mock creation
    init(id: UUID = UUID(), apiId: String? = nil, serviceCategory: String, packageName: String, packageNameAR: String = "", scheduledDate: Date, address: String, status: BookingStatus, price: String, priceAmount: Double = 0) {
        self.id              = id
        self.apiId           = apiId
        self.serviceCategory = serviceCategory
        self.packageName     = packageName
        self.packageNameAR   = packageNameAR
        self.scheduledDate   = scheduledDate
        self.address         = address
        self.status          = status
        self.price           = price
        self.priceAmount     = priceAmount
    }

    // Init from API response
    init(from api: APIBooking, language: AppLanguage = .english) {
        self.id              = UUID()
        self.apiId           = api.id
        self.serviceCategory = api.serviceCategory
        self.packageName     = api.packageNameEn
        self.packageNameAR   = api.packageNameAr
        self.scheduledDate   = api.scheduledDate
        self.address         = api.address
        self.status          = BookingStatus(rawValue: api.status) ?? .pending
        self.price           = "QAR \(Int(api.priceAmount))"
        self.priceAmount     = api.priceAmount
    }
}

// MARK: - Bundle DTOs

struct APIBundleComponent: Codable, Identifiable {
    let id: String
    let emoji: String
    let nameEn: String
    let nameAr: String
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
            id:      UUID(uuidString: id) ?? UUID(),
            name:    name,
            email:   email,
            phone:   phone    ?? "",
            address: address  ?? ""
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
    RewardTier(points: 50,   reward: "1 kg Laundry Free",        rewardAR: "١ كغ غسيل مجاني",
               icon: "🧺", detail: "Wash & Fold · 1 kg",               detailAR: "غسيل وطي · ١ كغ"),
    RewardTier(points: 100,  reward: "2 kg Laundry Free",        rewardAR: "٢ كغ غسيل مجاني",
               icon: "🧺", detail: "Wash & Fold · 2 kg",               detailAR: "غسيل وطي · ٢ كغ"),
    RewardTier(points: 300,  reward: "Exterior Wash + 2 kg",     rewardAR: "غسيل خارجي + ٢ كغ",
               icon: "🚿", detail: "Car exterior wash + 2 kg laundry",  detailAR: "غسيل خارجي للسيارة + ٢ كغ غسيل"),
    RewardTier(points: 500,  reward: "Interior & Exterior Wash", rewardAR: "غسيل داخلي وخارجي",
               icon: "✨", detail: "Full interior + exterior car wash",  detailAR: "غسيل كامل داخلي وخارجي للسيارة"),
    RewardTier(points: 1000, reward: "Full Detail",              rewardAR: "تلميع كامل",
               icon: "🏆", detail: "Complete car detailing package",     detailAR: "باقة تلميع شاملة للسيارة"),
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
}

// MARK: - Address Store

class AddressStore: ObservableObject {
    static let shared = AddressStore()

    @Published var addresses: [SavedAddress] = []

    private let udKey = "shine_saved_addresses"

    init() { load() }

    var defaultAddress: SavedAddress? {
        addresses.first { $0.isDefault } ?? addresses.first
    }

    func add(_ address: SavedAddress) {
        var a = address
        if addresses.isEmpty { a.isDefault = true }
        addresses.append(a)
        save()
    }

    func remove(_ address: SavedAddress) {
        let wasDefault = address.isDefault
        addresses.removeAll { $0.id == address.id }
        if wasDefault, !addresses.isEmpty {
            addresses[0].isDefault = true
        }
        save()
    }

    func setDefault(_ address: SavedAddress) {
        for i in addresses.indices {
            addresses[i].isDefault = (addresses[i].id == address.id)
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(addresses) else { return }
        UserDefaults.standard.set(data, forKey: udKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: udKey),
              let decoded = try? JSONDecoder().decode([SavedAddress].self, from: data)
        else { return }
        addresses = decoded
    }
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
            ServicePackage(emoji:"📅", name:"Weekly Bundle",    nameAR:"باقة أسبوعية",  detail:"Laundry + Clean + Car",         detailAR:"غسيل + تنظيف + سيارة",         price:"QAR 399",   category:.bundle),
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
