import SwiftUI
import MapKit
import CoreLocation

struct MainTabView: View {
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var locationService = LocationService()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
    @State private var selectedBraider: Braider?
    @State private var previewBraider: Braider?
    @State private var showLocationSheet = false
    @State private var showBookings = false
    @State private var selectedFilter: String = "All"
    @State private var mapAppeared = false

    private let filters = ["All", "Knotless", "Box", "Cornrows", "Boho"]

    private var filteredBraiders: [Braider] {
        if selectedFilter == "All" { return fb.braiders }
        return fb.braiders.filter { braider in
            braider.specialties.contains(where: { $0.localizedCaseInsensitiveContains(selectedFilter) })
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                floatingTopChrome
                floatingPreview
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationDestination(item: $selectedBraider) { braider in
                BraiderProfileView(braider: braider)
            }
            .sheet(isPresented: $showBookings) { BookingsSheet() }
            .onAppear(perform: onAppear)
            .sheet(isPresented: $showLocationSheet, onDismiss: onLocationDismiss) {
                LocationPermissionSheet { allowed in
                    handleLocationDecision(allowed)
                }
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(coordinateRegion: $region, annotationItems: filteredBraiders) { braider in
            MapAnnotation(coordinate: braider.coordinate) {
                BraiderPin(
                    braider: braider,
                    isSelected: previewBraider?.id == braider.id
                ) {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        previewBraider = braider
                    }
                }
            }
        }
        .ignoresSafeArea()
        .opacity(mapAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: mapAppeared)
    }

    // MARK: - Top chrome

    private var floatingTopChrome: some View {
        VStack(spacing: 12) {
            searchRow
            filterChips
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            searchBar
            avatarButton
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.slate)

            VStack(alignment: .leading, spacing: 1) {
                Text("Nearby")
                    .font(AppTheme.sans(10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundColor(AppTheme.stone)
                Text("Birmingham, UK")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
            }

            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.ink)
                .frame(width: 30, height: 30)
                .background(AppTheme.mist, in: Circle())
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private var avatarButton: some View {
        Button {
            Haptics.soft()
            showBookings = true
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.inkGradient)
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(BouncyPress())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(title: filter, isSelected: selectedFilter == filter) {
                        Haptics.select()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            selectedFilter = filter
                            previewBraider = nil
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Preview pill (floating above bottom bar)

    @ViewBuilder
    private var floatingPreview: some View {
        if let braider = previewBraider {
            VStack {
                Spacer()
                previewCard(braider: braider)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 90)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
    }

    private func previewCard(braider: Braider) -> some View {
        Button {
            Haptics.medium()
            selectedBraider = braider
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RemoteImage(url: braider.imageUrl)
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())

                    Circle()
                        .stroke(AppTheme.accent, lineWidth: 2)
                        .frame(width: 62, height: 62)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(braider.name)
                            .font(AppTheme.sans(15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.accent)
                        }
                    }

                    HStack(spacing: 5) {
                        StarRow(rating: braider.rating, size: 10)
                        Text(String(format: "%.1f", braider.rating))
                            .font(AppTheme.sans(11, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text("(\(braider.reviewCount))")
                            .font(AppTheme.sans(11))
                            .foregroundColor(AppTheme.stone)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text("from £\(braider.priceFrom)")
                            .font(AppTheme.sans(11, weight: .medium))
                            .foregroundColor(AppTheme.accentDeep)
                    }

                    Text(braider.tagline)
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.slate)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.stone)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.mist, in: Circle())
            }
            .padding(12)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
        }
        .buttonStyle(CardPress())
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            statTile(icon: "location.fill", value: "\(filteredBraiders.count)", label: "Nearby")
            statTile(icon: "star.fill", value: String(format: "%.1f", avgRating), label: "Rating")

            Button {
                Haptics.medium()
                showBookings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Bookings")
                        .font(AppTheme.sans(15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: AppTheme.ink.opacity(0.28), radius: 16, y: 8)
            }
            .buttonStyle(SoftPress())
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud.opacity(0.92), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var avgRating: Double {
        guard !filteredBraiders.isEmpty else { return 0 }
        let total = filteredBraiders.reduce(0.0) { $0 + $1.rating }
        return total / Double(filteredBraiders.count)
    }

    private func statTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(value)
                    .font(AppTheme.sans(15, weight: .bold))
                    .foregroundColor(AppTheme.ink)
            }
            Text(label)
                .font(AppTheme.sans(9, weight: .medium))
                .tracking(0.6)
                .foregroundColor(AppTheme.stone)
        }
        .frame(width: 68, height: 54)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
        )
    }

    // MARK: - Lifecycle

