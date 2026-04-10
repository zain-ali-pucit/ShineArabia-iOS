import SwiftUI

// MARK: - ManagerView
struct ManagerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ManagerViewModel()
    @State private var selectedTab: ManagerTab = .bookings

    enum ManagerTab { case bookings, bundles }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                ManagerHeaderView(vm: vm)
                ManagerTabBar(selected: $selectedTab)

                if selectedTab == .bookings {
                    FilterPillsView(vm: vm)
                    BookingListView(vm: vm)
                } else {
                    BundleManagementView(vm: vm)
                }
            }
        }
        .task {
            vm.requestNotificationPermission()
            async let bookings: () = vm.fetchBookings()
            async let bundles: ()  = vm.loadBundles()
            async let pkgs: ()     = vm.loadAvailablePackages()
            _ = await (bookings, bundles, pkgs)
            vm.startPolling()
        }
        .onDisappear { vm.stopPolling() }
        .sheet(isPresented: $vm.showBundleEditor) {
            if let bundle = vm.editingBundle {
                BundleEditorSheet(vm: vm, bundle: bundle)
            }
        }
    }
}

// MARK: - Header
private struct ManagerHeaderView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var vm: ManagerViewModel
    @State private var showSignOutConfirmation = false
    @State private var showNotifications = false

    private var hasUnread: Bool {
        appState.unreadCount > 0 || vm.hasNewBooking
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("Shine").foregroundColor(.shineInk) + Text("Arabia").foregroundColor(Color(hex: "8D1B3D")))
                    .font(ShineFont.displayBold(22))
                Text("Manager Panel")
                    .font(ShineFont.body(13, weight: .medium))
                    .foregroundColor(.shineInk3)
            }

            Spacer()

            // Notification bell — badge appears when unread notifications exist
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
                NotificationListSheet(notifications: appState.notifications)
            }

            // Sign-out
            Button {
                showSignOutConfirmation = true
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

// MARK: - Notification List Sheet
private struct NotificationListSheet: View {
    let notifications: [AppNotification]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
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
                    EmptyStateView(
                        icon: "🔔",
                        title: "No Notifications",
                        subtitle: "You'll see new booking alerts here."
                    )
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
            } else if let error = vm.errorMessage, vm.bookings.isEmpty {
                VStack(spacing: ShineSpacing.md) {
                    EmptyStateView(
                        icon: "⚠️",
                        title: "Failed to Load",
                        subtitle: error
                    )
                    Button("Retry") {
                        Task { await vm.fetchBookings() }
                    }
                    .font(ShineFont.body(14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.shineTeal)
                    .clipShape(Capsule())
                }
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
    @State private var pendingStatus: Booking.BookingStatus? = nil
    @State private var showReschedule = false
    @State private var rescheduleDate = Date().addingTimeInterval(86400)

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
                        .frame(width: 48, height: 48)
                    Text(categoryEmoji)
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.customerName ?? "Unknown Customer")
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(booking.packageNameEn)
                        .font(ShineFont.body(14))
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
                IconDetail(icon: "calendar", text: booking.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))
                Spacer()
                Text("QAR \(booking.priceAmount, specifier: "%.0f")")
                    .font(ShineFont.body(15, weight: .semibold))
                    .foregroundColor(.shineTeal)
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, 10)

            // ── Location row ────────────────────────────────────────
            if let lat = booking.latitude, let lon = booking.longitude {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.shineTeal)
                    Text(booking.address)
                        .font(ShineFont.body(12))
                        .foregroundColor(.shineInk2)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        let encodedAddress = booking.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        // Use coordinates for Google Maps query to pin the exact location.
                        let googleMapsURL = URL(string: "comgooglemaps://?q=\(lat),\(lon)")
                        let appleMapsURL = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedAddress)")

                        if let googleMapsURL, UIApplication.shared.canOpenURL(googleMapsURL) {
                            UIApplication.shared.open(googleMapsURL)
                        } else if let appleMapsURL {
                            UIApplication.shared.open(appleMapsURL)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 12))
                            Text("Open Map")
                                .font(ShineFont.body(13, weight: .semibold))
                        }
                        .foregroundColor(.shineTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.shineTealLight)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 10)
            }

            // Customer contact (email / phone + WhatsApp)
            if booking.customerEmail != nil || booking.customerPhone != nil {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let email = booking.customerEmail {
                            HStack(spacing: 5) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 11))
                                    .foregroundColor(.shineInk3)
                                Text(email)
                                    .font(ShineFont.body(12))
                                    .foregroundColor(.shineInk3)
                                    .lineLimit(1)
                            }
                        }
                        if let phone = booking.customerPhone {
                            HStack(spacing: 5) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.shineTeal)
                                Text(phone)
                                    .font(ShineFont.body(12, weight: .semibold))
                                    .foregroundColor(.shineInk)
                            }
                        }
                    }

                    Spacer()

                    if let phone = booking.customerPhone {
                        let digits = phone.filter { $0.isNumber }
                        if let url = URL(string: "https://wa.me/\(digits)") {
                            Link(destination: url) {
                                HStack(spacing: 5) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 12))
                                    Text("WhatsApp")
                                        .font(ShineFont.body(12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(hex: "25D366"))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.bottom, 10)
            }

            // ── Status action buttons ──────────────────────────────
            if !booking.allowedNextStatuses.isEmpty || booking.bookingStatus == .pending || booking.bookingStatus == .confirmed {
                Divider()
                    .background(Color.shineBorder)
                    .padding(.horizontal, ShineSpacing.md)

                HStack(spacing: ShineSpacing.sm) {
                    Text("Move to:")
                        .font(ShineFont.body(12, weight: .medium))
                        .foregroundColor(.shineInk3)

                    ForEach(booking.allowedNextStatuses, id: \.self) { nextStatus in
                        StatusActionButton(status: nextStatus) {
                            if nextStatus == .confirmed || nextStatus == .cancelled {
                                pendingStatus = nextStatus
                            } else {
                                Task { await vm.updateStatus(bookingId: booking.id, newStatus: nextStatus) }
                            }
                        }
                    }

                    if booking.bookingStatus == .pending || booking.bookingStatus == .confirmed {
                        Button {
                            rescheduleDate = max(booking.scheduledDate.addingTimeInterval(86400), Date().addingTimeInterval(86400))
                            showReschedule = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 11))
                                Text("Reschedule")
                                    .font(ShineFont.body(12, weight: .semibold))
                            }
                            .foregroundColor(.shineAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.shineAmber.opacity(0.1))
                            .clipShape(Capsule())
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
        .sheet(isPresented: $showReschedule) {
            ManagerRescheduleSheet(
                booking: booking,
                date: $rescheduleDate,
                onConfirm: {
                    showReschedule = false
                    Task { await vm.rescheduleBooking(bookingId: booking.id, date: rescheduleDate) }
                },
                onCancel: { showReschedule = false }
            )
        }
        .confirmationDialog(
            pendingStatus == .cancelled ? "Cancel Booking" : "Confirm Booking",
            isPresented: Binding(
                get: { pendingStatus != nil },
                set: { if !$0 { pendingStatus = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let status = pendingStatus {
                Button(
                    status == .cancelled ? "Yes, Cancel Booking" : "Yes, Confirm Booking",
                    role: status == .cancelled ? .destructive : .none
                ) {
                    Task { await vm.updateStatus(bookingId: booking.id, newStatus: status) }
                }
                Button("No, Keep It", role: .cancel) {}
            }
        } message: {
            if pendingStatus == .cancelled {
                Text("Are you sure you want to cancel \(booking.customerName ?? "this")'s booking? This cannot be undone.")
            } else {
                Text("Confirm booking for \(booking.customerName ?? "this customer")?")
            }
        }
    }
}

// MARK: - Reschedule Sheet

private struct ManagerRescheduleSheet: View {
    let booking: AdminBooking
    @Binding var date: Date
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reschedule Booking")
                            .font(ShineFont.displayBold(20))
                            .foregroundColor(.shineInk)
                        Text(booking.customerName ?? booking.packageNameEn)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk3)
                    }
                    Spacer()
                    Button(action: onCancel) {
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

                // Current date
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(.shineInk3)
                    Text("Current: \(booking.scheduledDate.formatted(.dateTime.day().month(.wide).year().hour().minute()))")
                        .font(ShineFont.body(13))
                        .foregroundColor(.shineInk3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.vertical, 14)
                .background(Color.shineSurface)

                Divider()

                // Date picker
                DatePicker(
                    "New Date & Time",
                    selection: $date,
                    in: Date().addingTimeInterval(3600)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color.shineAmber)
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, ShineSpacing.sm)

                Spacer()

                // Action buttons
                VStack(spacing: ShineSpacing.sm) {
                    Divider()
                    HStack(spacing: ShineSpacing.sm) {
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(ShineFont.body(15, weight: .semibold))
                                .foregroundColor(.shineInk2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.shineSurface)
                                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ShineRadius.md)
                                        .strokeBorder(Color.shineBorder, lineWidth: 1)
                                )
                        }
                        Button(action: onConfirm) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 14))
                                Text("Confirm Reschedule")
                                    .font(ShineFont.body(15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.shineAmber)
                            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        }
                    }
                    .padding(.horizontal, ShineSpacing.lg)
                    .padding(.bottom, ShineSpacing.lg)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

