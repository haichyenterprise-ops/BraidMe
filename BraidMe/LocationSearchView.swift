import SwiftUI
import CoreLocation

struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double
    let imageUrl: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullName: String { "\(name), \(region)" }
}

enum CityCatalog {
    static let all: [City] = [
        City(id: "birmingham",  name: "Birmingham",  region: "West Midlands", latitude: 52.4862, longitude: -1.8904,
             imageUrl: "https://images.unsplash.com/photo-1560427450-0849dd7fc0b7?w=400&q=75"),
        City(id: "solihull",    name: "Solihull",    region: "West Midlands", latitude: 52.4118, longitude: -1.7776,
             imageUrl: "https://images.unsplash.com/photo-1543872084-c7bd3822856f?w=400&q=75"),
        City(id: "wolverhampton", name: "Wolverhampton", region: "West Midlands", latitude: 52.5870, longitude: -2.1288,
             imageUrl: "https://images.unsplash.com/photo-1590418606746-018840f9cd0f?w=400&q=75"),
        City(id: "coventry",    name: "Coventry",    region: "West Midlands", latitude: 52.4068, longitude: -1.5197,
             imageUrl: "https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=400&q=75"),
        City(id: "london",      name: "London",      region: "Greater London", latitude: 51.5074, longitude: -0.1278,
             imageUrl: "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=75"),
        City(id: "manchester",  name: "Manchester",  region: "Greater Manchester", latitude: 53.4808, longitude: -2.2426,
             imageUrl: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=75"),
        City(id: "leeds",       name: "Leeds",       region: "West Yorkshire", latitude: 53.8008, longitude: -1.5491,
             imageUrl: "https://images.unsplash.com/photo-1543872084-c7bd3822856f?w=400&q=75"),
        City(id: "bristol",     name: "Bristol",     region: "South West", latitude: 51.4545, longitude: -2.5879,
             imageUrl: "https://images.unsplash.com/photo-1543872084-c7bd3822856f?w=400&q=75"),
        City(id: "cardiff",     name: "Cardiff",     region: "Wales", latitude: 51.4816, longitude: -3.1791,
             imageUrl: "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=75"),
        City(id: "swansea",     name: "Swansea",     region: "Wales", latitude: 51.6214, longitude: -3.9436,
             imageUrl: "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=75"),
        City(id: "edinburgh",   name: "Edinburgh",   region: "Scotland", latitude: 55.9533, longitude: -3.1883,
             imageUrl: "https://images.unsplash.com/photo-1506377711776-db0cf0d26e3e?w=400&q=75"),
        City(id: "glasgow",     name: "Glasgow",     region: "Scotland", latitude: 55.8642, longitude: -4.2518,
             imageUrl: "https://images.unsplash.com/photo-1506377711776-db0cf0d26e3e?w=400&q=75")
    ]

    static func closest(to location: CLLocation?) -> City? {
        guard let location else { return nil }
        return all.min { a, b in
            let da = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: location)
            let db = CLLocation(latitude: b.latitude, longitude: b.longitude).distance(from: location)
            return da < db
        }
    }
}

// MARK: - Search view

struct LocationSearchView: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    let initialCity: City
    var onSelect: (City) -> Void

    @State private var query = ""
    @State private var appeared = false
    @FocusState private var searchFocused: Bool

    private var filtered: [City] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return CityCatalog.all }
        return CityCatalog.all.filter {
            $0.name.lowercased().contains(q) ||
            $0.region.lowercased().contains(q)
        }
    }

    private var suggested: [City] {
        Array(CityCatalog.all.prefix(4))
    }

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambient

            VStack(spacing: 0) {
                navBar
                Spacer().frame(height: 16)
                searchField
                Spacer().frame(height: 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if query.isEmpty {
                            suggestedHeader
                            ForEach(suggested) { city in
                                CityRow(city: city, isSelected: city.id == initialCity.id) {
                                    select(city)
                                }
                                .padding(.horizontal, 20)
                            }

                            Spacer().frame(height: 24)

                            allCitiesHeader
                        }

                        ForEach(filtered) { city in
                            CityRow(city: city, isSelected: city.id == initialCity.id) {
                                select(city)
                            }
                            .padding(.horizontal, 20)

                            if city.id != filtered.last?.id {
                                Divider()
                                    .background(AppTheme.hairline.opacity(0.6))
                                    .padding(.leading, 76)
                            }
                        }

                        if filtered.isEmpty {
                            emptyState
                        }

                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                searchFocused = true
            }
        }
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 440, height: 440)
                .blur(radius: 50)
                .offset(x: -140, y: -220)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 160, y: 280)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.snow)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.5))
            }
            .buttonStyle(BouncyPress())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.slate)

            TextField("Search city or region", text: $query)
                .font(AppTheme.sans(16, weight: .medium))
                .foregroundColor(AppTheme.ink)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    Haptics.soft()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.ash)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
        .padding(.horizontal, 20)
    }

    // MARK: - Section headers

    private var suggestedHeader: some View {
        HStack {
            Text("POPULAR")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }

    private var allCitiesHeader: some View {
        HStack {
            Text("ALL CITIES")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(AppTheme.stone)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppTheme.ash)
            Text("No cities found")
                .font(AppTheme.sans(16, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text("Try a different city or region.")
                .font(AppTheme.sans(13))
                .foregroundColor(AppTheme.slate)
        }
        .padding(.top, 60)
    }

    // MARK: - Select

    private func select(_ city: City) {
        Haptics.medium()
        onSelect(city)

        // Persist to Firestore if signed in
        Task {
            let uid = session.uid
            guard !uid.isEmpty else { return }
            do {
                try await FirebaseManager.shared.updateUser(uid: uid, data: [
                    "city": city.name,
                    "region": city.region,
                    "latitude": city.latitude,
                    "longitude": city.longitude,
                    "cityUpdatedAt": Date()
                ])
            } catch {
                print("[LocationSearch] save failed:", error)
            }
        }

        dismiss()
    }
}

// MARK: - City row

struct CityRow: View {
    let city: City
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RemoteImage(url: city.imageUrl)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.accent, lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(city.name)
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)

                    Text(city.region)
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.slate)
                }

                Spacer()

                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Current")
                            .font(AppTheme.sans(10, weight: .bold))
                            .tracking(0.8)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.ink, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.ash)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(CardPress())
    }
}