    private func onAppear() {
        fb.fetchBraiders()
        withAnimation(.easeOut(duration: 0.6).delay(0.15)) { mapAppeared = true }

        if !fb.hasAskedForLocation {
            showLocationSheet = true
        } else {
            if fb.locationPermissionDecision == "allowed" {
                locationService.start()
            }
        }
    }

    private func onLocationDismiss() {
        if fb.locationPermissionDecision == nil {
            fb.locationPermissionDecision = "denied"
        }
    }

    private func handleLocationDecision(_ allowed: Bool) {
        Haptics.medium()
        fb.locationPermissionDecision = allowed ? "allowed" : "denied"
        if allowed { locationService.start() }

        if let uid = UserDefaults.standard.string(forKey: "currentUid"), uid != "" {
            Task {
                try? await FirebaseManager.shared.updateUserProfile(
                    uid: uid,
                    data: ["locationGranted": allowed]
                )
            }
        }

        showLocationSheet = false
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(AppTheme.sans(13, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.ink)
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(isSelected ? AppTheme.ink : AppTheme.snow)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppTheme.hairline.opacity(0.7), lineWidth: 0.5)
                )
                .shadow(
                    color: .black.opacity(isSelected ? 0.14 : 0.05),
                    radius: isSelected ? 12 : 4,
                    y: isSelected ? 4 : 2
                )
        }
        .buttonStyle(SoftPress())
    }
}

// MARK: - Pin

struct BraiderPin: View {
    let braider: Braider
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.28))
                        .frame(width: 104, height: 104)
                        .scaleEffect(pulse ? 1.2 : 0.85)
                        .opacity(pulse ? 0 : 0.7)
                        .animation(
                            .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }

                // Base halo
                Circle()
                    .fill(AppTheme.snow)
                    .frame(
                        width: isSelected ? 72 : 58,
                        height: isSelected ? 72 : 58
                    )
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 6)

                // Photo
                RemoteImage(url: braider.imageUrl)
                    .frame(
                        width: isSelected ? 62 : 48,
                        height: isSelected ? 62 : 48
                    )
                    .clipShape(Circle())

                // Ring
                Circle()
                    .stroke(isSelected ? AppTheme.accent : AppTheme.snow, lineWidth: isSelected ? 3 : 2)
                    .frame(
                        width: isSelected ? 68 : 54,
                        height: isSelected ? 68 : 54
                    )

                // Tiny rating badge when selected
                if isSelected {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.gold)
                        Text(String(format: "%.1f", braider.rating))
                            .font(AppTheme.sans(10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.ink)
                    .clipShape(Capsule())
                    .offset(y: -44)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(BouncyPress())
        .onAppear { pulse = true }
    }
}

// MARK: - Location sheet

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambient

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                icon
                Spacer().frame(height: 28)
                copy
                Spacer()
                buttons
                Spacer().frame(height: 28)
            }
            .padding(.horizontal, 26)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var ambient: some View {
        Circle()
            .fill(RadialGradient(
                colors: [AppTheme.accent.opacity(0.20), .clear],
                center: .center, startRadius: 0, endRadius: 240
            ))
            .frame(width: 480, height: 480)
            .blur(radius: 40)
            .offset(y: -140)
            .opacity(appeared ? 1 : 0)
    }

    private var icon: some View {
        ZStack {
            Circle().fill(AppTheme.accentSoft).frame(width: 118, height: 118)
            Circle().fill(AppTheme.accent.opacity(0.18)).frame(width: 92, height: 92)
            Image(systemName: "location.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(AppTheme.accent)
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
    }

    private var copy: some View {
        VStack(spacing: 12) {
            Text("Find braiders\nnear you")
                .font(AppTheme.serif(30))
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.ink)
                .lineSpacing(-2)

            Text("We use your location to surface verified braiders in Birmingham and show accurate travel times.")
                .font(AppTheme.sans(15))
                .foregroundColor(AppTheme.slate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Allow Location", icon: "location.fill") {
                onDecision(true)
            }
            SecondaryButton(title: "Not now") {
                onDecision(false)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Location service

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() { manager.requestWhenInUseAuthorization() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

// MARK: - Bookings sheet

struct BookingsSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()
                emptyState
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(AppTheme.accentSoft).frame(width: 120, height: 120)
                Circle().fill(AppTheme.accent.opacity(0.14)).frame(width: 92, height: 92)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 46, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            .scaleEffect(appeared ? 1 : 0.85)

            VStack(spacing: 8) {
                Text("No bookings yet")
                    .font(AppTheme.serif(26))
                    .foregroundColor(AppTheme.ink)
                Text("Your upcoming appointments will appear here.")
                    .font(AppTheme.sans(15))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
    }
}