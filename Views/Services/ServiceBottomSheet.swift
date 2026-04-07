import SwiftUI

struct ServiceBottomSheet: View {
    let category: ServiceCategory
    let packages: [ServicePackage]
    @Binding var selectedPackage: ServicePackage?
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

                // ── Package list ─────────────────────────────────────────
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
                        VStack(spacing: 10) {
                            ForEach(packages) { pkg in
                                PackageRow(
                                    package: pkg,
                                    isSelected: selectedPackage?.id == pkg.id,
                                    isArabic: isArabic
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPackage = pkg
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, ShineSpacing.lg)
                    }
                }

                // ── Date & Time ──────────────────────────────────────────
                DateTimePickerSection(
                    isArabic: isArabic,
                    selectedDate: $bookingVM.selectedDate
                )

                // ── Location / Address ───────────────────────────────────
                AddressInputSection(
                    isArabic: isArabic,
                    address: $bookingVM.address,
                    locationService: locationService
                )

                // ── Footer (promo + book button) ─────────────────────────
                VStack(spacing: 0) {
                    Divider().padding(.bottom, ShineSpacing.md)

                    // Promo code
                    PromoCodeField(
                        isArabic: isArabic,
                        promoInput: $promoInput,
                        promoMsg: $promoMsg,
                        promoIsValid: $promoIsValid,
                        isValidating: $isValidating,
                        selectedPackage: selectedPackage
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
                    let canBook = selectedPackage != nil && !bookingVM.isSubmitting
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
//                    .disabled(!canBook)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isArabic ? "العنوان" : "Location")
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(.shineInk3)
                .kerning(0.8)
                .textCase(.uppercase)
                .padding(.horizontal, ShineSpacing.lg)

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

                Spacer()

                // Auto-detect button
                if locationService.isResolving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 30, height: 30)
                } else {
                    Button {
                        Task {
                            let detected = await locationService.getCurrentAddress()
                            if !detected.isEmpty {
                                address = detected
                            }
                        }
                    } label: {
                        Image(systemName: locationService.isAuthorized
                              ? "location.circle.fill"
                              : "location.circle")
                            .font(.system(size: 26))
                            .foregroundColor(.shineCoral)
                    }
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
    }
}

// MARK: - Promo Code Field

private struct PromoCodeField: View {
    let isArabic: Bool
    @Binding var promoInput: String
    @Binding var promoMsg: String?
    @Binding var promoIsValid: Bool
    @Binding var isValidating: Bool
    let selectedPackage: ServicePackage?

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
                        .disabled(promoInput.isEmpty || selectedPackage == nil)
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

            if promoIsValid, bookingVM.promoDiscount > 0 {
                HStack {
                    Text(isArabic ? "الخصم المطبق" : "Discount applied")
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk3)
                    Spacer()
                    Text("- QAR \(String(format: "%.2f", bookingVM.promoDiscount))")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, ShineSpacing.lg)
        .padding(.bottom, ShineSpacing.md)
    }

    private func applyPromo() {
        guard let pkg = selectedPackage, let apiId = pkg.apiId else {
            promoMsg = isArabic ? "اختر خدمة أولاً" : "Select a package first"
            return
        }
        isValidating = true
        promoMsg = nil
        bookingVM.promoCode = promoInput.trimmingCharacters(in: .whitespaces).uppercased()

        Task {
            await bookingVM.validatePromo(packageId: apiId)
            await MainActor.run {
                isValidating = false
                if bookingVM.promoDiscount > 0 {
                    promoIsValid = true
                    promoMsg = isArabic
                        ? "تم تطبيق الخصم بنجاح 🎉"
                        : "Code applied! You save QAR \(String(format: "%.2f", bookingVM.promoDiscount))"
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
