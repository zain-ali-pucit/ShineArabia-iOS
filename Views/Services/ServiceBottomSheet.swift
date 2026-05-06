import SwiftUI

struct ServiceBottomSheet: View {
    let category: ServiceCategory
    let packages: [ServicePackage]
    let customBundleComponents: [ServicePackage]
    @Binding var selectedPackages: [ServicePackage]
    let isArabic: Bool
    let isLoading: Bool
    var categoryIconEmoji: String? = nil  // API icon — overrides enum fallback when set
    let onBook: () -> Void

    @EnvironmentObject var bookingVM: BookingViewModel
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.dismiss) var dismiss

    @State private var promoInput: String = ""
    @State private var promoMsg: String?
    @State private var promoIsValid: Bool = false
    @State private var isValidating: Bool = false

    private var displayedPackages: [ServicePackage] {
        packages
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Scrollable content (everything above the sticky footer) ─
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Sheet header ─────────────────────────────────
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(category.softColor)
                                    .frame(width: 64, height: 64)
                                Text(categoryIconEmoji ?? category.icon)  // prefer API icon
                                    .font(.system(size: 30))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isArabic ? category.titleAR : category.title)
                                    .font(ShineFont.displayBold(26))
                                    .foregroundColor(.shineInk)
                                Text(Loc.string("sheet.choose_package", isArabic: isArabic))
                                    .font(ShineFont.body(13))
                                    .foregroundColor(.shineInk3)
                            }
                            .padding(.top, 6)
                            Spacer()
                            Button { dismiss() } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.shineSurface2)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.shineInk2)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.top, ShineSpacing.lg)

                        Divider()
                            .padding(.vertical, ShineSpacing.lg)
                            .padding(.horizontal, ShineSpacing.lg)

                        // ── Welcome promo banner ─────────────────────────
                        if bookingVM.welcomePromoEligible {
                            HStack(spacing: 10) {
                                Text("🎁")
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isArabic ? "عرض العميل الجديد!" : "First booking offer!")
                                        .font(ShineFont.body(13, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(isArabic
                                         ? "خصم 20% يُطبَّق تلقائياً على طلبك الأول"
                                         : "20% off applied automatically to your first booking")
                                        .font(ShineFont.body(11))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color(hex: "6C5CE7"), Color(hex: "a29bfe")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                            .padding(.horizontal, ShineSpacing.lg)
                            .padding(.bottom, ShineSpacing.md)
                        }

                        // ── Packages label ───────────────────────────────
                        Text(Loc.string("sheet.packages", isArabic: isArabic))
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .kerning(0.8)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, ShineSpacing.lg)
                            .padding(.bottom, ShineSpacing.md)

                        // ── Packages / loading ───────────────────────────
                        if isLoading {
                            VStack(spacing: 10) {
                                ProgressView()
                                Text(isArabic ? "جاري تحميل الخدمات..." : "Loading packages...")
                                    .font(ShineFont.body(13))
                                    .foregroundColor(.shineInk3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(displayedPackages) { pkg in
                                    PackageRow(
                                        package: pkg,
                                        isSelected: selectedPackages.contains(where: { $0.id == pkg.id }),
                                        isArabic: isArabic,
                                        overrideName: nil,
                                        overrideNameAR: nil,
                                        overrideDetail: nil,
                                        overrideDetailAR: nil
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            if let idx = selectedPackages.firstIndex(where: { $0.id == pkg.id }) {
                                                selectedPackages.remove(at: idx)
                                            } else {
                                                selectedPackages.append(pkg)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, ShineSpacing.lg)
                            .padding(.bottom, ShineSpacing.md)

                            // Date & Time
                            DateTimePickerSection(
                                isArabic: isArabic,
                                selectedDate: $bookingVM.selectedDate
                            )

                            // Location / Address
                            AddressInputSection(
                                isArabic: isArabic,
                                address: $bookingVM.address,
                                latitude: $bookingVM.latitude,
                                longitude: $bookingVM.longitude,
                                locationService: locationService
                            )

                            // Promo code
                            PromoCodeField(
                                isArabic: isArabic,
                                promoInput: $promoInput,
                                promoMsg: $promoMsg,
                                promoIsValid: $promoIsValid,
                                isValidating: $isValidating,
                                selectedPackages: selectedPackages
                            )
                            .environmentObject(bookingVM)
                        }
                    }
                }

                // ── Sticky footer (price summary + book button) ──────────
                VStack(spacing: 0) {
                    Divider().padding(.bottom, ShineSpacing.md)

                    // Price summary
                    PriceSummarySection(
                        isArabic: isArabic,
                        selectedPackages: selectedPackages,
                        category: category
                    )
                    .environmentObject(bookingVM)

                    // Error message
                    if let err = bookingVM.errorMsg {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                            Text(err)
                                .font(ShineFont.body(13))
                                .lineLimit(2)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.sm)
                    }

                    // Book button
                    let canBook = !selectedPackages.isEmpty
                        && !bookingVM.address.trimmingCharacters(in: .whitespaces).isEmpty
                        && !bookingVM.isSubmitting
                    Button(action: onBook) {
                        ZStack {
                            HStack(spacing: 8) {
                                Text(Loc.string("sheet.book_now", isArabic: isArabic))
                                    .font(ShineFont.body(16, weight: .semibold))
                                Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .opacity(bookingVM.isSubmitting ? 0 : 1)

                            if bookingVM.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canBook ? Color.shineCoral : Color.shineInk3)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        .shadow(color: Color.shineCoral.opacity(canBook ? 0.3 : 0),
                                radius: 12, x: 0, y: 6)
                    }
                    .animation(.easeInOut(duration: 0.2), value: canBook)
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.top, ShineSpacing.md)
                    .padding(.bottom, 34)
                }
            }
        }
    }
}

