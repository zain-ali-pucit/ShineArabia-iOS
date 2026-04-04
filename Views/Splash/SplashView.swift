import SwiftUI

struct SplashView: View {
    @Binding var isFinished: Bool

    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var progress: CGFloat = 0
    @State private var progressOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.shineBG
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Logo
                VStack(spacing: 20) {
                    Image("ShineArabiaLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shineShadowMD()

                    Text("Premium Home Services")
                        .font(ShineFont.body(13, weight: .medium))
                        .foregroundColor(.shineInk3)
                        .tracking(2)
                        .textCase(.uppercase)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer()

                // MARK: Progress bar
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.shineBorder)
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.shineCoral, .shineTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 48)
                }
                .opacity(progressOpacity)
                .padding(.bottom, 64)
            }
        }
        .onAppear(perform: startAnimation)
    }

    private func startAnimation() {
        // Fade + scale in logo
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1
        }

        // Show progress bar shortly after
        withAnimation(.easeIn(duration: 0.3).delay(0.4)) {
            progressOpacity = 1
        }

        // Fill progress bar over 1.4 seconds
        withAnimation(.easeInOut(duration: 1.4).delay(0.5)) {
            progress = 1.0
        }

        // Dismiss splash after progress completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeInOut(duration: 0.35)) {
                isFinished = true
            }
        }
    }
}