// MARK: - Manager Tab Bar

private struct ManagerTabBar: View {
    @Binding var selected: ManagerView.ManagerTab

    var body: some View {
        HStack(spacing: 0) {
            TabPill(title: "Bookings", icon: "calendar", tab: .bookings, selected: $selected)
            TabPill(title: "Bundles",  icon: "gift",     tab: .bundles,  selected: $selected)
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, ShineSpacing.sm)
    }

    struct TabPill: View {
        let title: String
        let icon: String
        let tab: ManagerView.ManagerTab
        @Binding var selected: ManagerView.ManagerTab

        var isSelected: Bool { selected == tab }

        var body: some View {
            Button { withAnimation(.spring(response: 0.25)) { selected = tab } } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                    Text(title)
                        .font(ShineFont.body(14, weight: isSelected ? .semibold : .regular))
                }
                .foregroundColor(isSelected ? .white : .shineInk2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.shineTeal : Color.shineSurface)
                .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                .shineShadowXS()
            }
        }
    }
}

// MARK: - Bundle Management

private struct BundleManagementView: View {
    @ObservedObject var vm: ManagerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: ShineSpacing.md) {
                if let err = vm.bundleError {
                    Text(err)
                        .font(ShineFont.body(13))
                        .foregroundColor(.shineCoral)
                        .padding(ShineSpacing.md)
                }

                if vm.isBundleLoading && vm.bundles.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if vm.bundles.isEmpty {
                    EmptyStateView(icon: "🎁", title: "No Bundles", subtitle: "Add bundle packages in the service categories to create bundles here.")
                        .padding(.top, 40)
                } else {
                    ForEach(vm.bundles) { bundle in
                        BundleAdminCard(bundle: bundle, vm: vm)
                    }
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.bottom, ShineSpacing.xl)
        }
        .refreshable { await vm.loadBundles() }
    }
}

