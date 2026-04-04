import SwiftUI

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
    @State private var hasNotification = true

    var body: some View {
        Button {} label: {
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
                if hasNotification {
                    Circle()
                        .fill(Color.shineCoral)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.shineSurface, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
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

// MARK: - Empty State
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
