import SwiftUI
import CoreMotion
import CoreHaptics
import UIKit

// =============================================================================
// BraiderProfileView — "Haute Couture Dossier"
//
// A cinematic editorial profile. 3-layer parallax hero (image at 0.25x,
// film grain, foreground type at 1.0x). Palette-tinted ambient shadows.
// Odometer numeric roll-ins. 3D cover flow portfolio. Press-and-hold
// magnifying lens. 82pt scramble rating. Magnetic sheen CTA.
// =============================================================================

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var motion = ProfileMotion()
    @StateObject private var haptics = ProfileHaptics()

    // ─── Scroll tracking ───
    @State private var scrollOffset: CGFloat = 0
    @State private var heroHeight: CGFloat = 0

    // ─── Data ───
    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true

    // ─── Palette ───
    @State private var ambientPalette: Color? = nil

    // ─── Navigation ───
    @State private var showWriteReview = false
    @State private var showAllReviews = false
    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var selectedPortfolioItem: PortfolioItem?

    // ─── Animation ───
    @State private var heroAppeared = false
    @State private var contentAppeared = false
    @State private var savedPulse = false

    // ─── Portfolio carousel tracking ───
    @State private var portfolioScrollPosition: Int = 0

    // ─── Gyro tilt gate ───
    @AppStorage("braidme.gyroTilt") private var gyroTiltEnabled: Bool = true

    // ─── Env ───
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Computed

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }

    private var ratingText: String {
        reviews.isEmpty ? braider.ratingText :
            String(format: "%.1f", RatingBreakdown.from(reviews).average)
    }

    private var ratingCount: Int {
        reviews.isEmpty ? braider.reviewCount : reviews.count
    }

    /// Progress 0→1 as hero scrolls off screen.
    private var collapseProgress: CGFloat {
        guard heroHeight > 0 else { return 0 }
        let scrolled = -scrollOffset
        let threshold = heroHeight * 0.55
        return min(max(scrolled / threshold, 0), 1)
    }

    /// Hero image parallax — 0.25x speed.
    private var heroParallax: CGFloat {
        guard heroHeight > 0 else { return 0 }
        let scrolled = -scrollOffset
        return scrolled * 0.25
    }

    /// Foreground type parallax — 1.0x speed (slightly ahead to feel layered).
    private var foregroundParallax: CGFloat {
        guard heroHeight > 0 else { return 0 }
        let scrolled = -scrollOffset
        return scrolled * 0.55
    }

    /// Rubber-band scale on overscroll pull.
    private var heroScale: CGFloat {
        guard heroHeight > 0 else { return 1 }
        if scrollOffset > 0 {
            return 1 + (scrollOffset / heroHeight) * 0.4
        }
        return 1
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .frame(height: heroHeight > 0 ? heroHeight : 560)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ProfileHeroHeightKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )

                    contentSections
                        .background(Color.appBackground)
                }
            }
            .coordinateSpace(name: "profile-scroll")
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ProfileScrollOffsetKey.self,
                        value: proxy.frame(in: .named("profile-scroll")).minY
                    )
                }
            )
            .onPreferenceChange(ProfileScrollOffsetKey.self) { scrollOffset = $0 }
            .onPreferenceChange(ProfileHeroHeightKey.self) { heroHeight = $0 }
            .ignoresSafeArea(edges: .top)

            compactHeader
            floatingTopControls
                .opacity(1 - min(collapseProgress * 2.5, 1))
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bookingDock
        }
        .environment(\.ambientPalette, ambientPalette)
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
            haptics.prepare()
            if gyroTiltEnabled {
                motion.start()
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.78).delay(0.1)) {
                heroAppeared = true
            }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.4)) {
                contentAppeared = true
            }
        }
        .onDisappear {
            motion.stop()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Hero Section (3-layer parallax)
    // ═══════════════════════════════════════════════════════════════

    private var heroSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ─── Layer 0: Image (0.25x parallax) ───
                Group {
                    if !braider.coverUrl.isEmpty {
                        RemoteImage(url: braider.coverUrl, onPaletteReady: { color in
                            withAnimation(.easeIn(duration: 0.6)) {
                                ambientPalette = Color(uiColor: color)
                            }
                        })
                        .frame(width: geo.size.width, height: geo.size.height + 120)
                        .clipped()
                    } else if let first = braider.portfolio.first {
                        RemoteImage(url: first.imageUrl, onPaletteReady: { color in
                            withAnimation(.easeIn(duration: 0.6)) {
                                ambientPalette = Color(uiColor: color)
                            }
                        })
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

                // ─── Cinematic veil (5-stop) ───
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0.00),
                        .init(color: .clear,                location: 0.30),
                        .init(color: .black.opacity(0.10), location: 0.55),
                        .init(color: .black.opacity(0.78), location: 0.85),
                        .init(color: .black.opacity(0.98), location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // ─── Layer 1: Film grain ───
                NoiseTexture(opacity: 0.03, seed: 152)
                    .blendMode(.overlay)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)

                // ─── Layer 2: Foreground type with gyro tilt ───
                heroContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .offset(y: foregroundParallax)
                    .opacity(1 - min(collapseProgress * 1.8, 1))
                    .rotation3DEffect(
                        .degrees(gyroTiltEnabled ? motion.tiltX : 0),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.4
                    )
                    .rotation3DEffect(
                        .degrees(gyroTiltEnabled ? motion.tiltY : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ─── Gold eyebrow with rule ───
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 22, height: 1.5)

                HStack(spacing: 6) {
                    if braider.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.goldLight)
                    }
                    Text(heroEyebrowText)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 20)

            // ─── Serif name (48pt) ───
            HStack(alignment: .top, spacing: 12) {
                Text(braider.name)
                    .font(.system(size: 48, weight: .regular, design: .serif))
                    .tracking(-1.8)
                    .foregroundStyle(.white)
                    .lineSpacing(-6)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 6)

                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.goldLight)
                        .padding(.top, 12)
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 30)

            // ─── Tagline (serif italic 15pt) ───
            if !braider.tagline.isEmpty {
                Text(braider.tagline)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 30)
            }

            // ─── Meta pills ───
            HStack(spacing: 8) {
                metaPill(icon: "mappin.and.ellipse", text: braider.shortLocation)
                metaPill(icon: "star.fill", text: ratingText, accent: true)
                metaPill(icon: "text.bubble.fill", text: "\(ratingCount)")
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroEyebrowText: String {
        if braider.verified { return "VERIFIED ARTIST" }
        return "INDEPENDENT BRAIDER"
    }

    private func metaPill(icon: String, text: String, accent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accent ? Color.goldLight : .white.opacity(0.85))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Floating Top Controls
    // ═══════════════════════════════════════════════════════════════

    private var floatingTopControls: some View {
        HStack {
            glassButton(icon: "chevron.left", tint: .white) {
                Haptic.press()
                haptics.play(.dismiss)
                dismiss()
            }

            Spacer()

            glassButton(
                icon: isSaved ? "heart.fill" : "heart",
                tint: isSaved ? Color.appAlert : .white
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    savedPulse = true
                }
                Haptic.press()
                haptics.play(.select)
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

    private func glassButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                )
        }
        .buttonStyle(BMIconPressStyle())
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Compact Sticky Header
    // ═══════════════════════════════════════════════════════════════

    private var compactHeader: some View {
        HStack(spacing: 12) {
            smallGlassButton(icon: "chevron.left") {
                Haptic.press()
                haptics.play(.dismiss)
                dismiss()
            }

            HStack(spacing: 10) {
                if braider.avatarUrl.isEmpty {
                    Circle()
                        .fill(Color.gold.opacity(0.18))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Text(braider.initials)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.gold)
                        )
                } else {
                    RemoteImage(url: braider.avatarUrl)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(braider.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gold)
                        }
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.gold)
                        Text(ratingText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.appInk)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text("\(ratingCount) reviews")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appAsh)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.appDivider.opacity(0.5), lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)

            Spacer()

            smallGlassButton(
                icon: isSaved ? "heart.fill" : "heart",
                tint: isSaved ? Color.appAlert : Color.appInk
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    savedPulse = true
                }
                Haptic.press()
                haptics.play(.select)
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
                    ZStack {
                        Color.appBackground
                            .opacity(collapseProgress)
                            .ignoresSafeArea(edges: .top)

                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.clear,
                                            Color.gold.opacity(0.35),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.8)
                                .opacity((collapseProgress - 0.4) / 0.6)
                        }
                    }
                }
            }
        )
        .opacity(collapseProgress > 0.4 ? min((collapseProgress - 0.4) / 0.5, 1) : 0)
        .animation(.smooth(duration: 0.25), value: collapseProgress)
    }

    private func smallGlassButton(icon: String, tint: Color = .appInk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Color.appDivider.opacity(0.6), lineWidth: 0.5))
        }
        .buttonStyle(BMIconPressStyle())
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Content Sections
    // ═══════════════════════════════════════════════════════════════

    private var contentSections: some View {
        VStack(spacing: 0) {
            metricsCard
            bioSection
            specialtiesMarquee
            portfolioGallery
            servicesList
            reviewsEditorial
            footer
        }
        .padding(.bottom, 110)
    }

    // ─── Metrics Card (floating monolith) ───

    private var metricsCard: some View {
        HStack(spacing: 0) {
            ProfileMetricCell(
                value: ratingText,
                label: "Rating",
                icon: "star.fill",
                appeared: contentAppeared,
                delay: 0.0
            )
            metricDivider
            ProfileMetricCell(
                value: "\(braider.yearsExperience)",
                label: "Years",
                appeared: contentAppeared,
                delay: 0.05
            )
            metricDivider
            ProfileMetricCell(
                value: "\(ratingCount)",
                label: "Reviews",
                appeared: contentAppeared,
                delay: 0.1
            )
            metricDivider
            ProfileMetricCell(
                value: "£\(braider.priceFrom)",
                label: "From",
                appeared: contentAppeared,
                delay: 0.15
            )
        }
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous)
                .fill(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.goldLight.opacity(0.35),
                                    Color.gold.opacity(0.12),
                                    Color.goldDeep.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 28, y: 14)
                .shadow(color: (ambientPalette ?? Color.black).opacity(0.10), radius: 40, y: 8)
        }
        .padding(.horizontal, 24)
        .offset(y: -70)
        .padding(.bottom, -70)
        .opacity(contentAppeared ? 1 : 0)
        .scaleEffect(contentAppeared ? 1 : 0.94)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gold.opacity(0),
                        Color.gold.opacity(0.35),
                        Color.gold.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 0.5, height: 40)
    }

    // ─── Bio ───

    private var bioSection: some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.gold)
                            .frame(width: 24, height: 1.5)
                        Text("THE ARTIST")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Color.appAsh)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gold, Color.gold.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 3)
                            .frame(maxHeight: .infinity)

                        Text(braider.bio)
                            .font(.system(size: 17, weight: .regular, design: .serif))
                            .foregroundStyle(Color.appInk.opacity(0.9))
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }
        }
    }

    // ─── Specialties Marquee ───

    private var specialtiesMarquee: some View {
        Group {
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.gold)
                            .frame(width: 24, height: 1.5)
                        Text("SIGNATURES")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.horizontal, 24)

                    MarqueeView(
                        items: braider.specialties,
                        spacing: 10
                    )
                }
                .padding(.top, 30)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }
        }
    }

    // ─── Portfolio (3D cover flow) ───

    private var portfolioGallery: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.gold)
                        .frame(width: 24, height: 1.5)
                    Text("SELECTED WORK")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.appAsh)
                }
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
                PortfolioCoverFlow(
                    items: braider.portfolio,
                    onSelect: { item in
                        Haptic.select()
                        haptics.play(.select)
                        selectedPortfolioItem = item
                    }
                )
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
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.gold)
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous))
        .dualLayerGlassStroke(cornerRadius: Radius.squircle)
    }

    // ─── Services ───

    private var servicesList: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.gold)
                        .frame(width: 24, height: 1.5)
                    Text("CRAFTED SESSIONS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.appAsh)
                }
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
                VStack(spacing: 14) {
                    ForEach(braider.services) { service in
                        ServiceCoutureCard(service: service) {
                            Haptic.press()
                            haptics.play(.select)
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
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.gold)
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous))
        .dualLayerGlassStroke(cornerRadius: Radius.squircle)
    }

    // ─── Reviews ───

    private var reviewsEditorial: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.gold)
                            .frame(width: 24, height: 1.5)
                        Text("THE RECORD")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Color.appAsh)
                    }
                    Text("Kind words")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(-0.8)
                        .foregroundStyle(Color.appInk)
                }
                Spacer()
                if !reviews.isEmpty {
                    Button {
                        Haptic.press()
                        haptics.play(.select)
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
                    .tint(Color.gold)
                    .scaleEffect(1.1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if reviews.isEmpty {
                reviewsEmpty
                    .padding(.horizontal, 24)
            } else {
                GiantRatingBlock(
                    ratingText: ratingText,
                    reviewCount: reviews.count,
                    breakdown: RatingBreakdown.from(reviews),
                    appeared: contentAppeared
                )
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                        EditorialReviewCard(review: review)
                            .padding(.horizontal, 24)

                        if index < min(reviews.count, 3) - 1 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.gold.opacity(0),
                                            Color.gold.opacity(0.25),
                                            Color.gold.opacity(0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 0.5)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                if reviews.count > 3 {
                    Button {
                        Haptic.press()
                        haptics.play(.select)
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
                haptics.play(.select)
                showWriteReview = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Write about your visit")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color.goldInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.gold.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.gold.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(BMSquirclePressStyle())
            .padding(.horizontal, 24)
        }
        .padding(.top, 44)
    }

    private var reviewsEmpty: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "quote.opening")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.gold)
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous))
        .dualLayerGlassStroke(cornerRadius: Radius.squircle)
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
        .padding(.bottom, 30)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Booking Dock (Magnetic Sheen CTA)
    // ═══════════════════════════════════════════════════════════════

    private var bookingDock: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("FROM")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.appAsh)
                Text("£\(braider.priceFrom)")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .tracking(-0.5)
                    .foregroundStyle(Color.appInk)
            }
            Spacer()

            MagneticSheenCTA(
                title: "Book now",
                price: braider.priceFrom,
                ambientPalette: ambientPalette,
                onTap: {
                    Haptic.press()
                    haptics.play(.pinExpand)
                    showBooking = true
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)

                LinearGradient(
                    colors: [Color.clear, Color.gold.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.gold.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.8)
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

struct ProfileScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ProfileHeroHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Metric Cell (odometer numeric roll-in)
// ═══════════════════════════════════════════════════════════════════

struct ProfileMetricCell: View {
    let value: String
    let label: String
    var icon: String? = nil
    let appeared: Bool
    let delay: Double

    @State private var displayValue: String = "0"

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }
                Text(displayValue)
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .contentTransition(.numericText(countsDown: false))
            }
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    displayValue = value
                }
            }
        }
        .onChange(of: value) { _, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                displayValue = new
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Marquee View (auto-scrolling chips)
// ═══════════════════════════════════════════════════════════════════

struct MarqueeView: View {
    let items: [String]
    let spacing: CGFloat
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var isPaused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: spacing) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: spacing) {
                        ForEach(items, id: \.self) { item in
                            chipView(item)
                        }
                    }
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: WidthKey.self,
                                value: inner.size.width
                            )
                        }
                    )
                }
            }
            .offset(x: offset)
            .onPreferenceChange(WidthKey.self) { width in
                contentWidth = width
            }
            .onAppear {
                guard !reduceMotion else { return }
                startMarquee()
            }
        }
        .frame(height: 40)
        .clipped()
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .serif))
            .foregroundStyle(Color.appInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.appSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.appDivider, lineWidth: 0.8))
            .onTapGesture {
                isPaused.toggle()
                Haptic.select()
            }
    }

    private func startMarquee() {
        guard contentWidth > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startMarquee()
            }
            return
        }
        let totalWidth = contentWidth / 2 + spacing
        let duration = Double(totalWidth) / 40.0
        offset = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalWidth
        }
    }
}