private struct BundleAdminCard: View {
    let bundle: APIBundle
    @ObservedObject var vm: ManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: ShineSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.shineCoralLight)
                        .frame(width: 44, height: 44)
                    Text(bundle.emoji).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bundle.nameEn)
                        .font(ShineFont.body(15, weight: .semibold))
                        .foregroundColor(.shineInk)
                    Text(bundle.priceDisplay)
                        .font(ShineFont.body(13))
                        .foregroundColor(.shineCoral)
                }
                Spacer()
                // Auto-discount badge
                if bundle.discountPct > 0 {
                    Text("\(bundle.discountPct)% OFF")
                        .font(ShineFont.body(12, weight: .semibold))
                        .foregroundColor(.shineTeal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.shineTealLight)
                        .clipShape(Capsule())
                }
            }
            .padding(ShineSpacing.md)

            Divider().padding(.horizontal, ShineSpacing.md)

            // Price breakdown
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bundle Price")
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                    Text(bundle.priceDisplay)
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Without Bundle")
                        .font(ShineFont.body(11))
                        .foregroundColor(.shineInk3)
                    Text("QAR \(Int(bundle.originalTotal))")
                        .font(ShineFont.body(14, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .strikethrough(bundle.discountPct > 0, color: .shineInk3)
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.vertical, 10)

            // Components
            if !bundle.components.isEmpty {
                Divider().padding(.horizontal, ShineSpacing.md)
                VStack(alignment: .leading, spacing: 6) {
                    Text("COMPONENTS")
                        .font(ShineFont.body(10, weight: .semibold))
                        .foregroundColor(.shineInk3)
                        .kerning(0.8)
                    ForEach(bundle.components) { comp in
                        HStack {
                            Text(comp.emoji).font(.system(size: 14))
                            Text(comp.nameEn)
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineInk)
                            Spacer()
                            Text(comp.priceDisplay)
                                .font(ShineFont.body(13, weight: .medium))
                                .foregroundColor(.shineInk2)
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.vertical, 10)
            }

            Divider().padding(.horizontal, ShineSpacing.md)

            // Actions
            HStack(spacing: ShineSpacing.sm) {
                Button {
                    vm.startEditing(bundle)
                } label: {
                    Label("Edit Components", systemImage: "pencil")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.shineTealLight)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                }

                Button {
                    Task { await vm.clearBundle(bundlePackageId: bundle.id) }
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.shineCoralLight)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.sm))
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.vertical, 10)
        }
        .background(Color.shineSurface)
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowSM()
    }
}

