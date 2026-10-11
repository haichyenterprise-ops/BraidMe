import Foundation
import CoreLocation

struct Braider: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let imageUrl: String
    let coordinate: CLLocationCoordinate2D
    let rating: Double
    let reviewCount: Int
    let priceFrom: Int
    let bio: String
    let specialties: [String]
    let portfolio: [PortfolioItem]

    static func == (lhs: Braider, rhs: Braider) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PortfolioItem: Identifiable, Hashable {
    let id: String
    let imageUrl: String
    let caption: String
    let tag: String
}

struct Review: Identifiable, Hashable {
    let id: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: String
    let styleDone: String
}

struct RatingBreakdown: Hashable {
    let five: Int
    let four: Int
    let three: Int
    let two: Int
    let one: Int

    var total: Int { five + four + three + two + one }
    var average: Double {
        guard total > 0 else { return 0 }
        let sum = 5 * five + 4 * four + 3 * three + 2 * two + 1 * one
        return Double(sum) / Double(total)
    }
}

struct BraidStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    let priceFrom: Int
    let durationMinutes: Int
    let includes: [String]
}

struct TimeSlot: Identifiable, Hashable {
    let id: String
    let label: String
    let available: Bool
}

struct Booking: Identifiable {
    let id: String
    let braiderName: String
    let date: Date
    let time: String
    let style: String
    let status: String
}