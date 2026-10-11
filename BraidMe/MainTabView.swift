import SwiftUI
import MapKit
import CoreLocation

struct MainTabView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showLocationPopup = false
    @State private var locationManager = CLLocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904), // Birmingham
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedBraider: Braider?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Map
                Map(coordinateRegion: $region, annotationItems: firebaseManager.braiders) { braider in
                    MapAnnotation(coordinate: braider.coordinate) {
                        Button(action: {
                            selectedBraider = braider
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 50, height: 50)
                                    .shadow(radius: 5)
                                
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundColor(AppTheme.primary)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            }
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 3))
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Top 3 Braiders Overlay
                VStack {
                    Text("Top Braiders Near You")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(firebaseManager.braiders.prefix(3)) { braider in
                                Button(action: { selectedBraider = braider }) {
                                    VStack {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .foregroundColor(AppTheme.primary)
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                        Text(braider.name)
                                            .font(.caption.bold())
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text("⭐️ \(String(format: "%.1f", braider.rating))")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(15)
                                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                // Bottom Button (Bookings)
                Button(action: {
                    // Show bookings modal
                }) {
                    Text("My Bookings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.primaryGradient)
                        .cornerRadius(15)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
            .onAppear {
                firebaseManager.fetchBraiders()
                locationManager.requestWhenInUseAuthorization()
                showLocationPopup = true
            }
            .alert("Allow Location Access", isPresented: $showLocationPopup) {
                Button("Allow") {
                    locationManager.startUpdatingLocation()
                }
                Button("Don't Allow", role: .cancel) {}
            } message: {
                Text("BraidMe needs your location to find braiders near you.")
            }
            .navigationDestination(item: $selectedBraider) { braider in
                BraiderProfileView(braider: braider)
            }
        }
    }
}