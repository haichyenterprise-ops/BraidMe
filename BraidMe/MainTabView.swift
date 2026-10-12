import SwiftUI
import MapKit
import CoreLocation

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var locationService = LocationService()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
    @State private var currentCity: City = CityCatalog.all[0]
    @State private var selectedBraider: Braider?
    @State private var previewBraider: Braider?
    @State private var highlightedBraiderId: String?
    @State private var showLocationSheet = false
    @State private var showProfileSheet = false
    @State private var showCitySearch = false
    @State private var showBookings = false
    @State private var showSaved = false
    @State private var sheetDetent: SheetDetent = .collapsed
    @State private var mapAppeared = false
    @State private var userInfo: UserProfile?
    @State private var braidersLoading = false
    @State private var headerCollapsed = false

    enum SheetDetent: CaseIterable {
        case collapsed, medium, expanded
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    mapLayer
                    topChrome

                    VStack(spacing: 0) {
                        Spacer()
                        bottomSheet(height: geo.size.height)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
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
                    withAnimation(Motion.sheet) {
                        currentCity = newCity
                        region = MKCoordinateRegion(
                            center: newCity.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                        )
                    }
                    Haptic.success()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
            .onAppear(perform: onAppear)
            .sheet(isPresented: $showLocationSheet, onDismiss: onLocationDismiss) {
                LocationPermissionSheet { allowed in
                    handleLocationDecision(allowed)
                }
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled()
                .presentationCornerRadius(Radius.modal)
            }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: fb.braiders) { braider in
                MapAnnotation(coordinate: braider.coordinate) {
                    BraiderPin(
                        braider: braider,
                        isSelected: previewBraider?.id == braider.id || highlightedBraiderId == braider.id
                    ) {
                        Haptic.select()
                        withAnimation(Motion.bouncy) {
                            previewBraider = braider
                            highlightedBraiderId = braider.id
                            if sheetDetent == .expanded { sheetDetent = .medium }
                        }
                    }
                }
            }
            .ignoresSafeArea()

            // Map vignette overlay
            VStack {
                LinearGradient(
                    colors: [Color.appBackground.opacity(0.7), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
                .allowsHitTesting(false)

                Spacer()

                LinearGradient(
                    colors: [.clear, Color.appBackground.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .opacity(mapAppeared ? 1 : 0)
        .scaleEffect(mapAppeared ? 1 : 1.05)
        .animate(Motion.navigation, value: mapAppeared)
    }

    // MARK: - Top Chrome

    private var topChrome: some View {
        HStack(spacing: Space.xs) {
            searchBar
            savedButton
            profileButton
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
        .offset(y: headerCollapsed ? -100 : 0)
        .opacity(headerCollapsed ? 0 : 1)
        .animate(Motion.sheet, value: sheetDetent)
    }

    private var searchBar: some View {
        Button {
            Haptic.press()
            showCitySearch = true
        } label: {
            HStack(spacing: Space.sm) {
                ZStack {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 36, height: 36)
                    Image(systemName: "location.fill")
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("EXPLORING")
                        .font(.bmUI(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.appSmoke)
                    Text(currentCity.fullName)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(fb.braiders.count)")
                        .font(.bmMono(13, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.bmUI(9, weight: .bold))
                        .foregroundStyle(Color.appInkInverse.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appInk, in: Capsule())
            }
            .padding(.horizontal, Space.sm)
            .frame(minHeight: 60)
            .background {
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .fill(Color.appSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appDivider, Color.appDivider.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: Color.appInk.opacity(0.08), radius: 20, y: 8)
            }
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }

    private var savedButton: some View {
        Button {
            Haptic.press()
            showSaved = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.bmUI(16, weight: .medium))
                    .foregroundStyle(fb.savedBraiderIds.isEmpty ? Color.appInk : Color.appAlert)
                    .frame(width: 56, height: 56)
                    .background(Color.appSurface, in: Circle())
                    .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))
                    .shadow(color: Color.appInk.opacity(0.08), radius: 20, y: 8)

                if !fb.savedBraiderIds.isEmpty {
                    Text("\(fb.savedBraiderIds.count)")
                        .font(.bmMono(10, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, 5)
                        .background(Color.appAccent, in: Capsule())
                        .overlay(Capsule().stroke(Color.appSurface, lineWidth: 2))
                        .offset(x: 2, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animate(Motion.bouncy, value: fb.savedBraiderIds.count)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private var profileButton: some View {
        Button {
            Haptic.press()
            showProfileSheet = true
        } label: {
            ZStack {
                if let avatarUrl = userInfo?.avatarUrl, !avatarUrl.isEmpty {
                    RemoteImage(url: avatarUrl)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccentSoft],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                        )
                } else if let name = userInfo?.displayName ?? session.displayName, !name.isEmpty {
                    Circle()
                        .fill(Color.appInk)
                        .frame(width: 56, height: 56)
                    Text(initials(from: name))
                        .font(.bmUI(16, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                } else {
                    Image(systemName: "person.fill")
                        .font(.bmUI(16, weight: .medium))
                        .foregroundStyle(Color.appInkInverse)
                        .frame(width: 56, height: 56)
                        .background(Color.appInk, in: Circle())
                }
            }
            .shadow(color: Color.appInk.opacity(0.12), radius: 20, y: 8)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // MARK: - Bottom Sheet

    private func bottomSheet(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber

            switch sheetDetent {
            case .collapsed: collapsedContent
            case .medium:    mediumContent
            case .expanded:  expandedContent
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: sheetHeight(for: height), alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: Radius.modal, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.modal, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.appDivider, Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.appInk.opacity(0.15), radius: 32, y: -12)
        }
        .clipShape(
            .rect(
                topLeadingRadius: Radius.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.modal
            )
        )
        .gesture(dragGesture(for: height))
        .animate(Motion.sheet, value: sheetDetent)
    }

    private func sheetHeight(for height: CGFloat) -> CGFloat {
        switch sheetDetent {
        case .collapsed: return 220
        case .medium:    return height * 0.55
        case .expanded:  return height * 0.92
        }
    }

    private func dragGesture(for height: CGFloat) -> some Gesture {
        DragGesture()
            .onEnded { value in
                let threshold: CGFloat = 60
                withAnimation(Motion.sheet) {
                    if value.translation.height < -threshold {
                        switch sheetDetent {
                        case .collapsed: Haptic.medium(); sheetDetent = .medium
                        case .medium:    Haptic.medium(); sheetDetent = .expanded
                        case .expanded:  break
                        }
                    } else if value.translation.height > threshold {
                        switch sheetDetent {
                        case .collapsed: break
                        case .medium:    Haptic.medium(); sheetDetent = .collapsed
                        case .expanded:  Haptic.medium(); sheetDetent = .medium
                        }
                    }
                }
            }
    }

    private var grabber: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color.appDivider)
                .frame(width: 40, height: 5)
        }
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
    }

    // MARK: - Sheet Content

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                if braidersLoading {
                    BMSkeleton(height: 26, cornerRadius: 8).frame(width: 160)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nearby")
                            .font(.bmUI(11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.appAccent)
                        Text("\(fb.braiders.count) braiders")
                            .font(.bmDisplay(24, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                if !fb.braiders.isEmpty {
                    Button {
                        Haptic.press()
                        withAnimation(Motion.sheet) { sheetDetent = .medium }
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
                    .buttonStyle(BMPressStyle(scale: 0.96))
                }
            }

            if braidersLoading {
                loadingCarousel
            } else if fb.braiders.isEmpty {
                emptyState
            } else {
                braiderCarousel
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
    }

    private var loadingCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: Space.sm) {
                        BMSkeleton(height: 48, cornerRadius: 24).frame(width: 48)
                        VStack(alignment: .leading, spacing: 6) {
                            BMSkeleton(height: 14, cornerRadius: 4).frame(width: 90)
                            BMSkeleton(height: 10, cornerRadius: 4).frame(width: 60)
                        }
                    }
                    .padding(Space.sm)
                    .frame(width: 190, alignment: .leading)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, -Space.lg)
    }

    private var emptyState: some View {
        HStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 48, height: 48)
                Image(systemName: "mappin.slash")
                    .font(.bmUI(18, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("No braiders here")
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Try another city")
                    .font(.bmUI(12))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(Space.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
    }

    private var braiderCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                ForEach(fb.braiders.prefix(6)) { braider in
                    CompactBraiderCard(braider: braider) {
                        Haptic.select()
                        previewBraider = braider
                        selectedBraider = braider
                    }
                }
            }
            .padding(.horizontal, Space.lg)
        }
        .padding(.horizontal, -Space.lg)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sheetHeader

            if braidersLoading {
                VStack(spacing: Space.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: Space.sm) {
                            BMSkeleton(height: 64, cornerRadius: 32).frame(width: 64)
                            VStack(alignment: .leading, spacing: 8) {
                                BMSkeleton(height: 14, cornerRadius: 4).frame(width: 130)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 100)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 70)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, Space.xs)
            } else if fb.braiders.isEmpty {
                miniEmpty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(fb.braiders.enumerated()), id: \.element.id) { index, braider in
                            BraiderCard(
                                braider: braider,
                                isHighlighted: highlightedBraiderId == braider.id
                            ) {
                                Haptic.select()
                                previewBraider = braider
                                highlightedBraiderId = braider.id
                                selectedBraider = braider
                            }
                            .opacity(mapAppeared ? 1 : 0)
                            .offset(y: mapAppeared ? 0 : 16)
                            .animate(Motion.reveal.delay(Motion.stagger(index)), value: mapAppeared)

                            if index < fb.braiders.count - 1 {
                                BMDivider(inset: 80)
                            }
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sheetHeader

            if fb.braiders.isEmpty {
                miniEmpty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Space.sm) {
                        ForEach(Array(fb.braiders.enumerated()), id: \.element.id) { index, braider in
                            BigBraiderRow(braider: braider) {
                                Haptic.select()
                                selectedBraider = braider
                            }
                            .opacity(mapAppeared ? 1 : 0)
                            .offset(y: mapAppeared ? 0 : 16)
                            .animate(Motion.reveal.delay(Motion.stagger(index)), value: mapAppeared)
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var miniEmpty: some View {
        VStack(spacing: Space.sm) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 64, height: 64)
                Image(systemName: "mappin.slash")
                    .font(.bmUI(24, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text("No braiders here yet")
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("Try another city from the search bar.")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISCOVER")
                    .font(.bmUI(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAccent)
                Text("Braiders near you")
                    .font(.bmDisplay(26, weight: .semibold))
                    .foregroundStyle(Color.appInk)
            }
            Spacer()
            Button {
                Haptic.press()
                withAnimation(Motion.sheet) {
                    sheetDetent = (sheetDetent == .expanded) ? .medium : .collapsed
                }
            } label: {
                Image(systemName: sheetDetent == .expanded ? "chevron.down" : "chevron.up")
                    .font(.bmUI(13, weight: .bold))
                    .foregroundStyle(Color.appInk)
                    .frame(width: 36, height: 36)
                    .background(Color.appBackground, in: Circle())
            }
            .buttonStyle(BMIconPressStyle())
        }
    }

    // MARK: - Lifecycle

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
                        region = MKCoordinateRegion(
                            center: stored.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                        )
                    }
                }
            }
            await fb.fetchBraidersFromFirestore()
            await MainActor.run { braidersLoading = false }
        }

        withAnimation(Motion.heroReveal.delay(0.1)) { mapAppeared = true }

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
                withAnimation(Motion.sheet) {
                    currentCity = closest
                    region = MKCoordinateRegion(
                        center: closest.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
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
}

// MARK: - Braider Pin

struct BraiderPin: View {
    let braider: Braider
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Pulse ring when selected
                if isSelected {
                    Circle()
                        .stroke(Color.appAccent.opacity(0.4), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulse ? 1.3 : 1)
                        .opacity(pulse ? 0 : 0.7)
                        .onAppear {
                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                pulse = true
                            }
                        }
                }

                // Outer ring
                Circle()
                    .fill(Color.appSurface)
                    .frame(width: isSelected ? 72 : 54, height: isSelected ? 72 : 54)
                    .shadow(color: Color.appInk.opacity(0.25), radius: 14, y: 6)

                // Avatar / placeholder
                Group {
                    if braider.avatarUrl.isEmpty {
                        Image(systemName: "person.fill")
                            .font(.bmUI(isSelected ? 26 : 20, weight: .medium))
                            .foregroundStyle(Color.appAsh)
                            .frame(width: isSelected ? 62 : 46, height: isSelected ? 62 : 46)
                            .background(Color.appBackground, in: Circle())
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: isSelected ? 62 : 46, height: isSelected ? 62 : 46)
                            .clipShape(Circle())
                    }
                }

                // Accent ring
                Circle()
                    .stroke(
                        isSelected ? Color.appAccent : Color.appSurface,
                        lineWidth: isSelected ? 3 : 2.5
                    )
                    .frame(width: isSelected ? 68 : 50, height: isSelected ? 68 : 50)

                // Rating badge
                if isSelected {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8))
                            .foregroundStyle(Color.appAccent)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(10, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appInk, in: Capsule())
                    .overlay(Capsule().stroke(Color.appAccent.opacity(0.5), lineWidth: 1))
                    .offset(y: -46)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(BMIconPressStyle())
        .animate(Motion.bouncy, value: isSelected)
    }
}

// MARK: - Compact Card

struct CompactBraiderCard: View {
    let braider: Braider
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: braider.avatarUrl, size: 48, initials: initials, ringed: braider.verified)

                VStack(alignment: .leading, spacing: 3) {
                    Text(braider.name)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(9))
                            .foregroundStyle(Color.appAccent)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(11, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.bmMono(11, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.sm)
            .frame(width: 200, alignment: .leading)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.98))
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}

// MARK: - Location Permission Sheet

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    @State private var appeared = false
    @State private var ringPulse = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient gradient
            RadialGradient(
                colors: [Color.appAccent.opacity(0.1), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.xl)

                ZStack {
                    // Pulse rings
                    Circle()
                        .stroke(Color.appAccent.opacity(0.2), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringPulse ? 1.4 : 1)
                        .opacity(ringPulse ? 0 : 0.6)

                    Circle()
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringPulse ? 1.2 : 1)
                        .opacity(ringPulse ? 0 : 0.8)

                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 120, height: 120)

                    Image(systemName: "location.fill")
                        .font(.bmUI(44, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

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
            withAnimation(Motion.heroReveal) { appeared = true }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                ringPulse = true
            }
        }
    }
}

// MARK: - Location Service

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