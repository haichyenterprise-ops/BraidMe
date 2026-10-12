import SwiftUI
import MapKit
import CoreLocation
import CoreMotion
import CoreHaptics
import UIKit

// =============================================================================
// MainTabView — "The Spatial Canvas"
//
// Chrome: account top-right, nearby top-left. No gear, no re-center.
// Zoom: single continuous spring. Expanded state clears on map move.
// Capsule: avatar + stars only, no price.
// Transition: simple expand via GlobeMorphView.
// =============================================================================

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var motion = MotionTracker()
    @StateObject private var haptics = HapticEngine()

    // ─── Camera ───
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
            distance: 5500,
            heading: 0,
            pitch: 12
        )
    )
    @State private var cameraCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
        latitude: 52.4862, longitude: -1.8904
    )
    @State private var cameraDistance: Double = 5500
    @State private var cameraPitch: Double = 12
    @State private var currentCity: City = CityCatalog.all[0]
    @State private var mapAppeared = false

    // ─── Selection ───
    @State private var selectedBraider: Braider?
    @State private var expandedBraiderId: String?
    @State private var previewBraider: Braider?
    @Namespace private var orbNamespace

    // ─── Sheets ───
    @State private var showLocationSheet = false
    @State private var showProfileSheet = false
    @State private var showCitySearch = false

    // ─── Data ───
    @State private var userInfo: UserProfile?
    @State private var braidersLoading = false

    // ─── Shockwaves ───
    @State private var shockwaves: [Shockwave] = []

    // ─── Transition ───
    @State private var transitionActive = false
    @State private var transitionBraider: Braider?

    // ─── Gyro ───
    @AppStorage("braidme.gyroTilt") private var gyroTiltEnabled: Bool = true

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Shockwave model

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
                    mapCanvas(size: geo.size)

                    NoiseTexture(opacity: 0.035, seed: 937)
                        .blendMode(.overlay)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    vignetteLayer

                    // Top chrome
                    VStack(spacing: 0) {
                        topChrome
                            .padding(.horizontal, Space.md)
                            .padding(.top, safeAreaTop() + Space.xs)
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    .opacity(transitionActive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: transitionActive)

                    // Bottom chrome
                    VStack(spacing: 0) {
                        Spacer()
                        bottomChrome
                    }
                    .opacity(transitionActive ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: transitionActive)

                    // Simple transition overlay
                    if transitionActive, let braider = transitionBraider {
                        GlobeMorphView(braider: braider) {
                            finishTransition()
                        }
                        .transition(.opacity)
                        .zIndex(1000)
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
            .onChange(of: cameraPosition) { _, _ in
                // When camera moves via gesture, clear expanded state
                if expandedBraiderId != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        expandedBraiderId = nil
                        previewBraider = nil
                    }
                }
            }
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
    // MARK: - Map

    private func mapCanvas(size: CGSize) -> some View {
        Map(position: $cameraPosition, interactionModes: transitionActive ? [] : [.pan, .zoom]) {
            ForEach(fb.braiders) { braider in
                Annotation(
                    "",
                    coordinate: braider.coordinate,
                    anchor: .center
                ) {
                    Group {
                        if expandedBraiderId == braider.id {
                            OrbCapsule(
                                braider: braider,
                                onTap: { startTransition(braider) },
                                onDismiss: { collapseExpanded() }
                            )
                            .matchedGeometryEffect(
                                id: "orb-\(braider.id)",
                                in: orbNamespace,
                                isSource: true
                            )
                        } else {
                            StarOrbPin(
                                braider: braider,
                                onTap: { handlePinTap(braider) }
                            )
                            .matchedGeometryEffect(
                                id: "orb-\(braider.id)",
                                in: orbNamespace,
                                isSource: false
                            )
                            .opacity(mapAppeared ? 1 : 0)
                        }
                    }
                }
            }

            ForEach(shockwaves) { wave in
                Annotation(
                    "",
                    coordinate: wave.coordinate,
                    anchor: .center
                ) {
                    ShockwaveView(startTime: wave.startTime)
                        .allowsHitTesting(false)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .ignoresSafeArea()
        .opacity(mapAppeared ? 1 : 0)
        .scaleEffect(mapAppeared ? 1 : 1.06)
        .animation(.smooth(duration: 1.1).delay(0.05), value: mapAppeared)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Vignette

    private var vignetteLayer: some View {
        ZStack {
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.10)],
                center: .center,
                startRadius: 180,
                endRadius: 520
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

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

            LinearGradient(
                colors: [.clear, Color.appBackground.opacity(0.35)],
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
    // MARK: - Top chrome — nearby top-left, account top-right

    private var topChrome: some View {
        HStack(spacing: Space.sm) {
            nearbyChip
            Spacer(minLength: 0)
            accountOrb
        }
        .opacity(mapAppeared ? 1 : 0)
        .offset(y: mapAppeared ? 0 : -24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.2), value: mapAppeared)
    }

    private var nearbyChip: some View {
        HStack(spacing: 8) {
            // Live indicator
            ZStack {
                Circle()
                    .fill(Color.appSignal.opacity(0.2))
                    .frame(width: 10, height: 10)
                Circle()
                    .fill(Color.appSignal)
                    .frame(width: 6, height: 6)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("NEARBY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.appSmoke)
                Text("\(fb.braiders.count) braider\(fb.braiders.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.glassTintStrong, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .overlay(
            Capsule().stroke(
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
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
    }

    private var accountOrb: some View {
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
    // MARK: - Bottom chrome

    private var bottomChrome: some View {
        HStack(alignment: .bottom) {
            Spacer()
            cityChip
            Spacer()
            zoomStack
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, safeAreaBottom() + Space.sm)
        .opacity(mapAppeared ? 1 : 0)
        .offset(y: mapAppeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.3), value: mapAppeared)
    }

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

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.appSmoke)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                    .fill(Color.glassTint)
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

    private var zoomStack: some View {
        VStack(spacing: Space.xs) {
            zoomButton(icon: "plus") { adjustZoom(in: true) }
            zoomButton(icon: "minus") { adjustZoom(in: false) }
        }
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.rigid()
            haptics.play(.zoom)
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.glassTintStrong)
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
    // MARK: - Pin tap — single spring, rotating + zooming together

    private func handlePinTap(_ braider: Braider) {
        Haptic.medium()
        haptics.play(.pinTap)

        // Shockwave
        let wave = Shockwave(coordinate: braider.coordinate, startTime: Date())
        shockwaves.append(wave)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [wave] in
            shockwaves.removeAll { $0.id == wave.id }
        }

        cameraCenter = braider.coordinate
        cameraDistance = 1200
        cameraPitch = 26

        let targetHeading: Double = braider.longitude > currentCity.longitude ? 10 : -10

        // Single continuous spring — rotation and zoom together, one pace
        withAnimation(.spring(response: 0.95, dampingFraction: 0.78)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: braider.coordinate,
                    distance: 1200,
                    heading: targetHeading,
                    pitch: 26
                )
            )
        }

        withAnimation(Motion.morph) {
            expandedBraiderId = braider.id
            previewBraider = braider
        }

        haptics.play(.pinExpand)
    }

    private func collapseExpanded() {
        Haptic.light()
        haptics.play(.dismiss)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            expandedBraiderId = nil
            previewBraider = nil
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Simple transition

    private func startTransition(_ braider: Braider) {
        guard !transitionActive else { return }

        Haptic.heavy()
        haptics.play(.pinExpand)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            expandedBraiderId = nil
        }

        transitionBraider = braider

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.20)) {
                transitionActive = true
            }
        }
    }

    private func finishTransition() {
        guard let braider = transitionBraider else {
            transitionActive = false
            return
        }

        selectedBraider = braider

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.30)) {
                transitionActive = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            transitionBraider = nil
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Zoom

    private func adjustZoom(in closer: Bool) {
        let factor: Double = closer ? 0.55 : 1.8
        let newDistance = cameraDistance * factor
        let clamped = max(200, min(newDistance, 80000))
        cameraDistance = clamped

        let newPitch: Double = {
            let target = cameraPitch + (closer ? 4 : -4)
            return max(0, min(target, 45))
        }()
        cameraPitch = newPitch

        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: cameraCenter,
                    distance: clamped,
                    heading: 0,
                    pitch: newPitch
                )
            )
        }
    }

    private func flyTo(city: City) {
        cameraCenter = city.coordinate
        cameraDistance = 5000
        cameraPitch = 12

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
    // MARK: - User initials

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

        if gyroTiltEnabled {
            motion.start()
        }
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
                        cameraCenter = stored.coordinate
                        cameraDistance = 5500
                        cameraPitch = 10
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
                cameraCenter = closest.coordinate
                cameraDistance = 5000
                cameraPitch = 10
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
// MARK: - StarOrbPin
// ═══════════════════════════════════════════════════════════════════

struct StarOrbPin: View {
    let braider: Braider
    let onTap: () -> Void

    @State private var breathe = false
    @State private var appear = false

    private var ratingTier: (color: Color, brightness: Double) {
        let r = braider.rating
        if r >= 4.8 { return (Color(hex: "#34D399"), 0.55) }
        if r >= 4.5 { return (Color.goldLight, 0.5) }
        if r >= 4.0 { return (Color.gold, 0.4) }
        return (Color(hex: "#F59E0B"), 0.3)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.gold)

                    Text(braider.ratingText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(Color.appInk)
                        .overlay(
                            Capsule().stroke(
                                LinearGradient(
                                    colors: [
                                        ratingTier.color,
                                        ratingTier.color.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                        )
                        .shadow(color: ratingTier.color.opacity(0.5), radius: 6, y: 2)
                )
                .scaleEffect(appear ? 1 : 0.4)
                .opacity(appear ? 1 : 0)

                ZStack {
                    Circle()
                        .stroke(ratingTier.color.opacity(ratingTier.brightness), lineWidth: 1.4)
                        .frame(width: 32, height: 32)
                        .scaleEffect(breathe ? 1.8 : 1)
                        .opacity(breathe ? 0 : 0.85)

                    Circle()
                        .stroke(ratingTier.color.opacity(ratingTier.brightness * 0.5), lineWidth: 1)
                        .frame(width: 32, height: 32)
                        .scaleEffect(breathe ? 1.5 : 1)
                        .opacity(breathe ? 0 : 0.55)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ratingTier.color.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 22
                            )
                        )
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.goldLight, Color.gold, Color.goldDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: ratingTier.color.opacity(0.7), radius: 10, y: 3)

                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 4.5, height: 4.5)
                        .offset(x: -3, y: -3)
                }
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
            .scaleEffect(configuration.isPressed ? 1.22 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - OrbCapsule — avatar + stars only, no price
// ═══════════════════════════════════════════════════════════════════

struct OrbCapsule: View {
    let braider: Braider
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
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

                VStack(alignment: .leading, spacing: 4) {
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

                    // Stars only — no price
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: Double(i) < braider.rating.rounded() ? "star.fill" : "star")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.gold)
                        }
                        Text(braider.ratingText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.appAsh)
                            .padding(.leading, 2)
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
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                        .fill(Color.glassTintStrong)
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

                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.35), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: shimmerOffset * geo.size.width * 1.5)
                        .blendMode(.overlay)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
                }
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
            withAnimation(
                .linear(duration: 2.4)
                .repeatForever(autoreverses: false)
                .delay(0.8)
            ) {
                shimmerOffset = 1.2
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
// MARK: - Motion Tracker
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
            let gx = motion.gravity.x
            let gy = motion.gravity.y
            let radians = atan2(gy, gx)
            let degrees = radians * 180 / .pi
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
// MARK: - Haptic Engine
// ═══════════════════════════════════════════════════════════════════

final class HapticEngine: ObservableObject {
    enum Pattern {
        case select
        case tap
        case pinTap
        case pinExpand
        case dismiss
        case cityTap
        case zoom
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
            return [CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.4),
                .init(parameterID: .hapticSharpness, value: 0.5)
            ], relativeTime: 0)]
        case .tap:
            return [CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.5),
                .init(parameterID: .hapticSharpness, value: 0.7)
            ], relativeTime: 0)]
        case .pinTap:
            return [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.75),
                    .init(parameterID: .hapticSharpness, value: 0.9)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.3),
                    .init(parameterID: .hapticSharpness, value: 0.15)
                ], relativeTime: 0.02, duration: 0.12)
            ]
        case .pinExpand:
            return [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.4),
                    .init(parameterID: .hapticSharpness, value: 0.25)
                ], relativeTime: 0, duration: 0.25),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.6),
                    .init(parameterID: .hapticSharpness, value: 0.4)
                ], relativeTime: 0.24)
            ]
        case .dismiss:
            return [CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.35),
                .init(parameterID: .hapticSharpness, value: 0.2)
            ], relativeTime: 0)]
        case .cityTap:
            return [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.5),
                    .init(parameterID: .hapticSharpness, value: 0.4)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.25),
                    .init(parameterID: .hapticSharpness, value: 0.1)
                ], relativeTime: 0.04, duration: 0.14)
            ]
        case .zoom:
            return [CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: 0.55),
                .init(parameterID: .hapticSharpness, value: 0.85)
            ], relativeTime: 0)]
        }
    }

    private func fallback(_ pattern: Pattern) {
        switch pattern {
        case .select, .dismiss:     Haptic.select()
        case .tap, .cityTap:        Haptic.light()
        case .pinTap, .pinExpand:   Haptic.medium()
        case .zoom:                 Haptic.rigid()
        }
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
                        .font(.system(size: 34, weight: .bold, design: .serif))
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