private struct WidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Portfolio Cover Flow (3D perspective carousel)
// ═══════════════════════════════════════════════════════════════════

struct PortfolioCoverFlow: View {
    let items: [PortfolioItem]
    let onSelect: (PortfolioItem) -> Void

    @State private var scrollPosition: Int = 0
    private let cardWidth: CGFloat = 280
    private let cardHeight: CGFloat = 380
    private let spacing: CGFloat = 22

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PortfolioCoverCard(
                        item: item,
                        index: index,
                        isCentered: scrollPosition == index,
                        onTap: { onSelect(item) }
                    )
                    .frame(width: cardWidth, height: cardHeight + 70)
                    .id(index)
                }
            }
            .padding(.horizontal, 60)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding(
            get: { Optional(scrollPosition) },
            set: { newValue in
                if let newValue {
                    Haptic.light()
                    scrollPosition = newValue
                }
            }
        ))
        .safeAreaPadding(.horizontal, 0)
    }
}

struct PortfolioCoverCard: View {
    let item: PortfolioItem
    let index: Int
    let isCentered: Bool
    let onTap: () -> Void

    @State private var magnifierActive = false
    @State private var magnifierOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                // Image
                RemoteImage(url: item.imageUrl)
                    .frame(width: 280, height: 380)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Magnifier lens
                if magnifierActive {
                    MagnifierLens(
                        imageUrl: item.imageUrl,
                        offset: magnifierOffset,
                        size: 140
                    )
                    .offset(magnifierOffset)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
                }

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)

                // Holographic index number
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                    .padding(16)
                    .overlay(alignment: .topLeading) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.goldLight, Color.gold, Color.goldDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(16)
                            .blendMode(.plusLighter)
                            .opacity(0.6)
                    }
                    .allowsHitTesting(false)
            }

            // Meta
            VStack(alignment: .leading, spacing: 5) {
                if !item.tag.isEmpty {
                    Text(item.tag.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.gold)
                }
                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(width: 280, alignment: .leading)
        }
        .scaleEffect(isCentered ? 1.0 : 0.88)
        .opacity(isCentered ? 1.0 : 0.55)
        .rotation3DEffect(
            .degrees(isCentered ? 0 : 12),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 0.5
        )
        .shadow(
            color: isCentered ? Color.gold.opacity(0.35) : Color.black.opacity(0.08),
            radius: isCentered ? 30 : 12,
            y: isCentered ? 14 : 6
        )
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isCentered)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                magnifierActive = pressing
            }
            if pressing { Haptic.medium() }
        }, perform: {})
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard magnifierActive else { return }
                    magnifierOffset = CGSize(
                        width: value.translation.width,
                        height: value.translation.height
                    )
                }
        )
    }
}