// MARK: - Date & Time Picker Section

private struct DateTimePickerSection: View {
    let isArabic: Bool
    @Binding var selectedDate: Date
    @State private var minimumDate: Date = Date().addingTimeInterval(2 * 60 * 60)

    private func computedMinimumDate(from now: Date = Date()) -> Date {
        BookingViewModel.earliestBookableDate(from: now)
    }

    /// Old default was always “tomorrow at 10:00”; replace with real minimum so early-morning booking isn’t stuck on the wrong day.
    private func isStaleDefaultBookingTime(_ date: Date, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        guard let tomorrowStart = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
              let legacy = cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrowStart) else { return false }
        return abs(date.timeIntervalSince(legacy)) < 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isArabic ? "التاريخ والوقت" : "Date & Time")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, ShineSpacing.lg)

            HStack(spacing: 12) {
                // Date
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.shineCoral)
                    DatePicker("",
                               selection: $selectedDate,
                               in: minimumDate...,
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.shineCoral)
                        .environment(\.locale,
                                     isArabic ? Locale(identifier: "ar") : Locale(identifier: "en"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.shineBorder, lineWidth: 1))
                .shineShadowXS()

                // Time
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.shineTeal)
                    DatePicker("",
                               selection: $selectedDate,
                               in: minimumDate...,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.shineTeal)
                        .environment(\.locale,
                                     isArabic ? Locale(identifier: "ar") : Locale(identifier: "en"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.shineBorder, lineWidth: 1))
                .shineShadowXS()
            }
            .padding(.horizontal, ShineSpacing.lg)
        }
        .padding(.bottom, ShineSpacing.md)
        .onAppear {
            minimumDate = computedMinimumDate()
            if selectedDate < minimumDate || isStaleDefaultBookingTime(selectedDate) {
                selectedDate = minimumDate
            }
        }
        .onChange(of: selectedDate) { newValue in
            // Reuse the minimumDate captured on appear — recomputing here against
            // a microsecond-fresh `Date()` makes the clamp infinite-loop because
            // each tick produces a slightly later minimum and the write re-fires
            // this closure (full main-thread freeze).
            if newValue < minimumDate {
                selectedDate = minimumDate
            }
        }
    }
}

