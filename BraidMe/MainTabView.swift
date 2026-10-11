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

    private let filters = ["All", "Knotless", "Box", "Cornrows", "Boho"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                floatingChrome
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationDestination(item: $selectedBraider) { braider in
                BraiderProfileView(braider: braider)
            }
            .sheet(isPresented: $showBookings) { BookingsSheet() }
            .onAppear(perform: onAppear)
            .sheet(isPresented: $showLocationSheet, onDismiss: onDismiss) {
                LocationPermissionSheet { allowed in
                    fb.locationPermissionDecision = allowed ? "allowed" : "denied"
                    if allowed { locationService.start() }
                    showLocationSheet = false
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(coordinateRegion: $region, annotationItems: fb.braiders) { braider in
            MapAnnotation(coordinate: braider.coordinate) {
                BraiderPin(
                    braider: braider,
                    isSelected: previewBraider?.id == braider.id
                ) {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        previewBraider = braider
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Floating chrome

    private var floatingChrome: some View {
        VStack(spacing: 12) {
            searchAndAvatarRow
            filterChipsRow
            if let preview = previewBraider {
                previewPill(braider: preview)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Search + avatar

    private var searchAndAvatarRow: some View {
        HStack(spacing: 10) {
            searchBar
            avatar
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.slate)
            Text("Birmingham")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.ink)
            Spacer()
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(AppTheme.snow)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        .overlay(Capsule().stroke(Color.black.opacity(0.03), lineWidth: 0.5))
    }

    private var avatar: some View {
        Circle()
            .fill(AppTheme.inkGradient)
            .frame(width: 48, height: 48)
            .overlay(
                Text("ME")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: Filters

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        title: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        Haptics.select()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Preview pill

    private func previewPill(braider: Braider) -> some View {
        Button {
            selectedBraider = braider
        } label: {
            HStack(spacing: 12) {
                RemoteImage(url: braider.imageUrl)
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(braider.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.gold)
                        Text(String(format: "%.1f · %d reviews", braider.rating, braider.reviewCount))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                    }
                }

                Spacer()

                Text("View")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.ink)
                    .clipShape(Capsule())
            }
            .padding(10)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            quickStat(icon: "bolt.fill", value: "3", label: "Nearby")
            quickStat(icon: "star.fill", value: "4.8", label: "Avg")
            Button {
                Haptics.medium()
                showBookings = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.system(size: 15, weight: .semibold))
                    Text("Bookings").font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud.opacity(0.9), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func quickStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.ink)
                Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(AppTheme.stone)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
        )
    }

    // MARK: Lifecycle

    private func onAppear() {
        fb.fetchBraiders()
        if !fb.hasAskedForLocation { showLocationSheet = true }
        else { locationService.start() }
    }

    private func onDismiss() {
        if fb.locationPermissionDecision == nil { fb.locationPermissionDecision = "denied" }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(isSelected ? AppTheme.ink : AppTheme.snow)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : AppTheme.hairline.opacity(0.6),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: .black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 10 : 4, y: 2)
        }
        .buttonStyle(SoftPressStyle())
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
                        .fill(AppTheme.accent.opacity(0.25))
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                        .opacity(pulse ? 0 : 0.7)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                }

                Circle()
                    .fill(AppTheme.snow)
                    .frame(width: isSelected ? 68 : 56, height: isSelected ? 68 : 56)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                RemoteImage(url: braider.imageUrl)
                    .frame(width: isSelected ? 58 : 46, height: isSelected ? 58 : 46)
                    .clipShape(Circle())

                Circle()
                    .stroke(isSelected ? AppTheme.accent : AppTheme.snow, lineWidth: isSelected ? 3 : 2)
                    .frame(width: isSelected ? 64 : 52, height: isSelected ? 64 : 52)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(BouncyButtonStyle())
        .onAppear { pulse = true }
    }
}

// MARK: - Location Sheet

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            icon
            Spacer().frame(height: 24)
            copy
            Spacer()
            buttons
            Spacer().frame(height: 24)
        }
        .background(AppTheme.cloud)
    }

    private var icon: some View {
        ZStack {
            Circle().fill(AppTheme.accentSoft).frame(width: 110, height: 110)
            Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 84, height: 84)
            Image(systemName: "location.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(AppTheme.accent)
        }
    }

    private var copy: some View {
        VStack(spacing: 10) {
            Text("Enable Location")
                .font(AppTheme.display(26))
                .foregroundColor(AppTheme.ink)
            Text("Find braiders near you in Birmingham and get accurate travel times.")
                .font(AppTheme.body(15))
                .foregroundColor(AppTheme.slate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .lineSpacing(3)
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Allow Location", systemImage: "location.fill") { onDecision(true) }
            SecondaryButton(title: "Not now") { onDecision(false) }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Location Service

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
    }

    func start() { manager.requestWhenInUseAuthorization() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
    }
}

// MARK: - Bookings Sheet

struct BookingsSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(AppTheme.accentSoft).frame(width: 100, height: 100)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.accent)
                }
                Text("No bookings yet")
                    .font(AppTheme.display(24))
                    .foregroundColor(AppTheme.ink)
                Text("Your upcoming appointments will appear here.")
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.slate)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.cloud)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}