struct MagnifierLens: View {
    let imageUrl: String
    let offset: CGSize
    let size: CGFloat

    var body: some View {
        ZStack {
            RemoteImage(url: imageUrl)
                .frame(width: 280 * 2.5, height: 380 * 2.5)
                .offset(
                    x: -offset.width * 1.5,
                    y: -offset.height * 1.5
                )
                .clipShape(Circle())
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color.goldLight, Color.gold, Color.goldDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                )
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.8))
                .shadow(color: Color.gold.opacity(0.4), radius: 20, y: 6)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        }
        .offset(x: 140, y: 190)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Service Couture Card
// ═══════════════════════════════════════════════════════════════════

struct ServiceCoutureCard: View {
    let service: BraidService
    let onTap: () -> Void

    @State private var expanded = false
    @State private var sheen: CGFloat = -1

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // ── Image as background ──
                ZStack(alignment: .topTrailing) {
                    Group {
                        if !service.imageUrl.isEmpty {
                            RemoteImage(url: service.imageUrl)
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } else {
                            LinearGradient(
                                colors: [
                                    Color.gold.opacity(0.18),
                                    Color.goldDeep.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 160)
                        }
                    }
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )

                    // ── Signature ribbon ──
                    if service.popular {
                        ZStack {
                            Text("SIGNATURE")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.goldInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    LinearGradient(
                                        colors: [Color.goldLight, Color.gold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))

                            // Sheen sweep
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            .white.opacity(0.6),
                                            .clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 40, height: 22)
                                .offset(x: sheen * 60)
                                .blendMode(.overlay)
                                .clipShape(Capsule())
                                .allowsHitTesting(false)
                        }
                        .padding(12)
                    }

