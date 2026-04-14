import SwiftUI
import PhotosUI

// MARK: - StaffProfileViewModel
@MainActor
class StaffProfileViewModel: ObservableObject {

    // MARK: - State
    @Published var profile: APIUser?
    @Published var isLoading           = false
    @Published var isUploadingAvatar   = false
    @Published var isUploadingCert     = false
    @Published var isSavingProfile     = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Edit-form fields — synced from profile on fetch
    @Published var editName  = ""
    @Published var editPhone = ""

    private let service = StaffAPIService.shared

    // MARK: - Computed
    var isProfileComplete: Bool {
        (profile?.avatarUrl      ?? "").isEmpty == false &&
        (profile?.certificateUrl ?? "").isEmpty == false
    }

    // MARK: - API calls

    func fetchProfile() async {
        isLoading    = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user   = try await service.fetchProfile()
            profile    = user
            editName   = user.name
            editPhone  = user.phone ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadAvatar(image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        isUploadingAvatar = true
        errorMessage      = nil
        defer { isUploadingAvatar = false }
        do {
            profile        = try await service.uploadAvatar(imageData: data)
            successMessage = "Profile photo updated"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadCertificate(image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        isUploadingCert = true
        errorMessage    = nil
        defer { isUploadingCert = false }
        do {
            profile        = try await service.uploadCertificate(imageData: data)
            successMessage = "Certificate uploaded"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile() async {
        isSavingProfile = true
        errorMessage    = nil
        defer { isSavingProfile = false }
        do {
            let name  = editName.trimmingCharacters(in: .whitespaces)
            let phone = editPhone.trimmingCharacters(in: .whitespaces)
            profile        = try await service.updateProfile(
                name:  name.isEmpty  ? nil : name,
                phone: phone.isEmpty ? nil : phone
            )
            editName       = profile?.name  ?? editName
            editPhone      = profile?.phone ?? editPhone
            successMessage = "Profile saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
