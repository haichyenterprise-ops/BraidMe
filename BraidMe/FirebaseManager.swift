import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import UIKit

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    var db: Firestore { dbRef }

    // MARK: - Published
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

    func setAge(_ age: Int, uid: String) async throws {
        try await updateUser(uid: uid, data: ["age": age, "ageConfirmedAt": Date()])
    }

    func setName(_ name: String, uid: String) async throws {
        try await updateUser(uid: uid, data: ["displayName": name, "nameConfirmedAt": Date()])
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
        do {
            let snap = try await dbRef.collection("users").document(uid).getDocument()
            if let data = snap.data(), let user = UserProfile.from(uid, data: data) {
                self.currentUser = user
            }
        } catch {
            print("[FirebaseManager] loadUser failed:", error)
        }
    }

    // MARK: - Braiders (Firestore-backed)

    func fetchBraidersFromFirestore() async {
        isLoadingBraiders = true
        braidersError = nil
        do {
            let snap = try await dbRef.collection("braiders").getDocuments()
            if snap.documents.isEmpty {
                try await seedBraiders()
                let retry = try await dbRef.collection("braiders").getDocuments()
                self.braiders = retry.documents.compactMap { doc in
                    BraiderMapper.from(id: doc.documentID, data: doc.data())
                }
            } else {
                self.braiders = snap.documents.compactMap { doc in
                    BraiderMapper.from(id: doc.documentID, data: doc.data())
                }
            }
        } catch {
            braidersError = error.localizedDescription
            print("[FirebaseManager] fetchBraiders failed:", error)
        }
        isLoadingBraiders = false
    }

    // MARK: - Seeding

    private func seedBraiders() async throws {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())

        func dkey(_ offset: Int) -> String {
            let d = cal.date(byAdding: .day, value: offset, to: base) ?? base
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }

        func ts(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: base) ?? base
        }

        let seed: [[String: Any]] = [
            makeBraiderDoc(
                name: "Sarah Mensah",
                tagline: "Knotless artisan · 5 yrs",
                avatarUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&q=80",
                coverUrl: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1600&q=85",
                lat: 52.4862, lng: -1.8904,
                rating: 4.9, reviewCount: 218, priceFrom: 120,
                yearsExperience: 5, responseTime: "~15 min", verified: true,
                bio: "Five years perfecting knotless braids. I take my time, protect your edges, and every head leaves feeling royal.",
                specialties: ["Knotless", "Box Braids", "Feed-ins"],
                portfolio: sarahPortfolio(),
                styles: knotlessStyles(),
                availableSlots: [
                    dkey(1): ["9:00 AM", "10:30 AM", "1:30 PM", "3:00 PM"],
                    dkey(2): ["12:00 PM", "3:00 PM", "6:00 PM"],
                    dkey(4): ["9:00 AM", "10:30 AM", "12:00 PM", "1:30 PM"],
                    dkey(5): ["1:30 PM", "3:00 PM", "4:30 PM", "6:00 PM"],
                    dkey(7): ["9:00 AM", "12:00 PM", "3:00 PM"]
                ],
                availableDates: [ts(1), ts(2), ts(4), ts(5), ts(7)],
                city: "Birmingham"
            ),
            makeBraiderDoc(
                name: "Maya Kalu",
                tagline: "Box braid artisan · 7 yrs",
                avatarUrl: "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=800&q=80",
                coverUrl: "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=1600&q=85",
                lat: 52.4900, lng: -1.8800,
                rating: 4.8, reviewCount: 156, priceFrom: 100,
                yearsExperience: 7, responseTime: "~25 min", verified: true,
                bio: "Box braids are my craft. Traditional technique with modern styling — braids that photograph beautifully and last.",
                specialties: ["Box Braids", "Twists", "Boho"],
                portfolio: mayaPortfolio(),
                styles: boxBraidStyles(),
                availableSlots: [
                    dkey(0): ["10:30 AM", "1:30 PM", "4:30 PM"],
                    dkey(2): ["9:00 AM", "12:00 PM", "3:00 PM"],
                    dkey(3): ["10:30 AM", "1:30 PM", "6:00 PM"],
                    dkey(6): ["9:00 AM", "12:00 PM", "3:00 PM"]
                ],
                availableDates: [ts(0), ts(2), ts(3), ts(6)],
                city: "Birmingham"
            ),
            makeBraiderDoc(
                name: "Zara Adeyemi",
                tagline: "Cornrow queen · 4 yrs",
                avatarUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=800&q=80",
                coverUrl: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=1600&q=85",
                lat: 52.4800, lng: -1.9000,
                rating: 4.7, reviewCount: 94, priceFrom: 60,
                yearsExperience: 4, responseTime: "~10 min", verified: false,
                bio: "Cornrows, twists, and everything between. Fast, precise, gentle. Booking up quickly — secure your slot.",
                specialties: ["Cornrows", "Twists", "Kids"],
                portfolio: zaraPortfolio(),
                styles: cornrowStyles(),
                availableSlots: [
                    dkey(1): ["9:00 AM", "11:00 AM", "2:00 PM", "4:00 PM"],
                    dkey(3): ["10:00 AM", "1:00 PM", "3:00 PM"],
                    dkey(5): ["9:00 AM", "12:00 PM", "2:00 PM", "5:00 PM"]
                ],
                availableDates: [ts(1), ts(3), ts(5)],
                city: "Birmingham"
            ),
            makeBraiderDoc(
                name: "Amara Okafor",
                tagline: "Boho specialist · 6 yrs",
                avatarUrl: "https://images.unsplash.com/photo-1523824921871-d6f1a15151f1?w=800&q=80",
                coverUrl: "https://images.unsplash.com/photo-1523824921871-d6f1a15151f1?w=1600&q=85",
                lat: 52.4950, lng: -1.8700,
                rating: 4.9, reviewCount: 187, priceFrom: 150,
                yearsExperience: 6, responseTime: "~20 min", verified: true,
                bio: "Boho braids are my signature — curly ends, gold cuffs, waist-length. Every head looks editorial.",
                specialties: ["Boho", "Knotless", "Fulani"],
                portfolio: sarahPortfolio(),
                styles: knotlessStyles(),
                availableSlots: [
                    dkey(2): ["10:00 AM", "1:00 PM", "4:00 PM"],
                    dkey(4): ["9:00 AM", "12:00 PM", "3:00 PM"],
                    dkey(6): ["11:00 AM", "2:00 PM", "5:00 PM"],
                    dkey(8): ["9:00 AM", "1:00 PM", "4:00 PM"]
                ],
                availableDates: [ts(2), ts(4), ts(6), ts(8)],
                city: "Birmingham"
            ),
            makeBraiderDoc(
                name: "Nia Bennett",
                tagline: "Twists & locs · 3 yrs",
                avatarUrl: "https://images.unsplash.com/photo-1604004555489-723a93d6ce74?w=800&q=80",
                coverUrl: "https://images.unsplash.com/photo-1604004555489-723a93d6ce74?w=1600&q=85",
                lat: 52.4750, lng: -1.8950,
                rating: 4.6, reviewCount: 72, priceFrom: 85,
                yearsExperience: 3, responseTime: "~30 min", verified: false,
                bio: "Passion twists, spring twists, and locs. Natural texture honoured, gentle hands, beautiful results.",
                specialties: ["Twists", "Locs", "Natural"],
                portfolio: mayaPortfolio(),
                styles: boxBraidStyles(),
                availableSlots: [
                    dkey(1): ["10:00 AM", "1:00 PM", "3:30 PM"],
                    dkey(4): ["9:00 AM", "11:30 AM", "2:00 PM", "4:30 PM"],
                    dkey(7): ["9:30 AM", "12:30 PM", "3:00 PM"]
                ],
                availableDates: [ts(1), ts(4), ts(7)],
                city: "Birmingham"
            )
        ]

        for (i, doc) in seed.enumerated() {
            let id = "braider_\(i+1)"
            try await dbRef.collection("braiders").document(id).setData(doc)
        }
    }

    private func makeBraiderDoc(
        name: String, tagline: String,
        avatarUrl: String, coverUrl: String,
        lat: Double, lng: Double,
        rating: Double, reviewCount: Int, priceFrom: Int,
        yearsExperience: Int, responseTime: String, verified: Bool,
        bio: String, specialties: [String],
        portfolio: [[String: Any]],
        styles: [[String: Any]],
        availableSlots: [String: [String]],
        availableDates: [Date],
        city: String
    ) -> [String: Any] {
        [
            "name": name,
            "tagline": tagline,
            "avatarUrl": avatarUrl,
            "coverUrl": coverUrl,
            "latitude": lat,
            "longitude": lng,
            "rating": rating,
            "reviewCount": reviewCount,
            "priceFrom": priceFrom,
            "yearsExperience": yearsExperience,
            "responseTime": responseTime,
            "verified": verified,
            "bio": bio,
            "specialties": specialties,
            "portfolio": portfolio,
            "styles": styles,
            "availableSlots": availableSlots,
            "availableDates": availableDates,
            "city": city,
            "createdAt": Date()
        ]
    }

    private func sarahPortfolio() -> [[String: Any]] {
        [
            ["id": "p1", "imageUrl": "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1200&q=85",
             "caption": "Knotless, waist-length", "tag": "Knotless", "likes": 342],
            ["id": "p2", "imageUrl": "https://images.unsplash.com/photo-1523824921871-d6f1a15151f1?w=1200&q=85",
             "caption": "Medium box braids, curled ends", "tag": "Box Braids", "likes": 218],
            ["id": "p3", "imageUrl": "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=1200&q=85",
             "caption": "Feed-in cornrows, sculpted", "tag": "Cornrows", "likes": 189],
            ["id": "p4", "imageUrl": "https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=1200&q=85",
             "caption": "Boho knotless, gold cuffs", "tag": "Boho", "likes": 411],
            ["id": "p5", "imageUrl": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=1200&q=85",
             "caption": "Jumbo knotless, event-ready", "tag": "Knotless", "likes": 267]
        ]
    }

    private func mayaPortfolio() -> [[String: Any]] {
        [
            ["id": "p1", "imageUrl": "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=1200&q=85",
             "caption": "Classic box braids, mid-back", "tag": "Box", "likes": 312],
            ["id": "p2", "imageUrl": "https://images.unsplash.com/photo-1604004555489-723a93d6ce74?w=1200&q=85",
             "caption": "Passion twists, shoulder-length", "tag": "Twists", "likes": 245],
            ["id": "p3", "imageUrl": "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=1200&q=85",
             "caption": "Jumbo box braids, boho", "tag": "Jumbo", "likes": 198],
            ["id": "p4", "imageUrl": "https://images.unsplash.com/photo-1607746882042-944635dfe10e?w=1200&q=85",
             "caption": "Small box braids, waist-length", "tag": "Box", "likes": 356]
        ]
    }

    private func zaraPortfolio() -> [[String: Any]] {
        [
            ["id": "p1", "imageUrl": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=1200&q=85",
             "caption": "Sculpted cornrows, lemonade", "tag": "Cornrows", "likes": 189],
            ["id": "p2", "imageUrl": "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=1200&q=85",
             "caption": "Feed-in rows, gold accents", "tag": "Feed-in", "likes": 156],
            ["id": "p3", "imageUrl": "https://images.unsplash.com/photo-1521146764736-56c929d59c83?w=1200&q=85",
             "caption": "Two-strand twists, natural", "tag": "Twists", "likes": 142]
        ]
    }

    private func knotlessStyles() -> [[String: Any]] {
        [
            ["id": "s1", "name": "Knotless Braids",
             "description": "Seamless, pain-free braids that start with your own hair. Natural, lightweight, edge-protecting.",
             "imageUrl": "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1200&q=85",
             "priceFrom": 120, "durationMinutes": 240,
             "includes": ["Hair", "Styling", "Aftercare kit"],
             "popular": true],
            ["id": "s2", "name": "Boho Knotless",
             "description": "Knotless base with curly human hair ends and gold cuffs. Editorial, romantic, unforgettable.",
             "imageUrl": "https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?w=1200&q=85",
             "priceFrom": 150, "durationMinutes": 300,
             "includes": ["Hair", "Cuffs", "Styling"],
             "popular": false],
            ["id": "s3", "name": "Feed-in Cornrows",
             "description": "Cornrows that gradually transition into box braids. Bold, sculptural, long-lasting.",
             "imageUrl": "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=1200&q=85",
             "priceFrom": 90, "durationMinutes": 180,
             "includes": ["Hair", "Styling"],
             "popular": false]
        ]
    }

    private func boxBraidStyles() -> [[String: Any]] {
        [
            ["id": "s1", "name": "Classic Box Braids",
             "description": "Square parts, individual plaits, waist or mid-back. The style that never dates.",
             "imageUrl": "https://images.unsplash.com/photo-1614289371518-722f2615943d?w=1200&q=85",
             "priceFrom": 100, "durationMinutes": 210,
             "includes": ["Hair", "Styling"],
             "popular": true],
            ["id": "s2", "name": "Knotless Braids",
             "description": "Painless, seamless root, natural feel. Perfect for a first braid appointment.",
             "imageUrl": "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=1200&q=85",
             "priceFrom": 120, "durationMinutes": 240,
             "includes": ["Hair", "Styling", "Aftercare"],
             "popular": false],
            ["id": "s3", "name": "Passion Twists",
             "description": "Soft, water-wave twists with curly ends. Boho and effortless.",
             "imageUrl": "https://images.unsplash.com/photo-1604004555489-723a93d6ce74?w=1200&q=85",
             "priceFrom": 110, "durationMinutes": 180,
             "includes": ["Hair", "Styling"],
             "popular": false]
        ]
    }

    private func cornrowStyles() -> [[String: Any]] {
        [
            ["id": "s1", "name": "Sculpted Cornrows",
             "description": "Bold, close-to-scalp rows. Sleek, precise, and elegant.",
             "imageUrl": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=1200&q=85",
             "priceFrom": 60, "durationMinutes": 120,
             "includes": ["Styling", "Edge care"],
             "popular": true],
            ["id": "s2", "name": "Feed-in Rows",
             "description": "Cornrows that transition into box braids — sculptural and long-lasting.",
             "imageUrl": "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=1200&q=85",
             "priceFrom": 80, "durationMinutes": 150,
             "includes": ["Hair", "Styling"],
             "popular": false],
            ["id": "s3", "name": "Two-Strand Twists",
             "description": "Natural-texture twists. Gentle, protective, and endlessly versatile.",
             "imageUrl": "https://images.unsplash.com/photo-1521146764736-56c929d59c83?w=1200&q=85",
             "priceFrom": 70, "durationMinutes": 150,
             "includes": ["Styling"],
             "popular": false]
        ]
    }

    // MARK: - Reviews

    func reviews(for braider: Braider) -> [Review] {
        [
            Review(id: "r1", userName: "Amara Okafor", userAvatar: "https://i.pravatar.cc/200?img=45",
                   text: "Absolutely flawless work. Lasted 8 weeks and still fresh. Parting is unmatched — precise, clean, gentle.",
                   rating: 5.0, date: "2 weeks ago", styleDone: "Knotless Braids", helpful: 24),
            Review(id: "r2", userName: "Jasmine Bennett", userAvatar: "https://i.pravatar.cc/200?img=32",
                   text: "So professional and gentle with my edges. Booked again — took her time and it shows.",
                   rating: 5.0, date: "1 month ago", styleDone: "Box Braids", helpful: 18),
            Review(id: "r3", userName: "Naomi Price", userAvatar: "https://i.pravatar.cc/200?img=28",
                   text: "Beautiful result. Took a bit longer than expected but the quality was worth every minute.",
                   rating: 4.5, date: "1 month ago", styleDone: "Knotless Braids", helpful: 11),
            Review(id: "r4", userName: "Ifeoma Nwosu", userAvatar: "https://i.pravatar.cc/200?img=20",
                   text: "Best in Birmingham, hands down. Kind, talented, spotless workspace. Completely at ease.",
                   rating: 5.0, date: "2 months ago", styleDone: "Boho Knotless", helpful: 32),
            Review(id: "r5", userName: "Kelechi Davies", userAvatar: "https://i.pravatar.cc/200?img=12",
                   text: "Clean parts, no tension, exactly what I asked for. Recommending to everyone.",
                   rating: 5.0, date: "3 months ago", styleDone: "Box Braids", helpful: 15)
        ]
    }

    func ratingBreakdown(for braider: Braider) -> RatingBreakdown {
        RatingBreakdown(five: 189, four: 22, three: 5, two: 1, one: 1)
    }

    // MARK: - Booking

    func createBooking(
        braider: Braider,
        date: Date,
        time: String,
        style: BraidStyle,
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
            style: style.name,
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
        guard
            let name = data["name"] as? String,
            let tagline = data["tagline"] as? String,
            let avatar = data["avatarUrl"] as? String,
            let cover = data["coverUrl"] as? String,
            let lat = data["latitude"] as? Double,
            let lng = data["longitude"] as? Double
        else { return nil }

        let portfolioRaw = (data["portfolio"] as? [[String: Any]]) ?? []
        let stylesRaw = (data["styles"] as? [[String: Any]]) ?? []
        let slotsRaw = (data["availableSlots"] as? [String: [String]]) ?? [:]
        let datesRaw = (data["availableDates"] as? [Date]) ?? []

        let portfolio = portfolioRaw.compactMap { p -> PortfolioItem? in
            guard let i = p["id"] as? String,
                  let img = p["imageUrl"] as? String,
                  let cap = p["caption"] as? String,
                  let tag = p["tag"] as? String else { return nil }
            return PortfolioItem(id: i, imageUrl: img, caption: cap, tag: tag,
                                 likes: (p["likes"] as? Int) ?? 0)
        }

        let styles = stylesRaw.compactMap { s -> BraidStyle? in
            guard let i = s["id"] as? String,
                  let n = s["name"] as? String,
                  let d = s["description"] as? String,
                  let img = s["imageUrl"] as? String else { return nil }
            return BraidStyle(
                id: i, name: n, description: d, imageUrl: img,
                priceFrom: (s["priceFrom"] as? Int) ?? 0,
                durationMinutes: (s["durationMinutes"] as? Int) ?? 0,
                includes: (s["includes"] as? [String]) ?? [],
                popular: (s["popular"] as? Bool) ?? false
            )
        }

        return Braider(
            id: id,
            name: name,
            tagline: tagline,
            avatarUrl: avatar,
            coverUrl: cover,
            latitude: lat,
            longitude: lng,
            rating: (data["rating"] as? Double) ?? 0,
            reviewCount: (data["reviewCount"] as? Int) ?? 0,
            priceFrom: (data["priceFrom"] as? Int) ?? 0,
            bio: (data["bio"] as? String) ?? "",
            city: (data["city"] as? String) ?? "Birmingham",
            specialties: (data["specialties"] as? [String]) ?? [],
            yearsExperience: (data["yearsExperience"] as? Int) ?? 0,
            responseTime: (data["responseTime"] as? String) ?? "~30 min",
            verified: (data["verified"] as? Bool) ?? false,
            portfolio: portfolio,
            styles: styles,
            availableSlots: slotsRaw,
            availableDates: datesRaw
        )
    }
}