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
        ZStack {
            AuroraBackground(intensity: 0.45)

            VStack(spacing: 0) {
                BMSheetBar(title: "Choose a city", subtitle: "See braiders in another area") {
                    dismiss()
                }

                searchField
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.md)
                    .reveal(appeared, offset: 12, blur: 0)

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if query.isEmpty {
                            popularChips
                                .padding(.bottom, Space.lg)
                            BMSectionLabel(text: "All cities")
                                .padding(.bottom, Space.xs)
                        }

                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, city in
                            cityRow(city)
                                .reveal(appeared, delay: Motion.stagger(index), offset: 12, blur: 0)
                            if index < filtered.count - 1 {
                                BMDivider(inset: 58)
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
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                searchFocused = true
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(query.isEmpty ? Color.bmTextFaint : Color.bmGilt)

            TextField(
                "",
                text: $query,
                prompt: Text("Search city or region").foregroundColor(Color.bmTextFaint)
            )
            .font(.bmUI(16, weight: .medium))
            .foregroundStyle(Color.bmText)
            .tint(Color.bmGilt)
            .focused($searchFocused)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    Haptic.select()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.bmTextFaint)
                }
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 54)
        .bmGlass(radius: Radius.button)
        .animation(Motion.subtle, value: query.isEmpty)
    }

    private var popularChips: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            BMSectionLabel(text: "Popular")
            FlowLayout(spacing: Space.xs) {
                ForEach(suggested) { city in
                    BMChip(
                        title: city.name,
                        icon: city.id == initialCity.id ? "checkmark" : "mappin",
                        isSelected: city.id == initialCity.id
                    ) {
                        choose(city)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func cityRow(_ city: City) -> some View {
        let isCurrent = city.id == initialCity.id
        return Button {
            choose(city)
        } label: {
            HStack(spacing: Space.md) {
                Text(String(city.name.prefix(1)))
                    .font(.bmDisplay(18, weight: .semibold))
                    .foregroundStyle(isCurrent ? Color.bmOnGilt : Color.bmGilt)
                    .frame(width: 42, height: 42)
                    .background {
                        if isCurrent {
                            Circle().fill(LinearGradient.bmGiltGradient)
                        } else {
                            Circle().fill(Color.bmGilt.opacity(0.12))
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.bmUI(16, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                    Text(city.region)
                        .font(.bmUI(12))
                        .foregroundStyle(Color.bmTextDim)
                }
                Spacer()
                if isCurrent {
                    BMTag(text: "Current", icon: "location.fill")
                } else {
                    Image(systemName: "chevron.right")
                        .font(.bmUI(12, weight: .bold))
                        .foregroundStyle(Color.bmTextFaint)
                }
            }
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.99, dim: 0.02))
    }

    private func choose(_ city: City) {
        Haptic.select()
        onSelect(city)
        dismiss()
    }
}
