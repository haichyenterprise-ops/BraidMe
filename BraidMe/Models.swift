import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - User

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String                 // Firebase UID or Apple user ID
    var displayName: String
    var email: String?
    var age: Int
    var createdAt: Date
    var provider: String           // "apple" | "google" | "guest"
    var locationGranted: Bool

    var dictionary: [String: Any] {
        [
            "id": id,
            "displayName": displayName,
            "email": email as Any,
            "age": age,
            "createdAt": Timestamp(date: createdAt),
            "provider": provider,
            "locationGranted": locationGranted
        ]
    }

    static func from(_ id: String, data: [String: Any]) -> UserProfile? {
        guard
            let name = data["displayName"] as? String,
            let age = data["age"] as? Int,
            let created = (data["createdAt"] as? Timestamp)?.dateValue()
        else { return nil }

        return UserProfile(
            id: id,
            displayName: name,
            email: data["email"] as? String,
            age: age,
            createdAt: created,
            provider: data["provider"] as? String ?? "unknown",
            locationGranted: data["locationGranted"] as? Bool ?? false
        )
    }
}

// MARK: - Braider

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
    let yearsExperience: Int
    let responseTime: String
    let verified: Bool

    static func == (lhs: Braider, rhs: Braider) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PortfolioItem: Identifiable, Hashable {
    let id: String
    let imageUrl: String
    let caption: String
    let tag: String
    let likes: Int
}

// MARK: - Reviews

struct Review: Identifiable, Hashable {
    let id: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: String
    let styleDone: String
    let helpful: Int
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

// MARK: - Booking flow

struct BraidStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    let priceFrom: Int
    let durationMinutes: Int
    let includes: [String]
    let popular: Bool
}

struct TimeSlot: Identifiable, Hashable {
    let id: String
    let label: String
    let available: Bool
    let period: DayPeriod
}

enum DayPeriod: String, Hashable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
}

struct Booking: Identifiable, Codable {
    let id: String
    let braiderName: String
    let braiderId: String
    let date: Date
    let time: String
    let style: String
    let price: Int
    let status: String
    let createdAt: Date

    var dictionary: [String: Any] {
        [
            "id": id,
            "braiderName": braiderName,
            "braiderId": braiderId,
            "date": Timestamp(date: date),
            "time": time,
            "style": style,
            "price": price,
            "status": status,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}