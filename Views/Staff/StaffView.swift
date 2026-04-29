import SwiftUI
import CoreLocation

// MARK: - StaffView
struct StaffView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = StaffViewModel()

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                StaffHeaderView(vm: vm)
                StaffFilterPillsView(vm: vm)
                StaffBookingListView(vm: vm)
            }
        }
        .task {
            vm.userRole = appState.userRole
            vm.currentStaffId = appState.currentUser?.id.uuidString
            vm.currentStaffName = appState.currentUser?.name
            vm.requestNotificationPermission()
            vm.startLocationTracking()
            await vm.fetchBookings()
            vm.startPolling()
        }
        // FCM-driven refresh: a `booking_refresh` push (other staff accepted)
        // or a `new_booking` push (customer just booked) bumps this counter,
        // and we refetch immediately rather than waiting for the 30 s poll.
        .onChange(of: appState.bookingRefreshTick) { _ in
            Task { await vm.fetchBookings() }
        }
        // When a brand-new booking arrives via FCM, force the Pending tab so
        // staff don't have to switch tabs to find the freshly-arrived card.
        // (The card's "NEW" decoration is already driven by appState.newBookingIds.)
        .onChange(of: appState.newBookingIds) { ids in
            guard !ids.isEmpty else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                vm.selectedFilter = "pending"
            }
        }
        .onDisappear {
            vm.stopPolling()
            vm.stopLocationTracking()
        }
    }
}

// MARK: - Header
private struct StaffHeaderView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: StaffViewModel
    @State private var showSignOutConfirmation = false
    @State private var showNotifications       = false
    @State private var showProfileEdit         = false

    private var hasUnread: Bool { appState.unreadCount > 0 || vm.hasNewBooking }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color.shineTeal.opacity(0.15))
                .frame(width: 36, height: 36)
            Text(appState.currentUser?.avatarInitials ?? "SA")
                .font(ShineFont.body(12, weight: .bold))
                .foregroundColor(.shineTeal)
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("Shine").foregroundColor(.shineInk) + Text("Arabia").foregroundColor(Color(hex: "8D1B3D")))
                    .font(ShineFont.displayBold(22))
                Text("Staff Panel")
                    .font(ShineFont.body(13, weight: .medium))
                    .foregroundColor(.shineInk3)
            }

            Spacer()

            // Notification bell
            Button {
                vm.hasNewBooking = false
                appState.markAllNotificationsRead()
                showNotifications = true
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
                    if hasUnread {
                        Circle()
                            .fill(Color.shineCoral)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.shineSurface, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .padding(.trailing, 8)
            .sheet(isPresented: $showNotifications) {
                StaffNotificationSheet(notifications: appState.notifications)
            }

            // Profile
            Button { showProfileEdit = true } label: {
                ZStack {
                    if let urlStr = appState.currentUser?.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                avatarFallback
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.shineTeal.opacity(0.4), lineWidth: 1.5))
                    } else {
                        avatarFallback
                    }
                }
            }
            .sheet(isPresented: $showProfileEdit) {
                StaffProfileEditView()
            }
            .padding(.trailing, 4)

            // Sign-out
            Button { showSignOutConfirmation = true } label: {
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
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await appState.signOut()
                        await MainActor.run { appState.selectedTab = .home }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.top, ShineSpacing.md)
        .padding(.bottom, ShineSpacing.sm)
        .background(Color.shineBG)
    }
}

