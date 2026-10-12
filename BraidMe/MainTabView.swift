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
    @State private var dragOffset: CGFloat = 0
    @State private var mapAppeared = false
    @State private var userInfo: UserProfile?
    @State private var braidersLoading = false
    @State private var filter: BraiderFilter = .all

    enum SheetDetent: CaseIterable {
        case collapsed, medium, expanded
    }

    enum BraiderFilter: String, CaseIterable {
        case all = "All"
        case topRated = "Top rated"
        case verified = "Verified"
        case popular = "Most reviewed"

        var icon: String? {
            switch self {
            case .all: return nil
            case .topRated: return "star.fill"
            case .verified: return "checkmark.seal.fill"
            case .popular: return "flame.fill"
            }
        }
    }

    private var visibleBraiders: [Braider] {
        switch filter {
        case .all:      return fb.braiders
        case .topRated: return fb.braiders.filter { $0.rating >= 4.5 }
        case .verified: return fb.braiders.filter { $0.verified }
        case .popular:  return fb.braiders.sorted { $0.reviewCount > $1.reviewCount }
        }
    }

    private var firstName: String {
        let full = userInfo?.displayName ?? session.displayName ?? ""
        return full.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    mapLayer

                    LinearGradient(
                        colors: [Color.bmDeep.opacity(0.78), Color.bmDeep.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 190)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)

                    VStack(spacing: Space.sm) {
                        topChrome
                        filterRow
                    }
                    .padding(.top, Space.xs)

                    VStack(spacing: Space.sm) {
                        Spacer()
                        if let preview = previewBraider, sheetDetent == .collapsed {
                            previewCard(preview)
                                .padding(.horizontal, Space.md)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
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
                    .presentationBackground(Color.bmBase)
                    .presentationCornerRadius(Radius.modal)
            }
            .sheet(isPresented: $showBookings) {
                BookingsListView().environmentObject(session)
                    .presentationBackground(Color.bmBase)
                    .presentationCornerRadius(Radius.modal)
            }
            .sheet(isPresented: $showSaved) {
                SavedBraidersView().environmentObject(session)
                    .presentationBackground(Color.bmBase)
                    .presentationCornerRadius(Radius.modal)
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
                .presentationBackground(Color.bmBase)
                .presentationCornerRadius(Radius.modal)
            }
            .onAppear(perform: onAppear)
            .sheet(isPresented: $showLocationSheet, onDismiss: onLocationDismiss) {
                LocationPermissionSheet { allowed in
                    handleLocationDecision(allowed)
                }
                .presentationDetents([.height(540)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color.bmBase)
                .presentationCornerRadius(Radius.modal)
                .interactiveDismissDisabled()
            }
        }
        .tint(Color.bmGilt)
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(coordinateRegion: $region, annotationItems: visibleBraiders) { braider in
            MapAnnotation(coordinate: braider.coordinate) {
                BraiderPin(
                    braider: braider,
                    isSelected: previewBraider?.id == braider.id || highlightedBraiderId == braider.id
                ) {
                    focus(on: braider)
                }
            }
        }
        .ignoresSafeArea()
        .opacity(mapAppeared ? 1 : 0)
        .animate(Motion.navigation, value: mapAppeared)
    }

    private func focus(on braider: Braider) {
        Haptic.select()
        withAnimation(Motion.sheet) {
            previewBraider = braider
            highlightedBraiderId = braider.id
            sheetDetent = .collapsed
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: braider.latitude - region.span.latitudeDelta * 0.16,
                    longitude: braider.longitude
                ),
                span: region.span
            )
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        HStack(spacing: Space.xs) {
            searchBar
            savedButton
            profileButton
        }
        .padding(.horizontal, Space.md)
    }

    private var searchBar: some View {
        Button {
            Haptic.press()
            showCitySearch = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(LinearGradient.bmGiltGradient)
                    .frame(width: 32, height: 32)
                    .background(Color.bmGilt.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Braiders in")
                        .font(.bmUI(11, weight: .medium))
                        .foregroundStyle(Color.bmTextDim)
                    HStack(spacing: 4) {
                        Text(currentCity.name)
                            .font(.bmUI(15, weight: .bold))
                            .foregroundStyle(Color.bmText)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.bmUI(9, weight: .bold))
                            .foregroundStyle(Color.bmTextDim)
                    }
                }

                Spacer(minLength: 0)

                Text("\(visibleBraiders.count)")
                    .font(.bmNum(13, weight: .bold))
                    .foregroundStyle(Color.bmOnGilt)
                    .contentTransition(.numericText())
                    .frame(minWidth: 30, minHeight: 30)
                    .background(LinearGradient.bmGiltGradient, in: Circle())
                    .animation(Motion.press, value: visibleBraiders.count)
            }
            .padding(.horizontal, Space.sm)
            .frame(height: 56)
            .bmGlass(radius: 28, tint: Color.black.opacity(0.22))
            .shadow(color: Color.black.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(BMPressStyle(scale: 0.985, dim: 0.02))
    }

    private var savedButton: some View {
        Button {
            Haptic.press()
            showSaved = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: fb.savedBraiderIds.isEmpty ? "heart" : "heart.fill")
                    .font(.bmUI(17, weight: .semibold))
                    .foregroundStyle(fb.savedBraiderIds.isEmpty ? Color.bmText : Color.bmBad)
                    .frame(width: 56, height: 56)
                    .bmGlassCircle()
                    .shadow(color: Color.black.opacity(0.35), radius: 16, y: 6)

                if !fb.savedBraiderIds.isEmpty {
                    Text("\(fb.savedBraiderIds.count)")
                        .font(.bmNum(10, weight: .bold))
                        .foregroundStyle(Color.bmOnGilt)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(LinearGradient.bmGiltGradient, in: Capsule())
                        .offset(x: 3, y: -3)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(Motion.pop, value: fb.savedBraiderIds.count)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private var profileButton: some View {
        Button {
            Haptic.press()
            showProfileSheet = true
        } label: {
            BMAvatar(
                url: userInfo?.avatarUrl ?? "",
                size: 52,
                ringed: true,
                initials: bmInitials(userInfo?.displayName ?? session.displayName ?? "")
            )
            .frame(width: 58, height: 58)
            .shadow(color: Color.black.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(BMIconPressStyle())
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                ForEach(BraiderFilter.allCases, id: \.self) { f in
                    BMChip(title: f.rawValue, icon: f.icon, isSelected: filter == f) {
                        withAnimation(Motion.sheet) {
                            filter = f
                            if let p = previewBraider, !visibleBraiders.contains(where: { $0.id == p.id }) {
                                previewBraider = nil
                                highlightedBraiderId = nil
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Space.md)
        }
    }

    // MARK: - Preview card

    private func previewCard(_ braider: Braider) -> some View {
        HStack(spacing: Space.sm) {
            Button {
                Haptic.select()
                selectedBraider = braider
            } label: {
                HStack(spacing: Space.sm) {
                    BMAvatar(
                        url: braider.avatarUrl,
                        size: 56,
                        ringed: true,
                        initials: bmInitials(braider.name)
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Text(braider.name)
                                .font(.bmUI(16, weight: .bold))
                                .foregroundStyle(Color.bmText)
                                .lineLimit(1)
                            if braider.verified { VerifiedSeal() }
                        }
                        BMRatingLine(rating: braider.rating, count: braider.reviewCount, size: 12)
                        Text("from £\(braider.priceFrom)")
                            .font(.bmNum(13, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.bmUI(14, weight: .bold))
                        .foregroundStyle(Color.bmOnGilt)
                        .frame(width: 44, height: 44)
                        .background(LinearGradient.bmGiltGradient, in: Circle())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(BMPressStyle(scale: 0.985, dim: 0.02))

            Button {
                Haptic.select()
                withAnimation(Motion.sheet) {
                    previewBraider = nil
                    highlightedBraiderId = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.bmUI(11, weight: .bold))
                    .foregroundStyle(Color.bmTextDim)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(BMIconPressStyle())
        }
        .padding(Space.sm)
        .bmGlass(radius: Radius.card, tint: Color.black.opacity(0.22))
        .shadow(color: Color.black.opacity(0.4), radius: 22, y: 10)
    }

    // MARK: - Bottom sheet

    private func detentHeight(_ detent: SheetDetent, total: CGFloat) -> CGFloat {
        switch detent {
        case .collapsed: return 236
        case .medium:    return total * 0.56
        case .expanded:  return total * 0.92
        }
    }

    private func currentSheetHeight(total: CGFloat) -> CGFloat {
        let base = detentHeight(sheetDetent, total: total)
        let lower = detentHeight(.collapsed, total: total) - 24
        let upper = detentHeight(.expanded, total: total)
        return min(max(base - dragOffset, lower), upper)
    }

    private func bottomSheet(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                grabber
                if sheetDetent != .collapsed {
                    sheetHeader
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(total: height))

            Group {
                switch sheetDetent {
                case .collapsed: collapsedContent
                case .medium:    mediumContent
                case .expanded:  expandedContent
                }
            }
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentSheetHeight(total: height), alignment: .top)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Color.bmBase.opacity(0.72)
            }
        }
        .clipShape(
            .rect(
                topLeadingRadius: Radius.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.modal
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: Radius.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Radius.modal,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 0.9
            )
            .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 30, y: -10)
        .animation(Motion.sheet, value: sheetDetent)
    }

    private func dragGesture(total: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let base = detentHeight(sheetDetent, total: total)
                let projected = base - value.predictedEndTranslation.height
                let target = nearestDetent(to: projected, total: total)
                if target != sheetDetent { Haptic.press() }
                withAnimation(Motion.sheet) {
                    sheetDetent = target
                    dragOffset = 0
                }
            }
    }

    private func nearestDetent(to height: CGFloat, total: CGFloat) -> SheetDetent {
        var best: SheetDetent = .collapsed
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for d in SheetDetent.allCases {
            let dist = abs(detentHeight(d, total: total) - height)
            if dist < bestDistance {
                bestDistance = dist
                best = d
            }
        }
        return best
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.28))
            .frame(width: 40, height: 5)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.sm)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Sheet content

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                if braidersLoading {
                    BMSkeleton(height: 26, cornerRadius: 8).frame(width: 170)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(firstName.isEmpty ? "Nearby braiders" : "Hi \(firstName)")
                            .font(.bmDisplay(24, weight: .semibold))
                            .foregroundStyle(Color.bmText)
                        Text("\(visibleBraiders.count) available in \(currentCity.name)")
                            .font(.bmUI(13))
                            .foregroundStyle(Color.bmTextDim)
                    }
                }
                Spacer()
                if !visibleBraiders.isEmpty {
                    Button {
                        Haptic.press()
                        withAnimation(Motion.sheet) { sheetDetent = .medium }
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.bmUI(13, weight: .bold))
                            Image(systemName: "chevron.up")
                                .font(.bmUI(10, weight: .bold))
                        }
                        .foregroundStyle(Color.bmGilt)
                        .padding(.horizontal, Space.sm)
                        .frame(height: 34)
                        .background(Color.bmGilt.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(BMPressStyle(scale: 0.95))
                }
            }

            if braidersLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: Space.sm) {
                                BMSkeleton(height: 46, cornerRadius: 23).frame(width: 46)
                                VStack(alignment: .leading, spacing: 6) {
                                    BMSkeleton(height: 12, cornerRadius: 4).frame(width: 90)
                                    BMSkeleton(height: 10, cornerRadius: 4).frame(width: 56)
                                }
                            }
                            .padding(Space.sm)
                            .frame(width: 190, alignment: .leading)
                            .bmCard(radius: Radius.card, fill: Color.bmSurface.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
                .padding(.horizontal, -Space.lg)
            } else if visibleBraiders.isEmpty {
                VStack(spacing: Space.xxs) {
                    Text("No braiders match here yet")
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                    Text("Try another filter or a different city.")
                        .font(.bmUI(12))
                        .foregroundStyle(Color.bmTextDim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.sm) {
                        ForEach(Array(visibleBraiders.prefix(8))) { braider in
                            CompactBraiderCard(
                                braider: braider,
                                isHighlighted: highlightedBraiderId == braider.id
                            ) {
                                if highlightedBraiderId == braider.id {
                                    Haptic.select()
                                    selectedBraider = braider
                                } else {
                                    focus(on: braider)
                                }
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
        .padding(.top, Space.xxs)
    }

    private var mediumContent: some View {
        Group {
            if braidersLoading {
                VStack(spacing: Space.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: Space.sm) {
                            BMSkeleton(height: 62, cornerRadius: 31).frame(width: 62)
                            VStack(alignment: .leading, spacing: 8) {
                                BMSkeleton(height: 14, cornerRadius: 5).frame(width: 130)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 90)
                                BMSkeleton(height: 10, cornerRadius: 4).frame(width: 60)
                            }
                            Spacer()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xs)
            } else if visibleBraiders.isEmpty {
                miniEmpty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Space.xxs) {
                        ForEach(Array(visibleBraiders.enumerated()), id: \.element.id) { index, braider in
                            BraiderCard(
                                braider: braider,
                                isHighlighted: highlightedBraiderId == braider.id
                            ) {
                                Haptic.select()
                                previewBraider = braider
                                highlightedBraiderId = braider.id
                                selectedBraider = braider
                            }
                            .reveal(mapAppeared, delay: Motion.stagger(index), offset: 14, blur: 0)
                        }
                        Color.clear.frame(height: Space.xxl)
                    }
                    .padding(.horizontal, Space.md)
                }
                .refreshable {
                    await fb.fetchBraidersFromFirestore()
                }
            }
        }
    }

    private var expandedContent: some View {
        Group {
            if visibleBraiders.isEmpty {
                miniEmpty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Space.md) {
                        ForEach(visibleBraiders) { braider in
                            BigBraiderRow(
                                braider: braider,
                                isSaved: fb.savedBraiderIds.contains(braider.id)
                            ) {
                                Haptic.select()
                                selectedBraider = braider
                            }
                        }
                        Color.clear.frame(height: Space.xxl)
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.xxs)
                }
                .refreshable {
                    await fb.fetchBraidersFromFirestore()
                }
            }
        }
    }

    private var miniEmpty: some View {
        VStack(spacing: Space.xs) {
            Image(systemName: "mappin.slash")
                .font(.bmUI(26, weight: .light))
                .foregroundStyle(LinearGradient.bmGiltGradient)
            Text("No braiders here yet")
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Text("Try another filter or city from the search bar.")
                .font(.bmUI(13))
                .foregroundStyle(Color.bmTextDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    private var sheetHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Braiders near you")
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                Text("\(visibleBraiders.count) in \(currentCity.name)")
                    .font(.bmUI(13))
                    .foregroundStyle(Color.bmTextDim)
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
                    .foregroundStyle(Color.bmTextDim)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(BMIconPressStyle())
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.sm)
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

// MARK: - Map pin

struct BraiderPin: View {
    let braider: Braider
    let isSelected: Bool
    let onTap: () -> Void

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var size: CGFloat { isSelected ? 60 : 44 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(Color.bmGilt.opacity(0.7), lineWidth: 2)
                        .frame(width: size, height: size)
                        .scaleEffect(pulse ? 2.1 : 1)
                        .opacity(pulse ? 0 : 0.8)
                }

                Circle()
                    .fill(Color.bmBase)
                    .frame(width: size + 8, height: size + 8)
                    .shadow(
                        color: isSelected ? Color.bmGilt.opacity(0.65) : Color.black.opacity(0.45),
                        radius: isSelected ? 16 : 8,
                        y: 4
                    )

                Group {
                    if braider.avatarUrl.isEmpty {
                        Text(bmInitials(braider.name))
                            .font(.bmDisplay(size * 0.38, weight: .semibold))
                            .foregroundStyle(LinearGradient.bmGiltGradient)
                            .frame(width: size, height: size)
                            .background(Color.bmRaised, in: Circle())
                    } else {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    }
                }

                Circle()
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(AngularGradient(
                                colors: [Color.bmGilt, Color.bmEmber, Color.bmOrchid, Color.bmGilt],
                                center: .center
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.85)),
                        lineWidth: isSelected ? 3 : 2
                    )
                    .frame(width: size + 6, height: size + 6)

                if isSelected {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmNum(11, weight: .bold))
                            .foregroundStyle(Color.bmText)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Color.bmBase, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.bmGilt.opacity(0.6), lineWidth: 0.8))
                    .offset(y: -(size / 2 + 22))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 100, height: 100)
        }
        .buttonStyle(BMIconPressStyle())
        .animation(Motion.pop, value: isSelected)
        .onChange(of: isSelected) { _, nowSelected in
            guard nowSelected, !reduceMotion else { pulse = false; return }
            pulse = false
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .onAppear {
            guard isSelected, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Compact card

struct CompactBraiderCard: View {
    let braider: Braider
    var isHighlighted: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.sm) {
                BMAvatar(
                    url: braider.avatarUrl,
                    size: 46,
                    ringed: isHighlighted,
                    initials: bmInitials(braider.name)
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(braider.name)
                            .font(.bmUI(14, weight: .bold))
                            .foregroundStyle(Color.bmText)
                            .lineLimit(1)
                        if braider.verified { VerifiedSeal(size: 11) }
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.bmUI(9, weight: .bold))
                                .foregroundStyle(Color.bmGilt)
                            Text(String(format: "%.1f", braider.rating))
                                .font(.bmNum(12, weight: .bold))
                                .foregroundStyle(Color.bmText)
                        }
                        Text("£\(braider.priceFrom)")
                            .font(.bmNum(12, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                    }
                }
            }
            .padding(Space.sm)
            .frame(width: 214, alignment: .leading)
            .bmCard(
                radius: Radius.card,
                fill: isHighlighted ? Color.bmRaised : Color.bmSurface.opacity(0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isHighlighted ? Color.bmGilt.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.97, dim: 0.02))
        .animation(Motion.press, value: isHighlighted)
    }
}

