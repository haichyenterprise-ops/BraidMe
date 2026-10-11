import Foundation
import FirebaseFirestore
import CoreLocation

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    @Published var braiders: [Braider] = []
    
    // MARK: Location permission — persists
    var locationPermissionDecision: String? {
        get { UserDefaults.standard.string(forKey: "locationPermissionDecision") }
        set { UserDefaults.standard.set(newValue, forKey: "locationPermissionDecision") }
    }
    
    var hasAskedForLocation: Bool {
        locationPermissionDecision != nil
    }
    
    func fetchBraiders() {
        // Mock data with real Unsplash images of braids
        self.braiders = [
            Braider(
                id: "1",
                name: "Sarah M.",
                imageUrl: "https://images.unsplash.com/photo-1595959183082-7b570b7e08e2?w=400",
                coordinate: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
                rating: 4.9,
                bio: "5 years of knotless expertise. I specialize in protective styles that last.",
                posts: [
                    "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=800",
                    "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=800",
                    "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=800",
                    "https://images.unsplash.com/photo-1614023342696-17d7e2b1f7c9?w=800"
                ]
            ),
            Braider(
                id: "2",
                name: "Maya K.",
                imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=400",
                coordinate: CLLocationCoordinate2D(latitude: 52.4900, longitude: -1.8800),
                rating: 4.8,
                bio: "Box braids are my art. Every head tells a story.",
                posts: [
                    "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=800",
                    "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=800",
                    "https://images.unsplash.com/photo-1618374962044-3d5c0f5eb1e9?w=800"
                ]
            ),
            Braider(
                id: "3",
                name: "Zara A.",
                imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=400",
                coordinate: CLLocationCoordinate2D(latitude: 52.4800, longitude: -1.9000),
                rating: 4.7,
                bio: "Cornrows, twists, and everything in between. Booking fast.",
                posts: [
                    "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=800",
                    "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=800"
                ]
            )
        ]
    }
    
    func reviews(for braider: Braider) -> [Review] {
        [
            Review(id: "r1", userName: "Amara O.", userAvatar: "https://i.pravatar.cc/150?img=45",
                   text: "Absolutely flawless work. My knotless lasted 8 weeks and still looked fresh.", rating: 5.0, date: "2 weeks ago"),
            Review(id: "r2", userName: "Jasmine B.", userAvatar: "https://i.pravatar.cc/150?img=32",
                   text: "So professional and gentle with my edges. Will book again!", rating: 5.0, date: "1 month ago"),
            Review(id: "r3", userName: "Naomi P.", userAvatar: "https://i.pravatar.cc/150?img=28",
                   text: "Beautiful result. Took a bit longer than expected but worth it.", rating: 4.5, date: "1 month ago"),
            Review(id: "r4", userName: "Ifeoma N.", userAvatar: "https://i.pravatar.cc/150?img=20",
                   text: "Best braider in Birmingham, hands down. Sarah is a gem.", rating: 5.0, date: "2 months ago"),
            Review(id: "r5", userName: "Kelechi D.", userAvatar: "https://i.pravatar.cc/150?img=12",
                   text: "Clean parts, no tension, exactly what I asked for.", rating: 5.0, date: "3 months ago")
        ]
    }
    
    func braidStyles() -> [BraidStyle] {
        [
            BraidStyle(id: "s1", name: "Knotless Braids",
                       description: "Seamless, pain-free braids that start with your own hair. Perfect for a natural, lightweight feel that protects your edges.",
                       imageUrl: "https://images.unsplash.com/photo-1614023342667-6f060e9d5c04?w=800",
                       priceFrom: 120, durationMinutes: 240),
            BraidStyle(id: "s2", name: "Box Braids",
                       description: "Classic, timeless, and endlessly versatile. Square parts, individual plaits, and a look that lasts 6–8 weeks.",
                       imageUrl: "https://images.unsplash.com/photo-1595475207225-428b62bda831?w=800",
                       priceFrom: 100, durationMinutes: 210),
            BraidStyle(id: "s3", name: "Cornrows",
                       description: "Sleek, sculpted rows braided close to the scalp. Bold, elegant, and built to turn heads.",
                       imageUrl: "https://images.unsplash.com/photo-1523263685509-57c1d050d19b?w=800",
                       priceFrom: 60, durationMinutes: 120)
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
        // Randomize availability per day for realism
        let seed = Calendar.current.component(.day, from: date)
        return all.enumerated().map { idx, slot in
            var s = slot
            s.available = (idx + seed) % 3 != 0
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