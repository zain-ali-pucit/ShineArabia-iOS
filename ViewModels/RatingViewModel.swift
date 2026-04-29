import Foundation
import SwiftUI

@MainActor
class RatingViewModel: ObservableObject {
    @Published var averageRating: Double = 0
    @Published var totalCount: Int = 0
    @Published var myRating: Int = 0          // 0 = not rated yet
    @Published var myComment: String = ""
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var submitSuccess: Bool = false  // true if review exists (loaded or just submitted)
    @Published var justSubmitted: Bool = false  // true only right after the user hits Submit
    @Published var errorMessage: String?

    private let api = RatingAPIService.shared

    func load(staffId: String, bookingId: String) async {
        guard !staffId.isEmpty, !bookingId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        async let ratingTask = try? api.getStaffRating(staffId: staffId)
        async let reviewTask = try? api.getMyReviewForBooking(bookingId: bookingId)

        let ratingData = await ratingTask
        let myReview   = await reviewTask ?? nil

        averageRating = ratingData?.averageRating ?? 0
        totalCount    = ratingData?.totalCount    ?? 0
        myRating      = myReview?.rating          ?? 0
        myComment     = myReview?.comment         ?? ""
        submitSuccess = myReview != nil
        isLoading     = false
    }

    func setRating(_ stars: Int) {
        myRating = stars
        submitSuccess = false
    }

    func setComment(_ text: String) {
        myComment = text
    }

    func submit(bookingId: String, staffId: String) async {
        guard myRating > 0 else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let trimmed = myComment.trimmingCharacters(in: .whitespacesAndNewlines)
            try await api.submitReview(
                bookingId: bookingId,
                staffId: staffId,
                rating: myRating,
                comment: trimmed.isEmpty ? nil : trimmed
            )
            // Reload average after submit
            if let updated = try? await api.getStaffRating(staffId: staffId) {
                averageRating = updated.averageRating
                totalCount    = updated.totalCount
            }
            submitSuccess = true
            justSubmitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func clearJustSubmitted() {
        justSubmitted = false
    }
}