                    // ── Text overlay ──
                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()

                        Text(service.name)
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .tracking(-0.3)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(service.durationText)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.85))

                            Text("·")
                                .foregroundStyle(.white.opacity(0.5))

                            Text("£\(service.priceFrom)")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.goldLight)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .clipShape(
                    .rect(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 14
                    )
                )

                // ── Includes row ──
                if !service.includes.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(service.includes.prefix(3), id: \.self) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.gold)
                                Text(item)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.appInkSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.appInk)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appSurface)
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
        }
        .buttonStyle(BMSquirclePressStyle())
        .onAppear {
            withAnimation(
                .linear(duration: 2.5)
                .repeatForever(autoreverses: false)
                .delay(2)
            ) {
                sheen = 1
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Giant Rating Block (82pt + scramble)
// ═══════════════════════════════════════════════════════════════════

struct GiantRatingBlock: View {
    let ratingText: String
    let reviewCount: Int
    let breakdown: RatingBreakdown
    let appeared: Bool

    @State private var scrambleDisplay: String = "0.0"
    @State private var scrambleTimer: Timer?
    @State private var scrambleCount = 0
    @State private var barAppeared = false

    var body: some View {
        HStack(alignment: .center, spacing: 26) {
            // Left: giant scramble number
            VStack(alignment: .leading, spacing: 6) {
                Text(scrambleDisplay)
                    .font(.system(size: 82, weight: .regular, design: .serif))
                    .tracking(-4)
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(countsDown: false))

                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gold)
                    }
                }

                Text("\(reviewCount) verified")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appAsh)
                    .padding(.top, 4)
            }
            .frame(width: 160, alignment: .leading)

            // Divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gold.opacity(0),
                            Color.gold.opacity(0.4),
                            Color.gold.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 0.5, height: 100)

            // Right: tier bars
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
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.gold, Color.goldDeep],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geo.size.width * (barAppeared ? breakdown.ratio(for: star) : 0)
                                    )
                            }
                        }
                        .frame(height: 5)

                        Text("\(breakdown.count(for: star))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.appAsh)
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.squircle, style: .continuous))
        .dualLayerGlassStroke(cornerRadius: Radius.squircle)
        .shadow(color: Color.black.opacity(0.06), radius: 24, y: 12)
        .onAppear { startScramble() }
        .onDisappear { scrambleTimer?.invalidate() }
    }

    private func startScramble() {
        guard appeared else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startScramble()
            }
            return
        }

        // Character scramble over 500ms
        let target = ratingText
        let digits = Array(target)
        scrambleCount = 0

        scrambleTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            scrambleCount += 1

            if scrambleCount >= 10 {
                timer.invalidate()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    scrambleDisplay = target
                    barAppeared = true
                }
                return
            }

            var scrambled = ""
            for char in digits {
                if char.isNumber {
                    scrambled.append(String(Int.random(in: 0...9)))
                } else {
                    scrambled.append(char)
                }
            }
            scrambleDisplay = scrambled
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Editorial Review Card
// ═══════════════════════════════════════════════════════════════════

