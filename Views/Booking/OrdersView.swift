import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bookingVM: BookingViewModel
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(Loc.string("orders.title", isArabic: appState.isArabic))
                        .font(ShineFont.displayBold(28))
                        .foregroundColor(.shineInk)
                    Spacer()
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.md)

                // Segment
                HStack(spacing: 0) {
                    ForEach(["Active", "Past"].indices, id: \.self) { i in
                        let labels = [Loc.string("orders.active", isArabic: appState.isArabic), Loc.string("orders.past", isArabic: appState.isArabic)]
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedSegment = i }
                        } label: {
                            Text(labels[i])
                                .font(ShineFont.body(14, weight: selectedSegment == i ? .semibold : .regular))
                                .foregroundColor(selectedSegment == i ? .shineCoral : .shineInk3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .background(Color.shineSurface2)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.lg)

                // Content
                ScrollView(showsIndicators: false) {
                    if bookingVM.isLoading {
                        ProgressView()
                            .tint(.shineCoral)
                            .padding(.top, 80)
                    } else {
                        let items = selectedSegment == 0 ? bookingVM.activeBookings : bookingVM.pastBookings
                        if items.isEmpty {
                            EmptyStateView(
                                icon: selectedSegment == 0 ? "📋" : "🗂️",
                                title: Loc.string("orders.empty.title", isArabic: appState.isArabic),
                                subtitle: Loc.string("orders.empty.subtitle", isArabic: appState.isArabic)
                            )
                            .padding(.top, 60)
                        } else {
                            VStack(spacing: 14) {
                                ForEach(items) { booking in
                                    BookingCard(booking: booking, isArabic: appState.isArabic)
                                }
                            }
                            .padding(.horizontal, ShineSpacing.lg)
                        }
                    }
                }
            }
        }
        .task {
            await bookingVM.loadBookings()
        }
        .refreshable {
            await bookingVM.loadBookings()
        }
        .alert("Error", isPresented: Binding(
            get: { bookingVM.errorMsg != nil },
            set: { if !$0 { bookingVM.errorMsg = nil } }
        )) {
            Button("OK") { bookingVM.errorMsg = nil }
        } message: {
            Text(bookingVM.errorMsg ?? "")
        }
    }
}

// MARK: - Booking Card
struct BookingCard: View {
    let booking: Booking
    let isArabic: Bool
    @EnvironmentObject var bookingVM: BookingViewModel

    @State private var showReschedule = false
    @State private var showCancelConfirm = false
    @State private var newDate: Date = Date()

    // Prefer API-provided values; fall back to local enum so offline still works
    var categoryIcon: String {
        if let emoji = booking.categoryIconEmoji, !emoji.isEmpty { return emoji }
        return ServiceCategory(rawValue: booking.serviceCategory)?.icon ?? "✨"
    }
    var categoryColor: Color {
        ServiceCategory(rawValue: booking.serviceCategory)?.color ?? .shineCoral
    }
    var categorySoft: Color {
        if let hex = booking.categorySoftColorHex, !hex.isEmpty { return Color(hex: hex) }
        return ServiceCategory(rawValue: booking.serviceCategory)?.softColor ?? .shineCoralLight
    }

    var canReschedule: Bool {
        booking.status == .pending
    }

