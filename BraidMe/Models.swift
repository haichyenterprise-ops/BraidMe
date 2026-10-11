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
    
    static func == (lhs: Braider, rhs: Braider) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Review: Identifiable {
    let id: String
    let userName: String
    let text: String
    let rating: Double
}

struct Booking: Identifiable {
    let id: String
    let braiderName: String
    let date: Date
    let style: String
    let status: String
}