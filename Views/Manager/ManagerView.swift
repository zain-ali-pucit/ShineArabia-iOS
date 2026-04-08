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
