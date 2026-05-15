import SwiftUI
import MapKit
import CoreLocation

// MARK: - Addresses List View

struct AddressesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @ObservedObject private var store = AddressStore.shared
    @State private var showAddAddress = false
    @State private var pendingDelete: SavedAddress? = nil

    /// When non-nil the view is in selection mode: tapping an address calls this and dismisses.
    var onSelect: ((SavedAddress) -> Void)? = nil

    var isSelectionMode: Bool { onSelect != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color.shineBG.ignoresSafeArea()
                if store.addresses.isEmpty {
                    emptyState
                } else {
                    addressList
                }
            }
            .navigationTitle(appState.isArabic
                ? (isSelectionMode ? "اختر العنوان" : "عناويني")
                : (isSelectionMode ? "Select Address" : "My Addresses"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.shineInk)
                    }
                }
                if !isSelectionMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showAddAddress = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.shineCoral)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddAddress) {
                if #available(iOS 17.0, *) {
                    AddAddressView { saved in store.add(saved) }
                        .environmentObject(appState)
                } else {
                    // Fallback on earlier versions
                }
            }
            // Pull canonical address list from the server on each open. The
            // local UserDefaults cache renders immediately; reload() replaces
            // it with the server-side truth (and picks up new server IDs).
            .task { await store.reload() }
            // Confirm before deleting — easy to lose a saved address by accident.
            .confirmationDialog(
                appState.isArabic ? "حذف العنوان" : "Delete Address",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { target in
                Button(appState.isArabic ? "حذف" : "Delete", role: .destructive) {
                    store.remove(target)
                    pendingDelete = nil
                }
                Button(appState.isArabic ? "إلغاء" : "Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { target in
                let labelText = appState.isArabic ? target.label.titleAR : target.label.title
                Text(appState.isArabic
                     ? "هل أنت متأكد أنك تريد حذف \"\(labelText)\"؟ لا يمكن التراجع عن هذا الإجراء."
                     : "Are you sure you want to delete \"\(labelText)\"? This can't be undone.")
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.shineTealLight)
                    .frame(width: 100, height: 100)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 44))
                    .foregroundColor(.shineTeal)
            }
            VStack(spacing: 8) {
                Text(appState.isArabic ? "لا توجد عناوين محفوظة" : "No saved addresses")
                    .font(ShineFont.displayBold(22))
                    .foregroundColor(.shineInk)
                Text(appState.isArabic ? "أضف عناوين لتسهيل الحجز" : "Add addresses to speed up booking")
                    .font(ShineFont.body(14))
                    .foregroundColor(.shineInk3)
                    .multilineTextAlignment(.center)
            }
            Button {
                showAddAddress = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text(appState.isArabic ? "إضافة عنوان" : "Add Address")
                }
                .font(ShineFont.body(15, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color.shineCoral)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            }
            .padding(.horizontal, ShineSpacing.xl)
            .padding(.top, 8)
        }
        .padding(ShineSpacing.lg)
    }

    // MARK: Address list

    @State private var selectedId: UUID? = nil

    private var addressList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(store.addresses) { addr in
                    if isSelectionMode {
                        Button {
                            selectedId = addr.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onSelect?(addr)
                                dismiss()
                            }
                        } label: {
                            AddressCard(address: addr, isArabic: appState.isArabic,
                                        isSelected: selectedId == addr.id,
                                        onSetDefault: nil, onDelete: nil)
                        }
                        .buttonStyle(.plain)
                    } else {
                        AddressCard(address: addr, isArabic: appState.isArabic) {
                            store.setDefault(addr)
                        } onDelete: {
                            pendingDelete = addr
                        }
                    }
                }

                if !isSelectionMode {
                    Button {
                        showAddAddress = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.shineCoralLight)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.shineCoral)
                            }
                            Text(appState.isArabic ? "إضافة عنوان جديد" : "Add new address")
                                .font(ShineFont.body(15))
                                .foregroundColor(.shineCoral)
                            Spacer()
                        }
                        .padding(ShineSpacing.md)
                        .background(Color.shineSurface)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                        .shineShadowXS()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(ShineSpacing.lg)
            .padding(.top, 4)
        }
    }
}

// MARK: - Address Card

struct AddressCard: View {
    let address: SavedAddress
    let isArabic: Bool
    var isSelected: Bool = false
    var onSetDefault: (() -> Void)?
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(address.label.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: address.label.icon)
                    .font(.system(size: 18))
                    .foregroundColor(address.label.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isArabic ? address.label.titleAR : address.label.title)
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineInk)
                    if address.isDefault {
                        Text(isArabic ? "افتراضي" : "Default")
                            .font(ShineFont.body(10, weight: .semibold))
                            .foregroundColor(.shineTeal)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.shineTealLight)
                            .clipShape(Capsule())
                    }
                }
                Text(address.address)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk3)
                    .lineLimit(2)
            }

            Spacer()

            if onSetDefault != nil || onDelete != nil {
                VStack(spacing: 10) {
                    if !address.isDefault, let onSetDefault {
                        Button(action: onSetDefault) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.shineTeal)
                        }
                    }
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 17))
                                .foregroundColor(.shineCoral.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(ShineSpacing.md)
        .background(isSelected ? Color.shineCoralLight : Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ShineRadius.sm)
                .stroke(
                    isSelected ? Color.shineCoral :
                    (address.isDefault ? Color.shineTeal.opacity(0.35) : Color.clear),
                    lineWidth: isSelected ? 2 : 1.5
                )
        )
        .shineShadowXS()
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Add Address View

