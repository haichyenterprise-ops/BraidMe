import SwiftUI

// =============================================================================
// BraiderProfileView — Cinematic Dossier
//
// A parallax-scrolling editorial profile. The hero image collapses into a
// compact sticky header as you scroll. Oversized serif typography. Gallery
// that feels like a fashion magazine spread. Reviews as an editorial column.
// Booking dock that morphs from large CTA to compact pill on scroll.
// =============================================================================

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    // Scroll tracking
    @State private var scrollOffset: CGFloat = 0
    @State private var heroHeight: CGFloat = 0

    // Data
    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true

    // Navigation
    @State private var showWriteReview = false
    @State private var showAllReviews = false
    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var selectedPortfolioItem: PortfolioItem?

    // Animation
    @State private var heroAppeared = false
    @State private var contentAppeared = false
    @State private var savedPulse = false

    // MARK: - Computed

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }

    private var ratingText: String {
        reviews.isEmpty ? braider.ratingText :
            String(format: "%.1f", RatingBreakdown.from(reviews).average)
    }

    private var ratingCount: Int {
        reviews.isEmpty ? braider.reviewCount : reviews.count
    }

    /// Progress 0→1 as the hero scrolls off screen.
    private var collapseProgress: CGFloat {
        guard heroHeight > 0 else { return 0 }
        let scrolled = -scrollOffset
        let threshold = heroHeight * 0.55
        return min(max(scrolled / threshold, 0), 1)
    }

    /// Hero parallax — image moves slower than scroll.
    private var heroParallax: CGFloat {
        guard heroHeight > 0 else { return 0 }
        let scrolled = -scrollOffset
        // Parallax: image moves down by 35% of scroll distance
        return scrolled * 0.35
    }

    /// Scale hero when pulling down (rubber-band).
    private var heroScale: CGFloat {
        guard heroHeight > 0 else { return 1 }
        if scrollOffset > 0 {
            return 1 + (scrollOffset / heroHeight) * 0.4
        }
        return 1
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            // Scrolling content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .frame(height: heroHeight > 0 ? heroHeight : 560)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: HeroHeightKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )

                    contentSections
                        .background(Color.appBackground)
                }
            }
            .coordinateSpace(name: "scroll")
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
            .onPreferenceChange(HeroHeightKey.self) { heroHeight = $0 }
            .ignoresSafeArea(edges: .top)

            // Sticky compact header — appears on scroll
            compactHeader

            // Floating back + save — hides when compact header is showing
            floatingTopControls
                .opacity(1 - min(collapseProgress * 2, 1))
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bookingDock
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(braider: braider) {
                Task { await loadReviews() }
            }
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsSheet(
                braider: braider,
                reviews: reviews,
                breakdown: RatingBreakdown.from(reviews),
                onWriteReview: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showWriteReview = true
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showBooking) {
            BookingSelectionView(braider: braider)
        }
        .fullScreenCover(item: $showBookingForService) { service in
            BookingSelectionView(braider: braider, preselectServiceId: service.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookingFlowFinished)) { _ in
            showBooking = false
            showBookingForService = nil
        }
        .task {
            await loadReviews()
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.1)) {
                heroAppeared = true
            }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.35)) {
                contentAppeared = true
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Hero Section
    // ═══════════════════════════════════════════════════════════════

    private var heroSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Parallax image layer
                Group {
                    if !braider.coverUrl.isEmpty {
                        RemoteImage(url: braider.coverUrl)
                            .frame(width: geo.size.width, height: geo.size.height + 120)
                            .clipped()
                    } else if let first = braider.portfolio.first {
                        RemoteImage(url: first.imageUrl)
                            .frame(width: geo.size.width, height: geo.size.height + 120)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color.appSurfaceInverse, Color.appInk],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width, height: geo.size.height + 120)
                    }
                }
                .offset(y: heroParallax)
                .scaleEffect(heroScale, anchor: .top)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Cinematic gradient overlay
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.12), location: 0.55),
                        .init(color: .black.opacity(0.75), location: 0.85),
                        .init(color: .black.opacity(0.95), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // Hero content — fades as we scroll
                heroContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(1 - min(collapseProgress * 1.5, 1))
                    .offset(y: -collapseProgress * 40)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Verified eyebrow
            HStack(spacing: 8) {
                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appAccentSoft)
                    Text("VERIFIED ARTIST")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("INDEPENDENT BRAIDER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 20)

            // Oversized name
            HStack(alignment: .top, spacing: 12) {
                Text(braider.name)
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .tracking(-1.4)
                    .foregroundStyle(.white)
                    .lineSpacing(-6)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 4)

                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.appAccentSoft)
                        .padding(.top, 10)
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 30)

            if !braider.tagline.isEmpty {
                Text(braider.tagline)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 30)
            }

            // Meta row
            HStack(spacing: 12) {
                metaPill(icon: "mappin", text: braider.city)
                metaPill(icon: "star.fill", text: ratingText, accent: true)
                metaPill(icon: "text.bubble", text: "\(ratingCount)")
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaPill(icon: String, text: String, accent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accent ? Color.appAccentSoft : .white.opacity(0.85))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Sticky Compact Header
    // ═══════════════════════════════════════════════════════════════

    private var compactHeader: some View {
        HStack(spacing: 12) {
            BMGlassIconButton(icon: "chevron.left", size: 40, iconSize: 14, tint: .appInk) {
                dismiss()
            }

            HStack(spacing: 10) {
                if braider.avatarUrl.isEmpty {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text(braider.initials)
                                .font(.bmUI(12, weight: .bold))
                                .foregroundStyle(Color.appAccent)
                        )
                } else {
                    RemoteImage(url: braider.avatarUrl)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(braider.name)
                            .font(.bmUI(14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.bmUI(10))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(8))
                            .foregroundStyle(Color.appAccent)
                        Text(ratingText)
                            .font(.bmMono(10, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text("\(ratingCount) reviews")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appAsh)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.appDivider.opacity(0.5), lineWidth: 0.5))
            .shadow(color: Color.appInk.opacity(0.06), radius: 10, y: 4)

            Spacer()

            BMGlassIconButton(
                icon: isSaved ? "heart.fill" : "heart",
                size: 40,
                iconSize: 15,
                tint: isSaved ? Color.appAlert : .appInk
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    savedPulse = true
                }
                Task {
                    guard !session.uid.isEmpty else { return }
                    await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                    Haptic.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        savedPulse = false
                    }
                }
            }
            .scaleEffect(savedPulse ? 1.2 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 12)
        .background(
            Group {
                if collapseProgress > 0.4 {
                    Color.appBackground
                        .opacity(collapseProgress)
                        .ignoresSafeArea(edges: .top)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.appDivider.opacity(0.5))
                                .frame(height: 0.5)
                                .opacity((collapseProgress - 0.4) / 0.6)
                        }
                }
            }
        )
        .opacity(collapseProgress > 0.4 ? min((collapseProgress - 0.4) / 0.5, 1) : 0)
        .animation(.smooth(duration: 0.25), value: collapseProgress)
    }

    private var floatingTopControls: some View {
        HStack {
            BMGlassIconButton(icon: "chevron.left", size: 46, iconSize: 15, tint: .white) {
                dismiss()
            }

            Spacer()

            BMGlassIconButton(
                icon: isSaved ? "heart.fill" : "heart",
                size: 46,
                iconSize: 16,
                tint: isSaved ? Color.appAlert : .white
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    savedPulse = true
                }
                Task {
                    guard !session.uid.isEmpty else { return }
                    await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                    Haptic.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        savedPulse = false
                    }
                }
            }
            .scaleEffect(savedPulse ? 1.2 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Content Sections
    // ═══════════════════════════════════════════════════════════════

    private var contentSections: some View {
        VStack(spacing: 0) {
            metricsStrip
            bioSection
            specialtiesScroll
            portfolioGallery
            servicesList
            reviewsEditorial
            footer
        }
        .padding(.bottom, 100)
    }

    // ─── Metrics Strip ───

    private var metricsStrip: some View {
        HStack(spacing: 0) {
            metricCell(value: ratingText, label: "Rating", icon: "star.fill")
            divider
            metricCell(value: "\(ratingCount)", label: "Reviews")
            divider
            metricCell(value: "\(braider.services.count)", label: "Services")
            divider
            metricCell(value: "£\(braider.priceFrom)", label: "From")
        }
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [Color.appBackground, Color.appSurface.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appDivider)
                .frame(height: 0.5)
        }
        .opacity(contentAppeared ? 1 : 0)
        .offset(y: contentAppeared ? 0 : 20)
    }

    private func metricCell(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Text(value)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .contentTransition(.numericText())
            }
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(width: 0.5, height: 32)
    }

    // ─── Bio ───

    private var bioSection: some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    editorialEyebrow("THE ARTIST")

                    Text(braider.bio)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.appInk.opacity(0.85))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }
        }
    }

    private func editorialEyebrow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.appAccent)
                .frame(width: 24, height: 1.5)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(Color.appAsh)
        }
    }

    // ─── Specialties ───

    private var specialtiesScroll: some View {
        Group {
            if !braider.specialties.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(braider.specialties, id: \.self) { specialty in
                            Text(specialty)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appSurface, in: Capsule())
                                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 0.8))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 28)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }
        }
    }

    // ─── Portfolio Gallery ───

    private var portfolioGallery: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                editorialEyebrow("SELECTED WORK")
                Text("The portfolio")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Color.appInk)
            }
            .padding(.horizontal, 24)

            if braider.portfolio.isEmpty {
                portfolioEmpty
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { index, item in
                            PortfolioCard(item: item, index: index) {
                                Haptic.select()
                                selectedPortfolioItem = item
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.top, 40)
        .fullScreenCover(item: $selectedPortfolioItem) { item in
            PortfolioLightbox(item: item, name: braider.name)
        }
    }

    private var portfolioEmpty: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 48, height: 48)
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text("Portfolio coming soon")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text("New styles from \(braider.firstName) will appear here.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.appAccent.opacity(0.8)).frame(width: 3)
        }
    }

    // ─── Services ───

    private var servicesList: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                editorialEyebrow("MAKE IT YOURS")
                Text("Services")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Color.appInk)
            }
            .padding(.horizontal, 24)

            if braider.services.isEmpty {
                servicesEmpty
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(braider.services) { service in
                        ServiceDossierCard(service: service) {
                            Haptic.select()
                            showBookingForService = service
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 44)
    }

    private var servicesEmpty: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 48, height: 48)
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text("Services coming soon")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text("Check back soon for available styles and appointments.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.appAccent.opacity(0.8)).frame(width: 3)
        }
    }

    // ─── Reviews ───

    private var reviewsEditorial: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    editorialEyebrow("CLIENT EXPERIENCES")
                    Text("Kind words")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(-0.8)
                        .foregroundStyle(Color.appInk)
                }
                Spacer()
                if !reviews.isEmpty {
                    Button {
                        Haptic.press()
                        showAllReviews = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("All \(reviews.count)")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    }
                }
            }
            .padding(.horizontal, 24)

            if reviewsLoading {
                ProgressView()
                    .tint(Color.appAccent)
                    .scaleEffect(1.1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if reviews.isEmpty {
                reviewsEmpty
                    .padding(.horizontal, 24)
            } else {
                ratingSummary
                    .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                        EditorialReviewRow(review: review)
                            .padding(.horizontal, 24)
                        if index < min(reviews.count, 3) - 1 {
                            Rectangle()
                                .fill(Color.appDivider)
                                .frame(height: 0.5)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                if reviews.count > 3 {
                    Button {
                        Haptic.press()
                        showAllReviews = true
                    } label: {
                        HStack {
                            Text("Read all \(reviews.count) reviews")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                }
            }

            Button {
                Haptic.press()
                showWriteReview = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share your experience")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appDivider, lineWidth: 1)
                )
            }
            .buttonStyle(ProfilePressStyle())
            .padding(.horizontal, 24)
        }
        .padding(.top, 44)
    }

    private var reviewsEmpty: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 48, height: 48)
                Image(systemName: "quote.opening")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text("The first word is yours")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text("There are no reviews yet. Book an appointment and share your experience.")
                .font(.system(size: 14))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.appAccent.opacity(0.8)).frame(width: 3)
        }
    }

    private var ratingSummary: some View {
        let breakdown = RatingBreakdown.from(reviews)
        return HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ratingText)
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .tracking(-2.5)
                    .foregroundStyle(Color.appInk)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appAccent)
                    }
                }
                Text("\(reviews.count) verified")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appAsh)
                    .padding(.top, 4)
            }
            .frame(width: 130, alignment: .leading)

            Rectangle()
                .fill(Color.appDivider)
                .frame(width: 0.5, height: 90)

            VStack(alignment: .leading, spacing: 10) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                    HStack(spacing: 10) {
                        Text("\(star)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.appAsh)
                            .frame(width: 8)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.appDivider)
                                Capsule()
                                    .fill(Color.appAccent)
                                    .frame(width: geo.size.width * breakdown.ratio(for: star))
                            }
                        }
                        .frame(height: 4)
                        Text("\(breakdown.count(for: star))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.appAsh)
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
        .padding(22)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appDivider, lineWidth: 0.8)
        )
    }

    // ─── Footer ───

    private var footer: some View {
        VStack(spacing: 8) {
            Text("BRAIDME")
                .font(.system(size: 10, weight: .bold))
                .tracking(4)
                .foregroundStyle(Color.appAsh)
            Text("Good hair. Great feeling.")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Booking Dock
    // ═══════════════════════════════════════════════════════════════

    private var bookingDock: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FROM")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appAsh)
                Text("£\(braider.priceFrom)")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Color.appInk)
            }
            Spacer()
            Button {
                Haptic.press()
                showBooking = true
            } label: {
                HStack(spacing: 10) {
                    Text("Book now")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.appInkInverse)
                .padding(.horizontal, 24)
                .frame(height: 56)
                .background(Color.appInk, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.appInk.opacity(0.25), radius: 16, y: 8)
            }
            .buttonStyle(ProfilePressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)

                LinearGradient(
                    colors: [Color.clear, Color.appAccent.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    Rectangle()
                        .fill(Color.appDivider.opacity(0.6))
                        .frame(height: 0.5)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Data
    // ═══════════════════════════════════════════════════════════════

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            reviews = fetched
            reviewsLoading = false
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Preference Keys
// ═══════════════════════════════════════════════════════════════════

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HeroHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Portfolio Card
// ═══════════════════════════════════════════════════════════════════

struct PortfolioCard: View {
    let item: PortfolioItem
    let index: Int
    let onTap: () -> Void

    @State private var imageLoaded = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    RemoteImage(url: item.imageUrl)
                        .frame(width: 250, height: 320)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(14)
                }

                VStack(alignment: .leading, spacing: 5) {
                    if !item.tag.isEmpty {
                        Text(item.tag.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.appAccent)
                    }
                    if !item.caption.isEmpty {
                        Text(item.caption)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(width: 250, alignment: .leading)
            }
        }
        .buttonStyle(ProfilePressStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Service Dossier Card
// ═══════════════════════════════════════════════════════════════════

struct ServiceDossierCard: View {
    let service: BraidService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Group {
                    if !service.imageUrl.isEmpty {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 92, height: 108)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            LinearGradient(
                                colors: [Color.appAccentTint, Color.appAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(Color.appAccent)
                        }
                        .frame(width: 92, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if service.popular {
                        Text("SIGNATURE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.appAccent)
                    }
                    Text(service.name)
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(Color.appInk)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(service.durationText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                    HStack(spacing: 4) {
                        Text("From")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(service.priceFrom)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Color.appBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appInk)
                }
            }
            .padding(14)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appDivider, lineWidth: 0.8)
            )
            .shadow(color: Color.appInk.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(ProfilePressStyle())
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Editorial Review Row
// ═══════════════════════════════════════════════════════════════════

struct EditorialReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if review.userAvatar.isEmpty {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(review.initials)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                        )
                } else {
                    RemoteImage(url: review.userAvatar)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        Text(review.dateString)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appAsh)
                    }
                }
                Spacer()
            }

            Text(review.text)
                .font(.system(size: 15))
                .foregroundStyle(Color.appInk.opacity(0.9))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "scissors")
                        .font(.system(size: 9, weight: .semibold))
                    Text(review.styleDone)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appAccentTint, in: Capsule())
            }
        }
        .padding(.vertical, 20)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Portfolio Lightbox
