import SwiftUI
import UIKit
import CryptoKit

// MARK: - Keyboard Dismissal
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Language Toggle (EN / عر)
struct LanguageToggle: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        appState.language = lang
                    }
                } label: {
                    Text(lang.label)
                        .font(lang == .arabic
                              ? ShineFont.arabic(12, weight: .semibold)
                              : ShineFont.body(12, weight: .medium))
                        .foregroundColor(appState.language == lang ? .white : .shineInk3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            appState.language == lang
                            ? Color.shineInk
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.shineSurface)
        .clipShape(Capsule())
        .shineShadowXS()
    }
}

// MARK: - Notification Button
struct NotificationButton: View {
    @EnvironmentObject var appState: AppState
    @State private var showSheet = false

    var body: some View {
        Button {
            appState.requestNotificationPermission()
            showSheet = true
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
                if appState.unreadCount > 0 {
                    Circle()
                        .fill(Color.shineCoral)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.shineSurface, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            NotificationsSheet()
                .environmentObject(appState)
        }
    }
}

// MARK: - Notifications Sheet
struct NotificationsSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(appState.isArabic ? "الإشعارات" : "Notifications")
                        .font(ShineFont.displayBold(22))
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
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.md)

                Divider()

                if appState.notifications.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("🔔")
                            .font(.system(size: 48))
                        Text(appState.isArabic ? "لا توجد إشعارات" : "No notifications yet")
                            .font(ShineFont.displayBold(18))
                            .foregroundColor(.shineInk)
                        Text(appState.isArabic
                             ? "ستظهر هنا إشعارات طلباتك"
                             : "Your booking updates will appear here")
                            .font(ShineFont.body(13))
                            .foregroundColor(.shineInk3)
                            .multilineTextAlignment(.center)
                    }
                    .padding(ShineSpacing.xl)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(appState.notifications) { note in
                                NotificationRow(notification: note)
                            }
                        }
                        .padding(ShineSpacing.lg)
                    }
                }
            }
        }
        .onAppear { appState.markAllNotificationsRead() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
}

// MARK: - Notification Row
private struct NotificationRow: View {
    let notification: AppNotification

    private var timeAgo: String {
        let secs = Int(Date().timeIntervalSince(notification.date))
        if secs < 60  { return "Just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.shineCoralLight)
                    .frame(width: 44, height: 44)
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.shineCoral)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(ShineFont.body(14, weight: .semibold))
                    .foregroundColor(.shineInk)
                Text(notification.body)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk3)
                    .lineLimit(2)
                Text(timeAgo)
                    .font(ShineFont.body(11))
                    .foregroundColor(.shineInk3.opacity(0.7))
                    .padding(.top, 2)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Color.shineCoral)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .background(notification.isRead ? Color.shineSurface : Color.shineCoralLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
        .shineShadowXS()
    }
}

// MARK: - Avatar Button
struct AvatarButton: View {
    let initials: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.shineCoral, .shineAmber],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.shineCoral.opacity(0.3), radius: 6, x: 0, y: 3)
                Text(initials)
                    .font(ShineFont.body(14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Shine Button (Primary CTA)
struct ShineButton: View {
    let title: String
    let isArabic: Bool
    var color: Color = .shineCoral
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Text(title)
                        .font(ShineFont.body(16, weight: .semibold))
                    Image(systemName: isArabic ? "arrow.left" : "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
            .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .disabled(isLoading)
    }
}

// MARK: - Badge Pill
struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(ShineFont.body(10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: Booking.BookingStatus

    var color: Color {
        switch status {
        case .pending:    return .shineAmber
        case .confirmed:  return .shineTeal
        case .inProgress: return .shineCoral
        case .completed:  return .shineTeal
        case .cancelled:  return .shineInk3
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.displayTitle)
                .font(ShineFont.body(11, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Reward Badge
// Distinguishes a reward-redemption booking from a normal paid booking in the
// staff panel — paired with the 🏆 emoji tile on the card.
struct RewardBadge: View {
    let isArabic: Bool

    var body: some View {
        Text(isArabic ? "🏆 مكافأة" : "🏆 REWARD")
            .font(ShineFont.body(10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.shineAmber)
            .clipShape(Capsule())
    }
}

// MARK: - Empty State
struct IconDetail: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.shineInk3)
            Text(text)
                .font(ShineFont.body(13))
                .foregroundColor(.shineInk3)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Text(icon).font(.system(size: 56))
            Text(title)
                .font(ShineFont.displayBold(22))
                .foregroundColor(.shineInk)
            Text(subtitle)
                .font(ShineFont.body(14))
                .foregroundColor(.shineInk3)
                .multilineTextAlignment(.center)
        }
        .padding(ShineSpacing.xl)
    }
}

// MARK: - Avatar Image Cache (memory + disk, keyed by URL)

final class AvatarImageCache {
    static let shared = AvatarImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("AvatarCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 200
    }

    func image(for url: URL) -> UIImage? {
        let key = url.absoluteString as NSString
        if let img = memory.object(forKey: key) { return img }
        guard let data = try? Data(contentsOf: diskPath(for: url)),
              let img = UIImage(data: data) else { return nil }
        memory.setObject(img, forKey: key)
        return img
    }

    func store(_ image: UIImage, data: Data, for url: URL) {
        memory.setObject(image, forKey: url.absoluteString as NSString)
        try? data.write(to: diskPath(for: url))
    }

    func evict(url: URL) {
        memory.removeObject(forKey: url.absoluteString as NSString)
        try? FileManager.default.removeItem(at: diskPath(for: url))
    }

    private func diskPath(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}

// MARK: - CachedAsyncImage (drop-in for AsyncImage, backed by AvatarImageCache)

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let url, let cached = AvatarImageCache.shared.image(for: url) {
            self._phase = State(initialValue: .success(Image(uiImage: cached)))
        } else {
            self._phase = State(initialValue: .empty)
        }
    }

    var body: some View {
        content(phase).task(id: url) { await load() }
    }

    @MainActor
    private func load() async {
        guard let url else { phase = .empty; return }
        if let cached = AvatarImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }
        phase = .empty
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                phase = .failure(URLError(.badServerResponse))
                return
            }
            guard let img = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            AvatarImageCache.shared.store(img, data: data, for: url)
            phase = .success(Image(uiImage: img))
        } catch {
            phase = .failure(error)
        }
    }
}