// MARK: - Address Input Section

struct AddressInputSection: View {
    let isArabic: Bool
    @Binding var address: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @ObservedObject var locationService: LocationService
    @ObservedObject private var store = AddressStore.shared
    @EnvironmentObject private var appState: AppState
    @FocusState private var fieldFocused: Bool
    @State private var showPicker = false
    @State private var isLocating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isArabic ? "العنوان" : "Location")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, ShineSpacing.lg)

            // Text field + GPS button + picker button
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.shineTeal)

                TextField(
                    isArabic ? "أدخل عنوانك" : "Enter your address",
                    text: $address
                )
                .font(ShineFont.body(14))
                .foregroundColor(.shineInk)
                .focused($fieldFocused)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(isArabic ? "تم" : "Done") {
                            fieldFocused = false
                        }
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineCoral)
                    }
                }

                Spacer()

                // GPS current location button
                Button {
                    fieldFocused = false
                    fetchCurrentLocation()
                } label: {
                    if isLocating {
                        ProgressView()
                            .frame(width: 26, height: 26)
                    } else {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.shineTeal)
                    }
                }
                .disabled(isLocating)

                // Open address picker
                Button {
                    fieldFocused = false
                    showPicker = true
                } label: {
                    Image(systemName: "list.bullet.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.shineCoral)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.shineBorder, lineWidth: 1))
            .shineShadowXS()
            .padding(.horizontal, ShineSpacing.lg)
        }
        .padding(.bottom, ShineSpacing.md)
        .onAppear {
            if address.isEmpty, let def = store.defaultAddress {
                address   = def.address
                latitude  = def.latitude
                longitude = def.longitude
            }
        }
        .sheet(isPresented: $showPicker) {
            AddressesView(onSelect: { saved in
                address   = saved.address
                latitude  = saved.latitude
                longitude = saved.longitude
            })
            .environmentObject(appState)
        }
    }

    private func fetchCurrentLocation() {
        isLocating = true
        Task {
            if locationService.isNotDetermined { locationService.requestPermission() }
            guard locationService.isAuthorized else {
                await MainActor.run { isLocating = false }
                return
            }
            async let locationTask = locationService.getCurrentLocation()
            async let addressTask  = locationService.getCurrentAddress()
            let (loc, addr) = await (locationTask, addressTask)
            await MainActor.run {
                if let loc {
                    latitude  = loc.coordinate.latitude
                    longitude = loc.coordinate.longitude
                }
                if !addr.isEmpty { address = addr }
                isLocating = false
            }
        }
    }
}

// MARK: - Price Summary Section

private struct PriceSummarySection: View {
    let isArabic: Bool
    let selectedPackages: [ServicePackage]
    let category: ServiceCategory
    @EnvironmentObject var bookingVM: BookingViewModel

    /// Most expensive is full price; all others get 5% off their individual price.
    private var sortedPackages: [ServicePackage] {
        selectedPackages.sorted { $0.priceAmount > $1.priceAmount }
    }
    /// Subtotal always uses the original (pre-discount) price.
    private var subtotal: Double {
        selectedPackages.reduce(0) { $0 + $1.priceAmount }
    }
    private var selectedBundlePackages: [ServicePackage] {
        selectedPackages.filter { $0.category == .bundle }
    }
    private var bundleDiscount: Double {
        guard category == .bundle else { return 0 }
        let hasAppBundle = !selectedBundlePackages.isEmpty
        let hasCustomBundle = selectedPackages.filter { $0.category != .bundle }.count > 3
        guard hasAppBundle || hasCustomBundle else { return 0 }
        return subtotal * 0.30
    }
    private var multiItemDiscount: Double {
        guard category != .bundle, selectedPackages.count > 1 else { return 0 }
        return sortedPackages.dropFirst().reduce(0) { $0 + $1.priceAmount * 0.05 }
    }
    private var promoDiscount: Double { bookingVM.promoDiscount }
    private var total: Double         { max(0, subtotal - bundleDiscount - multiItemDiscount - promoDiscount) }

