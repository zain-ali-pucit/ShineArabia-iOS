import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Form fields — pre-filled from current user
    @State private var name: String
    @State private var phone: String

    // Avatar
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedImage: Image?

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(user: User) {
        _name  = State(initialValue: user.name)
        _phone = State(initialValue: user.phone)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ─────────────────────────────────────────────
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

                    Text("Edit Profile")
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
                        .background(Color.shineCoral)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, ShineSpacing.lg)
                .padding(.top, ShineSpacing.lg)
                .padding(.bottom, ShineSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ShineSpacing.lg) {

                        // ── Avatar picker ───────────────────────────────
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                avatarCircle
                                    .frame(width: 100, height: 100)

                                ZStack {
                                    Circle()
                                        .fill(Color.shineCoral)
                                        .frame(width: 30, height: 30)
                                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        .onChange(of: pickerItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    if let uiImg = UIImage(data: data) {
                                        selectedImage = Image(uiImage: uiImg)
                                    }
                                }
                            }
                        }
                        .padding(.top, ShineSpacing.md)

                        Text("Tap to change photo")
                            .font(ShineFont.body(12))
                            .foregroundColor(.shineInk3)

                        // ── Form fields ─────────────────────────────────
                        VStack(spacing: 0) {
                            EditFieldRow(
                                icon: "person.fill",
                                iconColor: .shineLavender,
                                placeholder: "Full name",
                                text: $name
                            )

                            Divider().padding(.leading, 52)

                            EditFieldRow(
                                icon: "phone.fill",
                                iconColor: .shineTeal,
                                placeholder: "Phone number",
                                text: $phone,
                                keyboardType: .phonePad
                            )

                        }
                        .background(Color.shineSurface)
                        .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                        .shineShadowXS()
                        .padding(.horizontal, ShineSpacing.lg)

                        // ── Email (read-only) ────────────────────────────
                        if let email = appState.currentUser?.email {
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    ProfileIconBox(icon: "envelope.fill", color: .shineInk3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Email")
                                            .font(ShineFont.body(12))
                                            .foregroundColor(.shineInk3)
                                        Text(email)
                                            .font(ShineFont.body(15))
                                            .foregroundColor(.shineInk2)
                                    }
                                    Spacer()
                                    Text("Fixed")
                                        .font(ShineFont.body(11))
                                        .foregroundColor(.shineInk3)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.shineSurface2)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, ShineSpacing.md)
                                .padding(.vertical, 13)
                            }
                            .background(Color.shineSurface)
                            .clipShape(RoundedRectangle(cornerRadius: ShineRadius.md))
                            .shineShadowXS()
                            .padding(.horizontal, ShineSpacing.lg)
                        }

                        // ── Error ────────────────────────────────────────
                        if let err = errorMessage {
                            Text(err)
                                .font(ShineFont.body(13))
                                .foregroundColor(.shineCoral)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, ShineSpacing.lg)
                        }

                        Spacer(minLength: ShineSpacing.xl)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Avatar Circle

    @ViewBuilder
    private var avatarCircle: some View {
        if let img = selectedImage {
            img
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.shineSurface, lineWidth: 3))
                .shadow(color: Color.shineCoral.opacity(0.25), radius: 12, x: 0, y: 4)
        } else if let urlStr = appState.currentUser?.avatarUrl, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.shineSurface, lineWidth: 3))
                        .shadow(color: Color.shineCoral.opacity(0.25), radius: 12, x: 0, y: 4)
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.shineCoral, .shineAmber],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
                .shadow(color: Color.shineCoral.opacity(0.3), radius: 12, x: 0, y: 4)
            Text(appState.currentUser?.avatarInitials ?? "SA")
                .font(ShineFont.displayBold(34))
                .foregroundColor(.white)
        }
    }

    // MARK: - Save

    private func save() async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        await MainActor.run {
            isSaving = true
            errorMessage = nil
        }

        do {
            var freshAvatarUrl: String? = nil

            // 1. Upload avatar first if a new image was picked
            if let imgData = selectedImageData {
                let compressed = UIImage(data: imgData)?
                    .jpegData(compressionQuality: 0.8) ?? imgData

                // Evict old cached image so AsyncImage re-fetches after upload
                if let oldUrlStr = appState.currentUser?.avatarUrl,
                   let oldUrl = URL(string: oldUrlStr) {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: oldUrl))
                    AvatarImageCache.shared.evict(url: oldUrl)
                }

                let avatarUser = try await UserAPIService.shared.uploadAvatar(imageData: compressed)
                // Append a version timestamp so AsyncImage treats the URL as new
                if let url = avatarUser.avatarUrl {
                    freshAvatarUrl = url + "?v=\(Int(Date().timeIntervalSince1970))"
                }
            }

            // 2. Update text fields
            let updated = try await UserAPIService.shared.updateProfile(
                name:     name.trimmingCharacters(in: .whitespaces),
                phone:    phone.trimmingCharacters(in: .whitespaces),
                address:  nil,
                language: nil
            )
            await MainActor.run {
                var user = updated.toUser()
                // Preserve the just-uploaded avatar URL (with cache-bust) if we did an upload
                if let freshUrl = freshAvatarUrl {
                    user.avatarUrl = freshUrl
                }
                appState.currentUser = user
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

// MARK: - Edit Field Row

private struct EditFieldRow: View {
    let icon: String
    let iconColor: Color
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 14) {
            ProfileIconBox(icon: icon, color: iconColor)
            TextField(placeholder, text: $text)
                .font(ShineFont.body(15))
                .foregroundColor(.shineInk)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, ShineSpacing.md)
        .padding(.vertical, 13)
    }
}
