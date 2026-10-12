import SwiftUI
import CoreLocation

// =============================================================================
// LocationSearchView — City picker, upgraded
// Editorial "Where to?" header, animated search field, staggered city rows.
// =============================================================================

struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var fullName: String { "\(name), \(region)" }
}

enum CityCatalog {
    static let all: [City] = [
        City(id: "birmingham", name: "Birmingham", region: "West Midlands", latitude: 52.4862, longitude: -1.8904),
        City(id: "solihull", name: "Solihull", region: "West Midlands", latitude: 52.4118, longitude: -1.7776),
        City(id: "wolverhampton", name: "Wolverhampton", region: "West Midlands", latitude: 52.5870, longitude: -2.1288),
        City(id: "coventry", name: "Coventry", region: "West Midlands", latitude: 52.4068, longitude: -1.5197),
        City(id: "london", name: "London", region: "Greater London", latitude: 51.5074, longitude: -0.1278),
        City(id: "manchester", name: "Manchester", region: "Greater Manchester", latitude: 53.4808, longitude: -2.2426),
        City(id: "leeds", name: "Leeds", region: "West Yorkshire", latitude: 53.8008, longitude: -1.5491),
        City(id: "bristol", name: "Bristol", region: "South West", latitude: 51.4545, longitude: -2.5879),
        City(id: "cardiff", name: "Cardiff", region: "Wales", latitude: 51.4816, longitude: -3.1791),
        City(id: "swansea", name: "Swansea", region: "Wales", latitude: 51.6214, longitude: -3.9436),
        City(id: "edinburgh", name: "Edinburgh", region: "Scotland", latitude: 55.9533, longitude: -3.1883),
        City(id: "glasgow", name: "Glasgow", region: "Scotland", latitude: 55.8642, longitude: -4.2518)
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
            $0.name.lowercased().contains(q) || $0.region.lowercased().contains(q)
        }
    }

    private var suggested: [City] { Array(CityCatalog.all.prefix(4)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                // Ambient gradient
                RadialGradient(
                    colors: [Color.gold.opacity(0.06), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    searchField
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.md)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(0.15), value: appeared)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            if query.isEmpty {
                                sectionHeader("POPULAR")
                                ForEach(suggested) { city in
                                    cityRow(city)
                                    if city.id != suggested.last?.id {
                                        BMDivider().padding(.leading, 76)
                                    }
                                }
                                Spacer().frame(height: Space.lg)
                                sectionHeader("ALL CITIES")
                            }

                            ForEach(filtered) { city in
                                cityRow(city)
                                if city.id != filtered.last?.id {
                                    BMDivider().padding(.leading, 76)
                                }
                            }

                            if filtered.isEmpty {
                                emptySearchResult
                            }

                            Color.clear.frame(height: Space.xl)
                        }
                        .padding(.horizontal, Space.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Haptic.press()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .frame(width: 40, height: 40)
                            .background(Color.appSurface, in: Circle())
                            .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                searchFocused = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 2)
                Text("EXPLORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.gold)
            }

            Text("Where to?")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)

            Text("Pick a city to discover braiders nearby.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(searchFocused ? Color.gold.opacity(0.12) : Color.appBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(searchFocused ? Color.gold : Color.appAsh)
            }
            .animation(.easeOut(duration: 0.2), value: searchFocused)

            TextField("Search city or region", text: $query)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appInk)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    Haptic.select()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appSmoke)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 60)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(
                    searchFocused ? Color.gold.opacity(0.5) : Color.appDivider,
                    lineWidth: searchFocused ? 1.5 : 0.5
                )
        )
        .shadow(color: searchFocused ? Color.gold.opacity(0.1) : .clear, radius: 8, y: 2)
        .animation(.easeOut(duration: 0.2), value: searchFocused)
        .animation(.easeOut(duration: 0.2), value: query.isEmpty)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Section header

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 12, height: 2)
                Text(text)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(.vertical, Space.sm)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - City row

    private func cityRow(_ city: City) -> some View {
        Button {
            Haptic.select()
            onSelect(city)
            dismiss()
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(city.id == initialCity.id ? Color.gold.opacity(0.14) : Color.appBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: city.id == initialCity.id ? "location.fill" : "mappin")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(city.id == initialCity.id ? Color.gold : Color.appAsh)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(city.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(city.region)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appAsh)
                }
                Spacer()

                if city.id == initialCity.id {
                    Text("Current")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.gold)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.gold.opacity(0.12), in: Capsule())
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appSmoke)
                        .frame(width: 32, height: 32)
                        .background(Color.appBackground, in: Circle())
                }
            }
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Empty state

    private var emptySearchResult: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.gold)
            }
            Text("No cities found")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Color.appInk)
            Text("Try a different city or region.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xxl)
    }
}