    /// Cancel is only allowed before the booking is confirmed.
    var canCancel: Bool {
        booking.status == .pending
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: booking.scheduledDate)
    }

    var hasAssignedStaff: Bool {
        booking.staffId != nil && !(booking.staffName ?? "").isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categorySoft)
                        .frame(width: 48, height: 48)
                    Text(categoryIcon).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.packageName)
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(booking.price)
                        .font(ShineFont.displayBold(18))
                        .foregroundColor(categoryColor)
                }
                Spacer()
                StatusBadge(status: booking.status)
            }

            Divider()

            HStack(spacing: 16) {
                Label(formattedDate, systemImage: "calendar")
                    .font(ShineFont.body(12))
                    .foregroundColor(.shineInk3)
                Spacer()
                Label(booking.address, systemImage: "location.fill")
                    .font(ShineFont.body(12))
                    .foregroundColor(.shineInk3)
                    .lineLimit(1)
            }

            if hasAssignedStaff,
               let staffId   = booking.staffId,
               let staffName = booking.staffName {
                NavigationLink {
                    AssignedStaffView(
                        staffName:      staffName,
                        staffPhone:     booking.staffPhone,
                        staffAvatarUrl: booking.staffAvatarUrl,
                        serviceName:    booking.packageName,
                        statusLabel:    isArabic ? booking.status.displayTitleAR : booking.status.displayTitle,
                        staffId:        staffId,
                        bookingId:      booking.apiId ?? ""
                    )
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.shineTealLight)
                                .frame(width: 32, height: 32)
                            if let avatar = booking.staffAvatarUrl, !avatar.isEmpty, let url = URL(string: avatar) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Text(String(staffName.prefix(1)).uppercased())
                                            .font(ShineFont.body(12, weight: .semibold))
                                            .foregroundColor(.shineTeal)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                Text(String(staffName.prefix(1)).uppercased())
                                    .font(ShineFont.body(12, weight: .semibold))
                                    .foregroundColor(.shineTeal)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isArabic ? "المحترف المعيّن" : "Assigned Professional")
                                .font(ShineFont.body(10))
                                .foregroundColor(.shineInk3)
                            HStack(spacing: 6) {
                                Text(staffName)
                                    .font(ShineFont.body(13, weight: .semibold))
                                    .foregroundColor(.shineInk)
                                if let rating = booking.staffAvgRating,
                                   let count = booking.staffRatingCount,
                                   count > 0 {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                    Text(String(format: "%.1f", rating))
                                        .font(ShineFont.body(11, weight: .medium))
                                        .foregroundColor(.shineInk)
                                    Text("(\(count))")
                                        .font(ShineFont.body(11))
                                        .foregroundColor(.shineInk3)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.shineInk3)
                    }
                    .padding(10)
                    .background(Color.shineTealLight.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if booking.status == .cancelled, let reason = booking.cancelReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.shineCoral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isArabic ? "سبب الإلغاء" : "Cancellation Reason")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineCoral)
                        Text(reason)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.shineCoralLight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if canReschedule {
                HStack(spacing: 16) {
                    Button {
                        newDate = max(booking.scheduledDate, Date().addingTimeInterval(60))
                        showReschedule = true
                    } label: {
                        Label(isArabic ? "إعادة الجدولة" : "Reschedule", systemImage: "calendar.badge.clock")
                            .font(ShineFont.body(13, weight: .medium))
                            .foregroundColor(.shineCoral)
                    }
                    .sheet(isPresented: $showReschedule) {
                        RescheduleSheet(
                            booking: booking,
                            newDate: $newDate,
                            isArabic: isArabic
                        ) {
                            Task { await bookingVM.rescheduleBooking(id: booking.id, newDate: newDate) }
                        }
                    }

                    if canCancel {
                        Spacer()

                        Button {
                            showCancelConfirm = true
                        } label: {
                            Label(isArabic ? "إلغاء" : "Cancel", systemImage: "xmark.circle")
                                .font(ShineFont.body(13, weight: .medium))
                                .foregroundColor(.shineInk3)
                        }
                        .confirmationDialog(
                            isArabic ? "إلغاء الحجز" : "Cancel Booking",
                            isPresented: $showCancelConfirm,
                            titleVisibility: .visible
                        ) {
                            Button(isArabic ? "تأكيد الإلغاء" : "Confirm Cancellation", role: .destructive) {
                                bookingVM.cancelBooking(id: booking.id)
                            }
                            Button(isArabic ? "تراجع" : "Keep Booking", role: .cancel) {}
                        } message: {
                            Text(isArabic ? "هل أنت متأكد أنك تريد إلغاء هذا الحجز؟" : "Are you sure you want to cancel this booking?")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowXS()
    }
}

// MARK: - Reschedule Sheet

struct RescheduleSheet: View {
    let booking: Booking
    @Binding var newDate: Date
    let isArabic: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.shineBG.ignoresSafeArea()

                VStack(spacing: ShineSpacing.lg) {

                    // Service info card
                    HStack(spacing: 14) {
                        let icon = ServiceCategory(rawValue: booking.serviceCategory)?.icon ?? "✨"
                        let soft  = ServiceCategory(rawValue: booking.serviceCategory)?.softColor ?? Color.shineCoralLight
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(soft)
                                .frame(width: 48, height: 48)
                            Text(icon).font(.system(size: 22))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isArabic ? "الخدمة" : "Service")
                                .font(ShineFont.body(11, weight: .semibold))
                                .foregroundColor(.shineInk3)
                                .textCase(.uppercase)
                                .kerning(0.5)
                            Text(booking.packageName)
                                .font(ShineFont.body(15, weight: .semibold))
                                .foregroundColor(.shineInk)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.shineSurface)
                    .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                    .shineShadowXS()

                    // Date & Time pickers
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isArabic ? "التاريخ والوقت الجديد" : "New Date & Time")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineInk3)
                            .textCase(.uppercase)
                            .kerning(0.5)

                        HStack(spacing: 12) {
                            // Date
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.shineCoral)
                                DatePicker("",
                                           selection: $newDate,
                                           in: Date()...,
                                           displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(.shineCoral)
                                    .environment(\.locale,
                                                 isArabic ? Locale(identifier: "ar") : Locale(identifier: "en"))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
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
                                           selection: $newDate,
                                           in: Date()...,
                                           displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(.shineTeal)
                                    .environment(\.locale,
                                                 isArabic ? Locale(identifier: "ar") : Locale(identifier: "en"))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                            .frame(maxWidth: .infinity)
                            .background(Color.shineSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.shineBorder, lineWidth: 1))
                            .shineShadowXS()
                        }
                    }

                    // Selected date summary
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.shineAmber)
                        Text(formattedSelection)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.shineAmberLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    // Confirm button
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text(isArabic ? "تأكيد إعادة الجدولة" : "Confirm Reschedule")
                            .font(ShineFont.body(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.shineCoral)
                            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                            .shadow(color: Color.shineCoral.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                }
                .padding(ShineSpacing.lg)
            }
            .navigationTitle(isArabic ? "إعادة الجدولة" : "Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") { dismiss() }
                        .foregroundColor(.shineCoral)
                }
            }
        }
    }

    private var formattedSelection: String {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .short
        df.locale = isArabic ? Locale(identifier: "ar") : Locale(identifier: "en")
        return df.string(from: newDate)
    }
}
