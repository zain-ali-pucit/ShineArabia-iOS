import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    let slides: [OnboardingSlide] = [
        OnboardingSlide(
            icon: "✨",
            title: "Premium Home\nServices",
            titleAR: "خدمات منزلية\nراقية",
            subtitle: "Laundry, cleaning & car wash — delivered with care to your door.",
            subtitleAR: "غسيل الملابس، تنظيف المنزل وغسيل السيارة — بعناية فائقة لبابك.",
            color: .shineCoral
        ),
        OnboardingSlide(
            icon: "📅",
            title: "Book in\n60 Seconds",
            titleAR: "احجز في\n٦٠ ثانية",
            subtitle: "Choose your service, pick a time, and our vetted professionals arrive.",
            subtitleAR: "اختر الخدمة، حدد الموعد وسيصلك محترفونا الموثوقون.",
            color: .shineTeal
        ),
        OnboardingSlide(
            icon: "🌟",
            title: "Shine Every\nDay",
            titleAR: "تألّق كل\nyوم",
            subtitle: "Trusted by thousands across the Gulf. Your satisfaction, guaranteed.",
            subtitleAR: "يثق بنا الآلاف في منطقة الخليج. رضاك مضمون دائماً.",
            color: .shineAmber
        ),
    ]

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // Language toggle
                HStack {
                    Spacer()
                    LanguageToggle()
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.md)

                Spacer()

                // Slide content
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        OnboardingSlideView(slide: slide, isArabic: appState.isArabic)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? slides[currentPage].color : Color.shineInk3.opacity(0.3))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentPage)
                    }
                }
                .padding(.bottom, ShineSpacing.xl)

                // CTA
                VStack(spacing: ShineSpacing.md) {
                    Button {
                        withAnimation(.spring(response: 0.5)) {
                            if currentPage < slides.count - 1 {
                                currentPage += 1
                            } else {
                                appState.hasCompletedOnboarding = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentPage < slides.count - 1
                                 ? (appState.isArabic ? "التالي" : "Next")
                                 : (appState.isArabic ? "ابدأ الآن" : "Get Started"))
                                .font(ShineFont.body(16, weight: .semibold))
                            Image(systemName: appState.isArabic ? "arrow.left" : "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(slides[currentPage].color)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        .shineShadowMD()
                    }

                    if currentPage < slides.count - 1 {
                        Button {
                            withAnimation { appState.hasCompletedOnboarding = true }
                        } label: {
                            Text(appState.isArabic ? "تخطي" : "Skip")
                                .font(ShineFont.body(14, weight: .medium))
                                .foregroundColor(.shineInk3)
                        }
                    }
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.bottom, 44)
            }
        }
    }
}

// MARK: - Onboarding Slide Data
struct OnboardingSlide {
    let icon: String
    let title: String
    let titleAR: String
    let subtitle: String
    let subtitleAR: String
    let color: Color
}

// MARK: - Slide View
struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let isArabic: Bool

    var body: some View {
        VStack(spacing: ShineSpacing.xl) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(slide.color.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(slide.color.opacity(0.08))
                    .frame(width: 200, height: 200)
                Text(slide.icon)
                    .font(.system(size: 72))
            }

            VStack(spacing: ShineSpacing.md) {
                Text(isArabic ? slide.titleAR : slide.title)
                    .font(ShineFont.displayBold(36))
                    .foregroundColor(.shineInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(isArabic ? slide.subtitleAR : slide.subtitle)
                    .font(ShineFont.body(15))
                    .foregroundColor(.shineInk2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, ShineSpacing.xl)
            }
        }
        .padding(.horizontal, ShineSpacing.lg)
    }
}
