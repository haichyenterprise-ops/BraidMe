import SwiftUI
import MapKit
import CoreLocation
import CoreMotion
import CoreHaptics
import UIKit

// =============================================================================
// MainTabView — "The Spatial Canvas"
//
// A clean, immersive map. Four chrome elements. Braider orbs that morph into
// floating glass capsules via matchedGeometryEffect. Camera flies to selected
// pins with a 28° pitch. Film grain overlay kills the flat vector look.
// Gyro-tilted borders on the top-bar orbs. Layered CoreHaptics on every tap.
// =============================================================================

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var motion = MotionTracker()
    @StateObject private var haptics = HapticEngine()

    // ─── Camera ───
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var currentCity: City = CityCatalog.all[0]
    @State private var mapAppeared = false

    // ─── Selection ───
    @State private var selectedBraider: Braider?
    @State private var expandedBraiderId: String?
    @Namespace private var orbNamespace

    // ─── Sheets ───
    @State private var showLocationSheet = false
    @State private var showProfileSheet = false
    @State private var showCitySearch = false
    @State private var showBookings = false
    @State private var showSaved = false
    @State private var showSettings = false

    // ─── Data ───
    @State private var userInfo: UserProfile?
    @State private var braidersLoading = false

    // ─── Shockwaves ───
    @State private var shockwaves: [Shockwave] = []

    // ─── Gyro tilt enabled (gated by settings) ───
    @AppStorage("braidme.gyroTilt") private var gyroTiltEnabled: Bool = true

    struct Shockwave: Identifiable, Equatable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        let startTime: Date

        static func == (lhs: Shockwave, rhs: Shockwave) -> Bool {
            lhs.id == rhs.id
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Body

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Layer 1: Living map
                    mapCanvas(size: geo.size)

                    // Layer 2: Shockwaves
                    shockwaveLayer

                    // Layer 3: Pins (overlay on map)
                    pinLayer

                    // Layer 4: Film grain over everything
                    NoiseTexture(opacity: 0.035, seed: 937)
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    // Layer 5: Radial vignette
                    vignetteLayer

                    // Layer 6: Top chrome
                    VStack(spacing: 0) {
                        topChrome
                        Spacer()
                    }

                    // Layer 7: Bottom chrome
                    VStack(spacing: 0) {
                        Spacer()
                        bottomChrome
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationDestination(item: $selectedBraider) { braider in
                BraiderProfileView(braider: braider)
            }
            .sheet(isPresented: $showProfileSheet) {
                UserInfoSheet()
            }
            .sheet(isPresented: $showBookings) {
                BookingsListView().environmentObject(session)
            }
            .sheet(isPresented: $showSaved) {
                SavedBraidersView().environmentObject(session)
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(gyroTiltEnabled: $gyroTiltEnabled)
            }
            .sheet(isPresented: $showCitySearch) {
                LocationSearchView(initialCity: currentCity) { newCity in
                    flyTo(city: newCity)
                    Haptic.success()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.modal)
            }
            .onAppear(perform: onAppear)
            .onDisappear { motion.stop() }
            .sheet(isPresented: $showLocationSheet, onDismiss: onLocationDismiss) {
                LocationPermissionSheet { allowed in
                    handleLocationDecision(allowed)
                }
                .presentationDetents([.height(560)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
                .presentationCornerRadius(Radius.modal)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 1: Map Canvas

    private func mapCanvas(size: CGSize) -> some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            // Empty — pins rendered as overlay (see pinLayer) for morphing
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .opacity(mapAppeared ? 1 : 0)
        .scaleEffect(mapAppeared ? 1 : 1.06)
        .animation(.smooth(duration: 1.1).delay(0.05), value: mapAppeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 3: Pins (overlay so they can morph)

    private var pinLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(fb.braiders) { braider in
                    if expandedBraiderId != braider.id {
                        // ── Idle dot ──
                        OrbPin(
                            braider: braider,
                            isExpanded: false,
                            onTap: { handlePinTap(braider) }
                        )
                        .matchedGeometryEffect(
                            id: "orb-\(braider.id)",
                            in: orbNamespace,
                            isSource: expandedBraiderId != braider.id
                        )
                        .position(screenPoint(for: braider.coordinate, in: geo.size))
                        .opacity(mapAppeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: expandedBraiderId)
                    }
                }
            }
            .overlay {
                // Expanded capsule rendered on top
                ForEach(fb.braiders) { braider in
                    if expandedBraiderId == braider.id {
                        OrbCapsule(
                            braider: braider,
                            onTap: {
                                Haptic.press()
                                haptics.play(.tap)
                                selectedBraider = braider
                            },
                            onDismiss: { collapseExpanded() }
                        )
                        .matchedGeometryEffect(
                            id: "orb-\(braider.id)",
                            in: orbNamespace,
                            isSource: expandedBraiderId == braider.id
                        )
                        .position(screenPoint(for: braider.coordinate, in: geo.size))
                        .transition(.identity)
                    }
                }
            }
        }
        .allowsHitTesting(expandedBraiderId == nil ? true : true)
    }

    /// Approximate screen position from coordinate via MapProxy-free math.
    /// We compute using the current region center + span.
    private func screenPoint(for coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let center = currentRegion.center
        let span = currentRegion.span

        let latDelta = coordinate.latitude - center.latitude
        let lonDelta = coordinate.longitude - center.longitude

        let xRatio = (lonDelta / span.longitudeDelta) + 0.5
        let yRatio = 0.5 - (latDelta / span.latitudeDelta)

        let x = size.width * xRatio
        let y = size.height * yRatio

        // Clamp to safe area so off-screen pins don't render wildly
        let clampedX = max(-100, min(size.width + 100, x))
        let clampedY = max(-100, min(size.height + 100, y))

        return CGPoint(x: clampedX, y: clampedY)
    }

    private var currentRegion: MKCoordinateRegion {
        if case .region(let r) = cameraPosition.region.map({ $0 }) ?? nil {
            return r
        }
        // Fallback: use braider bounds or default
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 2: Shockwaves

    private var shockwaveLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(shockwaves) { wave in
                    ShockwaveView(startTime: wave.startTime)
                        .position(screenPoint(for: wave.coordinate, in: geo.size))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 5: Vignette

    private var vignetteLayer: some View {
        ZStack {
            // Radial focus pull
            RadialGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.10)
                ],
                center: .center,
                startRadius: 180,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Top scrim so orbs read cleanly
            LinearGradient(
                colors: [
                    Color.appBackground.opacity(0.75),
                    Color.appBackground.opacity(0.25),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            // Bottom scrim
            LinearGradient(
                colors: [
                    .clear,
                    Color.appBackground.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Top Chrome

    private var topChrome: some View {
        HStack(spacing: Space.sm) {
            settingsOrb
            Spacer(minLength: 0)
            avatarOrb
        }
        .padding(.horizontal, Space.md)
        .padding(.top, safeAreaTop() + Space.xs)
        .opacity(mapAppeared ? 1 : 0)
        .offset(y: mapAppeared ? 0 : -24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.2), value: mapAppeared)
    }

    // ─── Settings Orb ───

    private var settingsOrb: some View {
        Button {
            Haptic.press()
            haptics.play(.select)
            showSettings = true
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 52, height: 52)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .overlay(gyroBorder(size: 52))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appInk)
            }
        }
        .buttonStyle(BMSquirclePressStyle())
    }

    // ─── Avatar Orb ───

    private var avatarOrb: some View {
        Button {
            Haptic.press()
            haptics.play(.select)
            showProfileSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.appInk)
                    .frame(width: 52, height: 52)
                    .overlay(gyroBorder(size: 52))
                    .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)

                if let url = userInfo?.avatarUrl, !url.isEmpty {
                    RemoteImage(url: url)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Text(userInitials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                }
            }
        }
        .buttonStyle(BMSquirclePressStyle())
    }

    // ─── Gyro-reactive gold border ───

    private func gyroBorder(size: CGFloat) -> some View {
        let angle = gyroTiltEnabled ? motion.angle : 0
        return Circle()
            .stroke(
                AngularGradient(
                    colors: [
                        Color.goldLight.opacity(0.9),
                        Color.gold.opacity(0.5),
                        Color.goldDeep.opacity(0.2),
                        Color.gold.opacity(0.5),
                        Color.goldLight.opacity(0.9)
                    ],
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: 1.2
            )
            .frame(width: size - 1, height: size - 1)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.7), value: angle)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Bottom Chrome

    private var bottomChrome: some View {
        HStack(alignment: .bottom) {
            Spacer()

            // City chip — centered
            cityChip

            Spacer()

            // Zoom stack — bottom right
            zoomStack
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, safeAreaBottom() + Space.sm)
        .opacity(mapAppeared ? 1 : 0)
        .offset(y: mapAppeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.3), value: mapAppeared)
    }

    // ─── City Chip ───

    private var cityChip: some View {
        Button {
            Haptic.press()
            haptics.play(.cityTap)
            showCitySearch = true
        } label: {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle()
                        .fill(Color.gold.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: "location.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("EXPLORING")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(Color.appSmoke)
                    Text(currentCity.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }

                Rectangle()
                    .fill(Color.appDivider)
                    .frame(width: 0.5, height: 18)

                Text("\(fb.braiders.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.appInk)
                    .contentTransition(.numericText())

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.appSmoke)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.goldLight.opacity(0.35),
                                        Color.gold.opacity(0.10),
                                        Color.goldDeep.opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 22, y: 10)
            }
        }
        .buttonStyle(BMSquirclePressStyle())
    }

    // ─── Zoom Stack ───

    private var zoomStack: some View {
        VStack(spacing: Space.xs) {
            zoomButton(icon: "plus") { adjustZoom(in: true) }
            zoomButton(icon: "minus") { adjustZoom(in: false) }
        }
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            haptics.play(.tap)
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [
                                    Color.goldLight.opacity(0.35),
                                    Color.goldDeep.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.appInk)
            }
        }
        .buttonStyle(BMIconPressStyle())
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Pin Tap

    private func handlePinTap(_ braider: Braider) {
        Haptic.medium()
        haptics.play(.pinTap)

        // Add shockwave
        let wave = Shockwave(coordinate: braider.coordinate, startTime: Date())
        shockwaves.append(wave)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shockwaves.removeAll { $0.id == wave.id }
        }

        // Fly camera to pin with pitch
        withAnimation(Motion.cameraFly) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: braider.coordinate,
                    distance: 1200,
                    heading: braider.longitude > currentCity.longitude ? 12 : -12,
                    pitch: 28
                )
            )
        }

        // Expand capsule
        withAnimation(Motion.morph) {
            expandedBraiderId = braider.id
        }

        // Haptic: soft + warm resonance
        haptics.play(.pinExpand)
    }

    private func collapseExpanded() {
        Haptic.light()
        haptics.play(.dismiss)
        withAnimation(Motion.collapse) {
            expandedBraiderId = nil
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Zoom Logic

    private func adjustZoom(in closer: Bool) {
        guard let region = cameraPosition.region else { return }
        let factor: CGFloat = closer ? 0.6 : 1.6
        let newSpan = MKCoordinateSpan(
            latitudeDelta: region.span.latitudeDelta * factor,
            longitudeDelta: region.span.longitudeDelta * factor
        )
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        withAnimation(.smooth(duration: 0.4)) {
            cameraPosition = .region(newRegion)
        }
    }

    private func flyTo(city: City) {
        withAnimation(.smooth(duration: 0.9)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: city.coordinate,
                    distance: 5000,
                    heading: 0,
                    pitch: 12
                )
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            currentCity = city
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - User Initials

    private var userInitials: String {
        let name = userInfo?.displayName ?? session.displayName ?? ""
        let parts = name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Lifecycle

    private func onAppear() {
        let uid = session.uid

        // Start gyro tracking
        if gyroTiltEnabled {
            motion.start()
        }

        // Prepare haptic engine
        haptics.prepare()

        Task {
            await MainActor.run { braidersLoading = true }
            if !uid.isEmpty {
                await fb.loadUser(uid: uid)
                await MainActor.run { userInfo = fb.currentUser }
                await fb.loadBookings(uid: uid)
                await fb.loadSavedBraiders(uid: uid)

                if let cityName = fb.currentUser?.city,
                   let stored = CityCatalog.all.first(where: { $0.name == cityName }) {
                    await MainActor.run {
                        currentCity = stored
                        cameraPosition = .camera(
                            MapCamera(
                                centerCoordinate: stored.coordinate,
                                distance: 5500,
                                heading: 0,
                                pitch: 10
                            )
                        )
                    }
                }
            }
            await fb.fetchBraidersFromFirestore()
            await MainActor.run { braidersLoading = false }
        }

        withAnimation { mapAppeared = true }

        if !fb.hasAskedForLocation {
            showLocationSheet = true
        } else if fb.locationPermissionDecision == "allowed" {
            locationService.start()
        }
    }

    private func onLocationDismiss() {
        if fb.locationPermissionDecision == nil {
            fb.locationPermissionDecision = "denied"
        }
    }

    private func handleLocationDecision(_ allowed: Bool) {
        Haptic.press()
        haptics.play(.select)
        fb.locationPermissionDecision = allowed ? "allowed" : "denied"

        if allowed {
            locationService.start()
            if let loc = locationService.lastLocation,
               let closest = CityCatalog.closest(to: loc) {
                withAnimation(.smooth(duration: 0.9)) {
                    currentCity = closest
                    cameraPosition = .camera(
                        MapCamera(
                            centerCoordinate: closest.coordinate,
                            distance: 5000,
                            heading: 0,
                            pitch: 10
                        )
                    )
                }
            }
        }

        let uid = session.uid
        guard !uid.isEmpty else { showLocationSheet = false; return }

        Task {
            try? await fb.updateUser(uid: uid, data: [
                "locationGranted": allowed,
                "city": currentCity.name,
                "region": currentCity.region,
                "latitude": currentCity.latitude,
                "longitude": currentCity.longitude,
                "locationUpdatedAt": Date()
            ])
            await fb.loadUser(uid: uid)
            await MainActor.run {
                userInfo = fb.currentUser
                showLocationSheet = false
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Safe Area

    private func safeAreaTop() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 44
    }

    private func safeAreaBottom() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 34
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - OrbPin (idle 14pt dot + breathing halo)
// ═══════════════════════════════════════════════════════════════════

struct OrbPin: View {
    let braider: Braider
    let isExpanded: Bool
    let onTap: () -> Void

    @State private var breathe = false
    @State private var appear = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer pulse ring (breathing)
                Circle()
                    .stroke(Color.gold.opacity(0.35), lineWidth: 1.2)
                    .frame(width: 32, height: 32)
                    .scaleEffect(breathe ? 1.7 : 1)
                    .opacity(breathe ? 0 : 0.7)

                // Second pulse — offset phase
                Circle()
                    .stroke(Color.gold.opacity(0.2), lineWidth: 1)
                    .frame(width: 32, height: 32)
                    .scaleEffect(breathe ? 1.4 : 1)
                    .opacity(breathe ? 0 : 0.5)

                // Halo glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.gold.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)

                // Core dot
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.goldLight, Color.gold, Color.goldDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Color.gold.opacity(0.55), radius: 8, y: 2)

                // Tiny center highlight
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .offset(x: -2.5, y: -2.5)
            }
            .scaleEffect(appear ? 1 : 0.1)
            .opacity(appear ? 1 : 0)
        }
        .buttonStyle(OrbPinPressStyle())
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appear = true
            }
            withAnimation(
                .easeOut(duration: 2.4)
                .repeatForever(autoreverses: false)
            ) {
                breathe = true
            }
        }
    }
}

