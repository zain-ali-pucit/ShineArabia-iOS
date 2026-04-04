import SwiftUI

// MARK: - ManagerView
// Full-screen booking management screen shown exclusively to admin/manager users.
// No tab bar — just the booking list + status controls.
struct ManagerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ManagerViewModel()

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                ManagerHeaderView(vm: vm)
                FilterPillsView(vm: vm)
                BookingListView(vm: vm)
            }
        }
        .task {
            vm.requestNotificationPermission()
            await vm.fetchBookings()
            vm.startPolling()
        }
        .onDisappear {
            vm.stopPolling()
        }
    }
}

// MARK: - Header
private struct ManagerHeaderView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: ManagerViewModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shine Arabia")
                    .font(ShineFont.displayBold(22))
                    .foregroundColor(.shineInk)
                Text("Manager Panel")
                    .font(ShineFont.body(13, weight: .medium))
                    .foregroundColor(.shineInk3)
            }

            Spacer()

            // Notification bell — badge appears when a new booking arrives
            Button {
                vm.hasNewBooking = false
            } label: {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.shineSurface)
                            .frame(width: 40, height: 40)
                            .shineShadowXS()
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.shineInk)
                    }
                    if vm.hasNewBooking {
                        Circle()
                            .fill(Color.shineCoral)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.shineSurface, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .padding(.trailing, 8)

            // Sign-out
            Button {
                Task { await appState.signOut() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("Sign Out")
                        .font(ShineFont.body(13, weight: .medium))
                }
                .foregroundColor(.shineCoral)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.shineCoralLight)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.top, ShineSpacing.md)
        .padding(.bottom, ShineSpacing.sm)
        .background(Color.shineBG)
    }
}

// MARK: - Filter Pills
private struct FilterPillsView: View {
    @ObservedObject var vm: ManagerViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ShineSpacing.sm) {
                ForEach(vm.filters, id: \.label) { filter in
                    let isSelected = vm.selectedFilter == filter.value
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            vm.selectedFilter = filter.value
                        }
                    } label: {
                        Text(filter.label)
                            .font(ShineFont.body(13, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .shineInk2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.shineTeal : Color.shineSurface)
                            .clipShape(Capsule())
                            .shineShadowXS()
                    }
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.vertical, ShineSpacing.sm)
        }
    }
}

// MARK: - Booking List
private struct BookingListView: View {
    @ObservedObject var vm: ManagerViewModel

    var body: some View {
        ZStack {
            if vm.isLoading && vm.bookings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.filteredBookings.isEmpty {
                EmptyStateView(
                    icon: "📋",
                    title: "No Bookings",
                    subtitle: vm.selectedFilter == nil
                        ? "No bookings have been made yet."
                        : "No bookings with this status."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: ShineSpacing.sm) {
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineCoral)
                                .padding(ShineSpacing.md)
                        }
                        ForEach(vm.filteredBookings) { booking in
                            ManagerBookingCard(booking: booking, vm: vm)
                        }
                    }
                    .padding(.horizontal, ShineSpacing.md)
                    .padding(.bottom, ShineSpacing.xl)
                }
                .refreshable {
                    await vm.fetchBookings()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Booking Card
private struct ManagerBookingCard: View {
    let booking: AdminBooking
    @ObservedObject var vm: ManagerViewModel

    private var categoryEmoji: String {
        switch booking.serviceCategory {
        case "laundry":  return "🧺"
        case "cleaning": return "🧹"
        case "carwash":  return "🚗"
        case "pest":     return "🪲"
        case "bundle":   return "🎁"
        default:         return "✨"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top row: customer + emoji ──────────────────────────
            HStack(alignment: .top, spacing: ShineSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.shineTealLight)
                        .frame(width: 44, height: 44)
                    Text(categoryEmoji)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.customerName ?? "Unknown Customer")
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(booking.packageNameEn)
                        .font(ShineFont.body(13))
                        .foregroundColor(.shineInk2)
                        .lineLimit(1)
                }

                Spacer()

                StatusBadge(status: booking.bookingStatus)
            }
            .padding(ShineSpacing.md)

            Divider()
                .background(Color.shineBorder)
                .padding(.horizontal, ShineSpacing.md)

            // ── Details row ────────────────────────────────────────
            HStack(spacing: ShineSpacing.lg) {
                IconDetail(icon: "calendar", text: booking.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year()))
                IconDetail(icon: "mappin.circle", text: booking.address)
                Spacer()
                Text("SAR \(booking.priceAmount, specifier: "%.0f")")
                    .font(ShineFont.body(14, weight: .semibold))
                    .foregroundColor(.shineTeal)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.vertical, 10)

            // Customer contact (email / phone)
            if let email = booking.customerEmail {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 11))
                        .foregroundColor(.shineInk3)
                    Text(email)
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk3)
                        .lineLimit(1)
                    if let phone = booking.customerPhone {
                        Text("·")
                            .foregroundColor(.shineInk3)
                        Image(systemName: "phone")
                            .font(.system(size: 11))
                            .foregroundColor(.shineInk3)
                        Text(phone)
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineInk3)
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.bottom, 10)
            }

            // ── Status action buttons ──────────────────────────────
            if !booking.allowedNextStatuses.isEmpty {
                Divider()
                    .background(Color.shineBorder)
                    .padding(.horizontal, ShineSpacing.md)

                HStack(spacing: ShineSpacing.sm) {
                    Text("Move to:")
                        .font(ShineFont.body(12, weight: .medium))
                        .foregroundColor(.shineInk3)

                    ForEach(booking.allowedNextStatuses, id: \.self) { nextStatus in
                        StatusActionButton(status: nextStatus) {
                            Task {
                                await vm.updateStatus(
                                    bookingId: booking.id,
                                    newStatus: nextStatus
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.vertical, 10)
            }
        }
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowSM()
    }
}

// MARK: - Helpers

private struct IconDetail: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.shineInk3)
            Text(text)
                .font(ShineFont.body(12))
                .foregroundColor(.shineInk2)
                .lineLimit(1)
        }
    }
}

private struct StatusActionButton: View {
    let status: Booking.BookingStatus
    let action: () -> Void

    private var label: String {
        switch status {
        case .confirmed:  return "Confirm"
        case .inProgress: return "Start"
        case .completed:  return "Complete"
        case .cancelled:  return "Cancel"
        default:          return status.displayTitle
        }
    }

    private var color: Color {
        switch status {
        case .confirmed:  return .shineTeal
        case .inProgress: return .shineAmber
        case .completed:  return .shineTeal
        case .cancelled:  return .shineInk3
        default:          return .shineInk3
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(ShineFont.body(12, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}
