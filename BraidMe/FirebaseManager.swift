import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseDatabase
import CoreLocation

@MainActor
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    private let dbRef = Firestore.firestore()
    private let rtdb = Database.database().reference()

    var db: Firestore { dbRef }
    var rtdbRoot: DatabaseReference { rtdb }

    @Published var braiders: [Braider] = []
    @Published var currentUser: UserProfile?
    @Published var bookings: [Booking] = []
    @Published var savedBraiderIds: Set<String> = []
    @Published var isLoadingBraiders = false
    @Published var braidersError: String?

    // MARK: - Location persistence

    var locationPermissionDecision: String? {
        get { UserDefaults.standard.string(forKey: "locationPermissionDecision") }
        set { UserDefaults.standard.set(newValue, forKey: "locationPermissionDecision") }
    }

    var hasAskedForLocation: Bool { locationPermissionDecision != nil }

    var currentUid: String? {
        UserDefaults.standard.string(forKey: "currentUid")
            ?? UserDefaults.standard.string(forKey: "appleUserId")
            ?? Auth.auth().currentUser?.uid
    }

    private init() {}

    // MARK: - Users

    @discardableResult
    func upsertUser(
        uid: String,
        displayName: String,
        email: String?,
        provider: String,
        age: Int = 0
    ) async throws -> UserProfile {
        let ref = dbRef.collection("users").document(uid)
        let snap = try await ref.getDocument()

        if snap.exists, let data = snap.data(), let existing = UserProfile.from(uid, data: data) {
            var updated = existing
            if !displayName.isEmpty { updated.displayName = displayName }
            updated.email = email ?? existing.email
            updated.provider = provider
            try await ref.setData(updated.dictionary, merge: true)
            self.currentUser = updated
            return updated
        } else {
            let new = UserProfile(
                id: uid,
                displayName: displayName.isEmpty ? "BraidMe User" : displayName,
                email: email,
                age: age,
                provider: provider,
                city: nil,
                locationGranted: false,
                avatarUrl: nil,
                createdAt: Date()
            )
            try await ref.setData(new.dictionary)
            self.currentUser = new
            return new
        }
    }

    func updateUser(uid: String, data: [String: Any]) async throws {
        guard !uid.isEmpty else { return }
        try await dbRef.collection("users").document(uid).setData(data, merge: true)
    }

    func setLocation(granted: Bool, city: String?, uid: String) async throws {
        var payload: [String: Any] = [
            "locationGranted": granted,
            "locationUpdatedAt": Date()
        ]
        if let city { payload["city"] = city }
        try await updateUser(uid: uid, data: payload)
    }

    func loadUser(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let snap = try await dbRef.collection("users").document(uid).getDocument()
            if let data = snap.data(), let user = UserProfile.from(uid, data: data) {
                self.currentUser = user
            }
        } catch {
            print("[FirebaseManager] loadUser failed:", error)
        }
    }

    // MARK: - Saved braiders (hearts)

    func loadSavedBraiders(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let snap = try await dbRef.collection("users").document(uid)
                .collection("saved")
                .getDocuments()
            let ids = Set(snap.documents.map { $0.documentID })
            await MainActor.run { self.savedBraiderIds = ids }
        } catch {
            print("[FirebaseManager] loadSavedBraiders failed:", error)
        }
    }

    func toggleSave(braiderId: String, uid: String) async {
        guard !uid.isEmpty, !braiderId.isEmpty else { return }
        let ref = dbRef.collection("users").document(uid)
            .collection("saved")
            .document(braiderId)

        let isSaved = savedBraiderIds.contains(braiderId)
        do {
            if isSaved {
                try await ref.delete()
                await MainActor.run { _ = self.savedBraiderIds.remove(braiderId) }
            } else {
                try await ref.setData(["savedAt": Date()])
                await MainActor.run { _ = self.savedBraiderIds.insert(braiderId) }
            }
        } catch {
            print("[FirebaseManager] toggleSave failed:", error)
        }
    }

    // MARK: - Braiders

    func fetchBraidersFromFirestore() async {
        isLoadingBraiders = true
        braidersError = nil
        do {
            let snap = try await dbRef.collection("braiders").getDocuments()
            let all = snap.documents.compactMap { doc in
                BraiderMapper.from(id: doc.documentID, data: doc.data())
            }
            self.braiders = all.filter { $0.published }
        } catch {
            braidersError = error.localizedDescription
            print("[FirebaseManager] fetchBraiders failed:", error)
        }
        isLoadingBraiders = false
    }

    // MARK: - Bookings

    func loadBookings(uid: String) async {
        guard !uid.isEmpty else { return }
        do {
            let snap = try await dbRef.collection("bookings")
                .whereField("uid", isEqualTo: uid)
                .getDocuments()

            let fetched: [Booking] = snap.documents.compactMap { doc in
                let d = doc.data()
                guard
                    let braiderName = d["braiderName"] as? String,
                    let braiderId = d["braiderId"] as? String,
                    let ts = d["date"] as? Timestamp,
                    let time = d["time"] as? String,
                    let style = d["style"] as? String,
                    let price = d["price"] as? Int,
                    let status = d["status"] as? String,
                    let created = d["createdAt"] as? Timestamp
                else { return nil }

                return Booking(
                    id: doc.documentID,
                    braiderName: braiderName,
                    braiderId: braiderId,
                    date: ts.dateValue(),
                    time: time,
                    style: style,
                    price: price,
                    status: status,
                    createdAt: created.dateValue()
                )
            }

            await MainActor.run {
                self.bookings = fetched.sorted { $0.date > $1.date }
            }
        } catch {
            print("[FirebaseManager] loadBookings failed:", error)
        }
    }

    func createBooking(
        braider: Braider,
        date: Date,
        time: String,
        service: BraidService,
        price: Int,
        uid: String,
        completion: @escaping (Bool) -> Void
    ) {
        let id = UUID().uuidString
        let booking = Booking(
            id: id,
            braiderName: braider.name,
            braiderId: braider.id,
            date: date,
            time: time,
            style: service.name,
            price: price,
            status: "confirmed",
            createdAt: Date()
        )
        var payload = booking.dictionary
        payload["uid"] = uid

        dbRef.collection("bookings").document(id).setData(payload) { error in
            DispatchQueue.main.async {
                if error == nil {
                    self.bookings.insert(booking, at: 0)
                }
                completion(error == nil)
            }
        }
    }

    /// Customer requests a cancellation. Status becomes "cancellation_requested"
    /// and the braider must approve or deny it.
    func requestCancellation(bookingId: String, reason: String) async throws {
        try await dbRef.collection("bookings").document(bookingId).setData([
            "status": "cancellation_requested",
            "cancellationRequestedAt": Date(),
            "cancellationReason": reason,
            "cancellationRequestedBy": "customer"
        ], merge: true)

        // Update local cache
        if let idx = bookings.firstIndex(where: { $0.id == bookingId }) {
            let b = bookings[idx]
            let updated = Booking(
                id: b.id, braiderName: b.braiderName, braiderId: b.braiderId,
                date: b.date, time: b.time, style: b.style,
                price: b.price, status: "cancellation_requested", createdAt: b.createdAt
            )
            bookings[idx] = updated
        }
    }

    // MARK: - Chat (Realtime Database)

    /// Deterministic chat ID for a booking. Same ID used by both apps.
    static func chatId(for bookingId: String) -> String {
        return "chat_\(bookingId)"
    }

    /// Sends a message via RTDB.
    func sendMessage(
        chatId: String,
        senderId: String,
        senderName: String,
        text: String
    ) async throws {
        let ref = rtdb.child("chats").child(chatId).child("messages").childByAutoId()
        try await ref.setValue([
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": ServerValue.timestamp()
        ])

        // Update chat metadata so the other side sees the latest message + preview
        try await rtdb.child("chats").child(chatId).child("meta").updateChildValues([
            "lastMessage": text,
            "lastSenderId": senderId,
            "lastUpdated": ServerValue.timestamp()
        ])
    }

    /// Live stream of messages for a chat.
    func observeMessages(
        chatId: String,
        onUpdate: @escaping ([ChatMessage]) -> Void
    ) -> DatabaseHandle {
        let ref = rtdb.child("chats").child(chatId).child("messages")
        return ref.observe(.value) { snapshot in
            var messages: [ChatMessage] = []
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let dict = snap.value as? [String: Any] else { continue }
                let senderId = (dict["senderId"] as? String) ?? ""
                let senderName = (dict["senderName"] as? String) ?? ""
                let text = (dict["text"] as? String) ?? ""
                let tsRaw = (dict["timestamp"] as? NSNumber)?.doubleValue ?? 0
                let timestamp = Date(timeIntervalSince1970: tsRaw / 1000.0)

                messages.append(ChatMessage(
                    id: snap.key,
                    senderId: senderId,
                    senderName: senderName,
                    text: text,
                    timestamp: timestamp
                ))
            }
            messages.sort { $0.timestamp < $1.timestamp }
            DispatchQueue.main.async { onUpdate(messages) }
        }
    }

    func removeObserver(chatId: String, handle: DatabaseHandle) {
        rtdb.child("chats").child(chatId).child("messages").removeObserver(withHandle: handle)
    }
}

