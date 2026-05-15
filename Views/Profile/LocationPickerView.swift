import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    let isArabic: Bool
    let onLocationPicked: (_ address: String, _ latitude: Double, _ longitude: Double) -> Void

    @Environment(\.dismiss) private var dismiss

    // Default to Doha, Qatar
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310),
        span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedAddress: String = ""
    @State private var selectedLat: Double = 25.2854
    @State private var selectedLng: Double = 51.5310
    @State private var isReverseGeocoding = false
    @State private var searchQuery: String = ""
    @State private var isSearching = false
    @State private var isMoving = false
    @State private var pinLifted = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            // Map — OpenStreetMap tiles overlaid on MKMapView
            OSMMapView(region: $region, isMoving: $isMoving) { center in
                handleCameraSettled(at: center)
            }
            .ignoresSafeArea()

            // Center pin
            VStack(spacing: 2) {
                if pinLifted {
                    Capsule()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 20, height: 6)
                }
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 36))
                    .foregroundColor(.shineCoral)
                    .offset(y: pinLifted ? -14 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pinLifted)
            }
            .offset(y: -20)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top bar: back + search
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer()

                // Bottom confirm card
                bottomCard
                    .padding(16)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: isMoving) { moving in
            withAnimation { pinLifted = moving }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.shineInk)
                    .frame(width: 42, height: 42)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.shineInk.opacity(0.15), radius: 6, x: 0, y: 2)
            }

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.shineInk3)
                TextField(
                    isArabic ? "ابحث عن موقع..." : "Search for a location...",
                    text: $searchQuery
                )
                .focused($searchFocused)
                .font(ShineFont.body(14))
                .foregroundColor(.shineInk)
                .submitLabel(.search)
                .onSubmit { performSearch() }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.shineInk3)
                    }
                }
                if isSearching {
                    ProgressView().scaleEffect(0.7).tint(.shineCoral)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.shineInk.opacity(0.15), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Address row
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 22))
                    .foregroundColor(.shineCoral)
                    .frame(width: 44, height: 44)
                    .background(Color.shineCoralLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isArabic ? "الموقع المحدد" : "SELECTED LOCATION")
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                        .kerning(0.5)

                    if isReverseGeocoding {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7).tint(.shineCoral)
                            Text(isArabic ? "جارٍ التحديد..." : "Locating...")
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineInk3)
                        }
                    } else {
                        Text(selectedAddress.isEmpty
                             ? (isArabic ? "حرّك الخريطة لتحديد موقعك" : "Drag the map to pick a location")
                             : selectedAddress)
                            .font(ShineFont.body(14, weight: selectedAddress.isEmpty ? .regular : .semibold))
                            .foregroundColor(selectedAddress.isEmpty ? .shineInk3 : .shineInk)
                            .lineLimit(3)
                    }
                }
                Spacer()
            }

            // Confirm button
            Button {
                if !selectedAddress.isEmpty {
                    onLocationPicked(selectedAddress, selectedLat, selectedLng)
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text(isArabic ? "استخدام هذا الموقع" : "Use This Location")
                        .font(ShineFont.body(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(canConfirm ? Color.shineCoral : Color.shineInk3.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canConfirm)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.shineInk.opacity(0.18), radius: 16, x: 0, y: 6)
    }

    private var canConfirm: Bool {
        !selectedAddress.isEmpty && !isReverseGeocoding
    }

    // MARK: - Actions

    private func handleCameraSettled(at center: CLLocationCoordinate2D) {
        selectedLat = center.latitude
        selectedLng = center.longitude
        Task { await reverseGeocode(center) }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        isReverseGeocoding = true
        defer { Task { @MainActor in isReverseGeocoding = false } }
        let address = await NominatimClient.reverseGeocode(
            latitude:     coordinate.latitude,
            longitude:    coordinate.longitude,
            languageCode: isArabic ? "ar" : "en"
        )
        if let address {
            await MainActor.run { selectedAddress = address }
        }
    }

    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        searchFocused = false
        isSearching = true

        Task {
            defer { Task { @MainActor in isSearching = false } }
            let hits = await NominatimClient.search(
                query: query, languageCode: isArabic ? "ar" : "en", limit: 1
            )
            guard let hit = hits.first else { return }
            await MainActor.run {
                let coord = hit.coordinate
                selectedLat     = coord.latitude
                selectedLng     = coord.longitude
                selectedAddress = hit.displayName
                withAnimation {
                    region = MKCoordinateRegion(
                        center: coord,
                        span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
}
