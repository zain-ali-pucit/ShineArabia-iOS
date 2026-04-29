import Foundation

// MARK: - Rating Response DTOs

struct StaffRatingResponse: Decodable {
    let success: Bool
    let data: StaffRatingData?
}

struct MyReviewResponse: Decodable {
    struct DataWrapper: Decodable { let review: APIMyReview? }
    let success: Bool
    let data: DataWrapper?
}

struct StaffMyRatingResponse: Decodable {
    let success: Bool
    let data: StaffMyRatingData?
}

struct StaffMyReviewsResponse: Decodable {
    let success: Bool
    let data: StaffMyReviewsData?
}

// MARK: - RatingAPIService
class RatingAPIService {
    static let shared = RatingAPIService()
    private let client = APIClient.shared

    // GET /api/reviews/staff/:staffId  → staff average + recent reviews
    func getStaffRating(staffId: String) async throws -> StaffRatingData {
        let res: StaffRatingResponse = try await client.request("/reviews/staff/\(staffId)")
        return res.data ?? StaffRatingData(averageRating: 0, totalCount: 0, reviews: [])
    }

    // GET /api/reviews/booking/:bookingId  → customer's own review for a booking (or nil)
    func getMyReviewForBooking(bookingId: String) async throws -> APIMyReview? {
        let res: MyReviewResponse = try await client.request("/reviews/booking/\(bookingId)")
        return res.data?.review
    }

    // POST /api/reviews
    func submitReview(bookingId: String, staffId: String, rating: Int, comment: String?) async throws {
        var body: [String: Any] = [
            "bookingId": bookingId,
            "staffId":   staffId,
            "rating":    rating,
        ]
        if let c = comment, !c.isEmpty { body["comment"] = c }
        let _: APIResponse<EmptyData> = try await client.request("/reviews", method: "POST", body: body)
    }

    // GET /api/staff/my-rating  → currently logged-in staff's average rating
    func getStaffMyRating() async throws -> StaffMyRatingData {
        let res: StaffMyRatingResponse = try await client.request("/staff/my-rating")
        return res.data ?? StaffMyRatingData(averageRating: 0, totalCount: 0)
    }

    // GET /api/staff/my-reviews?page=1&limit=50
    func getMyReviews(page: Int = 1, limit: Int = 50) async throws -> StaffMyReviewsData {
        let res: StaffMyReviewsResponse = try await client.request("/staff/my-reviews?page=\(page)&limit=\(limit)")
        return res.data ?? StaffMyReviewsData(
            averageRating: 0,
            totalCount: 0,
            reviews: [],
            pagination: ReviewPagination(total: 0, page: page, limit: limit)
        )
    }
}
