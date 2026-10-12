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
                    searchField
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.md)
                        .padding(.bottom, Space.md)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            if query.isEmpty {
                                sectionHeader("POPULAR")
                                ForEach(suggested) { city in
                                    cityRow(city)
                                    BMDivider().padding(.leading, Space.xxl)
                                }
                                Spacer().frame(height: Space.lg)
                                sectionHeader("ALL CITIES")
                            }

                            ForEach(filtered) { city in
                                cityRow(city)
                                if city.id != filtered.last?.id {
                                    BMDivider().padding(.leading, Space.xxl)
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
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                searchFocused = true
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.bmUI(15, weight: .medium))
                .foregroundStyle(Color.appAsh)

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
                        .font(.bmUI(14))
                        .foregroundStyle(Color.appSmoke)
                }
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 52)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.bmUI(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.appAsh)
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
                VStack(alignment: .leading, spacing: 2) {
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
                        .font(.bmUI(10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 4)
                        .background(Color.appAccentTint, in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.appSmoke)
                }
            }
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}