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
    private var locationCompletion: ((CLLocation?) -> Void)?

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
                self.isResolving = true
                self.locationCompletion = { location in
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
                self.manager.requestLocation()
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
                self.locationCompletion = { location in
                    continuation.resume(returning: location)
                }
                self.manager.requestLocation()
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
                var parts: [String] = []
                if let name = place.name,
                   !name.contains(","),
                   !(name.first?.isNumber ?? false) { parts.append(name) }
                if let sub = place.subLocality  { parts.append(sub) }
                if let city = place.locality    { parts.append(city) }
                if parts.isEmpty, let city = place.locality { parts.append(city) }
                continuation.resume(returning: parts.joined(separator: ", "))
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let completion = locationCompletion
        locationCompletion = nil
        completion?(location)
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isResolving = false
            let completion = self.locationCompletion
            self.locationCompletion = nil
            completion?(nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
