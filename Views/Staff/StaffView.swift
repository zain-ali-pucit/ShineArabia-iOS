import SwiftUI
import UIKit
import CoreLocation
import QuickLook

// Wrapper so `.sheet(item:)` can drive a QuickLook preview off a downloaded URL.
fileprivate struct ReceiptPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - StaffView
struct StaffView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = StaffViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
        // Refresh whenever the app returns to foreground. FCM pushes that arrive
        // while the app is backgrounded can't drive an in-memory refresh, so the
        // booking list would otherwise wait for the 30 s background poll — too
        // slow when staff just got pinged about a new order.
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await vm.fetchBookings() }
            }
        }
        // FCM-driven refresh: a `booking_refresh` push (other staff accepted)
        // or a `new_booking` push (customer just booked) bumps this counter,
        // and we refetch immediately rather than waiting for the 30 s poll.
        .onChange(of: appState.bookingRefreshTick) { _ in
            Task { await vm.fetchBookings() }
        }
        // When a brand-new booking arrives via FCM, force the Pending tab AND
        // refetch directly. We can't rely solely on bookingRefreshTick because
        // SwiftUI's onChange skips changes that happened while the view was
        // inactive — newBookingIds is the StateFlow-equivalent signal we always
        // get reliably, so we trigger the reload here too.
        .onChange(of: appState.newBookingIds) { ids in
            guard !ids.isEmpty else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                vm.selectedFilter = "pending"
            }
            Task { await vm.fetchBookings() }
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
                        CachedAsyncImage(url: url) { phase in
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
    @EnvironmentObject var appState: AppState
    @State private var showCancelSheet = false
    @State private var cancelReason = ""
    @State private var receiptPreview: ReceiptPreviewItem? = nil
    @State private var isOpeningReceipt: Bool              = false

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
        case "rewards":         return "🏆"
        default:                return "✨"
        }
    }

    private var isReward: Bool { booking.serviceCategory == "rewards" }

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
                VStack(alignment: .trailing, spacing: 6) {
                    if isReward {
                        RewardBadge(isArabic: appState.isArabic)
                    }
                    StatusBadge(status: booking.bookingStatus)
                }
            }
            .padding(.horizontal, ShineSpacing.md)
            .padding(.top, ShineSpacing.md)
            .padding(.bottom, 14)

            Divider()
                .background(Color.shineBorder)
                .padding(.horizontal, ShineSpacing.md)

            // ── Date + price (with discount line, mirrors admin panel) ─
            HStack(alignment: .top, spacing: ShineSpacing.lg) {
                IconDetail(
                    icon: "calendar",
                    text: booking.scheduledDate.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("QAR \(booking.priceAmount, specifier: "%.0f")")
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.shineTeal)
                    if booking.discountAmount > 0 {
                        Text("- QAR \(booking.discountAmount, specifier: "%.0f") disc")
                            .font(ShineFont.body(11))
                            .foregroundColor(.shineInk3)
                    }
                }
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

            // ── Receipt actions ───────────────────────────────────────
            // Completed bookings show the PAID receipt; in-progress bookings
            // show the same PDF without the stamp, plus a Send button so staff
            // can push it to the customer over WhatsApp for payment.
            // View downloads the PDF locally and opens it in QuickLook.
            if (booking.bookingStatus == .completed || booking.bookingStatus == .inProgress),
               let receiptURL = URL(string: "\(APIConfig.baseURL)/bookings/\(booking.id)/receipt") {
                let isUnpaid = booking.bookingStatus == .inProgress
                Divider()
                    .background(Color.shineBorder)
                    .padding(.horizontal, ShineSpacing.md)
                    .padding(.top, 14)

                HStack(spacing: ShineSpacing.sm) {
                    Button {
                        if isOpeningReceipt { return }
                        isOpeningReceipt = true
                        Task { @MainActor in
                            if let local = await downloadReceiptToCache(
                                receiptURL: receiptURL,
                                bookingId:  booking.id
                            ) {
                                receiptPreview = ReceiptPreviewItem(url: local)
                            }
                            isOpeningReceipt = false
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isOpeningReceipt {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(
                                        tint: isUnpaid ? .shineAmber : .shineTeal
                                    ))
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(appState.isArabic ? "عرض الإيصال" : "View Receipt")
                                    .font(ShineFont.body(13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        .foregroundColor(isUnpaid ? .shineAmber : .shineTeal)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 11)
                        .background(isUnpaid ? Color.shineAmberLight : Color.shineTealLight)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isOpeningReceipt)

                    // Send only on in-progress — completed bookings are already
                    // paid, so there's nothing for the customer to act on.
                    if isUnpaid {
                        Button {
                            shareReceiptViaWhatsApp(
                                receiptURL:    receiptURL,
                                bookingId:     booking.id,
                                customerPhone: booking.customerPhone,
                                customerName:  booking.customerName,
                                isArabic:      appState.isArabic
                            )
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(appState.isArabic ? "إرسال" : "Send")
                                    .font(ShineFont.body(13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 11)
                            .background(Color.shineAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.md)
                .padding(.top, 12)
                .sheet(item: $receiptPreview) { preview in
                    ReceiptQuickLookView(fileURL: preview.url)
                        .ignoresSafeArea()
                }
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

// MARK: - Receipt sharing helper
// Downloads the receipt PDF into the app's Documents folder AND opens WhatsApp
// pre-targeted to the customer with a message containing the receipt URL.
// Both run in parallel so the staff lands on the chat immediately while the
// file finishes saving in the background.
//
// Falls back gracefully:
//   • If the phone is missing/too short, presents the system share sheet.
//   • If WhatsApp isn't installed, wa.me hands off to Safari.
fileprivate func shareReceiptViaWhatsApp(
    receiptURL: URL,
    bookingId: String,
    customerPhone: String?,
    customerName: String?,
    isArabic: Bool
) {
    // 1. Background download of the PDF to Documents/Downloads/.
    Task.detached(priority: .utility) {
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: receiptURL)
            let docs = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let downloads = docs.appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
            let shortId  = String(bookingId.prefix(8)).uppercased()
            let dest = downloads.appendingPathComponent("ShineArabia-Receipt-\(shortId).pdf")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
        } catch {
            // Best-effort — WhatsApp deep-link still carries the public URL.
        }
    }

    // 2. Build the message and open WhatsApp targeted at the customer.
    let firstName = customerName?.split(separator: " ").first.map(String.init)?
        .trimmingCharacters(in: .whitespaces)
    let greeting: String
    let body: String
    if isArabic {
        greeting = (firstName?.isEmpty == false) ? "مرحبًا \(firstName!)،" : "مرحبًا،"
        body = "إيصالك من ShineArabia جاهز:\n\(receiptURL.absoluteString)"
    } else {
        greeting = (firstName?.isEmpty == false) ? "Hi \(firstName!)," : "Hi,"
        body = "Your ShineArabia service receipt is ready:\n\(receiptURL.absoluteString)"
    }
    let message = "\(greeting)\n\(body)"

    let digits = (customerPhone ?? "").filter(\.isNumber)
    let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    let waURL: URL? = (digits.count >= 7)
        ? URL(string: "https://wa.me/\(digits)?text=\(encoded)")
        : nil

    Task { @MainActor in
        if let waURL, await UIApplication.shared.canOpenURL(waURL) || waURL.scheme == "https" {
            await UIApplication.shared.open(waURL)
            return
        }
        // Fallback — show the system share sheet so staff can pick another app.
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        let activity = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        presenter.present(activity, animated: true)
    }
}

// MARK: - Receipt download helper
// Downloads the receipt PDF into the app cache and returns the local file URL,
// suitable for handing to QLPreviewController. Returns nil on failure.
fileprivate func downloadReceiptToCache(receiptURL: URL, bookingId: String) async -> URL? {
    do {
        let (tempURL, _) = try await URLSession.shared.download(from: receiptURL)
        let caches = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = caches.appendingPathComponent("receipts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let shortId = String(bookingId.prefix(8)).uppercased()
        let dest = dir.appendingPathComponent("ShineArabia-Receipt-\(shortId).pdf")
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    } catch {
        return nil
    }
}

// MARK: - QuickLook wrapper
// Hosts a QLPreviewController inside SwiftUI to render the PDF in-app, matching
// Android's "download then open in PDF viewer" UX.
fileprivate struct ReceiptQuickLookView: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No-op — fileURL is captured at init.
    }

    func makeCoordinator() -> Coordinator { Coordinator(fileURL: fileURL) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL
        init(fileURL: URL) { self.fileURL = fileURL }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            fileURL as QLPreviewItem
        }
    }
}
