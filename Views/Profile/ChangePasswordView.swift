import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var showCurrent = false
    @State private var showNew = false
    @State private var showConfirm = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSucceed = false

    // MARK: - Validation

    private var newPasswordValid: Bool { newPassword.count >= 8 }
    private var passwordsMatch: Bool { newPassword == confirmPassword }
    private var canSave: Bool {
        !currentPassword.isEmpty && newPasswordValid && passwordsMatch && !isSaving
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.shineSurface2)
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.shineInk2)
                        }
                    }

                    Spacer()

                    Text("Change Password")
                        .font(ShineFont.displayBold(18))
                        .foregroundColor(.shineInk)

                    Spacer()

                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                                    .frame(width: 60, height: 36)
                            } else {
                                Text("Save")
                                    .font(ShineFont.body(14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 36)
                            }
                        }
                        .background(canSave ? Color.shineCoral : Color.shineCoral.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canSave)
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ShineSpacing.lg) {

                        // ── Fields ───────────────────────────────────────
                        VStack(spacing: 0) {
                            PasswordFieldRow(
                                icon: "lock.fill",
                                iconColor: .shineInk3,
                                placeholder: "Current password",
                                text: $currentPassword,
                                showPassword: $showCurrent
                            )

                            Divider().padding(.leading, 52)

                            PasswordFieldRow(
                                icon: "lock.rotation",
                                iconColor: .shineCoral,
                                placeholder: "New password",
                                text: $newPassword,
                                showPassword: $showNew
                            )

                            if !newPassword.isEmpty && !newPasswordValid {
                                HStack {
                                    Text("At least 8 characters required")
                                        .font(ShineFont.body(11))
                                        .foregroundColor(.shineCoral)
                                        .padding(.leading, 52)
                                    Spacer()
                                }
                                .padding(.horizontal, ShineSpacing.md)
                                .padding(.bottom, 6)
                            }

                            Divider().padding(.leading, 52)

                            PasswordFieldRow(
                                icon: "checkmark.shield.fill",
                                iconColor: .shineTeal,
                                placeholder: "Confirm new password",
                                text: $confirmPassword,
                                showPassword: $showConfirm
                            )

                            if !confirmPassword.isEmpty && !passwordsMatch {
                                HStack {
                                    Text("Passwords don't match")
                                        .font(ShineFont.body(11))
                                        .foregroundColor(.shineCoral)
                                        .padding(.leading, 52)
                                    Spacer()
                                }
                                .padding(.horizontal, ShineSpacing.md)
                                .padding(.bottom, 6)
                            }
                        }
                        .background(Color.shineSurface)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        .shineShadowXS()
                        .padding(.horizontal, ShineSpacing.lg)

                        // ── Error ─────────────────────────────────────────
                        if let err = errorMessage {
                            Text(err)
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineCoral)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, ShineSpacing.lg)
                        }

                        // ── Success ───────────────────────────────────────
                        if didSucceed {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.shineTeal)
                                Text("Password updated successfully")
                                    .font(ShineFont.body(13, weight: .medium))
                                    .foregroundColor(.shineTeal)
                            }
                            .padding(.horizontal, ShineSpacing.lg)
                        }
                    }
                    .padding(.top, ShineSpacing.md)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Save

    private func save() async {
        await MainActor.run {
            isSaving = true
            errorMessage = nil
            didSucceed = false
        }
        do {
            try await UserAPIService.shared.changePassword(current: currentPassword, new: newPassword)
            await MainActor.run {
                isSaving = false
                didSucceed = true
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
            }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Password Field Row

private struct PasswordFieldRow: View {
    let icon: String
    let iconColor: Color
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 14) {
            ProfileIconBox(icon: icon, color: iconColor)
            Group {
                if showPassword {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(ShineFont.body(15))
            .foregroundColor(.shineInk)

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.shineInk3)
            }
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }
}
