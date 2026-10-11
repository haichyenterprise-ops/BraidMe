import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    var db: Firestore { dbRef }

    @Published var braiders: [Braider] = []
    @Published var currentUser: UserProfile?
    @Published var bookings: [Booking] = []
    @Published var isLoadingBraiders = false
    @Published var braidersError: String?

    // MARK: - Location persistence

    var locationPermissionDecision: String? {
        get { UserDefaults.standard.string(forKey: "locationPermissionDecision") }
        set { UserDefaults.standard.set(newValue, forKey: "locationPermissionDecision") }
    }

    var hasAskedForLocation: Bool { locationPermissionDecision != nil }

    var currentUid: String? {
        UserDefaults.standard.string(forKey: "currentUid")
            ?? UserDefaults.standard.string(forKey: "appleUserId")
    }

    private init() {}

    // MARK: - Users

    @discardableResult
    func upsertUser(
        uid: String,
        displayName: String,
        email: String?,
        provider: String,
        age: Int = 0
    ) async throws -> UserProfile {
        let ref = dbRef.collection("users").document(uid)
        let snap = try await ref.getDocument()

        if snap.exists, let data = snap.data(), let existing = UserProfile.from(uid, data: data) {
            var updated = existing
            if !displayName.isEmpty { updated.displayName = displayName }
            updated.email = email ?? existing.email
            updated.provider = provider
            try await ref.setData(updated.dictionary, merge: true)
            self.currentUser = updated
            return updated
        } else {
            let new = UserProfile(
                id: uid,
                displayName: displayName.isEmpty ? "BraidMe User" : displayName,
                email: email,
                age: age,
                provider: provider,
                city: nil,
                locationGranted: false,
                avatarUrl: nil,
                createdAt: Date()
            )
            try await ref.setData(new.dictionary)
            self.currentUser = new
            return new
        }
    }

    func updateUser(uid: String, data: [String: Any]) async throws {
        guard !uid.isEmpty else { return }
        try await dbRef.collection("users").document(uid).setData(data, merge: true)
    }

    func setLocation(granted: Bool, city: String?, uid: String) async throws {
        var payload: [String: Any] = [
            "locationGranted": granted,
            "locationUpdatedAt": Date()
        ]
        if let city { payload["city"] = city }
        try await updateUser(uid: uid, data: payload)
    }

    func loadUser(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let snap = try await dbRef.collection("users").document(uid).getDocument()
            if let data = snap.data(), let user = UserProfile.from(uid, data: data) {
                self.currentUser = user
            }
        } catch {
            print("[FirebaseManager] loadUser failed:", error)
        }
    }

    // MARK: - Braiders

    /// Fetches only published braiders from Firestore.
    func fetchBraidersFromFirestore() async {
        isLoadingBraiders = true
        braidersError = nil
        do {
            let snap = try await dbRef.collection("braiders").getDocuments()
            let all = snap.documents.compactMap { doc in
                BraiderMapper.from(id: doc.documentID, data: doc.data())
            }
            // Only show published braiders
            self.braiders = all.filter { $0.published }
        } catch {
            braidersError = error.localizedDescription
            print("[FirebaseManager] fetchBraiders failed:", error)
        }
        isLoadingBraiders = false
    }

    // MARK: - Reviews (real)

    /// Fetches reviews from the subcollection `braiders/{braiderId}/reviews`.
    func fetchReviews(braiderId: String) async -> [Review] {
        guard !braiderId.isEmpty else { return [] }
        do {
            let snap = try await dbRef
                .collection("braiders")
                .document(braiderId)
                .collection("reviews")
                .order(by: "date", descending: true)
                .getDocuments()

            return snap.documents.compactMap { doc -> Review? in
                let data = doc.data()
                guard
                    let userId = data["userId"] as? String,
                    let userName = data["userName"] as? String,
                    let text = data["text"] as? String,
                    let rating = data["rating"] as? Double,
                    let ts = data["date"] as? Timestamp
                else { return nil }

                return Review(
                    id: doc.documentID,
                    userId: userId,
                    userName: userName,
                    userAvatar: (data["userAvatar"] as? String) ?? "",
                    text: text,
                    rating: rating,
                    date: ts.dateValue(),
                    styleDone: (data["styleDone"] as? String) ?? "",
                    helpful: (data["helpful"] as? Int) ?? 0
                )
            }
        } catch {
            print("[FirebaseManager] fetchReviews failed:", error)
            return []
        }
    }

    /// Submits a review to `braiders/{braiderId}/reviews`.
    /// Also updates the braider doc's aggregate rating + reviewCount.
    func submitReview(
        braiderId: String,
        userId: String,
        userName: String,
        userAvatar: String,
        rating: Double,
        text: String,
        styleDone: String
    ) async throws {
        let reviewId = UUID().uuidString
        let now = Date()

        let payload: [String: Any] = [
            "id": reviewId,
            "userId": userId,
            "userName": userName,
            "userAvatar": userAvatar,
            "text": text,
            "rating": rating,
            "date": now,
            "styleDone": styleDone,
            "helpful": 0
        ]

        // 1. Write the review
        try await dbRef
            .collection("braiders")
            .document(braiderId)
            .collection("reviews")
            .document(reviewId)
            .setData(payload)

        // 2. Recompute aggregates
        let all = await fetchReviews(braiderId: braiderId)
        let count = all.count
        let avg = all.isEmpty ? 0 : all.reduce(0.0) { $0 + $1.rating } / Double(all.count)

        try await dbRef
            .collection("braiders")
            .document(braiderId)
            .setData([
                "rating": avg,
                "reviewCount": count,
                "lastReviewedAt": now
            ], merge: true)

        // 3. Update local cached braider if it's the same one
        if let idx = braiders.firstIndex(where: { $0.id == braiderId }) {
            let b = braiders[idx]
            let updated = Braider(
                id: b.id, name: b.name, tagline: b.tagline,
                avatarUrl: b.avatarUrl, coverUrl: b.coverUrl,
                latitude: b.latitude, longitude: b.longitude,
                rating: avg, reviewCount: count, priceFrom: b.priceFrom,
                bio: b.bio, story: b.story, city: b.city,
                specialties: b.specialties, yearsExperience: b.yearsExperience,
                responseTime: b.responseTime, verified: b.verified,
                portfolio: b.portfolio, services: b.services,
                availableSlots: b.availableSlots, availableDates: b.availableDates
            )
            braiders[idx] = updated
        }
    }

    // MARK: - Booking

    func createBooking(
        braider: Braider,
        date: Date,
        time: String,
        service: BraidService,
        price: Int,
        uid: String,
        completion: @escaping (Bool) -> Void
    ) {
        let id = UUID().uuidString
        let booking = Booking(
            id: id,
            braiderName: braider.name,
            braiderId: braider.id,
            date: date,
            time: time,
            style: service.name,
            price: price,
            status: "confirmed",
            createdAt: Date()
        )
        var payload = booking.dictionary
        payload["uid"] = uid

        dbRef.collection("bookings").document(id).setData(payload) { error in
            DispatchQueue.main.async {
                if error == nil { self.bookings.append(booking) }
                completion(error == nil)
            }
        }
    }
}

