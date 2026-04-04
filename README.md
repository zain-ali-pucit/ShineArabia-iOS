# ShineArabia iOS

Premium home services app for the Arab market. Book laundry, home cleaning, car wash, pest control, and bundle plans — in English or Arabic.

---

## App Overview

| Feature | Details |
|---------|---------|
| Platform | iOS |
| Language | Swift / SwiftUI |
| Min iOS | iOS 16 |
| Localization | English + Arabic (RTL) |
| Architecture | MVVM |
| Networking | async/await URLSession |
| Auth | JWT (stored in UserDefaults) |

---

## Project Structure

```
ShineArabia-iOS/
├── App/
│   ├── ShineArabiaApp.swift     # @main entry point
│   ├── AppState.swift           # Global state (auth, language, tab, user)
│   └── RootView.swift           # Routes: Splash → Onboarding → Login → Main
│
├── Models/
│   └── Models.swift             # User, ServicePackage, PopularItem, Booking + API conversions
│
├── ViewModels/
│   ├── AuthViewModel.swift      # Login / register logic
│   ├── HomeViewModel.swift      # Service discovery, package loading, search
│   └── BookingViewModel.swift   # Create, fetch, cancel bookings
│
├── Services/                    # API layer (all async/await)
│   ├── APIClient.swift          # Generic HTTP client, auto token refresh
│   ├── AuthService.swift        # Auth endpoints
│   ├── ServiceAPIService.swift  # Services & packages endpoints
│   ├── BookingAPIService.swift  # Bookings & promo endpoints
│   └── UserAPIService.swift     # User profile & stats endpoints
│
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Home/
│   │   ├── HomeView.swift       # Main discovery screen
│   │   └── ExploreView.swift    # Browse all services
│   ├── Services/
│   │   └── ServiceBottomSheet.swift  # Package selection sheet
│   ├── Booking/
│   │   └── OrdersView.swift     # Active & past orders
│   ├── Profile/
│   │   └── ProfileView.swift    # User profile & settings
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Splash/
│   │   └── SplashView.swift
│   └── Components/
│       ├── MainTabView.swift    # Floating tab bar
│       └── SharedComponents.swift
│
├── Resources/
│   └── DesignSystem.swift       # Colors, typography, spacing, shadows
│
└── Utilities/
    └── Extensions.swift         # View helpers, localization, date formatting
```

---

## Getting Started

### Prerequisites

- Xcode 15 or later
- iOS 16+ simulator or device
- ShineArabia backend running on `http://localhost:3000`

### Run the App

1. Open `ShineArabia-iOS.xcodeproj` in Xcode
2. Select a simulator (iPhone 15 or later recommended)
3. Press **Cmd + R**

> The app connects to `http://localhost:3000/api` by default. Make sure the backend server is running before launching.

### Change the API Base URL

Open `Services/APIClient.swift` and update:

```swift
enum APIConfig {
    static let baseURL = "http://localhost:3000/api"  // ← change this
}
```

For a real device on the same Wi-Fi network, replace `localhost` with your Mac's local IP address (e.g. `192.168.1.x`).

---

## App Flow

```
Launch
  └── SplashView (2s animation)
        └── hasCompletedOnboarding?
              ├── No  → OnboardingView → sets flag → LoginView
              └── Yes → isAuthenticated?
                          ├── No  → LoginView
                          └── Yes → MainTabView
                                      ├── Home
                                      ├── Explore
                                      ├── Orders
                                      └── Profile
```

---

## Services

| Category | Slug | Packages |
|----------|------|----------|
| Laundry | `laundry` | Wash & Fold, Dry Cleaning, Bedding Set, Express 6h |
| Home Clean | `cleaning` | Regular Clean, Deep Clean, Villa Package, Window Cleaning |
| Car Wash | `carwash` | Exterior Wash, Interior Clean, Full Detail, SUV Package |
| Pest Control | `pest` | Mosquito Treatment, Cockroach Control, Rodent Control, Annual Contract |
| Bundle | `bundle` | Weekly, Bi-weekly, Monthly, Premium Annual |

---

## Design System

Defined in `Resources/DesignSystem.swift`.

### Colors

| Name | Hex | Usage |
|------|-----|-------|
| `shineCoral` | `#E8715A` | Primary CTA, Laundry |
| `shineTeal` | `#2D8C7A` | Cleaning, success states |
| `shineAmber` | `#D4893A` | Car Wash, ratings |
| `shineLavender` | `#7B6FA0` | Pest Control |
| `shineBG` | `#F7F5F2` | App background |
| `shineInk` | `#1C1917` | Primary text |

### Typography

| Font | Usage |
|------|-------|
| `CormorantGaramond` | Display headings |
| `Outfit` | Body & UI text |
| `NotoKufiArabic` | Arabic text fallback |

---

## Authentication

- Tokens stored in `UserDefaults` via `TokenStore` in `Services/APIClient.swift`
- Access token (7 days) is automatically refreshed on 401 responses
- Sign out calls `AppState.signOut()` → clears tokens → redirects to `LoginView`

> For production, migrate `TokenStore` to use the iOS Keychain.

---

## Localization

Every string has an English and Arabic variant. The language is toggled via the EN/عر button in the top-right corner.

- Arabic enables RTL layout via the `.arabicLayout()` modifier
- Strings resolved through `Loc.string("key", isArabic:)` in `Utilities/Extensions.swift`
- String bundles: `en.lproj` and `ar.lproj`

---

## Booking Flow

1. User taps a service category on Home or Explore
2. `ServiceBottomSheet` loads packages from `GET /api/services/packages/:slug`
3. User selects a package and taps **Book Now**
4. `BookingViewModel.createBooking()` posts to `POST /api/bookings`
5. Booking appears in the **Orders** tab under Active

---

## Promo Codes

These codes are seeded in the database for testing:

| Code | Discount |
|------|----------|
| `SHINE30` | 30% off |
| `WELCOME` | 20% off |
| `FLAT50` | QAR 50 off |
| `NEWUSER` | 15% off |
