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
    @State private var showLocationSheet = false
    @State private var showBookings = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Map
                Map(coordinateRegion: $region,
                    annotationItems: fb.braiders) { braider in
                    MapAnnotation(coordinate: braider.coordinate) {
                        BraiderPin(braider: braider) {
                            selectedBraider = braider
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Top card rail
                VStack(spacing: 0) {
                    topHeader
                    topBraidersRail
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .navigationDestination(item: $selectedBraider) { braider in
                BraiderProfileView(braider: braider)
            }
            .sheet(isPresented: $showBookings) {
                BookingsSheet()
            }
            .onAppear {
                fb.fetchBraiders()
                if !fb.hasAskedForLocation {
                    showLocationSheet = true
                } else {
                    locationService.start()
                }
            }
            .sheet(isPresented: $showLocationSheet, onDismiss: {
                // Persist the decision
                if fb.locationPermissionDecision == nil {
                    fb.locationPermissionDecision = "denied"
                }
            }) {
                LocationPermissionSheet { allowed in
                    fb.locationPermissionDecision = allowed ? "allowed" : "denied"
                    if allowed { locationService.start() }
                    showLocationSheet = false
                }
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
            }
        }
    }
    
    // MARK: Header
    private var topHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Birmingham")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.slate)
                Text("Find your braider")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.ink)
            }
            Spacer()
            Circle()
                .fill(AppTheme.snow)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.ink)
                )
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0.95), AppTheme.cloud.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
    
    // MARK: Top braiders rail
    private var topBraidersRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top 3 near you")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Spacer()
                Text("See all")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(fb.braiders.prefix(3).enumerated()), id: \.element.id) { idx, braider in
                        BraiderCard(braider: braider, rank: idx + 1) {
                            selectedBraider = braider
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: Bottom bar
    private var bottomBar: some View {
        Button(action: { showBookings = true }) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                Text("My Bookings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Pin
struct BraiderPin: View {
    let braider: Braider
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(AppTheme.snow)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                RemoteImage(url: braider.imageUrl)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                Circle()
                    .stroke(AppTheme.accent, lineWidth: 2)
                    .frame(width: 52, height: 52)
            }
        }
        .buttonStyle(SoftPressStyle())
    }
}

// MARK: - Braider Card
struct BraiderCard: View {
    let braider: Braider
    let rank: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    RemoteImage(url: braider.imageUrl)
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    Text("#\(rank)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.ink.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(braider.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accent)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                    }
                }
            }
            .padding(10)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
        .buttonStyle(SoftPressStyle())
    }
}

// MARK: - Location sheet
struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule().frame(width: 40, height: 4)
                .foregroundColor(AppTheme.hairline)
                .padding(.top, 8)
            
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 96, height: 96)
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accent)
            }
            
            VStack(spacing: 8) {
                Text("Enable Location")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.ink)
                Text("Find braiders near you in Birmingham and get accurate travel times.")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer().frame(height: 8)
            
            VStack(spacing: 10) {
                PrimaryButton(title: "Allow") { onDecision(true) }
                SecondaryButton(title: "Not now") { onDecision(false) }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(AppTheme.cloud)
    }
}

// MARK: - Location service
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

// MARK: - Bookings placeholder
struct BookingsSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.slate)
                Text("No bookings yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text("Your upcoming appointments will appear here.")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.slate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.cloud)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}