// MARK: - Mapper

enum BraiderMapper {
    static func from(id: String, data: [String: Any]) -> Braider? {
        let portfolioRaw = (data["portfolio"] as? [[String: Any]]) ?? []
        let servicesRaw = (data["services"] as? [[String: Any]]) ?? []
        let slotsRaw = (data["availableSlots"] as? [String: [String]]) ?? [:]

        let datesRaw: [Date] = {
            if let dates = data["availableDates"] as? [Date] { return dates }
            if let stamps = data["availableDates"] as? [Timestamp] {
                return stamps.map { $0.dateValue() }
            }
            return []
        }()

        let portfolio: [PortfolioItem] = portfolioRaw.compactMap { p in
            guard let pid = p["id"] as? String,
                  let url = p["imageUrl"] as? String else { return nil }
            return PortfolioItem(
                id: pid, imageUrl: url,
                caption: (p["caption"] as? String) ?? "",
                tag: (p["tag"] as? String) ?? "",
                likes: (p["likes"] as? Int) ?? 0
            )
        }

        let services: [BraidService] = servicesRaw.compactMap { s -> BraidService? in
            guard let sid = s["id"] as? String,
                  let name = s["name"] as? String else { return nil }

            let serviceDates: [Date] = {
                if let d = s["availableDates"] as? [Date] { return d }
                if let ts = s["availableDates"] as? [Timestamp] {
                    return ts.map { $0.dateValue() }
                }
                return []
            }()

            let serviceSlots = (s["availableSlots"] as? [String: [String]]) ?? [:]

            return BraidService(
                id: sid,
                name: name,
                description: (s["description"] as? String) ?? "",
                imageUrl: (s["imageUrl"] as? String) ?? "",
                priceFrom: (s["priceFrom"] as? Int) ?? 0,
                durationMinutes: (s["durationMinutes"] as? Int) ?? 120,
                includes: (s["includes"] as? [String]) ?? [],
                popular: (s["popular"] as? Bool) ?? false,
                availableDates: serviceDates,
                availableSlots: serviceSlots
            )
        }

        return Braider(
            id: id,
            name: (data["name"] as? String) ?? "",
            tagline: (data["tagline"] as? String) ?? "",
            avatarUrl: (data["avatarUrl"] as? String) ?? "",
            coverUrl: (data["coverUrl"] as? String) ?? "",
            latitude: (data["latitude"] as? Double) ?? 52.4862,
            longitude: (data["longitude"] as? Double) ?? -1.8904,
            rating: (data["rating"] as? Double) ?? 0,
            reviewCount: (data["reviewCount"] as? Int) ?? 0,
            priceFrom: (data["priceFrom"] as? Int) ?? 0,
            bio: (data["bio"] as? String) ?? "",
            story: (data["story"] as? String) ?? "",
            city: (data["city"] as? String) ?? "Birmingham",
            specialties: (data["specialties"] as? [String]) ?? [],
            yearsExperience: (data["yearsExperience"] as? Int) ?? 0,
            responseTime: (data["responseTime"] as? String) ?? "~30 min",
            verified: (data["verified"] as? Bool) ?? false,
            portfolio: portfolio,
            services: services,
            availableSlots: slotsRaw,
            availableDates: datesRaw
        )
    }
}