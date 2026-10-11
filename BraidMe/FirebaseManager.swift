import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    var db: Firestore { dbRef }

    // MARK: - Published state
    @Published var braiders: [Braider] = []
    @Published var currentUser: UserProfile?
    @Published var bookings: [Booking] = []

    // MARK: - Location persistence
    var locationPermissionDecision: String? {
        get { UserDefaults.standard.string(forKey: "locationPermissionDecision") }
        set { UserDefaults.standard.set(newValue, forKey: "locationPermissionDecision") }
    }

    var hasAskedForLocation: Bool { locationPermissionDecision != nil }

    private init() {}

    // MARK: - Users

    /// Called from AuthView after a successful sign-in.
    /// Writes (or updates) the user document in Firestore.
    func signInAndUpsertUser(
        uid: String,
        displayName: String,
        email: String?,
        provider: String,
        age: Int
    ) async throws -> UserProfile {
        let ref = dbRef.collection("users").document(uid)
        let snapshot = try await ref.getDocument()

        if snapshot.exists, let data = snapshot.data(), let existing = UserProfile.from(uid, data: data) {
            var updated = existing
            updated.displayName = displayName
            updated.email = email
            updated.provider = provider
            try await ref.setData(updated.dictionary, merge: true)
            self.currentUser = updated
            return updated
        } else {
            let newUser = UserProfile(
                id: uid,
                displayName: displayName,
                email: email,
                age: age,
                createdAt: Date(),
                provider: provider,
                locationGranted: false
            )
            try await ref.setData(newUser.dictionary)
            self.currentUser = newUser
            return newUser
        }
    }

    /// Generic partial update — merges data into the user doc.
    /// Used by AgeVerificationView (age) and MainTabView (locationGranted).
    func updateUserProfile(uid: String, data: [String: Any]) async throws {
        guard !uid.isEmpty else { return }
        try await dbRef.collection("users").document(uid).setData(data, merge: true)
    }

    /// Convenience for age write.
    func updateAge(_ age: Int, for uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            try await dbRef.collection("users").document(uid).setData(
                ["age": age, "ageUpdatedAt": Timestamp(date: Date())],
                merge: true
            )
            UserDefaults.standard.set(age, forKey: "userAge")
        } catch {
            print("[FirebaseManager] updateAge failed:", error)
        }
    }

    /// Convenience for location flag write.
    func updateLocationGranted(_ granted: Bool, for uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            try await dbRef.collection("users").document(uid).setData(
                ["locationGranted": granted, "locationUpdatedAt": Timestamp(date: Date())],
                merge: true
            )
        } catch {
            print("[FirebaseManager] updateLocationGranted failed:", error)
        }
    }

    /// Load user document (useful on cold start).
    func loadCurrentUser(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let snap = try await dbRef.collection("users").document(uid).getDocument()
            if let data = snap.data(), let user = UserProfile.from(uid, data: data) {
                self.currentUser = user
            }
        } catch {
            print("[FirebaseManager] loadCurrentUser failed:", error)
        }
    }

    // MARK: - Braiders (mock)

    func fetchBraiders() {
        braiders = [
            Braider(
                id: "1",
                name: "Sarah Mensah",
                tagline: "Knotless artisan · 5 yrs",
                imageUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&q=80",
                coordinate: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
                rating: 4.9,
                reviewCount: 218,
                priceFrom: 120,
                bio: "Five years perfecting the art of knotless braids. Every head is a canvas — I take my time, protect your edges, and make sure you walk out feeling royal.",
                specialties: ["Knotless", "Box Braids", "Feed-ins"],
                portfolio: sarahPortfolio(),
                yearsExperience: 5,
                responseTime: "~15 min",
                verified: true
            ),
            Braider(
                id: "2",
                name: "Maya Kalu",
                tagline: "Box braid artisan",
                imageUrl: "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=800&q=80",
                coordinate: CLLocationCoordinate2D(latitude: 52.4900, longitude: -1.8800),
                rating: 4.8,
                reviewCount: 156,
                priceFrom: 100,
                bio: "Box braids are my art form. I blend traditional technique with modern styling to create braids that photograph beautifully and last for weeks.",
                specialties: ["Box Braids", "Twists", "Boho"],
                portfolio: mayaPortfolio(),
                yearsExperience: 7,
                responseTime: "~25 min",
                verified: true
            ),
            Braider(
                id: "3",
                name: "Zara Adeyemi",
                tagline: "Cornrow queen",
                imageUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=80",
                coordinate: CLLocationCoordinate2D(latitude: 52.4800, longitude: -1.9000),
                rating: 4.7,
                reviewCount: 94,
                priceFrom: 60,
                bio: "Cornrows, twists, and everything in between. Fast, precise, and gentle. Booking up quickly — secure your slot.",
                specialties: ["Cornrows", "Twists", "Kids"],
                portfolio: zaraPortfolio(),
                yearsExperience: 4,
                responseTime: "~10 min",
                verified: false
            )
        ]
    }

    // MARK: - Portfolios

    private func sarahPortfolio() -> [PortfolioItem] {
        [
            PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1200&q=85", caption: "Knotless, waist-length, natural blend", tag: "Knotless", likes: 342),
            PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1523824921871-d6f1a15151f1?w=1200&q=85", caption: "Medium box braids with curled ends", tag: "Box Braids", likes: 218),
            PortfolioItem(id: "p3", imageUrl: "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=1200&q=85", caption: "Feed-in cornrows, sculpted to crown", tag: "Cornrows", likes: 189),
            PortfolioItem(id: "p4", imageUrl: "https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=1200&q=85", caption: "Boho knotless with gold cuffs", tag: "Boho", likes: 411),
            PortfolioItem(id: "p5", imageUrl: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=1200&q=85", caption: "Jumbo knotless, styled for event", tag: "Knotless", likes: 267)
        ]
    }

    private func mayaPortfolio() -> [PortfolioItem] {
        [
            PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=1200&q=85", caption: "Classic box braids, mid-back length", tag: "Box", likes: 312),
            PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1604004555489-723a93d6ce74?w=1200&q=85", caption: "Passion twists, shoulder-length", tag: "Twists", likes: 245),
            PortfolioItem(id: "p3", imageUrl: "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=1200&q=85", caption: "Jumbo box braids, bohemian", tag: "Jumbo", likes: 198),
            PortfolioItem(id: "p4", imageUrl: "https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=1200&q=85", caption: "Small box braids, waist-length", tag: "Box", likes: 356)
        ]
    }

    private func zaraPortfolio() -> [PortfolioItem] {
        [
            PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=1200&q=85", caption: "Sculpted cornrows, lemonade style", tag: "Cornrows", likes: 189),
            PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=1200&q=85", caption: "Feed-in rows, gold accents", tag: "Feed-in", likes: 156),
            PortfolioItem(id: "p3", imageUrl: "https://images.unsplash.com/photo-1521146764736-56c929d59c83?w=1200&q=85", caption: "Two-strand twists, natural texture", tag: "Twists", likes: 142)
        ]
    }

    // MARK: - Reviews

    func reviews(for braider: Braider) -> [Review] {
        [
            Review(id: "r1", userName: "Amara Okafor", userAvatar: "https://i.pravatar.cc/200?img=45", text: "Absolutely flawless work. My knotless lasted 8 weeks and still looked fresh. Sarah's parting is unmatched — precise, clean, and gentle with my edges.", rating: 5.0, date: "2 weeks ago", styleDone: "Knotless Braids", helpful: 24),
            Review(id: "r2", userName: "Jasmine Bennett", userAvatar: "https://i.pravatar.cc/200?img=32", text: "So professional and gentle with my edges. Booked again for next month. Took her time and it shows — every single braid is uniform.", rating: 5.0, date: "1 month ago", styleDone: "Box Braids", helpful: 18),
            Review(id: "r3", userName: "Naomi Price", userAvatar: "https://i.pravatar.cc/200?img=28", text: "Beautiful result. Took a bit longer than expected but the quality was worth every minute. Would definitely recommend to anyone considering.", rating: 4.5, date: "1 month ago", styleDone: "Knotless Braids", helpful: 11),
            Review(id: "r4", userName: "Ifeoma Nwosu", userAvatar: "https://i.pravatar.cc/200?img=20", text: "Best braider in Birmingham, hands down. Sarah is a gem — kind, talented, and her workspace is spotless. I felt completely at ease.", rating: 5.0, date: "2 months ago", styleDone: "Boho Knotless", helpful: 32),
            Review(id: "r5", userName: "Kelechi Davies", userAvatar: "https://i.pravatar.cc/200?img=12", text: "Clean parts, no tension, exactly what I asked for. Will be recommending to everyone I know. Booking again in a month.", rating: 5.0, date: "3 months ago", styleDone: "Box Braids", helpful: 15)
        ]
    }

    func ratingBreakdown(for braider: Braider) -> RatingBreakdown {
        RatingBreakdown(five: 189, four: 22, three: 5, two: 1, one: 1)
    }

    // MARK: - Styles

    func braidStyles() -> [BraidStyle] {
        [
            BraidStyle(
                id: "s1",
                name: "Knotless Braids",
                description: "Seamless, pain-free braids that start with your own hair. Perfect for a natural, lightweight feel that protects your edges and lasts up to 8 weeks.",
                imageUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1200&q=85",
                priceFrom: 120,
                durationMinutes: 240,
                includes: ["Hair", "Styling", "Aftercare kit"],
                popular: true
            ),
            BraidStyle(
                id: "s2",
                name: "Box Braids",
                description: "Classic, timeless, and endlessly versatile. Square parts, individual plaits, and a look that turns heads and lasts 6–8 weeks.",
                imageUrl: "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=1200&q=85",
                priceFrom: 100,
                durationMinutes: 210,
                includes: ["Hair", "Styling"],
                popular: false
            ),
            BraidStyle(
                id: "s3",
                name: "Cornrows",
                description: "Sleek, sculpted rows braided close to the scalp. Bold, elegant, and built to turn heads. Perfect for a protective style that lasts.",
                imageUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=1200&q=85",
                priceFrom: 60,
                durationMinutes: 120,
                includes: ["Styling", "Edge care"],
                popular: false
            )
        ]
    }

    // MARK: - Time slots

    func timeSlots(for date: Date) -> [TimeSlot] {
        let seed = Calendar.current.component(.day, from: date)
        let raw: [(String, String, DayPeriod)] = [
            ("9:00 AM",  "t1", .morning),
            ("10:30 AM", "t2", .morning),
            ("12:00 PM", "t3", .afternoon),
            ("1:30 PM",  "t4", .afternoon),
            ("3:00 PM",  "t5", .afternoon),
            ("4:30 PM",  "t6", .evening),
            ("6:00 PM",  "t7", .evening)
        ]
        return raw.enumerated().map { idx, item in
            TimeSlot(
                id: item.1,
                label: item.0,
                available: (idx + seed) % 3 != 0,
                period: item.2
            )
        }
    }

    // MARK: - Booking

    func createBooking(
        braider: Braider,
        date: Date,
        time: String,
        style: BraidStyle,
        price: Int,
        completion: @escaping (Bool) -> Void
    ) {
        let bookingId = UUID().uuidString
        let uid = UserDefaults.standard.string(forKey: "currentUid")
            ?? UserDefaults.standard.string(forKey: "appleUserId")
            ?? "guest"

        let booking = Booking(
            id: bookingId,
            braiderName: braider.name,
            braiderId: braider.id,
            date: date,
            time: time,
            style: style.name,
            price: price,
            status: "confirmed",
            createdAt: Date()
        )

        dbRef.collection("users")
            .document(uid)
            .collection("bookings")
            .document(bookingId)
            .setData(booking.dictionary) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.bookings.append(booking)
                    }
                    completion(error == nil)
                }
            }
    }
}