// MARK: - Mapper

enum BraiderMapper {
    static func from(id: String, data: [String: Any]) -> Braider? {
        let portfolioRaw = (data["portfolio"] as? [[String: Any]]) ?? []
        let servicesRaw = (data["services"] as? [[String: Any]]) ?? []
        let slotsRaw = (data["availableSlots"] as? [String: [String]]) ?? [:]

        let datesRaw: [Date] = {
            if let dates = data["availableDates"] as? [Date] { return dates }
            if let stamps = data["availableDates"] as? [Timestamp] {
                return stamps.map { $0.dateValue() }
            }
            return []
        }()

        let portfolio: [PortfolioItem] = portfolioRaw.compactMap { p in
            guard let pid = p["id"] as? String,
                  let url = p["imageUrl"] as? String else { return nil }
            return PortfolioItem(
                id: pid, imageUrl: url,
                caption: (p["caption"] as? String) ?? "",
                tag: (p["tag"] as? String) ?? "",
                likes: (p["likes"] as? Int) ?? 0
            )
        }

        let services: [BraidService] = servicesRaw.compactMap { s -> BraidService? in
            guard let sid = s["id"] as? String,
                  let name = s["name"] as? String else { return nil }

            let serviceDates: [Date] = {
                if let d = s["availableDates"] as? [Date] { return d }
                if let ts = s["availableDates"] as? [Timestamp] {
                    return ts.map { $0.dateValue() }
                }
                return []
            }()

            let serviceSlots = (s["availableSlots"] as? [String: [String]]) ?? [:]

            return BraidService(
                id: sid,
                name: name,
                description: (s["description"] as? String) ?? "",
                imageUrl: (s["imageUrl"] as? String) ?? "",
                priceFrom: (s["priceFrom"] as? Int) ?? 0,
                durationMinutes: (s["durationMinutes"] as? Int) ?? 120,
                includes: (s["includes"] as? [String]) ?? [],
                popular: (s["popular"] as? Bool) ?? false,
                availableDates: serviceDates,
                availableSlots: serviceSlots
            )
        }

        return Braider(
            id: id,
            name: (data["name"] as? String) ?? "",
            tagline: (data["tagline"] as? String) ?? "",
            avatarUrl: (data["avatarUrl"] as? String) ?? "",
            coverUrl: (data["coverUrl"] as? String) ?? "",
            latitude: (data["latitude"] as? Double) ?? 52.4862,
            longitude: (data["longitude"] as? Double) ?? -1.8904,
            rating: (data["rating"] as? Double) ?? 0,
            reviewCount: (data["reviewCount"] as? Int) ?? 0,
            priceFrom: (data["priceFrom"] as? Int) ?? 0,
            bio: (data["bio"] as? String) ?? "",
            story: (data["story"] as? String) ?? "",
            city: (data["city"] as? String) ?? "Birmingham",
            specialties: (data["specialties"] as? [String]) ?? [],
            yearsExperience: (data["yearsExperience"] as? Int) ?? 0,
            responseTime: (data["responseTime"] as? String) ?? "~30 min",
            verified: (data["verified"] as? Bool) ?? false,
            published: (data["published"] as? Bool) ?? false,
            portfolio: portfolio,
            services: services,
            availableSlots: slotsRaw,
            availableDates: datesRaw
        )
    }
}