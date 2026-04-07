import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AuthViewModel()
    @State private var showRegister = false
    @State private var showPassword = false

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()
                .onTapGesture { hideKeyboard() }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ───────────────────────────────────────────
                    VStack(spacing: 12) {
                        Text("✨")
                            .font(.system(size: 52))
                            .padding(.top, 60)

                        Text(appState.isArabic ? "مرحباً بك" : "Welcome Back")
                            .font(.custom("CormorantGaramond-SemiBold", size: 34))
                            .foregroundColor(.shineInk)

                        Text(appState.isArabic ? "سجّل دخولك للمتابعة" : "Sign in to continue")
                            .font(.custom("Outfit-Regular", size: 15))
                            .foregroundColor(.shineInk2)
                    }
                    .padding(.bottom, 40)

                    // ── Form card ────────────────────────────────────────
                    VStack(spacing: 16) {
                        ShineTextField(
                            icon: "envelope",
                            placeholder: appState.isArabic ? "البريد الإلكتروني" : "Email address",
                            text: $vm.email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )

                        ShineSecureField(
                            icon: "lock",
                            placeholder: appState.isArabic ? "كلمة المرور" : "Password",
                            text: $vm.password,
                            showPassword: $showPassword
                        )

                        if let err = vm.errorMsg {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.shineCoral)
                                Text(err)
                                    .font(.custom("Outfit-Regular", size: 13))
                                    .foregroundColor(.shineCoral)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }

                        // ── Sign in button ────────────────────────────
                        Button {
                            Task { await vm.login() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.shineCoral)
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(appState.isArabic ? "تسجيل الدخول" : "Sign In")
                                        .font(.custom("Outfit-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(height: 52)
                        }
                        .disabled(vm.isLoading)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.shineSurface)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)

                    // ── Divider ──────────────────────────────────────────
                    HStack {
                        Rectangle()
                            .fill(Color.shineBorder)
                            .frame(height: 1)
                        Text(appState.isArabic ? "أو" : "or")
                            .font(.custom("Outfit-Regular", size: 13))
                            .foregroundColor(.shineInk3)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.shineBorder)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    // ── Social Sign-In ────────────────────────────────────
                    HStack(spacing: 12) {
                        // Apple
                        ZStack {
                            AppleIcon()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.shineSurface)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.shineBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                            SignInWithAppleButton(.signIn, onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            }, onCompletion: { result in
                                Task { await vm.handleAppleSignIn(result: result) }
                            })
                            .frame(height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .opacity(0.011)
                        }

                        // Google
                        Button { Task { await vm.loginWithGoogle() } } label: {
                            GoogleIcon()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.shineSurface)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.shineBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }

                        // Facebook
                        Button { Task { await vm.loginWithFacebook() } } label: {
                            FacebookIcon()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.shineSurface)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.shineBorder, lineWidth: 1))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .disabled(vm.isLoading)

                    // ── Register link ────────────────────────────────────
                    VStack(spacing: 8) {
                        Text(appState.isArabic ? "ليس لديك حساب؟" : "Don't have an account?")
                            .font(.custom("Outfit-Regular", size: 14))
                            .foregroundColor(.shineInk2)

                        Button {
                            showRegister = true
                        } label: {
                            Text(appState.isArabic ? "إنشاء حساب جديد" : "Create an account")
                                .font(.custom("Outfit-SemiBold", size: 14))
                                .foregroundColor(.shineCoral)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(appState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notif in
            if let apiUser = notif.object as? APIUser {
                appState.currentUser = apiUser.toUser()
                appState.isAuthenticated = true
            }
        }
        .arabicLayout(appState.isArabic)
    }
}

// MARK: - Brand Icons
struct AppleIcon: View {
    var body: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: 22, weight: .medium))
            .foregroundColor(.shineInk)
    }
}

struct GoogleIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                .frame(width: 34, height: 34)
            Text("G")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.52, blue: 0.96),
                            Color(red: 0.96, green: 0.26, blue: 0.21)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct FacebookIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.23, green: 0.35, blue: 0.60))
                .frame(width: 34, height: 34)
            Text("f")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(x: 1, y: 0)
        }
    }
}

// MARK: - Reusable Form Fields
struct ShineTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.shineInk3)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .font(.custom("Outfit-Regular", size: 15))
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(Color.shineBG)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.shineBorder, lineWidth: 1)
        )
    }
}

struct ShineSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.shineInk3)
                .frame(width: 20)
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.custom("Outfit-Regular", size: 15))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.shineInk3)
            }
        }
        .padding(16)
        .background(Color.shineBG)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.shineBorder, lineWidth: 1)
        )
    }
}