struct OrbPinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.25 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - OrbCapsule (expanded floating glass card)
// ═══════════════════════════════════════════════════════════════════

struct OrbCapsule: View {
    let braider: Braider
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    if braider.avatarUrl.isEmpty {
                        Circle()
                            .fill(Color.gold.opacity(0.18))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(braider.initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.gold)
                            )
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    }

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.goldLight, Color.goldDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.8
                        )
                        .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(braider.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gold)
                        }
                    }

                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.gold)
                            Text(braider.ratingText)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.appInk)
                        }

                        Text("·")
                            .foregroundStyle(Color.appSmoke)

                        Text("£\(braider.priceFrom)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.goldDeep)
                    }
                }

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .frame(width: 30, height: 30)
                    .background(Color.appBackground, in: Circle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.goldLight.opacity(0.6),
                                        Color.gold.opacity(0.2),
                                        Color.goldDeep.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
                    .shadow(color: Color.gold.opacity(0.15), radius: 30, y: 4)
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(BMSquirclePressStyle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onDismiss() }
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.05)) {
                appeared = true
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Shockwave
// ═══════════════════════════════════════════════════════════════════

struct ShockwaveView: View {
    let startTime: Date
    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0.9

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gold.opacity(opacity), lineWidth: 2)
                .frame(width: 40 + progress * 160, height: 40 + progress * 160)
                .blur(radius: progress * 6)

            Circle()
                .stroke(Color.goldLight.opacity(opacity * 0.6), lineWidth: 1)
                .frame(width: 20 + progress * 120, height: 20 + progress * 120)
                .blur(radius: progress * 3)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                progress = 1
                opacity = 0
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - MotionTracker (gyro → angle degrees)
// ═══════════════════════════════════════════════════════════════════

final class MotionTracker: ObservableObject {
    @Published var angle: Double = 0

    private let motionManager = CMMotionManager()
    private var isRunning = false

    func start() {
        guard motionManager.isDeviceMotionAvailable, !isRunning else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // Map gravity.x (landscape) and gravity.y (portrait) to a 0-360 angle
            let gx = motion.gravity.x
            let gy = motion.gravity.y
            let radians = atan2(gy, gx)
            let degrees = radians * 180 / .pi
            // Smooth via low-pass
            self?.angle = (self?.angle ?? 0) * 0.85 + degrees * 0.15
        }
        isRunning = true
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - HapticEngine (layered CoreHaptics with fallback)
// ═══════════════════════════════════════════════════════════════════

final class HapticEngine: ObservableObject {
    enum Pattern {
        case select
        case tap
        case pinTap
        case pinExpand
        case dismiss
        case cityTap
    }

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func prepare() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { _ in }
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            engine = nil
        }
    }

    func play(_ pattern: Pattern) {
        guard supportsHaptics, let engine = engine else {
            fallback(pattern)
            return
        }
        do {
            let events = eventsFor(pattern)
            let hapticPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
        } catch {
            fallback(pattern)
        }
    }

    private func eventsFor(_ pattern: Pattern) -> [CHHapticEvent] {
        switch pattern {
        case .select:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.4),
                        .init(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                )
            ]

        case .tap:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.5),
                        .init(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: 0
                )
            ]

        case .pinTap:
            // Sharp tick then soft resonance
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.75),
                        .init(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.3),
                        .init(parameterID: .hapticSharpness, value: 0.15)
                    ],
                    relativeTime: 0.02,
                    duration: 0.12
                )
            ]

        case .pinExpand:
            // Soft rising intensity — feels like something opening
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.4),
                        .init(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: 0,
                    duration: 0.25
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.6),
                        .init(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.24
                )
            ]

        case .dismiss:
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.35),
                        .init(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0
                )
            ]

        case .cityTap:
            // Warm tick + resonance
            return [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.5),
                        .init(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.25),
                        .init(parameterID: .hapticSharpness, value: 0.1)
                    ],
                    relativeTime: 0.04,
                    duration: 0.14
                )
            ]
        }
    }

    private func fallback(_ pattern: Pattern) {
        switch pattern {
        case .select, .dismiss:     Haptic.select()
        case .tap, .cityTap:        Haptic.light()
        case .pinTap, .pinExpand:   Haptic.medium()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Settings Sheet
// ═══════════════════════════════════════════════════════════════════

struct SettingsSheet: View {
    @Binding var gyroTiltEnabled: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.md) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Rectangle()
                                    .fill(Color.gold)
                                    .frame(width: 20, height: 2)
                                Text("PREFERENCES")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(2)
                                    .foregroundStyle(Color.gold)
                            }
                            Text("Settings")
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .tracking(-1)
                                .foregroundStyle(Color.appInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Space.sm)
                        .padding(.bottom, Space.md)

                        // Gyro tilt
                        settingRow(
                            icon: "gyroscope",
                            title: "Gyro-tilted elements",
                            subtitle: "Orbs subtly tilt as you move your device",
                            isOn: $gyroTiltEnabled
                        )
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appInk)
                }
            }
        }
    }

    private func settingRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gold.opacity(isOn.wrappedValue ? 0.18 : 0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Color.gold : Color.appSmoke)
            }
            .animation(Motion.subtle, value: isOn.wrappedValue)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appAsh)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.gold)
                .onChange(of: isOn.wrappedValue) { _, _ in Haptic.select() }
        }
        .padding(Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .dualLayerGlassStroke(cornerRadius: Radius.card, lineWidth: 0.6)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Location Permission Sheet
// ═══════════════════════════════════════════════════════════════════

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    @State private var appeared = false
    @State private var rings: [CGFloat] = [1, 1, 1]
    @State private var opacities: [Double] = [0.6, 0.4, 0.2]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.gold.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.xl)

                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.gold.opacity(opacities[i]), lineWidth: 1.5)
                            .frame(width: 120 + CGFloat(i) * 30, height: 120 + CGFloat(i) * 30)
                            .scaleEffect(rings[i])
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.gold.opacity(0.20), Color.gold.opacity(0.08)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color.gold.opacity(0.5), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(Color.gold)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: Space.xl)

                VStack(spacing: Space.sm) {
                    Text("Find braiders\nnear you")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(-1)
                        .foregroundStyle(Color.appInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)

                    Text("We use your location to surface verified braiders in your city.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appAsh)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Space.xl)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                VStack(spacing: Space.sm) {
                    BMPrimaryButton(title: "Allow Location", icon: "location.fill") {
                        onDecision(true)
                    }
                    BMSecondaryButton(title: "Not now") {
                        onDecision(false)
                    }
                }
                .padding(.horizontal, Space.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

                Spacer().frame(height: Space.lg)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
            animateRings()
        }
    }

    private func animateRings() {
        for i in 0..<3 {
            withAnimation(
                .easeOut(duration: 2.2)
                .repeatForever(autoreverses: false)
                .delay(Double(i) * 0.4)
            ) {
                rings[i] = 1.4
                opacities[i] = 0
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Location Service
// ═══════════════════════════════════════════════════════════════════

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