import Foundation
import CoreLocation

// =============================================================================
// BraidMe Models — with convenience extensions for the UI layer
// =============================================================================

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

extension UserProfile {
    /// Two-letter initials for avatar fallbacks.
    var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
            .isEmpty ? "·" : displayName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first }
                .map(String.init)
                .joined()
                .uppercased()
    }

    /// Whether onboarding has been completed (based on age + name)
    var isProfileComplete: Bool {
        age > 0 && !displayName.isEmpty && displayName != "BraidMe User"
    }

    /// Best-guess first name for greetings
    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
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

extension Braider {
    /// Two-letter initials for avatar fallbacks.
    var initials: String {
        let r = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        return r.isEmpty ? "·" : r
    }

    /// First name only — for warm greetings like "Sarah will see your booking"
    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// Location string with fallback
    var shortLocation: String {
        city.isEmpty ? "Location TBD" : city
    }

    /// Whether the braider has any bookable services
    var isBookable: Bool {
        !services.isEmpty && services.contains { $0.hasAvailability }
    }

    /// Total review count formatted for the badge
    var reviewCountText: String {
        "\(reviewCount) review\(reviewCount == 1 ? "" : "s")"
    }

    /// Formatted rating text (e.g., "4.8")
    var ratingText: String {
        String(format: "%.1f", rating)
    }
}

// MARK: - Portfolio

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

extension BraidService {
    /// "2h 30m" style duration
    var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// Whether the service has any available time slots for a given date
    func hasSlots(on date: Date) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        let key = f.string(from: date)
        return !(availableSlots[key] ?? []).isEmpty
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

extension Review {
    /// Two-letter initials for avatar fallbacks.
    var initials: String {
        let r = userName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
        return r.isEmpty ? "·" : r
    }

    /// Short relative date (e.g., "2w ago")
    var shortDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Rating Breakdown

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

    /// Count for a specific star tier
    func count(for stars: Int) -> Int {
        switch stars {
        case 5: return five
        case 4: return four
        case 3: return three
        case 2: return two
        default: return one
        }
    }

    /// Ratio of a specific star tier (0.0 – 1.0)
    func ratio(for stars: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(count(for: stars)) / Double(total)
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
    let customerName: String?

    var dictionary: [String: Any] {
        var d: [String: Any] = [
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
        if let customerName { d["customerName"] = customerName }
        return d
    }
}

extension Booking {
    /// Whether this booking is upcoming (from today onwards)
    var isUpcoming: Bool {
        date >= Calendar.current.startOfDay(for: Date())
            && status != "completed"
            && status != "cancelled"
    }

    /// Whether this booking can still be cancelled
    var isCancellable: Bool {
        status == "confirmed" && date > Date()
    }

    /// Whether the user can still message the braider
    var canMessage: Bool {
        status == "confirmed" || status == "cancellation_requested"
    }

    /// Whether this booking is considered "past" for filtering
    var isPast: Bool {
        let now = Calendar.current.startOfDay(for: Date())
        return date < now || status == "completed" || status == "cancelled"
    }

    /// Human-readable status label
    var statusLabel: String {
        switch status {
        case "confirmed":              return "Confirmed"
        case "completed":              return "Completed"
        case "cancelled":              return "Cancelled"
        case "cancellation_requested": return "Pending"
        case "cancellation_denied":    return "Denied"
        default:                       return status.capitalized
        }
    }

    /// Formatted time string for display
    var timeText: String {
        time.isEmpty ? "TBD" : time
    }

    /// Whether this is happening today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Time Slot

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

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "moon.stars.fill"
        }
    }
}