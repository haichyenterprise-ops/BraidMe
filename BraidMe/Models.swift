import Foundation
import CoreLocation

// MARK: - User

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var email: String?
    var age: Int
    var provider: String
    var city: String?
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
    let story: String
    let city: String
    let specialties: [String]
    let yearsExperience: Int
    let responseTime: String
    let verified: Bool
    let published: Bool
    let portfolio: [PortfolioItem]
    let services: [BraidService]
    let availableSlots: [String: [String]]
    let availableDates: [Date]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: Braider, rhs: Braider) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Used when a review is added — returns an updated copy with new aggregates.
    func updated(rating: Double, reviewCount: Int) -> Braider {
        Braider(
            id: id,
            name: name,
            tagline: tagline,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
            latitude: latitude,
            longitude: longitude,
            rating: rating,
            reviewCount: reviewCount,
            priceFrom: priceFrom,
            bio: bio,
            story: story,
            city: city,
            specialties: specialties,
            yearsExperience: yearsExperience,
            responseTime: responseTime,
            verified: verified,
            published: published,
            portfolio: portfolio,
            services: services,
            availableSlots: availableSlots,
            availableDates: availableDates
        )
    }
}

struct PortfolioItem: Identifiable, Hashable {
    let id: String
    let imageUrl: String
    let caption: String
    let tag: String
    let likes: Int
}

// MARK: - Service

struct BraidService: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String
    let priceFrom: Int
    let durationMinutes: Int
    let includes: [String]
    let popular: Bool
    let availableDates: [Date]
    let availableSlots: [String: [String]]

    var hasAvailability: Bool {
        !availableDates.isEmpty && availableSlots.values.contains { !$0.isEmpty }
    }
}

// MARK: - Reviews

struct Review: Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let userAvatar: String
    let text: String
    let rating: Double
    let date: Date
    let styleDone: String
    let helpful: Int

    var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
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

    static let empty = RatingBreakdown(five: 0, four: 0, three: 0, two: 0, one: 0)

    static func from(_ reviews: [Review]) -> RatingBreakdown {
        var f = 0, fo = 0, t = 0, tw = 0, o = 0
        for r in reviews {
            switch Int(r.rating.rounded()) {
            case 5: f += 1
            case 4: fo += 1
            case 3: t += 1
            case 2: tw += 1
            default: o += 1
            }
        }
        return RatingBreakdown(five: f, four: fo, three: t, two: tw, one: o)
    }
}

// MARK: - Chat

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
}
// MARK: - Booking

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

// MARK: - Time slot

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