@available(iOS 17.0, *)
struct AddAddressView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    let onSave: (SavedAddress) -> Void

    @State private var searchText: String = ""
    @State private var searchResults: [NominatimClient.Hit] = []
    @State private var selectedAddress: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310),
        span:   MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isMapMoving = false
    @State private var isLoadingLocation = false
    @State private var isDragging = false
    @State private var showLabelPicker = false
    @State private var selectedLabel: SavedAddress.AddressLabel = .home
    @FocusState private var searchFocused: Bool

    private let locationService = LocationService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                mapSection
                searchBar
                Spacer(minLength: 0)
            }

            // Content below search bar
            VStack(spacing: 0) {
                Color.clear.frame(height: UIScreen.main.bounds.height * 0.42 + 64)

                if searchText.isEmpty && selectedAddress.isEmpty {
                    emptySearchState
                } else if !searchText.isEmpty {
                    searchResultsList
                } else {
                    confirmedAddressView
                }

                Spacer()
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .top)
        .task { await autoZoomToCurrentLocation() }
        .onChange(of: searchText) { _, new in searchAddress(query: new) }
        .sheet(isPresented: $showLabelPicker) {
            labelPickerSheet
        }
    }

    // MARK: Map

    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            OSMMapView(region: $mapRegion, isMoving: $isMapMoving) { center in
                isDragging = false
                selectedCoordinate = center
                reverseGeocodeCenter(center)
            }
            .frame(height: UIScreen.main.bounds.height * 0.42)
            .onChange(of: isMapMoving) { _, moving in
                if moving { isDragging = true }
            }

            // Fixed center pin — always at the map's focal point
            ZStack {
                // Drop pin: circle head + triangle tail
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color.shineCoral)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.shineCoral.opacity(0.4), radius: 6, x: 0, y: 3)
                        Image(systemName: "mappin.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.shineCoral)
                        .offset(y: -3)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                // Lift the whole pin so its tail tip sits at map center
                .offset(y: isDragging ? -42 : -30)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isDragging)

                // Shadow dot at map center
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 16, height: 6)
                    .scaleEffect(isDragging ? 0.5 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isDragging)
            }
            .frame(maxWidth: .infinity, maxHeight: UIScreen.main.bounds.height * 0.42)
            .allowsHitTesting(false)

            // Current location button
            Button {
                Task { await useCurrentLocation() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 46, height: 46)
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                    if isLoadingLocation {
                        ProgressView()
                            .tint(.shineCoral)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.shineCoral)
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.shineInk)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.shineInk3)

                TextField(
                    appState.isArabic ? "أدخل عنوانك" : "Enter your address",
                    text: $searchText
                )
                .font(ShineFont.body(15))
                .foregroundColor(.shineInk)
                .focused($searchFocused)
                .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.shineInk3)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.shineBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 14)
        .background(Color.shineSurface)
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: Empty state

    private var emptySearchState: some View {
        VStack(spacing: 28) {
            Spacer()

            // Illustration
            ZStack {
                // Map paper shape
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "C8EDE6"), Color(hex: "9DD6CA")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 80)
                    .rotationEffect(.degrees(-8))
                    .offset(y: 10)

                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "E8F5F2"), Color(hex: "C8EDE6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 80)
                    .rotationEffect(.degrees(8))
                    .offset(y: 10)

                // Pin icon
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.shineCoral, Color.shineCoralLight)
                        .shadow(color: Color.shineCoral.opacity(0.25), radius: 8, x: 0, y: 4)
                }
                .offset(y: -8)
            }
            .frame(width: 150, height: 150)

            VStack(spacing: 8) {
                Text(
                    appState.isArabic
                        ? "أدخل عنوانًا للاستكشاف"
                        : "Enter an address to explore\nservices around you"
                )
                .font(ShineFont.body(14))
                .foregroundColor(.shineInk3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }

            // Use current location
            Button {
                Task { await useCurrentLocation() }
            } label: {
                HStack(spacing: 8) {
                    if isLoadingLocation {
                        ProgressView()
                            .tint(.shineCoral)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.shineCoral)
                    }
                    Text(appState.isArabic ? "استخدم موقعي الحالي" : "Use my current location")
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                }
            }
            .disabled(isLoadingLocation)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.shineSurface)
    }

    // MARK: Search results

    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, hit in
                    Button {
                        selectSearchHit(hit)
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.shineCoralLight)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "mappin.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.shineCoral)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hit.displayName)
                                    .font(ShineFont.body(14, weight: .medium))
                                    .foregroundColor(.shineInk)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, ShineSpacing.md)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color.shineSurface)
    }

    // MARK: Confirmed address

    private var confirmedAddressView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.shineTealLight)
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.shineTeal)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(appState.isArabic ? "العنوان المحدد" : "Selected address")
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                    Text(selectedAddress)
                        .font(ShineFont.body(14, weight: .medium))
                        .foregroundColor(.shineInk)
                        .lineLimit(2)
                }
                Spacer()
                Button {
                    selectedAddress = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.shineInk3)
                }
            }
            .padding(ShineSpacing.md)
            .background(Color.shineBG)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))

            Button {
                showLabelPicker = true
            } label: {
                Text(appState.isArabic ? "حفظ العنوان" : "Save Address")
                    .font(ShineFont.body(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.shineCoral)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            }
        }
        .padding(ShineSpacing.md)
        .background(Color.shineSurface)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: Label picker sheet

    private var labelPickerSheet: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.shineInk3.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text(appState.isArabic ? "نوع العنوان" : "Address Type")
                .font(ShineFont.displayBold(22))
                .foregroundColor(.shineInk)

            HStack(spacing: 12) {
                ForEach(SavedAddress.AddressLabel.allCases, id: \.self) { lbl in
                    Button {
                        selectedLabel = lbl
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(selectedLabel == lbl ? lbl.color : Color.shineBG)
                                    .frame(width: 56, height: 56)
                                Image(systemName: lbl.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(selectedLabel == lbl ? .white : lbl.color)
                            }
                            Text(appState.isArabic ? lbl.titleAR : lbl.title)
                                .font(ShineFont.body(13, weight: .medium))
                                .foregroundColor(selectedLabel == lbl ? lbl.color : .shineInk3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedLabel == lbl ? lbl.color.opacity(0.08) : Color.shineSurface)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: ShineRadius.sm)
                                .stroke(
                                    selectedLabel == lbl ? lbl.color.opacity(0.4) : Color.shineBorder,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ShineSpacing.md)

            Button {
                let saved = SavedAddress(
                    label: selectedLabel,
                    address: selectedAddress,
                    latitude: selectedCoordinate.map { $0.latitude },
                    longitude: selectedCoordinate.map { $0.longitude }
                )
                onSave(saved)
                showLabelPicker = false
                dismiss()
            } label: {
                Text(appState.isArabic ? "تأكيد وحفظ" : "Confirm & Save")
                    .font(ShineFont.body(15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.shineCoral)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            }
            .padding(.horizontal, ShineSpacing.md)

            Spacer()
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Actions

    /// On first appear, silently zoom the map to the user's current location.
    private func autoZoomToCurrentLocation() async {
        guard locationService.isAuthorized else { return }
        guard let location = await locationService.getCurrentLocation() else { return }
        let coord = location.coordinate
        await MainActor.run {
            selectedCoordinate = coord
            mapRegion = MKCoordinateRegion(
                center: coord,
                span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        reverseGeocodeCenter(coord)
    }

    /// Reverse-geocode a coordinate (via Nominatim) and update selectedAddress.
    private func reverseGeocodeCenter(_ coordinate: CLLocationCoordinate2D) {
        Task {
            let address = await NominatimClient.reverseGeocode(
                latitude:     coordinate.latitude,
                longitude:    coordinate.longitude,
                languageCode: appState.isArabic ? "ar" : "en"
            )
            await MainActor.run {
                self.selectedAddress = address ?? String(
                    format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude
                )
            }
        }
    }

    private func searchAddress(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            Task { @MainActor in searchResults = [] }
            return
        }
        Task {
            let hits = await NominatimClient.search(
                query: trimmed, languageCode: appState.isArabic ? "ar" : "en"
            )
            await MainActor.run { self.searchResults = hits }
        }
    }

    private func selectSearchHit(_ hit: NominatimClient.Hit) {
        selectedAddress    = hit.displayName
        selectedCoordinate = hit.coordinate
        searchText         = ""
        searchResults      = []
        searchFocused      = false
        withAnimation {
            mapRegion = MKCoordinateRegion(
                center: hit.coordinate,
                span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    private func useCurrentLocation() async {
        await MainActor.run { isLoadingLocation = true }
        guard let location = await locationService.getCurrentLocation() else {
            await MainActor.run { isLoadingLocation = false }
            return
        }
        let coord = location.coordinate
        await MainActor.run {
            isLoadingLocation  = false
            selectedCoordinate = coord
            searchText         = ""
            searchResults      = []
            searchFocused      = false
            withAnimation {
                mapRegion = MKCoordinateRegion(
                    center: coord,
                    span:   MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
        reverseGeocodeCenter(coord)
    }
}

// MARK: - MKPlacemark formatted address helper

private extension MKPlacemark {
    var formattedAddress: String {
        var parts: [String] = []
        if let sub = subThoroughfare  { parts.append(sub) }
        if let th  = thoroughfare     { parts.append(th) }
        if let loc = locality         { parts.append(loc) }
        if let aa  = administrativeArea { parts.append(aa) }
        if let cc  = country          { parts.append(cc) }
        return parts.joined(separator: ", ")
    }
}
