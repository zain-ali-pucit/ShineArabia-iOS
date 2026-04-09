import CoreLocation
import SwiftUI

// MARK: - LocationService
// Singleton CoreLocation wrapper. Requests "when in use" authorization,
// fetches the one-shot current location, and reverse-geocodes it to a
// human-readable address string.

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentAddress: String = ""
    @Published var isResolving: Bool = false

    private let manager = CLLocationManager()
    private var locationCompletions: [(CLLocation?) -> Void] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Public helpers

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Request permission if needed, then fetch current location and return a
    /// formatted address string. Returns "" on failure or denied permission.
    func getCurrentAddress() async -> String {
        if isNotDetermined { requestPermission() }
        guard isAuthorized else { return "" }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let isFirstRequest = self.locationCompletions.isEmpty
                self.locationCompletions.append { location in
                    guard let location else {
                        continuation.resume(returning: "")
                        return
                    }
                    Task {
                        let address = await self.reverseGeocode(location)
                        await MainActor.run {
                            self.currentAddress = address
                            self.isResolving = false
                        }
                        continuation.resume(returning: address)
                    }
                }
                if isFirstRequest {
                    self.isResolving = true
                    self.manager.requestLocation()
                }
            }
        }
    }

    /// Request permission if needed, then fetch current raw location.
    /// Returns nil on failure or denied permission.
    func getCurrentLocation() async -> CLLocation? {
        if isNotDetermined { requestPermission() }
        guard isAuthorized else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let isFirstRequest = self.locationCompletions.isEmpty
                self.locationCompletions.append { location in
                    continuation.resume(returning: location)
                }
                if isFirstRequest {
                    self.manager.requestLocation()
                }
            }
        }
    }

    // MARK: - Private

    private func reverseGeocode(_ location: CLLocation) async -> String {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                guard let place = placemarks?.first else {
                    continuation.resume(returning: String(format: "%.4f, %.4f",
                                                         location.coordinate.latitude,
                                                         location.coordinate.longitude))
                    return
                }
                continuation.resume(returning: place.fullAddress(fallback: location.coordinate))
            }
        }
    }
}

// MARK: - CLPlacemark full address helper

extension CLPlacemark {
    /// Builds a complete, human-readable address string from a placemark.
    /// Falls back to coordinate string if nothing useful is found.
    func fullAddress(fallback coordinate: CLLocationCoordinate2D) -> String {
        var parts: [String] = []

        // Street: "12 King Fahd Road"
        if let number = subThoroughfare, let street = thoroughfare {
            parts.append("\(number) \(street)")
        } else if let street = thoroughfare {
            parts.append(street)
        } else if let name = name,
                  !name.contains(","),
                  !(name.first?.isNumber ?? false) {
            // Named place (shop, landmark) when no street info
            parts.append(name)
        }

        // District / neighbourhood
        if let district = subLocality { parts.append(district) }

        // City
        if let city = locality { parts.append(city) }

        // State / province (skip if same as city to avoid duplication)
        if let state = administrativeArea, state != locality { parts.append(state) }

        // Country
        if let country = country { parts.append(country) }

        if parts.isEmpty {
            return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let completions = locationCompletions
        locationCompletions = []
        completions.forEach { $0(location) }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isResolving = false
            let completions = self.locationCompletions
            self.locationCompletions = []
            completions.forEach { $0(nil) }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