// ═══════════════════════════════════════════════════════════════════

struct PortfolioLightbox: View {
    let item: PortfolioItem
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var imageScale: CGFloat = 1.08
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [Color.appAccent.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    BMGlassIconButton(icon: "xmark", size: 44, iconSize: 14, tint: .white) {
                        dismiss()
                    }
                    Spacer()
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 20)

                // Image with drag-to-dismiss feel
                RemoteImage(url: item.imageUrl)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 620)
                    .clipped()
                    .scaleEffect(imageScale)
                    .offset(y: dragOffset.height)
                    .opacity(appeared ? 1 : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 100 {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )

                Spacer(minLength: 20)

                // Caption
                VStack(spacing: 10) {
                    if !item.tag.isEmpty {
                        Text(item.tag.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(2.5)
                            .foregroundStyle(Color.appAccentSoft)
                    }
                    if !item.caption.isEmpty {
                        Text(item.caption)
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    if item.likes > 0 {
                        Label("\(item.likes)", systemImage: "heart.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 38)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
            }
        }
        .statusBarHidden()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
                imageScale = 1
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - All Reviews Sheet
// ═══════════════════════════════════════════════════════════════════

struct AllReviewsSheet: View {
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    let onWriteReview: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(reviews.enumerated()), id: \.element.id) { index, r in
                            EditorialReviewRow(review: r)
                                .padding(.horizontal, 24)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.03),
                                    value: appeared
                                )

                            if index < reviews.count - 1 {
                                Rectangle()
                                    .fill(Color.appDivider)
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 24)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                }
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInk)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptic.press()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onWriteReview()
                        }
                    } label: {
                        Text("Write")
                            .font(.bmUI(15, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Press Style
// ═══════════════════════════════════════════════════════════════════

struct ProfilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}