    var body: some View {
        if !selectedPackages.isEmpty && subtotal > 0 {
            VStack(spacing: 6) {
                // Subtotal row — always show for bundles; otherwise show when multiple items or promo applied
                if category == .bundle || selectedPackages.count > 1 || promoDiscount > 0 {
                    HStack {
                        Text(isArabic ? "المجموع الجزئي" : "Subtotal")
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineInk3)
                        Spacer()
                        Text("QAR \(Int(subtotal))")
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk2)
                    }
                }
                // Bundle 30% discount
                if bundleDiscount > 0 {
                    HStack {
                        Text(isArabic ? "خصم الباقة (٣٠٪)" : "Bundle discount (30% off)")
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineTeal)
                        Spacer()
                        Text("- QAR \(String(format: "%.0f", bundleDiscount))")
                            .font(ShineFont.body(13, weight: .semibold))
                            .foregroundColor(.shineTeal)
                    }
                }
                // Multi-item 5% discount (non-bundle only)
                if multiItemDiscount > 0 {
                    HStack {
                        Text(isArabic
                             ? "خصم الخدمات المتعددة (٥٪)"
                             : "Multi-service discount (5% off \(selectedPackages.count - 1) item\(selectedPackages.count > 2 ? "s" : ""))")
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineTeal)
                        Spacer()
                        Text("- QAR \(String(format: "%.0f", multiItemDiscount))")
                            .font(ShineFont.body(13, weight: .semibold))
                            .foregroundColor(.shineTeal)
                    }
                }
                // Promo code discount
                if promoDiscount > 0 {
                    HStack {
                        Text(isArabic ? "خصم كود الترويج" : "Promo discount")
                            .font(ShineFont.body(12))
                            .foregroundColor(.green)
                        Spacer()
                        Text("- QAR \(String(format: "%.0f", promoDiscount))")
                            .font(ShineFont.body(13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                Divider()
                HStack {
                    Text(isArabic ? "الإجمالي" : "Total")
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Spacer()
                    Text("QAR \(Int(total))")
                        .font(ShineFont.displayBold(22))
                        .foregroundColor(.shineCoral)
                }
            }
            .padding(.horizontal, ShineSpacing.lg)
            .padding(.vertical, ShineSpacing.sm)
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .padding(.horizontal, ShineSpacing.lg)
            .padding(.bottom, ShineSpacing.md)
        }
    }
}

// MARK: - Promo Code Field

private struct PromoCodeField: View {
    let isArabic: Bool
    @Binding var promoInput: String
    @Binding var promoMsg: String?
    @Binding var promoIsValid: Bool
    @Binding var isValidating: Bool
    let selectedPackages: [ServicePackage]

