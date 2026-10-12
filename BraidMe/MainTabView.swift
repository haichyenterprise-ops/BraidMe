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
            }
            .onAppear(perform: onAppear)
            .sheet(isPresented: $showLocationSheet, onDismiss: onLocationDismiss) {
                LocationPermissionSheet { allowed in
                    handleLocationDecision(allowed)
                }
                .presentationDetents([.height(460)])
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
                    isSelected: previewBraider?.id == braider.id || highlightedBraiderId == braider.id
                ) {
                    Haptic.select()
                    withAnimation(Motion.press) {
                        previewBraider = braider
                        highlightedBraiderId = braider.id
                        if sheetDetent == .expanded { sheetDetent = .medium }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .opacity(mapAppeared ? 1 : 0)
        .animate(Motion.navigation, value: mapAppeared)
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        HStack(spacing: Space.xs) {
            searchBar
            savedButton
            profileButton
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
    }

    private var searchBar: some View {
        Button {
            Haptic.press()
            showCitySearch = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.bmUI(15, weight: .medium))
                    .foregroundStyle(Color.appAsh)

                VStack(alignment: .leading, spacing: 1) {
                    Text("NEARBY")
                        .font(.bmUI(10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Color.appSmoke)
                    Text(currentCity.fullName)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.bmUI(11, weight: .semibold))
                    .foregroundStyle(Color.appSmoke)

                Text("\(fb.braiders.count)")
                    .font(.bmMono(13, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(Color.appAccent, in: Circle())
            }
            .padding(.horizontal, Space.md)
            .frame(minHeight: 56)
            .padding(.vertical, 4)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.appInk.opacity(0.06), radius: 12, y: 4)
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }

    private var savedButton: some View {
        Button {
            Haptic.press()
            showSaved = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart")
                    .font(.bmUI(16, weight: .medium))
                    .foregroundStyle(Color.appInk)
                    .frame(width: 56, height: 56)
                    .background(Color.appSurface, in: Circle())
                    .overlay(Circle().stroke(Color.appDivider, lineWidth: 0.5))

                if !fb.savedBraiderIds.isEmpty {
                    Text("\(fb.savedBraiderIds.count)")
                        .font(.bmMono(10, weight: .bold))
                        .foregroundStyle(Color.appInkInverse)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 4)
                        .background(Color.appAccent, in: Capsule())
                        .offset(x: 2, y: 2)
                }
            }
            .shadow(color: Color.appInk.opacity(0.06), radius: 12, y: 4)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private var profileButton: some View {
        Button {
            Haptic.press()
            showProfileSheet = true
        } label: {
            ZStack {
                if let name = userInfo?.displayName ?? session.displayName, !name.isEmpty {
                    Circle()
                        .fill(Color.appInk)
                        .frame(width: 56, height: 56)
                    Text(initials(from: name))
                        .font(.bmUI(16, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                } else {
                    Image(systemName: "person")
                        .font(.bmUI(16, weight: .medium))
                        .foregroundStyle(Color.appInkInverse)
                        .frame(width: 56, height: 56)
                        .background(Color.appInk, in: Circle())
                }
            }
            .shadow(color: Color.appInk.opacity(0.10), radius: 12, y: 4)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // MARK: - Bottom sheet

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
        .background(Color.appSurface)
        .clipShape(
            .rect(
                topLeadingRadius: Radius.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.modal
            )
        )
        .shadow(color: Color.appInk.opacity(0.12), radius: 24, y: -8)
        .gesture(dragGesture(for: height))
        .animate(Motion.sheet, value: sheetDetent)
    }

    private func sheetHeight(for height: CGFloat) -> CGFloat {
        switch sheetDetent {
        case .collapsed: return 200
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
                        case .collapsed: Haptic.press(); sheetDetent = .medium
                        case .medium:    Haptic.press(); sheetDetent = .expanded
                        case .expanded:  break
                        }
                    } else if value.translation.height > threshold {
                        switch sheetDetent {
                        case .collapsed: break
                        case .medium:    Haptic.press(); sheetDetent = .collapsed
                        case .expanded:  Haptic.press(); sheetDetent = .medium
                        }
                    }
                }
            }
    }

    private var grabber: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color.appDivider)
                .frame(width: 36, height: 4)
        }
        .padding(.top, Space.sm)
        .padding(.bottom, Space.md)
    }

    // MARK: - Sheet content

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                if braidersLoading {
                    BMSkeleton(height: 24, cornerRadius: 6).frame(width: 140)
                } else {
                    Text("\(fb.braiders.count) near you")
                        .font(.bmDisplay(20, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                }
                Spacer()
                if !fb.braiders.isEmpty {
                    Button {
                        Haptic.press()
                        withAnimation(Motion.sheet) { sheetDetent = .medium }
                    } label: {
                        HStack(spacing: 2) {
                            Text("See all")
                                .font(.bmUI(13, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.bmUI(10, weight: .semibold))
                        }
                        .foregroundStyle(Color.appAccent)
                    }
                }
            }

            if braidersLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: Space.sm) {
                                BMSkeleton(height: 40, cornerRadius: 20).frame(width: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    BMSkeleton(height: 12, cornerRadius: 4).frame(width: 90)
                                    BMSkeleton(height: 10, cornerRadius: 4).frame(width: 50)
                                }
                            }
                            .padding(Space.sm)
                            .frame(width: 170, alignment: .leading)
                            .background(Color.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
                .padding(.horizontal, -Space.lg)
            } else if fb.braiders.isEmpty {
                VStack(spacing: Space.xs) {
                    Text("No braiders in this area yet")
                        .font(.bmUI(14, weight: .medium))
                        .foregroundStyle(Color.appInk)
                    Text("Try a different city from the search bar.")
                        .font(.bmUI(12))
                        .foregroundStyle(Color.appAsh)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(fb.braiders.prefix(4)) { braider in
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
    }

    private var mediumContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sheetHeader

            if braidersLoading {
                VStack(spacing: Space.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: Space.sm) {
                            BMSkeleton(height: 60, cornerRadius: 30).frame(width: 60)
                            VStack(alignment: .leading, spacing: 6) {
                                BMSkeleton(height: 14, cornerRadius: 4).frame(width: 120)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 90)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 60)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, Space.xs)
            } else if fb.braiders.isEmpty {
                miniEmpty
            } else {
                ScrollView(showsIndicators: true) {
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
                            .offset(y: mapAppeared ? 0 : 12)
                            .animate(Motion.reveal.delay(Motion.stagger(index)), value: mapAppeared)

                            if index < fb.braiders.count - 1 {
                                BMDivider(inset: 76)
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
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: Space.sm) {
                        ForEach(fb.braiders) { braider in
                            BigBraiderRow(braider: braider) {
                                Haptic.select()
                                selectedBraider = braider
                            }
                        }
                        Color.clear.frame(height: Space.lg)
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var miniEmpty: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: "mappin.slash")
                .font(.bmUI(24, weight: .light))
                .foregroundStyle(Color.appSmoke)
            Text("No braiders here yet")
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text("Try another city from the search bar.")
                .font(.bmUI(12))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Braiders near you")
                .font(.bmDisplay(22, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Spacer()
            Button {
                Haptic.press()
                withAnimation(Motion.sheet) {
                    sheetDetent = (sheetDetent == .expanded) ? .medium : .collapsed
                }
            } label: {
                Image(systemName: sheetDetent == .expanded ? "chevron.down" : "chevron.up")
                    .font(.bmUI(13, weight: .semibold))
                    .foregroundStyle(Color.appAsh)
                    .frame(width: 30, height: 30)
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

        withAnimation(Motion.navigation.delay(0.1)) { mapAppeared = true }

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

// MARK: - Pin

struct BraiderPin: View {
    let braider: Braider
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.appSurface)
                    .frame(width: isSelected ? 68 : 52, height: isSelected ? 68 : 52)
                    .shadow(color: Color.appInk.opacity(0.20), radius: 10, y: 4)

                if braider.avatarUrl.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.bmUI(isSelected ? 24 : 18, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                        .frame(width: isSelected ? 58 : 44, height: isSelected ? 58 : 44)
                        .background(Color.appBackground, in: Circle())
                } else {
                    RemoteImage(url: braider.avatarUrl)
                        .frame(width: isSelected ? 58 : 44, height: isSelected ? 58 : 44)
                        .clipShape(Circle())
                }

                Circle()
                    .stroke(isSelected ? Color.appAccent : Color.appSurface, lineWidth: isSelected ? 2.5 : 2)
                    .frame(width: isSelected ? 62 : 48, height: isSelected ? 62 : 48)

                if isSelected {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8))
                            .foregroundStyle(Color.appAccent)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(10, weight: .bold))
                            .foregroundStyle(Color.appInkInverse)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.appInk, in: Capsule())
                    .offset(y: -42)
                }
            }
        }
        .buttonStyle(BMIconPressStyle())
        .animate(Motion.press, value: isSelected)
    }
}

// MARK: - Compact card

struct CompactBraiderCard: View {
    let braider: Braider
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: braider.avatarUrl, size: 40, initials: initials)
                VStack(alignment: .leading, spacing: 2) {
                    Text(braider.name)
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                    Text("£\(braider.priceFrom)")
                        .font(.bmMono(11, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .frame(width: 170, alignment: .leading)
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

// MARK: - Location permission sheet

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.xl)
                ZStack {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 100, height: 100)
                    Image(systemName: "location.fill")
                        .font(.bmUI(36, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                Spacer().frame(height: Space.lg)
                VStack(spacing: Space.xs) {
                    Text("Find braiders near you")
                        .font(.bmDisplay(26, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    Text("We use your location to surface verified braiders in your city.")
                        .font(.bmUI(14))
                        .foregroundStyle(Color.appAsh)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, Space.xl)
                }
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
                Spacer().frame(height: Space.lg)
            }
        }
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