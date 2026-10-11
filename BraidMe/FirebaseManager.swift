import Foundation
import FirebaseFirestore
import CoreLocation

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()

    @Published var braiders: [Braider] = []

    // MARK: Location persistence

    var locationPermissionDecision: String? {
        get { UserDefaults.standard.string(forKey: "locationPermissionDecision") }
        set { UserDefaults.standard.set(newValue, forKey: "locationPermissionDecision") }
    }

    var hasAskedForLocation: Bool { locationPermissionDecision != nil }

    // MARK: Braiders

    func fetchBraiders() {
        braiders = [
            Braider(
                id: "1",
                name: "Sarah M.",
                tagline: "Knotless specialist · 5 yrs",
                imageUrl: "https://images.unsplash.com/photo-1595959183082-7b570b7e08e2?w=600",
                coordinate: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
                rating: 4.9,
                reviewCount: 218,
                priceFrom: 120,
                bio: "Five years perfecting the art of knotless braids. Every head is a canvas — I take my time, protect your edges, and make sure you walk out feeling royal.",
                specialties: ["Knotless", "Box Braids", "Feed-ins"],
                portfolio: [
                    PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=900", caption: "Knotless waist-length", tag: "Knotless"),
                    PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=900", caption: "Small-medium box braids", tag: "Box Braids"),
                    PortfolioItem(id: "p3", imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=900", caption: "Feed-in cornrows", tag: "Cornrows"),
                    PortfolioItem(id: "p4", imageUrl: "https://images.unsplash.com/photo-1614023342696-17d7e2b1f7c9?w=900", caption: "Boho knotless", tag: "Boho")
                ]
            ),
            Braider(
                id: "2",
                name: "Maya K.",
                tagline: "Box braid artisan",
                imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=600",
                coordinate: CLLocationCoordinate2D(latitude: 52.4900, longitude: -1.8800),
                rating: 4.8,
                reviewCount: 156,
                priceFrom: 100,
                bio: "Box braids are my art form. I blend traditional technique with modern styling to create braids that photograph beautifully and last for weeks.",
                specialties: ["Box Braids", "Twists", "Boho"],
                portfolio: [
                    PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=900", caption: "Classic box braids", tag: "Box"),
                    PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=900", caption: "Passion twists", tag: "Twists"),
                    PortfolioItem(id: "p3", imageUrl: "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=900", caption: "Jumbo box braids", tag: "Jumbo")
                ]
            ),
            Braider(
                id: "3",
                name: "Zara A.",
                tagline: "Cornrow queen",
                imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=600",
                coordinate: CLLocationCoordinate2D(latitude: 52.4800, longitude: -1.9000),
                rating: 4.7,
                reviewCount: 94,
                priceFrom: 60,
                bio: "Cornrows, twists, and everything in between. Fast, precise, and gentle. Booking up quickly — secure your slot.",
                specialties: ["Cornrows", "Twists", "Kids"],
                portfolio: [
                    PortfolioItem(id: "p1", imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=900", caption: "Sculpted cornrows", tag: "Cornrows"),
                    PortfolioItem(id: "p2", imageUrl: "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=900", caption: "Feed-in rows", tag: "Feed-in")
                ]
            )
        ]
    }

    func reviews(for braider: Braider) -> [Review] {
        [
            Review(id: "r1", userName: "Amara O.", userAvatar: "https://i.pravatar.cc/150?img=45",
                   text: "Absolutely flawless work. My knotless lasted 8 weeks and still looked fresh. Sarah's parting is unmatched — precise, clean, and gentle.",
                   rating: 5.0, date: "2 weeks ago", styleDone: "Knotless Braids"),
            Review(id: "r2", userName: "Jasmine B.", userAvatar: "https://i.pravatar.cc/150?img=32",
                   text: "So professional and gentle with my edges. Booked again for next month. Took her time and it shows.",
                   rating: 5.0, date: "1 month ago", styleDone: "Box Braids"),
            Review(id: "r3", userName: "Naomi P.", userAvatar: "https://i.pravatar.cc/150?img=28",
                   text: "Beautiful result. Took a bit longer than expected but the quality was worth every minute.",
                   rating: 4.5, date: "1 month ago", styleDone: "Knotless Braids"),
            Review(id: "r4", userName: "Ifeoma N.", userAvatar: "https://i.pravatar.cc/150?img=20",
                   text: "Best braider in Birmingham, hands down. Sarah is a gem — kind, talented, and her workspace is spotless.",
                   rating: 5.0, date: "2 months ago", styleDone: "Boho Knotless"),
            Review(id: "r5", userName: "Kelechi D.", userAvatar: "https://i.pravatar.cc/150?img=12",
                   text: "Clean parts, no tension, exactly what I asked for. Will be recommending to everyone.",
                   rating: 5.0, date: "3 months ago", styleDone: "Box Braids")
        ]
    }

    func ratingBreakdown(for braider: Braider) -> RatingBreakdown {
        RatingBreakdown(five: 189, four: 22, three: 5, two: 1, one: 1)
    }

    func braidStyles() -> [BraidStyle] {
        [
            BraidStyle(
                id: "s1",
                name: "Knotless Braids",
                description: "Seamless, pain-free braids that start with your own hair. Perfect for a natural, lightweight feel that protects your edges and lasts up to 8 weeks.",
                imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=900",
                priceFrom: 120,
                durationMinutes: 240,
                includes: ["Hair", "Styling", "Aftercare kit"]
            ),
            BraidStyle(
                id: "s2",
                name: "Box Braids",
                description: "Classic, timeless, and endlessly versatile. Square parts, individual plaits, and a look that turns heads and lasts 6–8 weeks.",
                imageUrl: "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=900",
                priceFrom: 100,
                durationMinutes: 210,
                includes: ["Hair", "Styling"]
            ),
            BraidStyle(
                id: "s3",
                name: "Cornrows",
                description: "Sleek, sculpted rows braided close to the scalp. Bold, elegant, and built to turn heads. Perfect for a protective style that lasts.",
                imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=900",
                priceFrom: 60,
                durationMinutes: 120,
                includes: ["Styling", "Edge care"]
            )
        ]
    }

    func timeSlots(for date: Date) -> [TimeSlot] {
        let all = [
            TimeSlot(id: "t1", label: "9:00 AM", available: true),
            TimeSlot(id: "t2", label: "10:30 AM", available: false),
            TimeSlot(id: "t3", label: "12:00 PM", available: true),
            TimeSlot(id: "t4", label: "1:30 PM", available: true),
            TimeSlot(id: "t5", label: "3:00 PM", available: true),
            TimeSlot(id: "t6", label: "4:30 PM", available: false),
            TimeSlot(id: "t7", label: "6:00 PM", available: true)
        ]
        let seed = Calendar.current.component(.day, from: date)
        return all.enumerated().map { idx, slot in
            var s = slot
            s = TimeSlot(id: slot.id, label: slot.label, available: (idx + seed) % 3 != 0)
            return s
        }
    }

    func createBooking(braiderName: String, date: Date, time: String, style: String, completion: @escaping (Bool) -> Void) {
        let bookingData: [String: Any] = [
            "braiderName": braiderName,
            "date": Timestamp(date: date),
            "time": time,
            "style": style,
            "userId": UserDefaults.standard.string(forKey: "appleUserId") ?? "guest",
            "status": "confirmed",
            "createdAt": Timestamp(date: Date())
        ]
        db.collection("bookings").addDocument(data: bookingData) { error in
            DispatchQueue.main.async { completion(error == nil) }
        }
    }
}