// MARK: - Location permission sheet

struct LocationPermissionSheet: View {
    let onDecision: (Bool) -> Void

    @State private var appeared = false
    @State private var ripple = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.7)

            VStack(spacing: 0) {
                Spacer(minLength: Space.xl)

                radar
                    .frame(height: 190)
                    .reveal(appeared, offset: 10, blur: 8)

                Spacer().frame(height: Space.lg)

                VStack(spacing: Space.xs) {
                    Text("Find braiders\nnear you")
                        .font(.bmDisplay(34, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(-4)
                    Text("We use your location to show verified braiders in your city. You can change it any time.")
                        .font(.bmUI(15))
                        .foregroundStyle(Color.bmTextDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, Space.xl)
                }
                .reveal(appeared, delay: 0.1)

                Spacer()

                VStack(spacing: Space.sm) {
                    BMPrimaryButton(title: "Allow location", icon: "location.fill") {
                        onDecision(true)
                    }
                    BMSecondaryButton(title: "Not now") {
                        onDecision(false)
                    }
                }
                .padding(.horizontal, Space.lg)
                .reveal(appeared, delay: 0.2)

                Spacer().frame(height: Space.lg)
            }
        }
        .onAppear {
            appeared = true
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) {
                ripple = true
            }
        }
    }

    private var radar: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.bmGilt.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ripple ? 2.2 : 0.6)
                    .opacity(ripple ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8),
                        value: ripple
                    )
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.bmRaised, Color.bmSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)
                .overlay(
                    Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.bmGilt.opacity(0.4), radius: 24)

            Image(systemName: "location.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(LinearGradient.bmGiltGradient)
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
