import Foundation
import CoreLocation

// MARK: - User

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var email: String?
    var age: Int
    var provider: String            // "apple" | "google" | "guest"
    var city: String?               // "Birmingham" once location granted
    var locationGranted: Bool
    var avatarUrl: String?
    var createdAt: Date

    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "id": id,
            "displayName": displayName,
            "age": age,
            "provider": provider,
            "locationGranted": locationGranted,
            "createdAt": createdAt
        ]
        if let email { d["email"] = email }
        if let city { d["city"] = city }
        if let avatarUrl { d["avatarUrl"] = avatarUrl }
        return d
    }

    static func from(_ id: String, data: [String: Any]) -> UserProfile? {
        let name = (data["displayName"] as? String) ?? "User"
        let age = (data["age"] as? Int) ?? 0
        let created = (data["createdAt"] as? Date) ?? Date()
        return UserProfile(
            id: id,
            displayName: name,
            email: data["email"] as? String,
            age: age,
            provider: (data["provider"] as? String) ?? "unknown",
            city: data["city"] as? String,
            locationGranted: (data["locationGranted"] as? Bool) ?? false,
            avatarUrl: data["avatarUrl"] as? String,
            createdAt: created
        )
    }
}

// MARK: - Braider

struct Braider: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let avatarUrl: String
    let coverUrl: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    let reviewCount: Int
    let priceFrom: Int
    let bio: String
    let city: String
    let specialties: [String]
    let yearsExperience: Int
    let responseTime: String
    let verified: Bool
    let portfolio: [PortfolioItem]
    let styles: [BraidStyle]
    let availableSlots: [String: [String]]   // "2026-02-14" -> ["9:00 AM", ...]
    let availableDates: [Date]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

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
            "date": date,
            "time": time,
            "style": style,
            "price": price,
            "status": status,
            "createdAt": createdAt
        ]
    }
}