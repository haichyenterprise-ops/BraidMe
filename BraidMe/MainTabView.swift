import SwiftUI
import MapKit
import CoreLocation

// =============================================================================
// MainTabView — Immersive Map Canvas
//
// A living, breathing map experience. The map breathes behind a floating
// search orb. Braider pins form a soft constellation. The bottom sheet morphs
// fluidly between three states: orb → list preview → full discovery panel.
// =============================================================================

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var locationService = LocationService()

    // Map state
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var currentCity: City = CityCatalog.all[0]
    @State private var mapAppeared = false

    // Selection
    @State private var selectedBraider: Braider?
    @State private var previewBraider: Braider?
    @State private var highlightedBraiderId: String?

    // Sheets
    @State private var showLocationSheet = false
    @State private var showProfileSheet = false
    @State private var showCitySearch = false
    @State private var showBookings = false
    @State private var showSaved = false

    // Sheet morphing
    @State private var sheetState: SheetState = .peek
    @GestureState private var dragOffset: CGFloat = 0
    @State private var sheetProgress: CGFloat = 0

    // Data
    @State private var userInfo: UserProfile?
    @State private var braidersLoading = false

    enum SheetState: CaseIterable {
        case peek, list, explore

        var heightRatio: CGFloat {
            switch self {
            case .peek: return 0.20
            case .list: return 0.52
            case .explore: return 0.94
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // ─── LAYER 1: Living map ───
                    mapCanvas(size: geo.size)

                    // ─── LAYER 2: Floating chrome (top) ───
                    topOrbLayer(size: geo.size)

                    // ─── LAYER 3: Morphing bottom sheet ───
                    morphingSheet(geo: geo)

                    // ─── LAYER 4: Ambient vignette ───
                    ambientOverlay
                        .allowsHitTesting(false)
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
            .sheet(isPresented: $showCitySearch) {
                LocationSearchView(initialCity: currentCity) { newCity in
                    withAnimation(.smooth(duration: 0.8)) {
                        currentCity = newCity
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: newCity.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                            )
                        )
                    }
                    Haptic.success()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(Radius.modal)
            }
            .onAppear(perform: onAppear)
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
    // MARK: - Layer 1: Living Map Canvas
    // ═══════════════════════════════════════════════════════════════

    private func mapCanvas(size: CGSize) -> some View {
        ZStack {
            // Base map
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                ForEach(fb.braiders) { braider in
                    Annotation("", coordinate: braider.coordinate, anchor: .center) {
                        ConstellationPin(
                            braider: braider,
                            isHighlighted: highlightedBraiderId == braider.id,
                            isPreviewed: previewBraider?.id == braider.id,
                            scale: mapScale(for: size)
                        ) {
                            selectBraider(braider)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()

            // Radial focus vignette — pulls focus to braider region
            RadialGradient(
                colors: [
                    .clear,
                    Color.appBackground.opacity(0.06)
                ],
                center: .center,
                startRadius: size.width * 0.3,
                endRadius: size.width * 0.9
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Top scrim
            LinearGradient(
                colors: [
                    Color.appBackground.opacity(0.85),
                    Color.appBackground.opacity(0.4),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .opacity(mapAppeared ? 1 : 0)
        .scaleEffect(mapAppeared ? 1 : 1.08)
        .animation(.smooth(duration: 1.2).delay(0.05), value: mapAppeared)
    }

    /// Slight scale adjustment — pins look larger when zoomed out
    private func mapScale(for size: CGSize) -> CGFloat {
        1.0
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 2: Top Orb (Search)
    // ═══════════════════════════════════════════════════════════════

    private func topOrbLayer(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.sm) {
                searchOrb
                Spacer(minLength: 0)
                actionOrbs
            }
            .padding(.horizontal, Space.md)
            .padding(.top, safeAreaTop() + Space.xs)
            Spacer()
        }
        .opacity(mapAppeared ? 1 : 0)
        .offset(y: mapAppeared ? 0 : -30)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: mapAppeared)
    }

    private var searchOrb: some View {
        Button {
            Haptic.press()
            showCitySearch = true
        } label: {
            HStack(spacing: Space.sm) {
                // Animated location beacon
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .scaleEffect(beaconPulse ? 1.4 : 1)
                        .opacity(beaconPulse ? 0 : 0.8)

                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 32, height: 32)

                    Image(systemName: "location.fill")
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("EXPLORING")
                        .font(.bmUI(9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.appSmoke)
                    Text(currentCity.name)
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }

                if fb.braiders.count > 0 {
                    Text("\(fb.braiders.count)")
                        .font(.bmMono(11, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 6)
                        .background(Color.appInk, in: Capsule())
                        .contentTransition(.numericText())
                }

                Image(systemName: "chevron.down")
                    .font(.bmUI(10, weight: .bold))
                    .foregroundStyle(Color.appSmoke)
                    .rotationEffect(.degrees(showCitySearch ? 180 : 0))
                    .animation(.smooth(duration: 0.4), value: showCitySearch)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay(
                        Capsule().stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                    )
                    .shadow(color: Color.appInk.opacity(0.12), radius: 24, y: 10)
            }
        }
        .buttonStyle(OrbPressStyle())
        .onAppear { beaconPulse = true }
    }

    @State private var beaconPulse = false

    private var actionOrbs: some View {
        HStack(spacing: Space.xs) {
            // Saved orb
            Button {
                Haptic.press()
                showSaved = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    orbIcon(systemName: "heart.fill", filled: !fb.savedBraiderIds.isEmpty)

                    if !fb.savedBraiderIds.isEmpty {
                        Circle()
                            .fill(Color.appAlert)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.appSurface, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(OrbPressStyle())

            // Profile orb
            Button {
                Haptic.press()
                showProfileSheet = true
            } label: {
                profileOrb
            }
            .buttonStyle(OrbPressStyle())
        }
    }

    private func orbIcon(systemName: String, filled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                )
                .shadow(color: Color.appInk.opacity(0.12), radius: 20, y: 8)

            Image(systemName: systemName)
                .font(.bmUI(16, weight: .semibold))
                .foregroundStyle(filled ? Color.appAlert : Color.appInk)
        }
    }

    private var profileOrb: some View {
        ZStack {
            Circle()
                .fill(Color.appInk)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color.appAccentSoft.opacity(0.6), Color.appAccent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                )
                .shadow(color: Color.appInk.opacity(0.25), radius: 20, y: 8)

            if let avatarUrl = userInfo?.avatarUrl, !avatarUrl.isEmpty {
                RemoteImage(url: avatarUrl)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Text(userInitials)
                    .font(.bmUI(15, weight: .bold))
                    .foregroundStyle(Color.appInkInverse)
            }
        }
    }

    private var userInitials: String {
        let name = userInfo?.displayName ?? session.displayName ?? ""
        let parts = name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 3: Morphing Sheet
    // ═══════════════════════════════════════════════════════════════

    private func morphingSheet(geo: GeometryProxy) -> some View {
        let baseHeight = geo.size.height * sheetState.heightRatio
        let maxHeight = geo.size.height * SheetState.explore.heightRatio
        let minHeight = geo.size.height * SheetState.peek.heightRatio
        let currentHeight = min(max(baseHeight - dragOffset, minHeight), maxHeight)

        return VStack(spacing: 0) {
            sheetHandle
                .padding(.top, 10)
                .padding(.bottom, 6)

            Group {
                switch sheetState {
                case .peek: peekContent
                case .list: listContent
                case .explore: exploreContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: currentHeight)
        .background {
            ZStack {
                // Base surface
                UnevenRoundedRectangle(
                    topLeadingRadius: 36,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 36,
                    style: .continuous
                )
                .fill(.regularMaterial)

                // Fine gradient overlay
                UnevenRoundedRectangle(
                    topLeadingRadius: 36,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 36,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appSurface.opacity(0.4),
                            Color.appSurface.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Top highlight edge
                UnevenRoundedRectangle(
                    topLeadingRadius: 36,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 36,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            }
            .shadow(color: Color.appInk.opacity(0.18), radius: 40, y: -12)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 36,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 36,
                style: .continuous
            )
        )
        .gesture(sheetDragGesture(geo: geo))
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.82), value: sheetState)
        .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.82), value: dragOffset)
    }

    private var sheetHandle: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color.appSmoke.opacity(0.6), Color.appSmoke.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 44, height: 5)
    }

    private func sheetDragGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height
                let translation = value.translation.height

                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.82)) {
                    if translation < -50 || velocity < -300 {
                        advanceSheet()
                    } else if translation > 50 || velocity > 300 {
                        retreatSheet()
                    }
                }
            }
    }

    private func advanceSheet() {
        Haptic.medium()
        switch sheetState {
        case .peek: sheetState = .list
        case .list: sheetState = .explore
        case .explore: break
        }
    }

    private func retreatSheet() {
        Haptic.medium()
        switch sheetState {
        case .peek: break
        case .list: sheetState = .peek
        case .explore: sheetState = .list
        }
    }

    // ─── Peek Content ───

    private var peekContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    if braidersLoading {
                        BMSkeleton(height: 22, cornerRadius: 8).frame(width: 140)
                    } else {
                        Text("Nearby")
                            .font(.bmUI(10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.appAccent)
                        Text("\(fb.braiders.count) braider\(fb.braiders.count == 1 ? "" : "s")")
                            .font(.bmDisplay(26, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                if !fb.braiders.isEmpty {
                    Button {
                        Haptic.press()
                        advanceSheet()
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.bmUI(13, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.bmUI(10, weight: .bold))
                        }
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 8)
                        .background(Color.appBackground, in: Capsule())
                    }
                    .buttonStyle(OrbPressStyle())
                }
            }

            if braidersLoading {
                loadingPeek
            } else if fb.braiders.isEmpty {
                emptyPeek
            } else {
                peekCarousel
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
    }

    private var loadingPeek: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: Space.sm) {
                        BMSkeleton(height: 44, cornerRadius: 22).frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            BMSkeleton(height: 12, cornerRadius: 4).frame(width: 80)
                            BMSkeleton(height: 9, cornerRadius: 4).frame(width: 55)
                        }
                    }
                    .padding(Space.sm)
                    .frame(width: 175, alignment: .leading)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, -Space.lg)
    }

    private var emptyPeek: some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle().fill(Color.appAccentTint).frame(width: 40, height: 40)
                Image(systemName: "mappin.slash")
                    .font(.bmUI(15, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("No braiders here")
                    .font(.bmUI(13, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Try a different city")
                    .font(.bmUI(11))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(Space.sm)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
    }

    private var peekCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(fb.braiders.prefix(8)) { braider in
                    PeekCard(braider: braider) {
                        selectBraider(braider)
                    }
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, -Space.lg)
    }

    // ─── List Content ───

    private var listContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sheetSectionHeader
                .padding(.horizontal, Space.lg)

            if braidersLoading {
                listLoadingView
            } else if fb.braiders.isEmpty {
                emptyExploreView
            } else {
                listScrollView
            }
        }
    }

    private var sheetSectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DISCOVER")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAccent)
                Text("Top picks nearby")
                    .font(.bmDisplay(26, weight: .semibold))
                    .foregroundStyle(Color.appInk)
            }
            Spacer()
            Button {
                Haptic.press()
                withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.82)) {
                    sheetState = (sheetState == .explore) ? .list : .explore
                }
            } label: {
                Image(systemName: sheetState == .explore ? "chevron.down" : "chevron.up")
                    .font(.bmUI(13, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .frame(width: 36, height: 36)
                    .background(Color.appBackground, in: Circle())
            }
            .buttonStyle(OrbPressStyle())
        }
    }

    private var listLoadingView: some View {
        VStack(spacing: Space.md) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: Space.sm) {
                    BMSkeleton(height: 60, cornerRadius: 30).frame(width: 60)
                    VStack(alignment: .leading, spacing: 8) {
                        BMSkeleton(height: 14, cornerRadius: 4).frame(width: 130)
                        BMSkeleton(height: 10, cornerRadius: 4).frame(width: 100)
                        BMSkeleton(height: 10, cornerRadius: 4).frame(width: 70)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
    }

    private var emptyExploreView: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                Circle().fill(Color.appAccentTint).frame(width: 64, height: 64)
                Image(systemName: "mappin.slash")
                    .font(.bmUI(24, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text("No braiders here yet")
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("Try another city from the search orb.")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var listScrollView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(fb.braiders.enumerated()), id: \.element.id) { index, braider in
                    DiscoveryRow(
                        braider: braider,
                        isHighlighted: highlightedBraiderId == braider.id,
                        onTap: { selectBraider(braider) }
                    )
                    .opacity(mapAppeared ? 1 : 0)
                    .offset(y: mapAppeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.05),
                        value: mapAppeared
                    )

                    if index < fb.braiders.count - 1 {
                        Rectangle()
                            .fill(Color.appDivider)
                            .frame(height: 0.5)
                            .padding(.leading, 92)
                    }
                }
                Color.clear.frame(height: 120)
            }
            .padding(.horizontal, Space.lg)
        }
    }

    // ─── Explore Content ───

    private var exploreContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sheetSectionHeader
                .padding(.horizontal, Space.lg)

            if fb.braiders.isEmpty {
                emptyExploreView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Space.md) {
                        ForEach(Array(fb.braiders.enumerated()), id: \.element.id) { index, braider in
                            ExploreCard(braider: braider) {
                                selectBraider(braider)
                            }
                            .opacity(mapAppeared ? 1 : 0)
                            .offset(y: mapAppeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.04),
                                value: mapAppeared
                            )
                        }
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Layer 4: Ambient Overlay
    // ═══════════════════════════════════════════════════════════════

    private var ambientOverlay: some View {
        // Delicate noise to give the map a tactile quality
        NoiseTexture(opacity: 0.02)
            .ignoresSafeArea()
            .blendMode(.overlay)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Actions
    // ═══════════════════════════════════════════════════════════════

    private func selectBraider(_ braider: Braider) {
        Haptic.select()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            previewBraider = braider
            highlightedBraiderId = braider.id
            if sheetState == .explore { sheetState = .list }
        }
        // Small delay so the highlight animates, then navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedBraider = braider
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Lifecycle
    // ═══════════════════════════════════════════════════════════════

    private func onAppear() {
        let uid = session.uid

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
                        cameraPosition = .region(
                            MKCoordinateRegion(
                                center: stored.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
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
        fb.locationPermissionDecision = allowed ? "allowed" : "denied"

        if allowed {
            locationService.start()
            if let loc = locationService.lastLocation,
               let closest = CityCatalog.closest(to: loc) {
                withAnimation(.smooth(duration: 0.8)) {
                    currentCity = closest
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: closest.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
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
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Constellation Pin
// ═══════════════════════════════════════════════════════════════════

struct ConstellationPin: View {
    let braider: Braider
    let isHighlighted: Bool
    let isPreviewed: Bool
    let scale: CGFloat
    let onTap: () -> Void

    @State private var breathe = false
    @State private var haloRotation: Double = 0

    private var isActive: Bool { isHighlighted || isPreviewed }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer halo — only shown when active
                if isActive {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.appAccent.opacity(0),
                                    Color.appAccent.opacity(0.9),
                                    Color.appAccent.opacity(0),
                                    Color.appAccentSoft.opacity(0.6),
                                    Color.appAccent.opacity(0)
                                ],
                                center: .center,
                                angle: .degrees(haloRotation)
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 88, height: 88)
                        .transition(.scale.combined(with: .opacity))
                }

                // Breathing pulse
                if isActive {
                    Circle()
                        .fill(Color.appAccent.opacity(0.12))
                        .frame(width: 78, height: 78)
                        .scaleEffect(breathe ? 1.15 : 1)
                        .opacity(breathe ? 0.4 : 0.9)
                }

                // Platform shadow
                Circle()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: isActive ? 62 : 46, height: 12)
                    .blur(radius: 6)
                    .offset(y: 28)

                // Main pin container
                ZStack {
                    // Backdrop
                    Circle()
                        .fill(Color.appSurface)
                        .frame(width: isActive ? 68 : 50, height: isActive ? 68 : 50)
                        .shadow(color: Color.black.opacity(0.22), radius: 14, y: 6)

                    // Image
                    if braider.avatarUrl.isEmpty {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccentTint, Color.appAccent.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: isActive ? 60 : 42, height: isActive ? 60 : 42)
                            .overlay(
                                Text(braider.initials)
                                    .font(.bmUI(isActive ? 20 : 14, weight: .bold))
                                    .foregroundStyle(Color.appAccent)
                            )
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: isActive ? 60 : 42, height: isActive ? 60 : 42)
                            .clipShape(Circle())
                    }

                    // Ring
                    Circle()
                        .stroke(
                            isActive ? Color.appAccent : Color.appSurface,
                            lineWidth: isActive ? 3 : 2.5
                        )
                        .frame(width: isActive ? 66 : 48, height: isActive ? 66 : 48)
                }
                .scaleEffect(isActive ? 1.0 : 1.0)

                // Rating pill — floats above
                if isActive {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8))
                            .foregroundStyle(Color.appAccent)
                        Text(braider.ratingText)
                            .font(.bmMono(10, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appInk, in: Capsule())
                    .overlay(Capsule().stroke(Color.appAccent.opacity(0.6), lineWidth: 1))
                    .offset(y: -48)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PinTapStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isActive)
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    haloRotation = 360
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    haloRotation = 360
                }
            } else {
                breathe = false
                haloRotation = 0
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Peek Card (carousel)
// ═══════════════════════════════════════════════════════════════════

struct PeekCard: View {
    let braider: Braider
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                // Mini pin visual
                ZStack {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 44, height: 44)
                    if braider.avatarUrl.isEmpty {
                        Text(braider.initials)
                            .font(.bmUI(14, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    }
                    Circle()
                        .stroke(Color.appAccent.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(braider.name)
                            .font(.bmUI(13, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.bmUI(9))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8))
                            .foregroundStyle(Color.appAccent)
                        Text(braider.ratingText)
                            .font(.bmMono(10, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("·").foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.bmMono(10, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.sm)
            .frame(width: 185, alignment: .leading)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(OrbPressStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Discovery Row (list)
// ═══════════════════════════════════════════════════════════════════

struct DiscoveryRow: View {
    let braider: Braider
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                // Avatar with subtle ring
                ZStack {
                    if braider.verified {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccentSoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 66, height: 66)
                    }
                    if braider.avatarUrl.isEmpty {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccentTint, Color.appAccent.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(braider.initials)
                                    .font(.bmUI(20, weight: .bold))
                                    .foregroundStyle(Color.appAccent)
                            )
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: Space.xs) {
                        Text(braider.name)
                            .font(.bmUI(16, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.bmUI(11))
                                .foregroundStyle(Color.appAccent)
                        }
                    }

                    HStack(spacing: Space.xs) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < braider.rating.rounded() ? "star.fill" : "star")
                                    .font(.bmUI(9))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        Text(braider.ratingText)
                            .font(.bmMono(12, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text(braider.reviewCountText)
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAsh)
                    }

                    HStack(spacing: Space.xs) {
                        Text("from")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.bmMono(13, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        if !braider.city.isEmpty {
                            Text("·").foregroundStyle(Color.appSmoke)
                            Text(braider.city)
                                .font(.bmUI(11))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.bmUI(12, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground, in: Circle())
            }
            .padding(.vertical, Space.sm)
            .padding(.horizontal, isHighlighted ? Space.sm : 0)
            .background(
                Group {
                    if isHighlighted {
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .fill(Color.appAccentTint)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(OrbPressStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHighlighted)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Explore Card (full expanded)
// ═══════════════════════════════════════════════════════════════════

struct ExploreCard: View {
    let braider: Braider
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image
                if !braider.coverUrl.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        RemoteImage(url: braider.coverUrl)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.4)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )

                        // Rating badge
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.bmUI(10))
                                .foregroundStyle(Color.appAccent)
                            Text(braider.ratingText)
                                .font(.bmMono(12, weight: .bold))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, Space.sm)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .padding(Space.sm)
                    }
                    .clipShape(
                        .rect(
                            topLeadingRadius: Radius.card,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: Radius.card
                        )
                    )
                }

                // Info
                HStack(alignment: .top, spacing: Space.md) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: Space.xs) {
                            Text(braider.name)
                                .font(.bmDisplay(20, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                                .lineLimit(1)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.bmUI(13))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.bmUI(13))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(2)
                        }

                        HStack(spacing: Space.md) {
                            BMPriceTag(price: braider.priceFrom)

                            if !braider.responseTime.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.bmUI(10))
                                    Text(braider.responseTime)
                                        .font(.bmMono(11, weight: .medium))
                                }
                                .foregroundStyle(Color.appAsh)
                            }
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.appInk)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.appInk.opacity(0.2), radius: 8, y: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.bmUI(14, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                }
                .padding(Space.md)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.appInk.opacity(0.08), radius: 20, y: 10)
        }
        .buttonStyle(OrbPressStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Press Styles
// ═══════════════════════════════════════════════════════════════════

struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct PinTapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: configuration.isPressed)
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

            // Ambient gradient
            RadialGradient(
                colors: [Color.appAccent.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.xl)

                ZStack {
                    // Concentric animated rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                Color.appAccent.opacity(opacities[i]),
                                lineWidth: 1.5
                            )
                            .frame(width: 120 + CGFloat(i) * 30, height: 120 + CGFloat(i) * 30)
                            .scaleEffect(rings[i])
                    }

                    // Solid center
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appAccentTint, Color.appAccent.opacity(0.2)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color.appAccent.opacity(0.5), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.bmUI(44, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)
                }

                Spacer().frame(height: Space.xl)

                VStack(spacing: Space.sm) {
                    Text("Find braiders\nnear you")
                        .font(.bmHero(32))
                        .foregroundStyle(Color.appInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)

                    Text("We use your location to surface verified braiders in your city.")
                        .font(.bmUI(15))
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