// MARK: - Bundle Editor Sheet

private struct BundleEditorSheet: View {
    @ObservedObject var vm: ManagerViewModel
    let bundle: APIBundle
    @Environment(\.dismiss) var dismiss

    // Group available packages by category
    private var grouped: [(category: String, packages: [AdminPackageItem])] {
        let dict = Dictionary(grouping: vm.availablePackages, by: { $0.categoryName })
        return dict.map { ($0.key, $0.value) }.sorted { $0.category < $1.category }
    }

    private var selectedPackages: [AdminPackageItem] {
        vm.availablePackages.filter { vm.selectedComponentIds.contains($0.id) }
    }

    private var originalTotal: Double {
        selectedPackages.reduce(0) { $0 + $1.priceAmount }
    }

    private var discountPct: Int {
        vm.calculatedDiscount(bundlePrice: bundle.priceAmount)
    }

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit Bundle")
                            .font(ShineFont.displayBold(22))
                            .foregroundColor(.shineInk)
                        Text(bundle.nameEn)
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk3)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.shineSurface2).frame(width: 34, height: 34)
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundColor(.shineInk2)
                        }
                    }
                }
                .padding(ShineSpacing.lg)

                // Live summary
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bundle Price").font(ShineFont.body(11)).foregroundColor(.shineInk3)
                        Text(bundle.priceDisplay).font(ShineFont.body(15, weight: .semibold)).foregroundColor(.shineCoral)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Components Total").font(ShineFont.body(11)).foregroundColor(.shineInk3)
                        Text("QAR \(Int(originalTotal))").font(ShineFont.body(15, weight: .semibold)).foregroundColor(.shineInk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Auto Discount").font(ShineFont.body(11)).foregroundColor(.shineInk3)
                        Text("\(discountPct)% OFF")
                            .font(ShineFont.body(15, weight: .semibold))
                            .foregroundColor(discountPct > 0 ? .shineTeal : .shineInk3)
                    }
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.vertical, 14)
                .background(Color.shineSurface)

                if let err = vm.bundleError {
                    Text(err).font(ShineFont.body(12)).foregroundColor(.shineCoral).padding(.horizontal, ShineSpacing.lg)
                }

                Divider()

                // Package picker grouped by category
                ScrollView {
                    VStack(alignment: .leading, spacing: ShineSpacing.md) {
                        ForEach(grouped, id: \.category) { group in
                            Text(group.category.uppercased())
                                .font(ShineFont.body(11, weight: .semibold))
                                .foregroundColor(.shineInk3)
                                .kerning(0.8)
                                .padding(.horizontal, ShineSpacing.lg)

                            ForEach(group.packages) { pkg in
                                let isSelected = vm.selectedComponentIds.contains(pkg.id)
                                Button { vm.toggleComponent(pkg.id) } label: {
                                    HStack(spacing: 12) {
                                        Text(pkg.emoji).font(.system(size: 20))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pkg.nameEn).font(ShineFont.body(14, weight: .semibold)).foregroundColor(.shineInk)
                                            Text(pkg.priceDisplay).font(ShineFont.body(12)).foregroundColor(.shineInk3)
                                        }
                                        Spacer()
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(isSelected ? .shineTeal : .shineInk3)
                                    }
                                    .padding(.horizontal, ShineSpacing.lg)
                                    .padding(.vertical, 10)
                                    .background(isSelected ? Color.shineTealLight : Color.clear)
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.horizontal, ShineSpacing.lg)
                            }
                        }
                    }
                    .padding(.vertical, ShineSpacing.md)
                }

                // Save button
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        Task {
                            await vm.saveBundle(
                                bundlePackageId: bundle.id,
                                priceAmount: nil,
                                priceDisplay: nil
                            )
                        }
                    } label: {
                        Group {
                            if vm.isBundleLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Bundle  ·  \(discountPct)% auto-discount")
                                        .font(ShineFont.body(15, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(vm.selectedComponentIds.isEmpty ? Color.shineInk3 : Color.shineTeal)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                    }
                    .disabled(vm.selectedComponentIds.isEmpty || vm.isBundleLoading)
                    .padding(ShineSpacing.lg)
                    .padding(.bottom, 10)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
