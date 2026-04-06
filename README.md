# ShineArabia iOS

Premium home-services app for the Arab market. Book laundry, home cleaning, car wash, pest control, and bundle plans — in English or Arabic. Includes a dedicated Manager role for booking oversight and real-time Firebase push notifications.

---

## App Overview

| | |
|---|---|
| Platform | iOS 16+ |
| Language | Swift / SwiftUI |
| Architecture | MVVM |
| Networking | `async/await` + `URLSession` |
| Auth | JWT (access + refresh tokens) |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Localization | English + Arabic (RTL) |

---

## Project Structure

```
ShineArabia-iOS/
├── App/
│   ├── ShineArabiaApp.swift        # @main — Firebase init, APNs/FCM delegate, AppDelegate
│   ├── AppState.swift              # Global state: auth, language, tab, userRole
│   └── RootView.swift              # Routes: Splash → Onboarding → MainTabView or ManagerView
│
├── Models/
│   └── Models.swift                # User, ServicePackage, Booking, BookingStatus, PopularItem
│
├── ViewModels/
│   ├── AuthViewModel.swift         # Login, register, Apple/Google/Facebook sign-in
│   ├── HomeViewModel.swift         # Service discovery, search (debounced), popular items
│   ├── BookingViewModel.swift      # Create, fetch, cancel, reschedule bookings
│   └── ManagerViewModel.swift      # Admin booking list, status updates, 30s polling, notifications
│
├── Services/
│   ├── APIClient.swift             # Generic HTTP client, auto token refresh on 401
│   ├── AuthService.swift           # Auth endpoints — login/register/social/fetchMe
│   ├── ServiceAPIService.swift     # Services, packages, popular, search
│   ├── BookingAPIService.swift     # Bookings + promo validation
│   ├── UserAPIService.swift        # Profile, stats, password, FCM token registration
│   └── ManagerAPIService.swift     # Admin booking list, status update, admin FCM token
│
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Home/
│   │   ├── HomeView.swift          # Promo banner, service grid, popular list
│   │   └── ExploreView.swift       # Full service browse + search results
│   ├── Services/
│   │   └── ServiceBottomSheet.swift  # Package selector, date picker, promo field
│   ├── Booking/
│   │   └── OrdersView.swift        # Active / Past orders, BookingCard, RescheduleSheet
│   ├── Profile/
│   │   └── ProfileView.swift       # Avatar, stats, settings, sign-out
│   ├── Manager/
│   │   └── ManagerView.swift       # Manager-only screen: booking list + status controls
│   ├── Onboarding/
│   │   └── OnboardingView.swift    # 3-slide paged onboarding
│   ├── Splash/
│   │   └── SplashView.swift        # Animated logo splash
│   └── Components/
│       ├── MainTabView.swift       # Floating pill tab bar (Home/Explore/Orders/Profile)
│       └── SharedComponents.swift  # StatusBadge, ShineButton, BadgePill, EmptyState…
│
├── Resources/
│   ├── DesignSystem.swift          # Colors, ShineFont, ShineSpacing, ShineRadius, shadows
│   ├── Assets.xcassets/
│   ├── GoogleService-Info.plist    # Firebase configuration (add before building)
│   ├── en.lproj/Localizable.strings
│   └── ar.lproj/Localizable.strings
│
└── Utilities/
    └── Extensions.swift            # arabicLayout(), Loc helper, DateFormatter
```

---

## Getting Started

### Prerequisites

- Xcode 15 or later
- iOS 16+ simulator or physical device
- ShineArabia backend running on `http://localhost:3000`
- `GoogleService-Info.plist` added to the Xcode project (see Firebase setup below)

### Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com) → your project → **Project Settings**
2. Under **Your apps**, select the iOS app and download `GoogleService-Info.plist`
3. Drag it into Xcode under the `Resources/` group (check **Copy items if needed**)
4. In Xcode → **Signing & Capabilities** → add **Push Notifications** and **Background Modes → Remote notifications**

### Run the App

```bash
# Open in Xcode
open ShineArabia-iOS.xcodeproj
```

Select a simulator or device, then press **Cmd + R**.

> Push notifications only work on a **physical device** (not simulator). The app must be signed with an Apple Developer account that has APNs enabled.

### API Base URL

Defined in `Services/APIClient.swift`:

```swift
#if DEBUG
static let baseURL = "http://127.0.0.1:3000/api"   // local backend
#else
static let baseURL = "https://www.shine-arabia.com/api"
#endif
```

For a real device on the same Wi-Fi, change `127.0.0.1` to your Mac's local IP.

---

## App Flow

### Customer

```
Launch
  └─ SplashView (animated logo)
       └─ hasCompletedOnboarding?
             ├─ No  → OnboardingView → MainTabView
             └─ Yes → isAuthenticated?
                           ├─ No  → shows Login sheet on booking attempt
                           └─ Yes → MainTabView
                                      ├─ Home    — service cards, promo banner, popular items
                                      ├─ Explore — full grid + search
                                      ├─ Orders  — active & past bookings
                                      └─ Profile — stats, settings, sign-out
```

### Manager (role: admin)

