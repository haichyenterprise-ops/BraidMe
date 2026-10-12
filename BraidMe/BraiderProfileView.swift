import SwiftUI
import CoreMotion
import CoreHaptics
import UIKit

// =============================================================================
// BraiderProfileView — Lag-free editorial profile.
// =============================================================================

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared
    @StateObject private var motion = ProfileMotion()
    @StateObject private var haptics = ProfileHaptics()

    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true
    @State private var ambientPalette: Color? = nil

    @State private var showWriteReview = false
    @State private var showAllReviews = false
    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var selectedPortfolioItem: PortfolioItem?

    @State private var heroAppeared = false
    @State private var contentAppeared = false
    @State private var savedPulse = false

    @State private var portfolioIndex: Int = 0

    @AppStorage("braidme.gyroTilt") private var gyroTiltEnabled: Bool = true

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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                contentSections
                    .background(Color.appBackground)
            }
        }
        .coordinateSpace(name: "profile-scroll")
        .background(Color.appBackground)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            topControls
        }
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
            haptics.prepare()
            if gyroTiltEnabled { motion.start() }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { heroAppeared = true }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) { contentAppeared = true }
        }
        .onDisappear {
            motion.stop()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Hero

    private var hero: some View {
        GeometryReader { geo in            let minY = geo.frame(in: .named("profile-scroll")).minY
            let stretch = max(0, minY)
            let parallax = minY * 0.4

            ZStack(alignment: .bottom) {
                Group {
                    if !braider.coverUrl.isEmpty {
                        RemoteImage(url: braider.coverUrl, onPaletteReady: { color in
                            ambientPalette = Color(uiColor: color)
                        })
                        .frame(width: geo.size.width, height: geo.size.height + 120)
                        .clipped()
                    } else if let first = braider.portfolio.first {
                        RemoteImage(url: first.imageUrl, onPaletteReady: { color in
                            ambientPalette = Color(uiColor: color)
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
                .offset(y: -parallax)
                .frame(width: geo.size.width, height: geo.size.height + stretch)
                .clipped()

                // Gradient veil
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

                heroContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .frame(height: 560)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    Text(braider.verified ? "VERIFIED ARTIST" : "INDEPENDENT BRAIDER")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 20)

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
    // MARK: - Top controls

    private var topControls: some View {
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
    // MARK: - Content

    private var contentSections: some View {
        VStack(spacing: 0) {
            metricsCard
            bioSection
            specialtiesMarquee
            portfolioSection
            servicesSection
            reviewsSection
            footerSection
        }
        .padding(.bottom, 110)
    }

    // ─── Metrics ───

    private var metricsCard: some View {
        HStack(spacing: 0) {
            metricCell(value: ratingText, label: "Rating", icon: "star.fill")
            metricDivider
            metricCell(value: "\(braider.yearsExperience)", label: "Years")
            metricDivider
            metricCell(value: "\(ratingCount)", label: "Reviews")
            metricDivider
            metricCell(value: "£\(braider.priceFrom)", label: "From")
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
                .shadow(color: (ambientPalette ?? Color.black).opacity(0.08), radius: 40, y: 8)
        }
        .padding(.horizontal, 24)
        .offset(y: -70)
        .padding(.bottom, -70)
        .opacity(contentAppeared ? 1 : 0)
        .scaleEffect(contentAppeared ? 1 : 0.94)
    }

    private func metricCell(value: String, label: String, icon: String? = nil) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }
                Text(value)
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
                    sectionEyebrow("THE ARTIST")

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
            }
        }
    }

    // ─── Specialties marquee ───

    private var specialtiesMarquee: some View {
        Group {
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionEyebrow("SIGNATURES")
                        .padding(.horizontal, 24)

                    MarqueeView(items: braider.specialties, spacing: 10)
                }
                .padding(.top, 30)
            }
        }
    }

    // ─── Portfolio ───

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                sectionEyebrow("SELECTED WORK")
                Text("The portfolio")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Color.appInk)
            }
            .padding(.horizontal, 24)

            if braider.portfolio.isEmpty {
                emptyCard(
                    icon: "camera",
                    title: "Portfolio coming soon",
                    message: "New styles from \(braider.firstName) will appear here."
                )
                .padding(.horizontal, 24)
            } else {
                // Simple horizontal scroll — cards freely swipeable
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { index, item in
                            PortfolioCardView(
                                item: item,
                                index: index,
                                onTap: {
                                    Haptic.select()
                                    haptics.play(.select)
                                    selectedPortfolioItem = item
                                }
                            )
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 40)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.top, 40)
        .fullScreenCover(item: $selectedPortfolioItem) { item in
            PortfolioLightbox(item: item, name: braider.name)
        }
    }

    // ─── Services ───

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                sectionEyebrow("CRAFTED SESSIONS")
                Text("Services")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Color.appInk)
            }
            .padding(.horizontal, 24)

            if braider.services.isEmpty {
                emptyCard(
                    icon: "calendar",
                    title: "Services coming soon",
                    message: "Check back soon for available styles and appointments."
                )
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 14) {
                    ForEach(braider.services) { service in
                        ServiceRowCard(service: service) {
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

    // ─── Reviews ───

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    sectionEyebrow("THE RECORD")
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
                emptyCard(
                    icon: "quote.opening",
                    title: "The first word is yours",
                    message: "There are no reviews yet. Book an appointment and share your experience."
                )
                .padding(.horizontal, 24)
            } else {
                RatingSummaryBlock(
                    ratingText: ratingText,
                    reviewCount: reviews.count,
                    breakdown: RatingBreakdown.from(reviews)
                )
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                        EditorialReviewCard(review: review)
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

    private var footerSection: some View {
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
    // MARK: - Helpers

    private func sectionEyebrow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.gold)
                .frame(width: 24, height: 1.5)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(Color.appAsh)
        }
    }

    private func emptyCard(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Color.gold)
            }
            Text(title)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text(message)
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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Booking dock

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

            Button {
                Haptic.press()
                haptics.play(.pinExpand)
                showBooking = true
            } label: {
                HStack(spacing: 10) {
                    Text("Book now")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.goldLight)
                .padding(.horizontal, 24)
                .frame(height: 56)
                .background(Color.appInk)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
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
                )
                .shadow(color: Color.appInk.opacity(0.25), radius: 16, y: 8)
                .shadow(color: (ambientPalette ?? Color.gold).opacity(0.2), radius: 20, y: 6)
            }
            .buttonStyle(BMSquirclePressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
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
// MARK: - Portfolio Card (working swipe + magnifier)
// ═══════════════════════════════════════════════════════════════════

struct PortfolioCardView: View {
    let item: PortfolioItem
    let index: Int
    let onTap: () -> Void

    @State private var magnifierActive = false
    @State private var magnifierLocation: CGPoint = CGPoint(x: 130, y: 170)

    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 340

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ─── Image ───
            RemoteImage(url: item.imageUrl)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // ─── Gradient overlay ───
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .allowsHitTesting(false)

            // ─── Index ───
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                .padding(16)
                .allowsHitTesting(false)

            // ─── Gold border ───
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goldLight.opacity(0.7),
                            Color.gold.opacity(0.2),
                            Color.goldDeep.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)

            // ─── Magnifier lens ───
            if magnifierActive {
                MagnifierLens(
                    imageUrl: item.imageUrl,
                    location: magnifierLocation,
                    cardSize: CGSize(width: cardWidth, height: cardHeight),
                    size: 140
                )
                .allowsHitTesting(false)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.25, pressing: { pressing in
            if pressing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    magnifierActive = true
                }
                Haptic.medium()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    magnifierActive = false
                }
            }
        }, perform: {})
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if magnifierActive {
                        magnifierLocation = value.location
                    }
                }
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Magnifier Lens
// ═══════════════════════════════════════════════════════════════════

