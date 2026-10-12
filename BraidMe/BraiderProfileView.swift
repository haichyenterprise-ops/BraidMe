import SwiftUI

// =============================================================================
// BraiderProfileView — rebuilt, editorial edition
//
// Design direction: premium editorial magazine.
//   · Full-bleed cinematic hero with parallax + reputation band
//   · Signature "signature" monogram treatment
//   · Portfolio as a hero mosaic (1 large + 2 stacked), not a flat grid
//   · Story as a pull-quote with drop-cap first letter
//   · Services as cards with price prominence
//   · Reviews with prominent aggregate card
//   · Sticky booking bar with price-anchored CTA
//
// No custom drag gesture. No nested horizontal scroll. No preference keys.
// Everything is native SwiftUI. Nothing fights anything.
// =============================================================================

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var showAllReviews = false
    @State private var showWriteReview = false
    @State private var appeared = false

    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }
    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }
    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                reputationBand
                contentBody
            }
            .padding(.bottom, 140)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bookingBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptic.press()
                    Task {
                        let uid = session.uid
                        guard !uid.isEmpty else { return }
                        await fb.toggleSave(braiderId: braider.id, uid: uid)
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.appAlert : Color.appInk)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsSheet(
                braider: braider,
                reviews: reviews,
                breakdown: RatingBreakdown.from(reviews),
                onWriteReview: { showWriteReview = true }
            )
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(braider: braider) {
                Task { await loadReviews() }
            }
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
            appeared = true
            await loadReviews()
        }
    }

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            self.reviews = fetched
            self.reviewsLoading = false
        }
    }

    // MARK: - Hero
    //
    // 460pt. Full-bleed cover, layered gradient, name in display type.
    // Avatar sits at the bottom edge, half-overlapping the reputation band
    // below so the two sections visually interlock.

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover
            Group {
                if !braider.coverUrl.isEmpty {
                    RemoteImage(url: braider.coverUrl)
                        .frame(height: 460)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    Color.appSurfaceInverse.frame(height: 460)
                }
            }

            // Editorial gradient
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0.0),
                    .init(color: .black.opacity(0.12), location: 0.32),
                    .init(color: .clear, location: 0.48),
                    .init(color: .black.opacity(0.42), location: 0.78),
                    .init(color: .black.opacity(0.94), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 460)

            // Text stack
            VStack(alignment: .leading, spacing: Space.md) {
                Spacer()

                // Verified chip
                if braider.verified {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.bmUI(10, weight: .bold))
                        Text("Verified")
                            .font(.bmUI(10, weight: .semibold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(Color.appAccentSoft)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }

                // Name
                Text(braider.name)
                    .font(.bmDisplay(38, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 3)

                // Tagline
                if !braider.tagline.isEmpty {
                    Text(braider.tagline)
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInkInverse.opacity(0.88))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 78)
        }
        .frame(height: 460)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            // Avatar overlapping the band below
            BMAvatar(
                url: braider.avatarUrl,
                size: 96,
                ringed: false,
                initials: initials
            )
            .overlay(
                Circle().stroke(Color.appBackground, lineWidth: 5)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
            .padding(.leading, Space.lg)
            .offset(y: 48)
        }
    }

    // MARK: - Reputation band
    //
    // A dark ink band showing rating, city, response time as a single row.
    // Avatar overlaps its top edge, creating a nice interlock.

    private var reputationBand: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                reputationItem(
                    value: String(format: "%.1f", braider.rating),
                    label: "Rating",
                    icon: "star.fill"
                )
                reputationDivider
                reputationItem(
                    value: "\(braider.reviewCount)",
                    label: "Reviews",
                    icon: "bubble.left"
                )
                reputationDivider
                reputationItem(
                    value: "\(braider.yearsExperience) yr\(braider.yearsExperience == 1 ? "" : "s")",
                    label: "Experience",
                    icon: "clock"
                )
            }
            .padding(.vertical, Space.lg)
            .padding(.top, 40) // room for the overlapping avatar
            .background(Color.appSurfaceInverse)
        }
    }

    private var reputationDivider: some View {
        Rectangle()
            .fill(Color.appInkInverse.opacity(0.12))
            .frame(width: 0.5, height: 34)
    }

    private func reputationItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.bmUI(11, weight: .semibold))
                    .foregroundStyle(Color.appAccentSoft)
                Text(value)
                    .font(.bmDisplay(20, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
            }
            Text(label.uppercased())
                .font(.bmUI(9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.appInkInverse.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content body

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            cityStrip
            portfolioMosaic
            storySection
            specialtiesSection
            servicesSection
            reviewsSection
        }
        .padding(.top, Space.xl)
    }

    // MARK: - City strip

    private var cityStrip: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "mappin.and.ellipse")
                .font(.bmUI(13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(braider.city)
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.appInk)
            Text("·")
                .foregroundStyle(Color.appSmoke)
            Image(systemName: "clock")
                .font(.bmUI(12, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("Responds in \(braider.responseTime)")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
            Spacer()
        }
        .padding(.horizontal, Space.lg)
    }

    // MARK: - Portfolio mosaic
    //
    // Editorial layout: one hero image + two stacked, then remaining as pairs.
    // All inside a single vertical flow — no nested scroll views.

    private var portfolioMosaic: some View {
        Group {
            if !braider.portfolio.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    portfolioHeader
                    mosaicGrid
                }
                .padding(.vertical, Space.lg)
                .background(Color.appSurfaceInverse)
            }
        }
    }

    private var portfolioHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Portfolio")
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
                Text("Recent work")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appInkInverse.opacity(0.55))
            }
            Spacer()
            Text("\(braider.portfolio.count)")
                .font(.bmMono(13, weight: .semibold))
                .foregroundStyle(Color.appAccentSoft)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appInkInverse.opacity(0.08), in: Capsule())
        }
        .padding(.horizontal, Space.lg)
    }

    private var mosaicGrid: some View {
        let items = braider.portfolio
        return VStack(spacing: Space.xs) {
            // Row 1: hero image (left) + stacked pair (right)
            HStack(alignment: .top, spacing: Space.xs) {
                if items.count >= 1 {
                    PortfolioTile(item: items[0], height: 320, index: 0, appeared: appeared)
                        .frame(maxWidth: .infinity)
                }

                if items.count >= 2 {
                    VStack(spacing: Space.xs) {
                        PortfolioTile(item: items[1], height: 156, index: 1, appeared: appeared)
                        if items.count >= 3 {
                            PortfolioTile(item: items[2], height: 156, index: 2, appeared: appeared)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Space.lg)

            // Remaining items as full-width pairs
            let remaining = Array(items.dropFirst(3))
            if !remaining.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Space.xs),
                        GridItem(.flexible(), spacing: Space.xs)
                    ],
                    spacing: Space.xs
                ) {
                    ForEach(Array(remaining.enumerated()), id: \.element.id) { index, item in
                        PortfolioTile(item: item, height: 200, index: index + 3, appeared: appeared)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    // MARK: - Story with drop cap

    private var storySection: some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    BMSectionLabel(text: "The story")
                        .padding(.horizontal, Space.lg)

                    // Drop cap + body
                    HStack(alignment: .top, spacing: Space.md) {
                        // Drop cap
                        Text(String(braider.bio.first ?? "·"))
                            .font(.bmDisplay(72, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 48, alignment: .leading)
                            .lineLimit(1)
                            .baselineOffset(-8)

                        Text(String(braider.bio.dropFirst()))
                            .font(.bmDisplay(19, weight: .regular))
                            .foregroundStyle(Color.appInk)
                            .lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Space.lg)

                    // Divider flourish
                    HStack {
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: 40, height: 2)
                        Spacer()
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.xs)
                }
            }
        }
    }

    // MARK: - Specialties

    private var specialtiesSection: some View {
        Group {
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    BMSectionLabel(text: "Specialties")
                        .padding(.horizontal, Space.lg)

                    FlowLayout(spacing: Space.xs) {
                        ForEach(braider.specialties, id: \.self) { s in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: 4, height: 4)
                                Text(s)
                                    .font(.bmUI(13, weight: .medium))
                                    .foregroundStyle(Color.appInk)
                            }
                            .padding(.horizontal, Space.sm)
                            .frame(minHeight: 34)
                            .padding(.vertical, 6)
                            .background(Color.appAccentTint, in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.appAccent.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    // MARK: - Services

    private var servicesSection: some View {
        Group {
            if !braider.services.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    servicesHeader
                    servicesList
                }
            }
        }
    }

    private var servicesHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Services")
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text("Tap to book")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(.horizontal, Space.lg)
    }

    private var servicesList: some View {
        VStack(spacing: Space.sm) {
            ForEach(Array(braider.services.enumerated()), id: \.element.id) { index, service in
                ServiceCard(service: service) {
                    Haptic.select()
                    showBookingForService = service
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
            }
        }
        .padding(.horizontal, Space.lg)
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            reviewsHeader

            if reviewsLoading {
                BMLoadingView(message: "Loading reviews")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.lg)
            } else if reviews.isEmpty {
                emptyReviews
            } else {
                reviewAggregate
                reviewsList
                if reviews.count > 2 {
                    seeAllButton
                }
            }
        }
    }

    private var reviewsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reviews")
                    .font(.bmDisplay(24, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text(reviewsLoading ? "Loading…" : "\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
            Button {
                Haptic.press()
                showWriteReview = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.bmUI(11, weight: .semibold))
                    Text("Write")
                        .font(.bmUI(12, weight: .semibold))
                }
                .foregroundStyle(Color.appInkInverse)
                .padding(.horizontal, Space.sm)
                .frame(minHeight: 30)
                .padding(.vertical, 4)
                .background(Color.appAccent, in: Capsule())
            }
            .buttonStyle(BMPressStyle(scale: 0.96))
        }
        .padding(.horizontal, Space.lg)
    }

    private var reviewAggregate: some View {
        let breakdown = RatingBreakdown.from(reviews)
        return HStack(alignment: .center, spacing: Space.lg) {
            VStack(spacing: 2) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.bmDisplay(52, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .frame(width: 100)

            VStack(alignment: .leading, spacing: 5) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    ratingBar(stars: stars, count: breakdownCount(stars, breakdown), total: breakdown.total)
                }
            }
        }
        .padding(Space.md)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .padding(.horizontal, Space.lg)
    }

    private func breakdownCount(_ stars: Int, _ b: RatingBreakdown) -> Int {
        switch stars {
        case 5: return b.five
        case 4: return b.four
        case 3: return b.three
        case 2: return b.two
        default: return b.one
        }
    }

    private func ratingBar(stars: Int, count: Int, total: Int) -> some View {
        let ratio = total > 0 ? CGFloat(count) / CGFloat(total) : 0
        return HStack(spacing: Space.xs) {
            Text("\(stars)")
                .font(.bmUI(10, weight: .semibold))
                .foregroundStyle(Color.appAsh)
                .frame(width: 8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appDivider)
                    Capsule()
                        .fill(Color.appAccent)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 4)
            Text("\(count)")
                .font(.bmMono(10, weight: .medium))
                .foregroundStyle(Color.appAsh)
                .frame(width: 24, alignment: .trailing)
        }
    }

    private var reviewsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(reviews.prefix(2).enumerated()), id: \.element.id) { index, review in
                ReviewRowView(review: review)
                if index < min(reviews.count, 2) - 1 {
                    BMDivider(inset: Space.lg)
                }
            }
        }
    }

    private var seeAllButton: some View {
        Button {
            Haptic.press()
            showAllReviews = true
        } label: {
            HStack {
                Text("See all \(reviews.count) reviews")
                    .font(.bmUI(13, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            .padding(.horizontal, Space.lg)
            .frame(minHeight: 48)
        }
    }

    private var emptyReviews: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.bmUI(26, weight: .light))
                .foregroundStyle(Color.appSmoke)
            Text("No reviews yet")
                .font(.bmUI(14, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("Be the first to share your experience.")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
    }

    // MARK: - Booking bar

    private var bookingBar: some View {
        VStack(spacing: 0) {
            BMDivider()
            VStack(spacing: Space.sm) {
                if braider.services.isEmpty {
                    Text("Not taking bookings yet")
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appAsh)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                } else {
                    HStack(alignment: .center, spacing: Space.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FROM")
                                .font(.bmUI(9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(Color.appAsh)
                            Text("£\(braider.priceFrom)")
                                .font(.bmDisplay(22, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }

                        Spacer()

                        Button {
                            Haptic.press()
                            showBooking = true
                        } label: {
                            HStack(spacing: Space.xs) {
                                Image(systemName: "calendar")
                                    .font(.bmUI(14, weight: .semibold))
                                Text("Book \(firstName)")
                                    .font(.bmUI(15, weight: .semibold))
                            }
                            .foregroundStyle(Color.appInkInverse)
                            .padding(.horizontal, Space.lg)
                            .frame(minHeight: 52)
                            .background(Color.appInk, in: Capsule())
                        }
                        .buttonStyle(BMPressStyle())
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
            .background(Color.appSurface)
        }
    }
}

// =============================================================================
// Portfolio tile — image with caption overlay + reveal animation
// =============================================================================

struct PortfolioTile: View {
    let item: PortfolioItem
    let height: CGFloat
    let index: Int
    let appeared: Bool

    @State private var revealed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

            // Tag chip top-left
            if !item.tag.isEmpty {
                VStack {
                    HStack {
                        Text(item.tag.uppercased())
                            .font(.bmUI(9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Color.appInkInverse)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(Space.xs)
            }

            if !item.caption.isEmpty {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                Text(item.caption)
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .opacity(revealed ? 1 : 0)
        .scaleEffect(revealed ? 1 : 0.94)
        .animate(Motion.reveal.delay(Motion.stagger(index)), value: revealed)
        .onAppear { if appeared { revealed = true } }
        .onChange(of: appeared) { _, newValue in
            if newValue { revealed = true }
        }
    }
}

// =============================================================================
// Service card
// =============================================================================

struct ServiceCard: View {
    let service: BraidService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                // Image
                ZStack {
                    if service.imageUrl.isEmpty {
                        RoundedRectangle(cornerRadius: Radius.button)
                            .fill(Color.appDivider)
                            .frame(width: 76, height: 76)
                        Image(systemName: "photo")
                            .font(.bmUI(22))
                            .foregroundStyle(Color.appSmoke)
                    } else {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Space.xxs) {
                        Text(service.name)
                            .font(.bmUI(15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if service.popular {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.bmUI(8))
                                Text("POPULAR")
                                    .font(.bmUI(8, weight: .bold))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appAccentTint, in: Capsule())
                        }
                    }

                    Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                        .font(.bmUI(12))
                        .foregroundStyle(Color.appAsh)

                    HStack(spacing: 3) {
                        Text("from")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(service.priceFrom)")
                            .font(.bmMono(14, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    }
                }

                Spacer(minLength: 0)

                // Arrow
                ZStack {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 32, height: 32)
                    Image(systemName: "chevron.right")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(Space.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}

// =============================================================================
// Review row
// =============================================================================

struct ReviewRowView: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: review.userAvatar, size: 38, initials: userInitials)
                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    HStack(spacing: Space.xxs) {
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                                    .font(.bmUI(9))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        Text(review.dateString)
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAsh)
                    }
                }
                Spacer()
            }

            Text(review.text)
                .font(.bmUI(14))
                .foregroundStyle(Color.appInk.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                        .font(.bmUI(9, weight: .semibold))
                    Text(review.styleDone)
                        .font(.bmUI(10, weight: .semibold))
                        .tracking(0.3)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, Space.xs)
                .padding(.vertical, 4)
                .background(Color.appAccentTint, in: Capsule())
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
    }

    private var userInitials: String {
        let parts = review.userName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}

// =============================================================================
// All reviews sheet
// =============================================================================

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

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(reviews.enumerated()), id: \.element.id) { index, r in
                            ReviewRowView(review: r)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 12)
                                .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)

                            if index < reviews.count - 1 {
                                BMDivider(inset: Space.lg)
                            }
                        }
                    }
                    .padding(.vertical, Space.sm)
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
            .onAppear { appeared = true }
        }
    }
}

// =============================================================================
// Flow layout
// =============================================================================

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}