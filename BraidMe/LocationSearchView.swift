import SwiftUI
import CoreLocation

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

                VStack(spacing: 0) {
                    header

                    searchField
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.md)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animate(Motion.heroReveal.delay(0.15), value: appeared)

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
                                BMEmptyState(
                                    icon: "magnifyingglass",
                                    title: "No cities found",
                                    message: "Try a different city or region."
                                )
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
                    BMGlassIconButton(icon: "xmark", size: 40, iconSize: 14, tint: .appInk) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            withAnimation(Motion.heroReveal.delay(0.1)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                searchFocused = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 20, height: 2)
                Text("EXPLORE")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAccent)
            }

            Text("Where to?")
                .font(.bmHero(34))
                .foregroundStyle(Color.appInk)
                .lineSpacing(-4)

            Text("Pick a city to discover braiders nearby.")
                .font(.bmUI(14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animate(Motion.heroReveal, value: appeared)
    }

    private var searchField: some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(searchFocused ? Color.appAccentTint : Color.appBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: "magnifyingglass")
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(searchFocused ? Color.appAccent : Color.appAsh)
            }
            .animation(Motion.subtle, value: searchFocused)

            TextField("Search city or region", text: $query)
                .font(.bmUI(16, weight: .medium))
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
                        .font(.bmUI(16))
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
                    searchFocused ? Color.appAccent.opacity(0.5) : Color.appDivider,
                    lineWidth: searchFocused ? 1.5 : 0.5
                )
        )
        .shadow(color: searchFocused ? Color.appAccent.opacity(0.1) : .clear, radius: 8, y: 2)
        .animation(Motion.subtle, value: searchFocused)
        .animation(Motion.subtle, value: query.isEmpty)
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 12, height: 2)
                Text(text)
                    .font(.bmUI(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(.vertical, Space.sm)
    }

    private func cityRow(_ city: City) -> some View {
        Button {
            Haptic.select()
            onSelect(city)
            dismiss()
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    Circle()
                        .fill(city.id == initialCity.id ? Color.appAccentTint : Color.appBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: city.id == initialCity.id ? "location.fill" : "mappin")
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(city.id == initialCity.id ? Color.appAccent : Color.appAsh)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(city.name)
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text(city.region)
                        .font(.bmUI(12))
                        .foregroundStyle(Color.appAsh)
                }
                Spacer()

                if city.id == initialCity.id {
                    Text("Current")
                        .font(.bmUI(10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.appAccentTint, in: Capsule())
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.bmUI(12, weight: .semibold))
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
}