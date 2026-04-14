import SwiftUI
import PhotosUI

// MARK: - StaffProfileSetupView
/// Shown when a staff member hasn't yet uploaded their avatar or certificate.
/// They cannot proceed to the Staff Panel until both are uploaded.
struct StaffProfileSetupView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = StaffProfileViewModel()

    @State private var avatarItem: PhotosPickerItem?
    @State private var certItem:   PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.shineBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    uploadCards
                    errorBanner
                    continueButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 48)
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

    // MARK: - Sync uploaded profile back to AppState
    private func syncAppState() {
        guard let p = vm.profile else { return }
        appState.currentUser = p.toUser()
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.shineTeal.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.shineTeal)
            }

            VStack(spacing: 8) {
                Text("Complete Your Profile")
                    .font(ShineFont.displayBold(24))
                    .foregroundColor(.shineInk)

                Text("Upload your profile photo and work certificate before you can access the Staff Panel.")
                    .font(ShineFont.body(14))
                    .foregroundColor(.shineInk3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Upload cards
    private var uploadCards: some View {
        VStack(spacing: 16) {
            uploadCard(
                title:       "Profile Photo",
                description: "A clear photo of your face",
                icon:        "person.crop.circle.fill",
                isDone:      (vm.profile?.avatarUrl ?? "").isEmpty == false,
                isUploading: vm.isUploadingAvatar
            ) {
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    uploadLabel(isDone: (vm.profile?.avatarUrl ?? "").isEmpty == false)
                }
                .disabled(vm.isUploadingAvatar)
            }

            uploadCard(
                title:       "Work Certificate",
                description: "Your professional certificate or ID card",
                icon:        "doc.text.fill",
                isDone:      (vm.profile?.certificateUrl ?? "").isEmpty == false,
                isUploading: vm.isUploadingCert
            ) {
                PhotosPicker(selection: $certItem, matching: .images) {
                    uploadLabel(isDone: (vm.profile?.certificateUrl ?? "").isEmpty == false)
                }
                .disabled(vm.isUploadingCert)
            }
        }
    }

    @ViewBuilder
    private func uploadCard<Content: View>(
        title: String,
        description: String,
        icon: String,
        isDone: Bool,
        isUploading: Bool,
        @ViewBuilder picker: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(isDone ? Color.shineTeal.opacity(0.12) : Color.shineInk.opacity(0.07))
                    .frame(width: 52, height: 52)
                Image(systemName: isDone ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 22))
                    .foregroundColor(isDone ? .shineTeal : .shineInk3)
            }

            // Labels
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ShineFont.body(15, weight: .semibold))
                    .foregroundColor(.shineInk)
                Text(isDone ? "Uploaded ✓" : description)
                    .font(ShineFont.body(12))
                    .foregroundColor(isDone ? .shineTeal : .shineInk3)
            }

            Spacer()

            if isUploading {
                ProgressView().tint(.shineTeal).scaleEffect(0.9)
            } else {
                picker()
            }
        }
        .padding(18)
        .background(Color.shineSurface)
        .cornerRadius(18)
        .shineShadowXS()
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isDone ? Color.shineTeal.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func uploadLabel(isDone: Bool) -> some View {
        Text(isDone ? "Change" : "Upload")
            .font(ShineFont.body(13, weight: .semibold))
            .foregroundColor(isDone ? .shineInk3 : .shineTeal)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isDone ? Color.shineInk.opacity(0.07) : Color.shineTeal.opacity(0.1))
            .cornerRadius(12)
    }

    // MARK: - Error banner
    @ViewBuilder
    private var errorBanner: some View {
        if let err = vm.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.shineCoral)
                Text(err)
                    .font(ShineFont.body(13))
                    .foregroundColor(.shineInk)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.shineCoral.opacity(0.08))
            .cornerRadius(12)
        }
    }

    // MARK: - Continue button
    private var continueButton: some View {
        let ready = vm.isProfileComplete && !vm.isUploadingAvatar && !vm.isUploadingCert
        return Button {
            syncAppState()          // triggers RootView to switch to StaffView
        } label: {
            ZStack {
                if vm.isUploadingAvatar || vm.isUploadingCert || vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue to Staff Panel")
                        .font(ShineFont.body(16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(ready ? Color.shineTeal : Color.shineInk.opacity(0.15))
            .cornerRadius(18)
        }
        .disabled(!ready)
        .animation(.easeInOut(duration: 0.2), value: ready)
    }
}
