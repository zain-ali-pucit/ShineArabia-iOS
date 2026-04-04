import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showPassword  = false
    @State private var showConfirm   = false

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ─────────────────────────────────────────
                    VStack(spacing: 12) {
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.shineInk2)
                                    .frame(width: 36, height: 36)
                                    .background(Color.shineSurface)
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Text("🌟")
                            .font(.system(size: 48))
                            .padding(.top, 12)

                        Text(appState.isArabic ? "إنشاء حساب" : "Create Account")
                            .font(.custom("CormorantGaramond-SemiBold", size: 32))
                            .foregroundColor(.shineInk)

                        Text(appState.isArabic ? "انضم إلى شاين عربيا اليوم" : "Join ShineArabia today")
                            .font(.custom("Outfit-Regular", size: 15))
                            .foregroundColor(.shineInk2)
                    }
                    .padding(.bottom, 32)

                    // ── Form ──────────────────────────────────────────
                    VStack(spacing: 14) {
                        ShineTextField(
                            icon: "person",
                            placeholder: appState.isArabic ? "الاسم الكامل" : "Full name",
                            text: $vm.name
                        )

                        ShineTextField(
                            icon: "envelope",
                            placeholder: appState.isArabic ? "البريد الإلكتروني" : "Email address",
                            text: $vm.email,
                            keyboardType: .emailAddress,
                            autocapitalization: .never
                        )

                        ShineTextField(
                            icon: "phone",
                            placeholder: appState.isArabic ? "رقم الجوال (اختياري)" : "Phone number (optional)",
                            text: $vm.phone,
                            keyboardType: .phonePad
                        )

                        ShineSecureField(
                            icon: "lock",
                            placeholder: appState.isArabic ? "كلمة المرور" : "Password (min 8 chars)",
                            text: $vm.password,
                            showPassword: $showPassword
                        )

                        ShineSecureField(
                            icon: "lock.shield",
                            placeholder: appState.isArabic ? "تأكيد كلمة المرور" : "Confirm password",
                            text: $vm.confirmPassword,
                            showPassword: $showConfirm
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

                        Button {
                            Task { await vm.register() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.shineCoral, Color(hex: "D45A43")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(appState.isArabic ? "إنشاء الحساب" : "Create Account")
                                        .font(.custom("Outfit-SemiBold", size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(height: 52)
                        }
                        .disabled(vm.isLoading)
                        .padding(.top, 6)

                        // Terms text
                        Text(appState.isArabic
                             ? "بالتسجيل، أنت توافق على شروط الخدمة وسياسة الخصوصية"
                             : "By registering, you agree to our Terms of Service and Privacy Policy")
                            .font(.custom("Outfit-Regular", size: 12))
                            .foregroundColor(.shineInk3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(24)
                    .background(Color.shineSurface)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notif in
            if let apiUser = notif.object as? APIUser {
                appState.currentUser = apiUser.toUser()
                appState.isAuthenticated = true
                dismiss()
            }
        }
        .arabicLayout(appState.isArabic)
    }
}
