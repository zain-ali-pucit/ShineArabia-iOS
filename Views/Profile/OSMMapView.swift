import SwiftUI
import MapKit
import CoreLocation

// MARK: - OSM Tile Overlay
// Forces MKMapView to render OpenStreetMap raster tiles instead of Apple's
// default tiles. OSM's usage policy requires a meaningful User-Agent on every
// tile request, so we override `loadTile(...)` to attach one.
final class OSMTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        canReplaceMapContent = true   // hide Apple's tiles
        minimumZ             = 0
        maximumZ             = 19
        tileSize             = CGSize(width: 256, height: 256)
    }

    override func loadTile(
        at path: MKTileOverlayPath,
        result: @escaping (Data?, Error?) -> Void
    ) {
        var request = URLRequest(url: self.url(forTilePath: path))
        request.setValue(NominatimClient.userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, error in
            result(data, error)
        }.resume()
    }
}

// MARK: - SwiftUI wrapper around MKMapView with OSM tiles
// Replaces both the `MapReader` in LocationPickerView and the SwiftUI
// `Map(position:)` in AddressesView so both screens render identical OSM tiles.
struct OSMMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isMoving: Bool
    let onSettled: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.addOverlay(OSMTileOverlay(), level: .aboveLabels)
        map.setRegion(region, animated: false)
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Only animate when the SwiftUI-owned region diverges from the map's
        // current region (e.g. search-result pan) — otherwise we'd fight the
        // user's drag gesture.
        let coordEqual = abs(map.region.center.latitude  - region.center.latitude)  < 1e-5 &&
                         abs(map.region.center.longitude - region.center.longitude) < 1e-5
        if !coordEqual {
            map.setRegion(region, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OSMMapView
        init(_ parent: OSMMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            DispatchQueue.main.async { self.parent.isMoving = true }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.region.center
            DispatchQueue.main.async {
                self.parent.isMoving = false
                self.parent.region   = mapView.region
                self.parent.onSettled(center)
            }
        }
    }
}

// MARK: - Nominatim HTTP client
// Free OSM-hosted geocoder. No API key, ~1 req/sec per IP. We must send a
// User-Agent that identifies the application per their usage policy:
// https://operations.osmfoundation.org/policies/nominatim/
enum NominatimClient {
    static let userAgent = "ShineArabia/com.shinearabia.app"
    private static let base = URL(string: "https://nominatim.openstreetmap.org")!

    struct Hit {
        let coordinate: CLLocationCoordinate2D
        let displayName: String
    }

    /// Reverse-geocode a coordinate to a human-readable address.
    static func reverseGeocode(
        latitude: Double,
        longitude: Double,
        languageCode: String
    ) async -> String? {
        var components = URLComponents(url: base.appendingPathComponent("reverse"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "lat",    value: String(latitude)),
            URLQueryItem(name: "lon",    value: String(longitude)),
            URLQueryItem(name: "zoom",   value: "18"),
            URLQueryItem(name: "addressdetails", value: "1"),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let name = json["display_name"] as? String,
                !name.isEmpty
            else { return nil }
            return name
        } catch {
            return nil
        }
    }

    /// Forward-search a free-text query. Returns up to 5 hits.
    static func search(
        query: String,
        languageCode: String,
        limit: Int = 5
    ) async -> [Hit] {
        var components = URLComponents(url: base.appendingPathComponent("search"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "q",      value: query),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(languageCode, forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return arr.compactMap { obj in
                guard
                    let latStr = obj["lat"] as? String,
                    let lonStr = obj["lon"] as? String,
                    let lat = Double(latStr),
                    let lon = Double(lonStr)
                else { return nil }
                let name = (obj["display_name"] as? String) ?? query
                return Hit(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                           displayName: name)
            }
        } catch {
            return []
        }
    }
}
