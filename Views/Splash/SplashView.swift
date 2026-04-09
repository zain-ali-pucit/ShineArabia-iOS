import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool

    // Shimmer — starts off-screen left, sweeps right across the logo
    @State private var shimmerProgress: CGFloat = -0.3

    // Tagline
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 8

    // Expanding rings — each goes from 0→1 scale while fading 1→0 opacity
    @State private var ring1: CGFloat = 0
    @State private var ring2: CGFloat = 0
    @State private var ring3: CGFloat = 0

    // Sparkles
    @State private var sparkleOpacity: Double = 0
    @State private var sparkleScale:   CGFloat = 0.4

    // Progress bar
    @State private var progress:        CGFloat = 0
    @State private var progressOpacity: Double  = 0

    // ─────────────────────────────────────────────────────────
    // MARK: Body
    // ─────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            // Soft ambient glow that pulses behind the logo
            RadialGradient(
                colors: [Color.shineAmber.opacity(0.13), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 210
            )
            .ignoresSafeArea()
            .opacity(1 - ring1)   // fades as first ring expands (reuses animation value)

            // ── Ripple rings ──────────────────────────────────
            rippleRing(progress: ring1, diameter: 210, color: .shineAmber, lineWidth: 1.4)
            rippleRing(progress: ring2, diameter: 300, color: .shineCoral,  lineWidth: 1.0)
            rippleRing(progress: ring3, diameter: 390, color: .shineTeal,   lineWidth: 0.7)

            // ── Sparkles around the logo ──────────────────────
            sparkleCluster

            // ── Logo + tagline ────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Logo — fully visible on appear, matching launch screen exactly
                Image("ShineArabiaFullLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(.horizontal, 40)
                    .overlay(shimmerOverlay)

                // Reserved space keeps logo position stable whether tagline is
                // visible or not, so it never jumps when the text fades in.
                Text("PREMIUM HOME SERVICES")
                    .font(ShineFont.body(11, weight: .semibold))
                    .foregroundColor(.shineInk3)
                    .kerning(2.8)
                    .padding(.top, 18)
                    .frame(height: 36, alignment: .top)
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)

                Spacer()
            }

            // ── Progress bar ──────────────────────────────────
            VStack {
                Spacer()
                progressBar
                    .opacity(progressOpacity)
                    .padding(.bottom, 62)
            }
        }
        .onAppear(perform: startAnimation)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Sub-views
    // ─────────────────────────────────────────────────────────

    /// A single expanding + fading ring.
    private func rippleRing(
        progress: CGFloat,
        diameter: CGFloat,
        color: Color,
        lineWidth: CGFloat
    ) -> some View {
        Circle()
            .strokeBorder(color, lineWidth: lineWidth)
            .frame(width: diameter * max(progress, 0.001),
                   height: diameter * max(progress, 0.001))
            .opacity(Double(1.0 - progress))
    }

    /// Five sparkles positioned around the logo center.
    @ViewBuilder
    private var sparkleCluster: some View {
        let items: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (-118,  -88,  10, .shineAmber),
            ( 112,  -98,   8, .shineCoral),
            (-102,   82,   7, .shineTeal),
            ( 120,   76,  11, .shineAmber),
            (   2, -138,   7, .shineLavender),
        ]
        ForEach(Array(items.enumerated()), id: \.offset) { i, item in
            Image(systemName: "sparkle")
                .font(.system(size: item.2))
                .foregroundColor(item.3)
                .offset(x: item.0, y: item.1)
                .opacity(sparkleOpacity * (i % 2 == 0 ? 1.0 : 0.65))
                .scaleEffect(sparkleScale)
        }
    }

    /// Gold shimmer that sweeps left-to-right across the logo as a gradient overlay.
    private var shimmerOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear,                             location: 0.0),
                .init(color: .clear,                             location: max(0, shimmerProgress - 0.20)),
                .init(color: Color.white.opacity(0.20),          location: max(0, shimmerProgress - 0.07)),
                .init(color: Color(hex: "F4C97A").opacity(0.50), location: shimmerProgress),
                .init(color: Color.white.opacity(0.20),          location: min(1, shimmerProgress + 0.07)),
                .init(color: .clear,                             location: min(1, shimmerProgress + 0.20)),
                .init(color: .clear,                             location: 1.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Coral → amber → teal gradient progress bar with a soft glow cap.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.shineBorder)
                    .frame(height: 3)

                // Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [.shineCoral, .shineAmber, .shineTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 3)
                    .shadow(color: Color.shineCoral.opacity(0.55), radius: 5)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 48)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Animation sequence
    // ─────────────────────────────────────────────────────────

    private func startAnimation() {

        // ── Phase 1 · Ripple rings burst outward (staggered) ──
        withAnimation(.easeOut(duration: 1.1).delay(0.10)) { ring1 = 1 }
        withAnimation(.easeOut(duration: 1.2).delay(0.25)) { ring2 = 1 }
        withAnimation(.easeOut(duration: 1.3).delay(0.40)) { ring3 = 1 }

        // ── Phase 2 · Sparkles pop in ─────────────────────────
        withAnimation(.spring(response: 0.38, dampingFraction: 0.58).delay(0.50)) {
            sparkleOpacity = 1
            sparkleScale   = 1
        }
        // … then dissolve before the tagline draws attention
        withAnimation(.easeOut(duration: 0.45).delay(1.25)) {
            sparkleOpacity = 0
        }

        // ── Phase 3 · Gold shimmer sweep ──────────────────────
        withAnimation(.easeInOut(duration: 0.72).delay(0.55)) {
            shimmerProgress = 1.3
        }

        // ── Phase 4 · Tagline rises in ────────────────────────
        withAnimation(.easeOut(duration: 0.50).delay(0.85)) {
            taglineOpacity = 1
            taglineOffset  = 0
        }

        // ── Phase 5 · Progress bar fills (with a pause at end) ─
        withAnimation(.easeIn(duration: 0.22).delay(0.90)) {
            progressOpacity = 1
        }
        withAnimation(.easeInOut(duration: 1.60).delay(1.00)) {
            progress = 1.0
        }

        // ── Phase 6 · Dismiss after progress completes ─────────
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            withAnimation(.easeInOut(duration: 0.40)) {
                isFinished = true
            }
        }
    }
}
