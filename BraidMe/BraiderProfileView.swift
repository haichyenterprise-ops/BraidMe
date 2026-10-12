import SwiftUI

// =============================================================================
// BraiderProfileView — Final rebuild
//
// Every container has a defined width. Every text element is line-limited.
// No nested horizontal scroll. No LazyVGrid. No preference keys. No custom
// drag gesture. Nothing escapes the screen.
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
        GeometryReader { geo in
            let width = geo.size.width

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    hero(width: width)
                    reputationBand(width: width)
                    contentBody(width: width)
                }
                .frame(width: width)
                .padding(.bottom, 140)
            }
            .frame(width: width)
            .background(Color.appBackground)
        }
        .background(Color.appBackground.ignoresSafeArea())
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

    // =========================================================================
    // MARK: - HERO
    // =========================================================================

    private func hero(width: CGFloat) -> some View {
        let heroHeight: CGFloat = 460
        let gutter = Space.lg

        return ZStack(alignment: .top) {

            Group {
                if !braider.coverUrl.isEmpty {
                    RemoteImage(url: braider.coverUrl)
                        .frame(width: width, height: heroHeight)
                        .clipped()
                } else {
                    Color.appSurfaceInverse
                        .frame(width: width, height: heroHeight)
                }
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0.0),
                    .init(color: .black.opacity(0.10), location: 0.32),
                    .init(color: .clear, location: 0.50),
                    .init(color: .black.opacity(0.50), location: 0.80),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: heroHeight)

            VStack(alignment: .leading, spacing: Space.sm) {

                Spacer()

                if braider.verified {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.bmUI(10, weight: .bold))
                        Text("Verified")
                            .font(.bmUI(10, weight: .semibold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                }

                Text(braider.name)
                    .font(.bmDisplay(36, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 3)
                    .frame(width: width - gutter * 2, alignment: .leading)

                if !braider.tagline.isEmpty {
                    Text(braider.tagline)
                        .font(.bmUI(15, weight: .medium))
                        .foregroundStyle(Color.appInkInverse.opacity(0.90))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                        .frame(width: width - gutter * 2, alignment: .leading)
                }

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.bmUI(11, weight: .semibold))
                        .foregroundStyle(Color.appAccentSoft)
                    Text(String(format: "%.1f", braider.rating))
                        .font(.bmMono(13, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                    Text("·")
                        .foregroundStyle(Color.appInkInverse.opacity(0.5))
                    Text("\(braider.reviewCount) review\(braider.reviewCount == 1 ? "" : "s")")
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appInkInverse.opacity(0.85))
                    Text("·")
                        .foregroundStyle(Color.appInkInverse.opacity(0.5))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.bmUI(11, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse.opacity(0.8))
                    Text(braider.city)
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appInkInverse.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(width: width - gutter * 2, alignment: .leading)
            }
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, gutter)
            .padding(.bottom, 60)
        }
        .frame(width: width, height: heroHeight)
        .overlay(alignment: .bottomLeading) {
            BMAvatar(url: braider.avatarUrl, size: 92, ringed: false, initials: initials)
                .overlay(Circle().stroke(Color.appBackground, lineWidth: 5))
                .shadow(color: .black.opacity(0.28), radius: 16, y: 6)
                .padding(.leading, gutter)
                .offset(y: 46)
        }
    }

    // =========================================================================
    // MARK: - REPUTATION BAND
    // =========================================================================

    private func reputationBand(width: CGFloat) -> some View {
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
                    value: "\(braider.yearsExperience) yrs",
                    label: "Experience",
                    icon: "clock"
                )
            }
            .frame(width: width)
            .padding(.top, 56)
            .padding(.bottom, Space.lg)
        }
        .background(Color.appSurfaceInverse)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label.uppercased())
                .font(.bmUI(9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.appInkInverse.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // =========================================================================
    // MARK: - CONTENT BODY
    // =========================================================================

    private func contentBody(width: CGFloat) -> some View {
        let gutter = Space.lg
        let inner = width - gutter * 2

        return VStack(alignment: .leading, spacing: Space.xxl) {
            cityStrip(width: width, inner: inner)
            portfolioSection(width: width, inner: inner)
            storySection(inner: inner)
            specialtiesSection(inner: inner)
            servicesSection(width: width, inner: inner)
            reviewsSection(width: width, inner: inner)
        }
        .frame(width: width, alignment: .leading)
        .padding(.top, Space.xl)
    }

    private func cityStrip(width: CGFloat, inner: CGFloat) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "mappin.and.ellipse")
                .font(.bmUI(13, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(braider.city)
                .font(.bmUI(14, weight: .medium))
                .foregroundStyle(Color.appInk)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(Color.appSmoke)
            Image(systemName: "clock")
                .font(.bmUI(12, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text("Responds in \(braider.responseTime)")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(width: inner, alignment: .leading)
        .padding(.horizontal, Space.lg)
    }

    // =========================================================================
    // MARK: - PORTFOLIO
    // =========================================================================

    private func portfolioSection(width: CGFloat, inner: CGFloat) -> some View {
        Group {
            if !braider.portfolio.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
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
                    .frame(width: inner, alignment: .leading)
                    .padding(.horizontal, Space.lg)

                    portfolioGrid(inner: inner)
                }
                .frame(width: width)
                .padding(.vertical, Space.lg)
                .background(Color.appSurfaceInverse)
            }
        }
    }

    private func portfolioGrid(inner: CGFloat) -> some View {
        let items = braider.portfolio
        let halfWidth = (inner - Space.xs) / 2

        return VStack(spacing: Space.xs) {

            if items.count >= 3 {
                HStack(alignment: .top, spacing: Space.xs) {
                    PortfolioTile(item: items[0], height: 320, index: 0, appeared: appeared)
                        .frame(width: halfWidth, height: 320)

                    VStack(spacing: Space.xs) {
                        PortfolioTile(item: items[1], height: 156, index: 1, appeared: appeared)
                            .frame(width: halfWidth, height: 156)
                        PortfolioTile(item: items[2], height: 156, index: 2, appeared: appeared)
                            .frame(width: halfWidth, height: 156)
                    }
                    .frame(width: halfWidth)
                }
                .frame(width: inner)
                .padding(.horizontal, Space.lg)
            } else if items.count == 2 {
                HStack(spacing: Space.xs) {
                    PortfolioTile(item: items[0], height: 220, index: 0, appeared: appeared)
                        .frame(width: halfWidth, height: 220)
                    PortfolioTile(item: items[1], height: 220, index: 1, appeared: appeared)
                        .frame(width: halfWidth, height: 220)
                }
                .frame(width: inner)
                .padding(.horizontal, Space.lg)
            } else if items.count == 1 {
                PortfolioTile(item: items[0], height: 260, index: 0, appeared: appeared)
                    .frame(width: inner, height: 260)
                    .padding(.horizontal, Space.lg)
            }

            let remaining = items.count > 3 ? Array(items.dropFirst(3)) : []
            if !remaining.isEmpty {
                VStack(spacing: Space.xs) {
                    ForEach(Array(stride(from: 0, to: remaining.count, by: 2)), id: \.self) { i in
                        HStack(spacing: Space.xs) {
                            PortfolioTile(item: remaining[i], height: 180, index: i + 3, appeared: appeared)
                                .frame(width: halfWidth, height: 180)

                            if i + 1 < remaining.count {
                                PortfolioTile(item: remaining[i + 1], height: 180, index: i + 4, appeared: appeared)
                                    .frame(width: halfWidth, height: 180)
                            } else {
                                Color.clear.frame(width: halfWidth, height: 180)
                            }
                        }
                        .frame(width: inner)
                    }
                }
                .frame(width: inner)
                .padding(.horizontal, Space.lg)
            }
        }
        .frame(width: inner)
    }

    // =========================================================================
    // MARK: - STORY
    // =========================================================================

    private func storySection(inner: CGFloat) -> some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    BMSectionLabel(text: "The story")

                    Text(braider.bio)
                        .font(.bmDisplay(19, weight: .regular))
                        .foregroundStyle(Color.appInk)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: 40, height: 2)
                        .padding(.top, Space.xs)
                }
                .frame(width: inner, alignment: .leading)
                .padding(.horizontal, Space.lg)
            }
        }
    }

    // =========================================================================
    // MARK: - SPECIALTIES
    // =========================================================================

    private func specialtiesSection(inner: CGFloat) -> some View {
        Group {
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    BMSectionLabel(text: "Specialties")

                    FlowLayout(spacing: Space.xs) {
                        ForEach(braider.specialties, id: \.self) { s in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.appAccent)
                                    .frame(width: 4, height: 4)
                                Text(s)
                                    .font(.bmUI(13, weight: .medium))
                                    .foregroundStyle(Color.appInk)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, Space.sm)
                            .frame(height: 34)
                            .background(Color.appAccentTint, in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.appAccent.opacity(0.15), lineWidth: 0.5)
                            )
                        }
                    }
                    .frame(width: inner, alignment: .leading)
                }
                .frame(width: inner, alignment: .leading)
                .padding(.horizontal, Space.lg)
            }
        }
    }

    // =========================================================================
    // MARK: - SERVICES
    // =========================================================================

    private func servicesSection(width: CGFloat, inner: CGFloat) -> some View {
        Group {
            if !braider.services.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
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
                    .frame(width: inner, alignment: .leading)
                    .padding(.horizontal, Space.lg)

                    VStack(spacing: Space.sm) {
                        ForEach(Array(braider.services.enumerated()), id: \.element.id) { index, service in
                            ServiceCard(service: service) {
                                Haptic.select()
                                showBookingForService = service
                            }
                            .frame(width: inner)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animate(Motion.reveal.delay(Motion.stagger(index)), value: appeared)
                        }
                    }
                    .frame(width: inner)
                    .padding(.horizontal, Space.lg)
                }
                .frame(width: width, alignment: .leading)
            }
        }
    }

    // =========================================================================
    // MARK: - REVIEWS
    // =========================================================================

    private func reviewsSection(width: CGFloat, inner: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
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
                    .frame(height: 30)
                    .background(Color.appAccent, in: Capsule())
                }
                .buttonStyle(BMPressStyle(scale: 0.96))
            }
            .frame(width: inner, alignment: .leading)
            .padding(.horizontal, Space.lg)

            if reviewsLoading {
                BMLoadingView(message: "Loading reviews")
                    .frame(width: inner, height: 100)
                    .padding(.horizontal, Space.lg)
            } else if reviews.isEmpty {
                emptyReviews(inner: inner)
            } else {
                let breakdown = RatingBreakdown.from(reviews)
                reviewAggregate(breakdown: breakdown, inner: inner)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(2).enumerated()), id: \.element.id) { index, review in
                        ReviewRow(review: review, inner: inner)
                        if index < min(reviews.count, 2) - 1 {
                            BMDivider(inset: Space.lg)
                        }
                    }
                }
                .frame(width: inner)
                .padding(.horizontal, Space.lg)

                if reviews.count > 2 {
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
                        .frame(width: inner, height: 48)
                        .padding(.horizontal, Space.lg)
                    }
                }
            }
        }
        .frame(width: width, alignment: .leading)
    }

    private func reviewAggregate(breakdown: RatingBreakdown, inner: CGFloat) -> some View {
        HStack(alignment: .center, spacing: Space.lg) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.bmDisplay(48, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .frame(width: 90)

            VStack(alignment: .leading, spacing: 6) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    ratingBar(
                        stars: stars,
                        count: breakdownCount(stars, breakdown),
                        total: breakdown.total
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .frame(width: inner)
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
                .frame(width: 8, alignment: .leading)
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

    private func emptyReviews(inner: CGFloat) -> some View {
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
        }
        .frame(width: inner)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.lg)
    }

    // =========================================================================
    // MARK: - BOOKING BAR
    // =========================================================================

    private var bookingBar: some View {
        VStack(spacing: 0) {
            BMDivider()
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FROM")
                        .font(.bmUI(9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.appAsh)
                    Text("£\(braider.priceFrom)")
                        .font(.bmDisplay(22, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if braider.services.isEmpty {
                    Text("Not taking bookings yet")
                        .font(.bmUI(13, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                } else {
                    Button {
                        Haptic.press()
                        showBooking = true
                    } label: {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "calendar")
                                .font(.bmUI(14, weight: .semibold))
                            Text("Book \(firstName)")
                                .font(.bmUI(15, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.appInkInverse)
                        .padding(.horizontal, Space.lg)
                        .frame(height: 52)
                        .background(Color.appInk, in: Capsule())
                    }
                    .buttonStyle(BMPressStyle())
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
// MARK: - PORTFOLIO TILE
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if !item.caption.isEmpty {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .top, endPoint: .bottom
                )
                Text(item.caption)
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(Space.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !item.tag.isEmpty {
                Text(item.tag.uppercased())
                    .font(.bmUI(9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .padding(Space.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .opacity(revealed ? 1 : 0)
        .scaleEffect(revealed ? 1 : 0.95)
        .animate(Motion.reveal.delay(Motion.stagger(index)), value: revealed)
        .onAppear { if appeared { revealed = true } }
        .onChange(of: appeared) { _, newValue in
            if newValue { revealed = true }
        }
    }
}

// =============================================================================
// MARK: - SERVICE CARD
// =============================================================================

struct ServiceCard: View {
    let service: BraidService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                ZStack {
                    if service.imageUrl.isEmpty {
                        RoundedRectangle(cornerRadius: Radius.button)
                            .fill(Color.appDivider)
                            .frame(width: 72, height: 72)
                        Image(systemName: "photo")
                            .font(.bmUI(22))
                            .foregroundStyle(Color.appSmoke)
                    } else {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Space.xxs) {
                        Text(service.name)
                            .font(.bmUI(15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if service.popular {
                            Image(systemName: "flame.fill")
                                .font(.bmUI(10))
                                .foregroundStyle(Color.appAccent)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
// MARK: - REVIEW ROW
// =============================================================================

struct ReviewRow: View {
    let review: Review
    let inner: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: review.userAvatar, size: 38, initials: userInitials)
                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
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
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: inner, alignment: .leading)

            Text(review.text)
                .font(.bmUI(14))
                .foregroundStyle(Color.appInk.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: inner, alignment: .leading)

            if !review.styleDone.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                        .font(.bmUI(9, weight: .semibold))
                    Text(review.styleDone)
                        .font(.bmUI(10, weight: .semibold))
                        .tracking(0.3)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, Space.xs)
                .padding(.vertical, 4)
                .background(Color.appAccentTint, in: Capsule())
            }
        }
        .frame(width: inner, alignment: .leading)
        .padding(.vertical, Space.md)
    }

    private var userInitials: String {
        let parts = review.userName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}

// =============================================================================
// MARK: - ALL REVIEWS SHEET
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

                GeometryReader { geo in
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(Array(reviews.enumerated()), id: \.element.id) { index, r in
                                ReviewRow(review: r, inner: geo.size.width - Space.lg * 2)
                                    .padding(.horizontal, Space.lg)
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