// MARK: - Notification Sheet
private struct StaffNotificationSheet: View {
    let notifications: [AppNotification]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Notifications")
                        .font(ShineFont.displayBold(20))
                        .foregroundColor(.shineInk)
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
                }
                .padding(ShineSpacing.lg)

                Divider()

                if notifications.isEmpty {
                    Spacer()
                    EmptyStateView(icon: "🔔", title: "No Notifications", subtitle: "New booking alerts will appear here.")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(notifications) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(note.title)
                                            .font(ShineFont.body(14, weight: .semibold))
                                            .foregroundColor(.shineInk)
                                        Spacer()
                                        Text(note.date, style: .relative)
                                            .font(ShineFont.body(11))
                                            .foregroundColor(.shineInk3)
                                    }
                                    Text(note.body)
                                        .font(ShineFont.body(13))
                                        .foregroundColor(.shineInk2)
                                }
                                .padding(ShineSpacing.md)
                                .background(note.isRead ? Color.clear : Color.shineTealLight.opacity(0.4))
                                Divider().padding(.horizontal, ShineSpacing.md)
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Filter Pills
private struct StaffFilterPillsView: View {
    @ObservedObject var vm: StaffViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ShineSpacing.sm) {
                ForEach(vm.filters, id: \.label) { filter in
                    let isSelected = vm.selectedFilter == filter.value
                    Button {
                        withAnimation(.spring(response: 0.25)) { vm.selectedFilter = filter.value }
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
private struct StaffBookingListView: View {
    @ObservedObject var vm: StaffViewModel

    var body: some View {
        ZStack {
            if vm.isLoading && vm.bookings.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.errorMessage, vm.bookings.isEmpty {
                VStack(spacing: ShineSpacing.md) {
                    EmptyStateView(icon: "⚠️", title: "Failed to Load", subtitle: error)
                    Button("Retry") { Task { await vm.fetchBookings() } }
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .background(Color.shineTeal).clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.filteredBookings.isEmpty {
                EmptyStateView(
                    icon: "📋",
                    title: "No Bookings",
                    subtitle: vm.selectedFilter == nil ? "No active bookings." : "No bookings with this status."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: ShineSpacing.sm) {
                            Color.clear.frame(height: 0).id("bookingListTop")
                            ForEach(vm.filteredBookings) { booking in
                                StaffBookingCard(booking: booking, vm: vm)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal:   .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.filteredBookings.map { $0.id })
                        .padding(.horizontal, ShineSpacing.md)
                        .padding(.bottom, ShineSpacing.xl)
                    }
                    .refreshable { await vm.fetchBookings() }
                    .onChange(of: vm.selectedFilter) { _ in
                        proxy.scrollTo("bookingListTop", anchor: .top)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Booking Card
private struct StaffBookingCard: View {
    let booking: StaffBooking
    @ObservedObject var vm: StaffViewModel
    @State private var showCancelSheet = false
    @State private var cancelReason = ""

    private var isUpdating: Bool { vm.inFlightBookingIds.contains(booking.id) }

    private var distanceText: String? {
        guard let lat = booking.latitude,
              let lon = booking.longitude,
              let staffLoc = vm.staffLocation else { return nil }
        let bookingLoc = CLLocation(latitude: lat, longitude: lon)
        let meters = staffLoc.distance(from: bookingLoc)
        return meters < 1000
            ? "\(Int(meters.rounded())) m"
            : String(format: "%.1f km", meters / 1000)
    }

    private var categoryEmoji: String {
        switch booking.serviceCategory {
        case "cleaning":        return "🧹"
        case "office-cleaning": return "🏢"
        case "shop-cleaning":   return "🏪"
        case "laundry":         return "🧺"
        case "carwash":         return "🚗"
        case "bundle":          return "🎁"
        default:                return "✨"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top row ───────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.shineTealLight)
                        .frame(width: 56, height: 56)
                    Text(categoryEmoji)
                        .font(.system(size: 28))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(booking.customerName ?? "Unknown Customer")
                        .font(ShineFont.body(17, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(booking.packageNameEn)
                        .font(ShineFont.body(15))
                        .foregroundColor(.shineInk2)
                        .lineLimit(1)
                }

                Spacer()
                StatusBadge(status: booking.bookingStatus)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, ShineSpacing.md)
            .padding(.bottom, 14)

            Divider()
                .background(Color.shineBorder)
                .padding(.horizontal, ShineSpacing.md)

            // ── Date + price ──────────────────────────────────────────
            HStack(spacing: ShineSpacing.lg) {
                IconDetail(
                    icon: "calendar",
                    text: booking.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
                )
                Spacer()
                Text("QAR \(booking.priceAmount, specifier: "%.0f")")
                    .font(ShineFont.body(16, weight: .semibold))
                    .foregroundColor(.shineTeal)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, 14)

            // ── Address ───────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.shineTeal)
                Text(booking.address)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk2)
                    .lineLimit(2)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, 10)

            // ── Distance + map button ─────────────────────────────────
            HStack(spacing: ShineSpacing.sm) {
                if let dist = distanceText {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 10, weight: .semibold))
                        Text(dist)
                            .font(ShineFont.body(13, weight: .semibold))
                    }
                    .foregroundColor(.shineAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.shineAmberLight)
                    .clipShape(Capsule())
                }
                Spacer()
                if let lat = booking.latitude, let lon = booking.longitude {
                    Button {
                        let encoded = booking.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let googleURL = URL(string: "comgooglemaps://?q=\(lat),\(lon)")
                        let appleURL  = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encoded)")
                        if let g = googleURL, UIApplication.shared.canOpenURL(g) {
                            UIApplication.shared.open(g)
                        } else if let a = appleURL {
                            UIApplication.shared.open(a)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill").font(.system(size: 13))
                            Text("Open Map").font(ShineFont.body(14, weight: .semibold))
                        }
                        .foregroundColor(.shineTeal)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.shineTealLight)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, 8)

            // ── Customer contact ──────────────────────────────────────
            if booking.customerEmail != nil || booking.customerPhone != nil {
                Divider()
                    .background(Color.shineBorder)
                    .padding(.horizontal, ShineSpacing.md)
                    .padding(.top, 12)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let email = booking.customerEmail {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 12)).foregroundColor(.shineInk3)
                                Text(email).font(ShineFont.body(13)).foregroundColor(.shineInk3).lineLimit(1)
                            }
                        }
                        if let phone = booking.customerPhone {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12)).foregroundColor(.shineTeal)
                                Text(phone).font(ShineFont.body(14, weight: .semibold)).foregroundColor(.shineInk)
                            }
                        }
                    }
                    Spacer()
                    if let phone = booking.customerPhone {
                        let digits = phone.filter { $0.isNumber }
                        if let url = URL(string: "https://wa.me/\(digits)") {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "message.fill").font(.system(size: 13))
                                    Text("WhatsApp").font(ShineFont.body(14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Color(hex: "25D366"))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, 12)
            }

            // ── Cancel reason (admin view) ────────────────────────────
            if booking.status == "cancelled", let reason = booking.cancelReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.shineCoral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cancellation Reason")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineCoral)
                        Text(reason)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.shineCoralLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, 10)
            }

            // ── Completed by ──────────────────────────────────────────
            if booking.status == "completed", let staffName = booking.completedByStaffName {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.shineTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completed by")
                            .font(ShineFont.body(11, weight: .semibold))
                            .foregroundColor(.shineTeal)
                        HStack(spacing: 6) {
                            Text(staffName)
                                .font(ShineFont.body(13, weight: .semibold))
                                .foregroundColor(.shineInk)
                            if let completedAt = booking.completedAt {
                                Text("·")
                                    .foregroundColor(.shineInk3)
                                Text(completedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                    .font(ShineFont.body(12))
                                    .foregroundColor(.shineInk3)
                            }
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.shineTealLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, 10)
            }

            // ── Action buttons ────────────────────────────────────────
            if !booking.allowedNextStatuses.isEmpty {
                Divider()
                    .background(Color.shineBorder)
                    .padding(.horizontal, ShineSpacing.md)
                    .padding(.top, 14)

                HStack(spacing: ShineSpacing.sm) {
                    ForEach(booking.allowedNextStatuses, id: \.self) { nextStatus in
                        if nextStatus == .cancelled {
                            Button { showCancelSheet = true } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: nextStatus.actionIcon)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(nextStatus.actionLabel)
                                        .font(ShineFont.body(15, weight: .semibold))
                                }
                                .foregroundColor(.shineCoral)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.shineCoralLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isUpdating)
                            .sheet(isPresented: $showCancelSheet) {
                                CancelReasonSheet(reason: $cancelReason) {
                                    showCancelSheet = false
                                    Task {
                                        await vm.cancelWithReason(bookingId: booking.id, reason: cancelReason)
                                        cancelReason = ""
                                    }
                                }
                            }
                        } else {
                            Button {
                                Task {
                                    await vm.updateStatus(bookingId: booking.id, newStatus: nextStatus)
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    if isUpdating {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: nextStatus.actionIcon)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(nextStatus.actionLabel)
                                            .font(ShineFont.body(15, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(nextStatus.actionColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isUpdating)
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, 12)
            }

            Spacer().frame(height: ShineSpacing.lg)
        }
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.lg))
        .shineShadowSM()
    }
}