    @EnvironmentObject var bookingVM: BookingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.shineInk3)
                TextField(
                    isArabic ? "كود الخصم (اختياري)" : "Promo code (optional)",
                    text: $promoInput
                )
                .font(ShineFont.body(14))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: promoInput) { _ in
                    promoMsg = nil
                    promoIsValid = false
                    bookingVM.promoCode = ""
                    bookingVM.promoDiscount = 0
                }

                if isValidating {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(isArabic ? "تطبيق" : "Apply") { applyPromo() }
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(promoInput.isEmpty ? .shineInk3 : .shineCoral)
                        .disabled(promoInput.isEmpty || selectedPackages.isEmpty)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ShineRadius.sm)
                    .stroke(
                        promoIsValid ? Color.green : (promoMsg != nil ? Color.red : Color.clear),
                        lineWidth: 1.5
                    )
            )

            if let msg = promoMsg {
                HStack(spacing: 4) {
                    Image(systemName: promoIsValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(msg)
                        .font(ShineFont.body(12))
                }
                .foregroundColor(promoIsValid ? .green : .red)
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, ShineSpacing.lg)
        .padding(.bottom, ShineSpacing.md)
    }

    private func applyPromo() {
        let apiIds = selectedPackages.compactMap { $0.apiId }
        guard let firstId = apiIds.first else {
            promoMsg = isArabic ? "اختر خدمة أولاً" : "Select a package first"
            return
        }
        let total = selectedPackages.reduce(0) { $0 + $1.priceAmount }
        isValidating = true
        promoMsg = nil
        bookingVM.promoCode = promoInput.trimmingCharacters(in: .whitespaces).uppercased()

        Task {
            await bookingVM.validatePromo(packageId: firstId, totalAmount: total)
            await MainActor.run {
                isValidating = false
                if bookingVM.promoDiscount > 0 {
                    promoIsValid = true
                    promoMsg = isArabic
                        ? "تم تطبيق الخصم بنجاح 🎉"
                        : "Code applied! You save QAR \(String(format: "%.0f", bookingVM.promoDiscount))"
                } else {
                    promoIsValid = false
                    bookingVM.promoCode = ""
                    promoMsg = isArabic ? "كود الخصم غير صالح" : "Invalid or expired promo code"
                }
            }
        }
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let package: ServicePackage
    let isSelected: Bool
    let isArabic: Bool
    let overrideName: String?
    let overrideNameAR: String?
    let overrideDetail: String?
    let overrideDetailAR: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(package.emoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isArabic ? (overrideNameAR ?? package.nameAR) : (overrideName ?? package.name))
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(isArabic ? (overrideDetailAR ?? package.detailAR) : (overrideDetail ?? package.detail))
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk3)
                }

                Spacer()

                if package.category == .bundle && package.priceAmount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(package.price)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk3)
                            .strikethrough(true, color: .shineInk3)
                        Text("QAR \(Int((package.priceAmount * 0.7).rounded()))")
                            .font(ShineFont.displayBold(20))
                            .foregroundColor(.shineCoral)
                    }
                } else {
                    Text(package.price)
                        .font(ShineFont.displayBold(20))
                        .foregroundColor(isSelected ? .shineCoral : .shineInk)
                }

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.shineCoral : Color.shineBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.shineCoral)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.shineCoralLight : Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ShineRadius.md)
                    .stroke(isSelected ? Color.shineCoral : Color.clear, lineWidth: 2)
            )
            .shineShadowXS()
        }
        .buttonStyle(.plain)
    }
}

struct CustomBundleBuilderView: View {
    let isArabic: Bool
    let components: [ServicePackage]
    var isLoading: Bool = false
    let onBook: ([ServicePackage]) -> Void

    @EnvironmentObject private var bookingVM: BookingViewModel
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedComponents: [ServicePackage] = []

    private func resolvedPrice(for item: ServicePackage) -> Double {
        if item.priceAmount > 0 { return item.priceAmount }
        let digits = item.price.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(digits) ?? 0
    }

