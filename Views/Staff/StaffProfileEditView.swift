import SwiftUI
import PhotosUI

// MARK: - StaffProfileEditView
/// Sheet for editing a staff member's name, phone, avatar, and certificate.
struct StaffProfileEditView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = StaffProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var avatarItem: PhotosPickerItem?
    @State private var certItem:   PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.shineBG.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        avatarSection
                        fieldsSection
                        certificateSection
                        feedbackBanners
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.shineInk3)
                }
            }
            .task { await vm.fetchProfile() }
            .onChange(of: avatarItem) { item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let img  = UIImage(data: data) else { return }
                    await vm.uploadAvatar(image: img)
                    syncAppState()
                }
            }
            .onChange(of: certItem) { item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let img  = UIImage(data: data) else { return }
                    await vm.uploadCertificate(image: img)
                    syncAppState()
                }
            }
        }
    }

    // MARK: - Sync profile back to AppState
    private func syncAppState() {
        guard let p = vm.profile else { return }
        appState.currentUser = p.toUser()
    }

    // MARK: - Avatar section
    private var avatarSection: some View {
        VStack(spacing: 14) {
            // Avatar preview
            Group {
                if let urlStr = vm.profile?.avatarUrl, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.shineTeal.opacity(0.3), lineWidth: 2))
                } else {
                    avatarPlaceholder
                }
            }

            // Change photo button
            PhotosPicker(selection: $avatarItem, matching: .images) {
                HStack(spacing: 6) {
                    if vm.isUploadingAvatar {
                        ProgressView().tint(.shineTeal).scaleEffect(0.8)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                        Text("Change Photo")
                            .font(ShineFont.body(13, weight: .semibold))
                    }
                }
                .foregroundColor(.shineTeal)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Color.shineTeal.opacity(0.1))
                .cornerRadius(20)
            }
            .disabled(vm.isUploadingAvatar)
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.shineTeal.opacity(0.12))
                .frame(width: 96, height: 96)
            Text(appState.currentUser?.avatarInitials ?? "SA")
                .font(ShineFont.displayBold(30))
                .foregroundColor(.shineTeal)
        }
    }

    // MARK: - Name & Phone fields
    private var fieldsSection: some View {
        VStack(spacing: 0) {
            fieldRow(label: "Full Name", icon: "person.fill", placeholder: "Your name", text: $vm.editName)
                .padding(.bottom, 12)
            Divider().padding(.leading, 36)
            fieldRow(label: "Phone Number", icon: "phone.fill", placeholder: "+974 xxxx xxxx", text: $vm.editPhone)
                .padding(.top, 12)
                .keyboardType(.phonePad)
        }
        .padding(18)
        .background(Color.shineSurface)
        .cornerRadius(18)
        .shineShadowXS()
    }

    @ViewBuilder
    private func fieldRow(label: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.shineInk3)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(ShineFont.body(11, weight: .medium))
                    .foregroundColor(.shineInk3)
                TextField(placeholder, text: text)
                    .font(ShineFont.body(15))
                    .foregroundColor(.shineInk)
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - Certificate section
    private var certificateSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(hasCert ? Color.shineTeal.opacity(0.1) : Color.shineInk.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: hasCert ? "checkmark.seal.fill" : "doc.badge.plus")
                    .font(.system(size: 22))
                    .foregroundColor(hasCert ? .shineTeal : .shineInk3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Work Certificate")
                    .font(ShineFont.body(15, weight: .semibold))
                    .foregroundColor(.shineInk)
                Text(hasCert ? "Certificate on file ✓" : "No certificate uploaded yet")
                    .font(ShineFont.body(12))
                    .foregroundColor(hasCert ? .shineTeal : .shineInk3)
            }

            Spacer()

            if vm.isUploadingCert {
                ProgressView().tint(.shineTeal).scaleEffect(0.9)
            } else {
                PhotosPicker(selection: $certItem, matching: .images) {
                    Text(hasCert ? "Replace" : "Upload")
                        .font(ShineFont.body(13, weight: .semibold))
                        .foregroundColor(.shineTeal)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.shineTeal.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .padding(18)
        .background(Color.shineSurface)
        .cornerRadius(18)
        .shineShadowXS()
    }

    private var hasCert: Bool { (vm.profile?.certificateUrl ?? "").isEmpty == false }

    // MARK: - Feedback banners
    @ViewBuilder
    private var feedbackBanners: some View {
        if let err = vm.errorMessage {
            bannerRow(text: err, color: .shineCoral, icon: "exclamationmark.triangle.fill")
        }
        if let success = vm.successMessage {
            bannerRow(text: success, color: .shineTeal, icon: "checkmark.circle.fill")
        }
    }

    @ViewBuilder
    private func bannerRow(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(ShineFont.body(13))
                .foregroundColor(.shineInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Save button
    private var saveButton: some View {
        Button {
            Task {
                await vm.saveProfile()
                syncAppState()
            }
        } label: {
            ZStack {
                if vm.isSavingProfile {
                    ProgressView().tint(.white)
                } else {
                    Text("Save Changes")
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.shineTeal)
            .cornerRadius(18)
        }
        .disabled(vm.isSavingProfile)
    }
}