// MARK: - Cancel Reason Sheet
private struct CancelReasonSheet: View {
    @Binding var reason: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.shineBorder)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Title
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cancel Booking")
                            .font(ShineFont.displayBold(20))
                            .foregroundColor(.shineInk)
                        Text("Please provide a reason for cancellation.")
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk3)
                    }
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
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, ShineSpacing.md)
                .padding(.bottom, ShineSpacing.md)

                Divider()

                // Reason text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineInk2)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.shineSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isFocused ? Color.shineCoral : Color.shineBorder, lineWidth: 1.5)
                            )

                        if reason.isEmpty {
                            Text("e.g. Staff unavailable, emergency, rescheduling needed…")
                                .font(ShineFont.body(14))
                                .foregroundColor(.shineInk3)
                                .padding(.horizontal, 14)
                                .padding(.top, 13)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $reason)
                            .font(ShineFont.body(14))
                            .foregroundColor(.shineInk)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .focused($isFocused)
                    }
                    .frame(height: 120)
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, ShineSpacing.md)

                Spacer()

                // Confirm button
                Button {
                    guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onConfirm()
                } label: {
                    Text("Confirm Cancellation")
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.shineCoral.opacity(0.4)
                                    : Color.shineCoral)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                }
                .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, ShineSpacing.md)
                .padding(.bottom, ShineSpacing.xl)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .onAppear { isFocused = true }
    }
}
