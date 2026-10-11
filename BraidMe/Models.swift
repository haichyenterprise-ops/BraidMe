import Foundation
import CoreLocation

struct Braider: Identifiable, Hashable {
    let id: String
    let name: String
    let imageUrl: String
    let coordinate: CLLocationCoordinate2D
    let rating: Double
    let bio: String
    let posts: [String]
    
    static func == (lhs: Braider, rhs: Braider) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Review: Identifiable, Hashable {
    let id: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: String
}

struct Booking: Identifiable {
    let id: String
    let braiderName: String
    let date: Date
    let time: String
    let style: String
    let status: String
}

struct BraidStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    let priceFrom: Int
    let durationMinutes: Int
}

struct TimeSlot: Identifiable, Hashable {
    let id: String
    let label: String  // "9:00 AM"
    var available: Bool
}