    private var subtotal: Double {
        selectedComponents.reduce(0) { $0 + resolvedPrice(for: $1) }
    }
    private var customDiscount: Double {
        selectedComponents.count >= 3 ? subtotal * 0.30 : 0
    }
    private var total: Double {
        max(0, subtotal - customDiscount)
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Scrollable content (everything above the sticky footer) ─
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Header ────────────────────────────────────────
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "1C1917").opacity(0.08))
                                    .frame(width: 64, height: 64)
                                Text("📦")
                                    .font(.system(size: 30))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isArabic ? "الباقة" : "Bundle")
                                    .font(ShineFont.displayBold(26))
                                    .foregroundColor(.shineInk)
                                HStack(spacing: 5) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.shineCoral)
                                    Text(isArabic ? "اختر ٣ خدمات أو أكثر للحصول على خصم ٣٠٪" : "Select 3+ services to get 30% off")
                                        .font(ShineFont.body(12, weight: .medium))
                                        .foregroundColor(.shineCoral)
                                }
                            }
                            .padding(.top, 6)
                            Spacer()
                            Button { dismiss() } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.shineSurface2)
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.shineInk2)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.top, ShineSpacing.lg)

                        Divider()
                            .padding(.vertical, ShineSpacing.lg)
                            .padding(.horizontal, ShineSpacing.lg)

                        // ── Package list ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            if isLoading {
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text(isArabic ? "جاري تحميل الخدمات..." : "Loading services...")
                                        .font(ShineFont.body(13))
                                        .foregroundColor(.shineInk3)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                            ForEach(components) { item in
                                PackageRow(
                                    package: item,
                                    isSelected: selectedComponents.contains(where: { $0.id == item.id }),
                                    isArabic: isArabic,
                                    overrideName: nil,
                                    overrideNameAR: nil,
                                    overrideDetail: nil,
                                    overrideDetailAR: nil
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        if let idx = selectedComponents.firstIndex(where: { $0.id == item.id }) {
                                            selectedComponents.remove(at: idx)
                                        } else {
                                            selectedComponents.append(item)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                        .padding(.bottom, ShineSpacing.md)

                        // ── Date & Time ──────────────────────────────────
                        DateTimePickerSection(
                            isArabic: isArabic,
                            selectedDate: $bookingVM.selectedDate
                        )

                        // ── Address ──────────────────────────────────────
                        AddressInputSection(
                            isArabic: isArabic,
                            address: $bookingVM.address,
                            latitude: $bookingVM.latitude,
                            longitude: $bookingVM.longitude,
                            locationService: locationService
                        )
                    }
                }

                // ── Sticky footer (price summary + book button) ──────────
                VStack(spacing: 0) {
                    Divider()
                        .padding(.top, ShineSpacing.sm)

                    VStack(spacing: 6) {
                        HStack {
                            Text(isArabic ? "المجموع الجزئي" : "Subtotal")
                                .font(ShineFont.body(12))
                                .foregroundColor(.shineInk3)
                            Spacer()
                            Text("QAR \(Int(subtotal.rounded()))")
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineInk2)
                        }

                        if customDiscount > 0 {
                            HStack {
                                Text(isArabic ? "خصم الباقة المخصصة (٣٠٪)" : "Custom bundle discount (30% off)")
                                    .font(ShineFont.body(12))
                                    .foregroundColor(.shineTeal)
                                Spacer()
                                Text("- QAR \(Int(customDiscount.rounded()))")
                                    .font(ShineFont.body(13, weight: .semibold))
                                    .foregroundColor(.shineTeal)
                            }
                        }

                        Divider()

                        HStack {
                            Text(isArabic ? "الإجمالي" : "Total")
                                .font(ShineFont.body(14, weight: .semibold))
                                .foregroundColor(.shineInk)
                            Spacer()
                            Text("QAR \(Int(total.rounded()))")
                                .font(ShineFont.displayBold(22))
                                .foregroundColor(.shineCoral)
                        }
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.top, ShineSpacing.md)

                    if let err = bookingVM.errorMsg {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                            Text(err)
                                .font(ShineFont.body(13))
                                .lineLimit(2)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, ShineSpacing.lg)
                    }

                    let canBook = !selectedComponents.isEmpty
                        && !bookingVM.address.trimmingCharacters(in: .whitespaces).isEmpty
                        && !bookingVM.isSubmitting
                    Button {
                        onBook(selectedComponents)
                    } label: {
                        ZStack {
                            HStack(spacing: 8) {
                                Text(isArabic ? "احجز الآن" : "Book Now")
                                    .font(ShineFont.body(16, weight: .semibold))
                                Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .opacity(bookingVM.isSubmitting ? 0 : 1)
                            if bookingVM.isSubmitting {
                                ProgressView().tint(.white)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canBook ? Color.shineCoral : Color.shineInk3)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        .shadow(color: Color.shineCoral.opacity(canBook ? 0.3 : 0), radius: 10, x: 0, y: 5)
                    }
                    .animation(.easeInOut(duration: 0.2), value: canBook)
                    .disabled(!canBook)
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.bottom, 34)
                }
                .background(Color.shineBG)
            }
        }
    }
}
