import SwiftUI

struct AssignedStaffView: View {
    let staffName: String
    let staffPhone: String?
    let staffAvatarUrl: String?
    let serviceName: String
    let statusLabel: String
    let staffId: String
    let bookingId: String

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = RatingViewModel()
    @FocusState private var commentFocused: Bool

    private var isArabic: Bool { appState.isArabic }
    private var isCompleted: Bool {
        statusLabel.caseInsensitiveCompare("Completed") == .orderedSame ||
        statusLabel == "مكتمل"
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)

                    // Avatar
                    avatarView
                        .frame(width: 100, height: 100)
                        .background(Color.shineTealLight)
                        .clipShape(Circle())
                        .shadow(color: Color.shineInk.opacity(0.12), radius: 6, x: 0, y: 4)

                    Spacer().frame(height: 16)

                    // Name
                    Text(staffName)
                        .font(ShineFont.displayBold(24))
                        .foregroundColor(.shineInk)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 4)

                    // Average rating display
                    if !vm.isLoading && vm.totalCount > 0 {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(i < Int(vm.averageRating) ? Color(hex: "F59E0B") : .shineBorder)
                            }
                            Text("\(String(format: "%.1f", vm.averageRating)) (\(vm.totalCount))")
                                .font(ShineFont.body(12))
                                .foregroundColor(.shineInk2)
                                .padding(.leading, 4)
                        }
                        .padding(.bottom, 4)
                    }

                    // Role badge
                    Text(isArabic ? "محترف معتمد" : "Certified Professional")
                        .font(ShineFont.body(12, weight: .medium))
                        .foregroundColor(.shineTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.shineTealLight)
                        .clipShape(Capsule())

                    Spacer().frame(height: 24)

                    // Booking details card
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isArabic ? "تفاصيل الحجز" : "Booking Details")
                            .font(ShineFont.body(13, weight: .semibold))
                            .foregroundColor(.shineInk2)

                        Divider()

                        DetailRow(label: isArabic ? "الخدمة" : "Service", value: serviceName)
                        DetailRow(label: isArabic ? "الحالة" : "Status",  value: statusLabel)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.shineSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                    .shineShadowXS()

                    Spacer().frame(height: 16)

                    // Contact buttons (hidden once the booking is completed)
                    if let phone = staffPhone, !phone.isEmpty, !isCompleted {
                        HStack(spacing: 14) {
                            StaffActionButton(
                                icon: "phone.fill",
                                label: isArabic ? "اتصل" : "Call",
                                color: .shineTeal,
                                bgColor: .shineTealLight
                            ) {
                                callPhone(phone)
                            }

                            StaffActionButton(
                                icon: "message.fill",
                                label: isArabic ? "واتساب" : "WhatsApp",
                                color: Color(hex: "25D366"),
                                bgColor: Color(hex: "E8F9EE")
                            ) {
                                openWhatsApp(phone)
                            }
                        }
                        Spacer().frame(height: 16)
                    }

                    // Rating section (only for completed bookings)
                    if isCompleted {
                        ratingReviewSection
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle(isArabic ? "المحترف المعيّن" : "Your Professional")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !staffId.isEmpty, !bookingId.isEmpty {
                await vm.load(staffId: staffId, bookingId: bookingId)
            }
        }
        .onTapGesture { commentFocused = false }
        .onChange(of: vm.justSubmitted) { justSubmitted in
            if justSubmitted {
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    vm.clearJustSubmitted()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var avatarView: some View {
        if let urlStr = staffAvatarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    avatarFallback
                }
            }
        } else {
            avatarFallback
        }
    }

    private var avatarFallback: some View {
        Text(String(staffName.prefix(1)).uppercased())
            .font(ShineFont.displayBold(38))
            .foregroundColor(.shineTeal)
    }

    private var ratingReviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isArabic ? "تقييمك ومراجعتك" : "Your Rating & Review")
                .font(ShineFont.body(15, weight: .semibold))
                .foregroundColor(.shineInk)

            Divider()

            // Star selector
            HStack(spacing: 0) {
                Spacer()
                ForEach(1...5, id: \.self) { star in
                    let filled = star <= vm.myRating
                    Button {
                        vm.setRating(star)
                    } label: {
                        Image(systemName: filled ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundColor(filled ? Color(hex: "F59E0B") : .shineBorder)
                            .padding(4)
                    }
                    .disabled(vm.isSubmitting)
                    .animation(.easeInOut(duration: 0.15), value: filled)
                }
                Spacer()
            }

            // Star label
            if vm.myRating > 0 {
                Text(starLabel(for: vm.myRating))
                    .font(ShineFont.body(13, weight: .semibold))
                    .foregroundColor(Color(hex: "F59E0B"))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }

            // Review text field
            ZStack(alignment: .topLeading) {
                if vm.myComment.isEmpty {
                    Text(isArabic ? "اكتب مراجعتك هنا (اختياري)..." : "Write your review here (optional)...")
                        .font(ShineFont.body(13))
                        .foregroundColor(.shineInk3)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(
                    get: { vm.myComment },
                    set: { vm.setComment($0) }
                ))
                .focused($commentFocused)
                .font(ShineFont.body(13))
                .foregroundColor(.shineInk)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minHeight: 80)
                .disabled(vm.isSubmitting)
            }
            .background(Color.shineSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(commentFocused ? Color.shineTeal : Color.shineBorder, lineWidth: 1)
            )

            // Error
            if let err = vm.errorMessage {
                Text(err)
                    .font(ShineFont.body(12))
                    .foregroundColor(.shineCoral)
            }

            // Submit / Success
            if vm.submitSuccess {
                HStack {
                    Spacer()
                    Text(isArabic ? "✅ شكراً على تقييمك!" : "✅ Thank you for your review!")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineTeal)
                    Spacer()
                }
                .padding(12)
                .background(Color.shineTealLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.myRating > 0 {
                    Button {
                        Task { await vm.submit(bookingId: bookingId, staffId: staffId) }
                    } label: {
                        Text(isArabic ? "تحديث التقييم" : "Update Review")
                            .font(ShineFont.body(13, weight: .medium))
                            .foregroundColor(.shineInk2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .disabled(vm.isSubmitting)
                }
            } else {
                Button {
                    Task { await vm.submit(bookingId: bookingId, staffId: staffId) }
                } label: {
                    HStack {
                        if vm.isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Text(isArabic ? "إرسال التقييم" : "Submit Review")
                                .font(ShineFont.body(14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(canSubmit ? Color.shineTeal : Color.shineInk3.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowXS()
    }

    private var canSubmit: Bool {
        vm.myRating > 0 && !vm.isSubmitting && !staffId.isEmpty && !bookingId.isEmpty
    }

    private func starLabel(for rating: Int) -> String {
        switch rating {
        case 1: return isArabic ? "سيئ" : "Poor"
        case 2: return isArabic ? "مقبول" : "Fair"
        case 3: return isArabic ? "جيد" : "Good"
        case 4: return isArabic ? "جيد جداً" : "Very Good"
        case 5: return isArabic ? "ممتاز!" : "Excellent!"
        default: return ""
        }
    }

    private func callPhone(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "")
        guard let url = URL(string: "tel:\(cleaned)") else { return }
        UIApplication.shared.open(url)
    }

    private func openWhatsApp(_ phone: String) {
        let cleaned = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "+", with: "")
        let waApp = URL(string: "whatsapp://send?phone=\(cleaned)")
        let waWeb = URL(string: "https://wa.me/\(cleaned)")
        if let app = waApp, UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else if let web = waWeb {
            UIApplication.shared.open(web)
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(ShineFont.body(13))
                .foregroundColor(.shineInk3)
            Spacer()
            Text(value)
                .font(ShineFont.body(13, weight: .medium))
                .foregroundColor(.shineInk)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Staff Action Button

private struct StaffActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
                Text(label)
                    .font(ShineFont.body(13, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.shineInk.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }
}
