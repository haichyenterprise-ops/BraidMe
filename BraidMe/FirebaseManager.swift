import Foundation
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    @Published var braiders: [Braider] = []
    @Published var userBookings: [Booking] = []
    
    // Mock fetch for now - replace with actual Firebase calls when your DB is ready
    func fetchBraiders() {
        // In a real app, this would be a snapshotListener
        self.braiders = [
            Braider(id: "1", name: "Sarah", imageUrl: "", coordinate: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904), rating: 4.9, bio: "5 years experience in knotless braids.", posts: ["post1", "post2"]),
            Braider(id: "2", name: "Maya", imageUrl: "", coordinate: CLLocationCoordinate2D(latitude: 52.4900, longitude: -1.8800), rating: 4.8, bio: "Specialist in box braids.", posts: ["post3"]),
            Braider(id: "3", name: "Zara", imageUrl: "", coordinate: CLLocationCoordinate2D(latitude: 52.4800, longitude: -1.9000), rating: 4.7, bio: "Cornrows and twists.", posts: ["post4"])
        ]
    }
    
    func createBooking(braiderName: String, date: Date, style: String, completion: @escaping (Bool) -> Void) {
        let bookingData: [String: Any] = [
            "braiderName": braiderName,
            "date": Timestamp(date: date),
            "style": style,
            "userId": "current_user_id",
            "status": "confirmed"
        ]
        
        db.collection("bookings").addDocument(data: bookingData) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
}