```
Launch
  └─ SplashView
       └─ ManagerView (no tab bar, no home, no explore — bookings only)
             ├─ Filter pills: All / Pending / Confirmed / In Progress / Completed / Cancelled
             ├─ Booking cards: customer name, service, date, address, price, status
             ├─ Status action buttons per card (valid transitions only)
             ├─ Pull-to-refresh
             ├─ Notification bell — badge on new booking
             └─ Sign-out button
```

---

## Manager Role

The manager role is stored on the backend as `role = "admin"` on the users table.

### How it works

1. On login / session restore, `APIUser.role` is read and stored in `AppState.userRole`
2. `AppState.isManager` is `true` when `userRole == "admin"`
3. `RootView` routes to `ManagerView` instead of `MainTabView` when `isManager` is `true`

### Manager credentials (dev)

| Field | Value |
|---|---|
| Email | `manager@shinearabia.com` |
| Password | `ShineArabia321` |

### Booking status transitions (manager)

| Current status | Actions available |
|---|---|
| Pending | Confirm, Cancel |
| Confirmed | Start, Cancel |
| In Progress | Complete, Cancel |
| Completed | — |
| Cancelled | — |

---

## Push Notifications (Firebase FCM)

### How it works

1. On first launch the app requests notification permission via `UNUserNotificationCenter`
2. iOS registers with APNs → `AppDelegate` forwards the raw APNs token to Firebase (`Messaging.messaging().apnsToken`)
3. Firebase maps the APNs token to an FCM token and delivers it via `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)`
4. The FCM token is:
   - Persisted in `UserDefaults` under `fcm_token`
   - Sent to `POST /api/users/device-token` for all authenticated users
   - Sent to `POST /api/admin/devices` for manager users (so the backend knows where to push booking alerts)
5. When a customer creates a booking the backend fires an FCM multicast to all `admin_device_tokens` — the manager device receives a banner notification instantly

### Notification name helpers (in `ShineArabiaApp.swift`)

| Name | Purpose |
|---|---|
| `.fcmTokenReceived` | Broadcast when a new FCM token is ready |
| `.pushNotificationTapped` | Broadcast when the user taps a notification |
| `.deviceTokenReceived` | Legacy APNs token broadcast |

### Foreground display

`UNUserNotificationCenterDelegate.willPresent` is configured to show `.banner`, `.sound`, and `.badge` even when the app is in the foreground.

---

## Services

| Category | Slug | Packages |
|---|---|---|
| Laundry | `laundry` | Wash & Fold, Dry Cleaning, Bedding Set, Express 6h |
| Home Clean | `cleaning` | Regular Clean, Deep Clean, Villa Package, Window Cleaning |
| Car Wash | `carwash` | Exterior Wash, Interior Clean, Full Detail, SUV Package |
| Pest Control | `pest` | Mosquito Treatment, Cockroach Control, Rodent Control, Annual Contract |
| Bundle | `bundle` | Weekly, Bi-weekly, Monthly, Premium Annual |

---

## Booking Flow

1. User taps a service card on Home or Explore
2. `ServiceBottomSheet` loads packages from `GET /api/services/packages/:slug`
3. User picks a package, date, and optional promo code → taps **Book Now**
4. If unauthenticated, Login sheet appears; booking resumes automatically after sign-in
5. `BookingViewModel.createBooking()` posts to `POST /api/bookings`
6. Backend saves the booking and fires an FCM push to the manager device
7. Booking appears in the **Orders** tab under Active

---

## Promo Codes

| Code | Type | Value |
|---|---|---|
| `SHINE30` | Percentage | 30% off |
| `WELCOME` | Percentage | 20% off (auto-applied to first booking) |
| `FLAT50` | Fixed | QAR 50 off |
| `NEWUSER` | Percentage | 15% off |

---

## Authentication

- Email / password, Apple Sign-In, Google Sign-In, Facebook Login
- Access token (7 days) is automatically refreshed on 401 responses inside `APIClient`
- Tokens stored in `UserDefaults` via `TokenStore` (migrate to Keychain for production)
- Sign-out clears tokens, `currentUser`, and `userRole` from `AppState`

---

## Design System (`Resources/DesignSystem.swift`)

### Colors

| Token | Hex | Usage |
|---|---|---|
| `shineCoral` | `#E8715A` | Primary CTA, Laundry |
| `shineTeal` | `#2D8C7A` | Cleaning, confirmed/completed states |
| `shineAmber` | `#D4893A` | Car Wash, pending states |
| `shineLavender` | `#7B6FA0` | Pest Control |
| `shineBG` | `#F7F5F2` | App background |
| `shineInk` | `#1C1917` | Primary text |

### Typography

| Font | Usage |
|---|---|
| `CormorantGaramond` | Display / editorial headings |
| `Outfit` | Body and UI text |
| `NotoKufiArabic` | Arabic text fallback |

---

## Localization

Toggle between English and Arabic with the **EN / عر** pill in the top-right corner.

- Arabic activates RTL layout via the `.arabicLayout()` SwiftUI modifier
- Strings resolved through `Loc.string("key", isArabic:)` in `Utilities/Extensions.swift`
- String bundles: `en.lproj/Localizable.strings` and `ar.lproj/Localizable.strings`
