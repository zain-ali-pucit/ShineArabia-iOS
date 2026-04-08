import SwiftUI

struct ServiceBottomSheet: View {
    let category: ServiceCategory
    let packages: [ServicePackage]
    @Binding var selectedPackages: [ServicePackage]
    let isArabic: Bool
    let isLoading: Bool
    let onBook: () -> Void

    @EnvironmentObject var bookingVM: BookingViewModel
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.dismiss) var dismiss

    @State private var promoInput: String = ""
    @State private var promoMsg: String?
    @State private var promoIsValid: Bool = false
    @State private var isValidating: Bool = false

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Sheet header ─────────────────────────────────────────
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(category.softColor)
                            .frame(width: 64, height: 64)
                        Text(category.icon)
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

                // ── Welcome promo banner ─────────────────────────────────
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

                // ── Packages label ───────────────────────────────────────
                Text(Loc.string("sheet.packages", isArabic: isArabic))
                    .font(ShineFont.body(11, weight: .semibold))
                    .foregroundColor(.shineInk3)
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.bottom, ShineSpacing.md)

                // ── Bundle discount banner ───────────────────────────────
                if category == .bundle {
                    HStack(spacing: 10) {
                        Text("🎁")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isArabic ? "خصم ٣٠٪ على الباقات" : "30% off all bundles")
                                .font(ShineFont.body(13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(isArabic ? "وفّر أكثر مع باقاتنا المميزة" : "Save more with our curated bundles")
                                .font(ShineFont.body(11))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Text("30% OFF")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(Color(hex: "F4A799"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [Color(hex: "1C1917"), Color(hex: "3D3530")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.bottom, ShineSpacing.md)
                }

                // ── Scrollable: packages + date/time + address ───────────
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
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Package list
                            VStack(spacing: 10) {
                                ForEach(packages) { pkg in
                                    PackageRow(
                                        package: pkg,
                                        isSelected: selectedPackages.contains(where: { $0.id == pkg.id }),
                                        isArabic: isArabic
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
                        selectedPackages: selectedPackages
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
                               in: Date()...,
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
                               in: Date()...,
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
    }
}

// MARK: - Address Input Section

private struct AddressInputSection: View {
    let isArabic: Bool
    @Binding var address: String
    @ObservedObject var locationService: LocationService
    @ObservedObject private var store = AddressStore.shared
    @EnvironmentObject private var appState: AppState
    @FocusState private var fieldFocused: Bool
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isArabic ? "العنوان" : "Location")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, ShineSpacing.lg)

            // Saved address chips
            if !store.addresses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.addresses) { saved in
                            let isSelected = address == saved.address
                            Button {
                                address = saved.address
                                fieldFocused = false
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: saved.label.icon)
                                        .font(.system(size: 11))
                                    Text(isArabic ? saved.label.titleAR : saved.label.title)
                                        .font(ShineFont.body(13, weight: .medium))
                                }
                                .foregroundColor(isSelected ? .white : saved.label.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? saved.label.color : saved.label.color.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(saved.label.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                }
            }

            // Text field + picker button
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
                address = def.address
            }
        }
        .sheet(isPresented: $showPicker) {
            AddressesView(onSelect: { saved in
                address = saved.address
            })
            .environmentObject(appState)
        }
    }
}

// MARK: - Price Summary Section

private struct PriceSummarySection: View {
    let isArabic: Bool
    let selectedPackages: [ServicePackage]
    @EnvironmentObject var bookingVM: BookingViewModel

    /// Most expensive is full price; all others get 5% off their individual price.
    private var sortedPackages: [ServicePackage] {
        selectedPackages.sorted { $0.priceAmount > $1.priceAmount }
    }
    private var subtotal: Double {
        selectedPackages.reduce(0) { $0 + $1.priceAmount }
    }
    private var multiItemDiscount: Double {
        guard selectedPackages.count > 1 else { return 0 }
        return sortedPackages.dropFirst().reduce(0) { $0 + $1.priceAmount * 0.05 }
    }
    private var promoDiscount: Double { bookingVM.promoDiscount }
    private var total: Double         { max(0, subtotal - multiItemDiscount - promoDiscount) }

    var body: some View {
        if !selectedPackages.isEmpty && subtotal > 0 {
            VStack(spacing: 6) {
                // Subtotal row (only needed when there are multiple items or discounts)
                if selectedPackages.count > 1 || promoDiscount > 0 {
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
                // Multi-item 5% discount
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(package.emoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isArabic ? package.nameAR : package.name)
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(isArabic ? package.detailAR : package.detail)
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