struct MagnifierLens: View {
    let imageUrl: String
    let location: CGPoint
    let cardSize: CGSize
    let size: CGFloat
    var zoomFactor: CGFloat = 2.2

    var body: some View {
        ZStack {
            GeometryReader { _ in
                ZStack {
                    RemoteImage(url: imageUrl)
                        .frame(
                            width: cardSize.width * zoomFactor,
                            height: cardSize.height * zoomFactor
                        )
                        .offset(
                            x: -(location.x * zoomFactor) + size / 2,
                            y: -(location.y * zoomFactor) + size / 2
                        )
                }
                .frame(width: size, height: size)
                .clipped()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.goldLight, Color.gold, Color.goldDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )

            Circle()
                .stroke(.white.opacity(0.4), lineWidth: 0.8)
                .padding(2)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.gold.opacity(0.5), radius: 20, y: 6)
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
        .position(x: location.x, y: location.y)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Service Row Card
// ═══════════════════════════════════════════════════════════════════

struct ServiceRowCard: View {
    let service: BraidService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
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

                    if service.popular {
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
                            .padding(12)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Spacer()
                        Text(service.name)
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(service.durationText)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.85))

                            Text("·").foregroundStyle(.white.opacity(0.5))

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
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Rating Summary
// ═══════════════════════════════════════════════════════════════════

struct RatingSummaryBlock: View {
    let ratingText: String
    let reviewCount: Int
    let breakdown: RatingBreakdown

    @State private var barAppeared = false

    var body: some View {
        HStack(alignment: .center, spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ratingText)
                    .font(.system(size: 72, weight: .regular, design: .serif))
                    .tracking(-3)
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

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
            .frame(width: 150, alignment: .leading)

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
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.2)) {
                barAppeared = true
            }
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
// MARK: - Marquee
// ═══════════════════════════════════════════════════════════════════

struct MarqueeView: View {
    let items: [String]
    let spacing: CGFloat

    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { _ in
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
                                key: MarqueeWidthKey.self,
                                value: inner.size.width
                            )
                        }
                    )
                }
            }
            .offset(x: offset)
            .onPreferenceChange(MarqueeWidthKey.self) { width in
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
    }

    private func startMarquee() {
        guard contentWidth > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { startMarquee() }
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

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    @State private var imageScale: CGFloat = 1.05
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
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

                            if index < reviews.count - 1 {
                                Rectangle()
                                    .fill(Color.appDivider)
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 24)
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.gold)
                    }
                }
            }
            .onAppear { appeared = true }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Profile Motion
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
// MARK: - Profile Haptics
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