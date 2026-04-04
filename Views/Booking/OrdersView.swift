import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bookingVM: BookingViewModel
    @State private var selectedSegment = 0

    var body: some View {
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
    }
}

// MARK: - Booking Card
struct BookingCard: View {
    let booking: Booking
    let isArabic: Bool
    @EnvironmentObject var bookingVM: BookingViewModel

    @State private var showReschedule = false
    @State private var newDate: Date = Date()

    var categoryIcon: String {
        ServiceCategory(rawValue: booking.serviceCategory)?.icon ?? "✨"
    }
    var categoryColor: Color {
        ServiceCategory(rawValue: booking.serviceCategory)?.color ?? .shineCoral
    }
    var categorySoft: Color {
        ServiceCategory(rawValue: booking.serviceCategory)?.softColor ?? .shineCoralLight
    }

    var canReschedule: Bool {
        booking.status == .pending || booking.status == .confirmed
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: booking.scheduledDate)
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

            if canReschedule {
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
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isArabic ? "الخدمة" : "Service")
                        .font(ShineFont.body(11, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .textCase(.uppercase)
                        .kerning(0.5)
                    Text(booking.packageName)
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.shineInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isArabic ? "التاريخ والوقت الجديد" : "New Date & Time")
                        .font(ShineFont.body(11, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .textCase(.uppercase)
                        .kerning(0.5)
                    DatePicker(
                        "",
                        selection: $newDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(.shineCoral)
                    .environment(\.locale, isArabic ? Locale(identifier: "ar") : Locale(identifier: "en"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

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
                }
            }
            .padding(ShineSpacing.lg)
            .navigationTitle(isArabic ? "إعادة الجدولة" : "Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") { dismiss() }
                }
            }
        }
    }
}