struct EditorialReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if review.userAvatar.isEmpty {
                    Circle()
                        .fill(Color.gold.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(review.initials)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.gold)
                        )
                } else {
                    RemoteImage(url: review.userAvatar)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.gold)
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
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk.opacity(0.92))
                .lineSpacing(8)
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
                .foregroundStyle(Color.goldInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gold.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(Color.gold.opacity(0.4), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 20)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Magnetic Sheen CTA
// ═══════════════════════════════════════════════════════════════════

struct MagneticSheenCTA: View {
    let title: String
    let price: Int
    let ambientPalette: Color?
    let onTap: () -> Void

    @State private var magneticOffset: CGSize = .zero
    @State private var sheen: CGFloat = -1
    @State private var pressed = false

    var body: some View {
        Button(action: {
            Haptic.press()
            onTap()
        }) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appInk)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                // Content
                HStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.goldLight)

                // Sheen sweep
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.goldLight.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.4)
                    .offset(x: sheen * geo.size.width * 1.4)
                    .blendMode(.overlay)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)

                // Gold border
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.goldLight.opacity(0.6),
                                Color.gold.opacity(0.3),
                                Color.goldDeep.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .frame(height: 56)
            .frame(minWidth: 150)
            .padding(.horizontal, 24)
            .offset(magneticOffset)
            .shadow(color: Color.appInk.opacity(0.25), radius: 16, y: 8)
            .shadow(color: (ambientPalette ?? Color.gold).opacity(0.20), radius: 20, y: 6)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    pressed = true
                    let loc = value.location
                    // Magnetic pull — offset toward finger within bounds
                    let dx = max(-4, min(4, (loc.x - 100) * 0.05))
                    let dy = max(-4, min(4, (loc.y - 28) * 0.05))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        magneticOffset = CGSize(width: dx, height: dy)
                    }
                }
                .onEnded { _ in
                    pressed = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        magneticOffset = .zero
                    }
                }
        )
        .onAppear {
            withAnimation(
                .linear(duration: 2.5)
                .repeatForever(autoreverses: false)
                .delay(3)
            ) {
                sheen = 1
            }
        }
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

            RadialGradient(
                colors: [Color.gold.opacity(0.10), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        Haptic.press()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
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

                VStack(spacing: 10) {
                    if !item.tag.isEmpty {
                        Text(item.tag.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(2.5)
                            .foregroundStyle(Color.goldLight)
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
                            EditorialReviewCard(review: r)
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
                            .foregroundStyle(Color.gold)
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
// MARK: - Profile Motion (gyro tilt for hero)
// ═══════════════════════════════════════════════════════════════════

final class ProfileMotion: ObservableObject {
    @Published var tiltX: Double = 0
    @Published var tiltY: Double = 0

    private let motionManager = CMMotionManager()
    private var isRunning = false

    func start() {
        guard motionManager.isDeviceMotionAvailable, !isRunning else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // Max 6 degrees
            let targetX = -motion.gravity.y * 6
            let targetY = motion.gravity.x * 6
            self?.tiltX = (self?.tiltX ?? 0) * 0.85 + targetX * 0.15
            self?.tiltY = (self?.tiltY ?? 0) * 0.85 + targetY * 0.15
        }
        isRunning = true
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Profile Haptics (layered CoreHaptics)
// ═══════════════════════════════════════════════════════════════════

final class ProfileHaptics: ObservableObject {
    enum Pattern {
        case select
        case tap
        case pinExpand
        case dismiss
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
                        .init(parameterID: .hapticSharpness, value: 0.65)
                    ],
                    relativeTime: 0
                )
            ]
        case .pinExpand:
            return [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.4),
                        .init(parameterID: .hapticSharpness, value: 0.25)
                    ],
                    relativeTime: 0,
                    duration: 0.22
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        .init(parameterID: .hapticIntensity, value: 0.55),
                        .init(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0.22
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
        }
    }

    private func fallback(_ pattern: Pattern) {
        switch pattern {
        case .select, .dismiss:    Haptic.select()
        case .tap:                 Haptic.light()
        case .pinExpand:           Haptic.medium()
        }
    }
}