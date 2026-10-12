import SwiftUI

// =============================================================================
// BraiderProfileView — full-screen photo-first profile
//
// Completely different architecture from previous versions.
//
//   · Background is a full-screen vertical pager of portfolio photos
//   · Swipe up/down to move between photos (like Reels)
//   · Top chrome: back button, name, save heart — always visible
//   · Page 1 shows profile info overlaid on the cover photo
//   · Bottom sheet slides up over the pager for services + reviews
//   · Reviews section: aggregate, list, and Write button
//   · Everything is bounded to screen width — nothing overflows
// =============================================================================

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var pageIndex: Int = 0
    @State private var showSheet = false
    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var showWriteReview = false
    @State private var showAllReviews = false

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

    // Pages: first is cover + profile, then every portfolio item
    private var pages: [PageContent] {
        var out: [PageContent] = []
        out.append(.intro)
        for item in braider.portfolio {
            out.append(.photo(item))
        }
        return out
    }

    enum PageContent: Hashable {
        case intro
        case photo(PortfolioItem)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack(alignment: .top) {

                // ---------- Background pager ----------
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        pageView(page, width: width, height: height)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: width, height: height)
                .ignoresSafeArea()

                // ---------- Top chrome ----------
                topChrome(width: width)
                    .zIndex(2)

                // ---------- Page dots ----------
                pageDots
                    .frame(width: width, height: height, alignment: .trailing)
                    .zIndex(2)

                // ---------- Bottom handle / sheet trigger ----------
                VStack {
                    Spacer()
                    handleBar(width: width)
                }
                .zIndex(2)
            }
            .sheet(isPresented: $showSheet) {
                ProfileSheet(
                    braider: braider,
                    reviews: reviews,
                    reviewsLoading: reviewsLoading,
                    onWriteReview: { showWriteReview = true },
                    onSeeAllReviews: { showAllReviews = true },
                    onBook: { showBooking = true },
                    onBookService: { service in showBookingForService = service }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appSurface)
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
                    onWriteReview: { showWriteReview = true }
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
        }
        .background(Color.appSurfaceInverse)
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .task { await loadReviews() }
    }

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            self.reviews = fetched
            self.reviewsLoading = false
        }
    }

    // =====================================================================
    // MARK: - Page content
    // =====================================================================

    @ViewBuilder
    private func pageView(_ page: PageContent, width: CGFloat, height: CGFloat) -> some View {
        switch page {
        case .intro:
            introPage(width: width, height: height)
        case .photo(let item):
            photoPage(item: item, width: width, height: height)
        }
    }

    // ----- INTRO PAGE -----

    private func introPage(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {

            // Cover image or fallback
            Group {
                if !braider.coverUrl.isEmpty {
                    RemoteImage(url: braider.coverUrl)
                        .frame(width: width, height: height)
                        .clipped()
                } else {
                    Color.appSurfaceInverse.frame(width: width, height: height)
                }
            }

            // Full-screen gradient
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0.0),
                    .init(color: .black.opacity(0.05), location: 0.28),
                    .init(color: .clear, location: 0.50),
                    .init(color: .black.opacity(0.35), location: 0.78),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height)

            // Bottom-left info stack
            VStack(alignment: .leading, spacing: Space.md) {

                // Avatar + name row
                HStack(spacing: Space.md) {
                    BMAvatar(
                        url: braider.avatarUrl,
                        size: 84,
                        ringed: false,
                        initials: initials
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 3))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(braider.name)
                                .font(.bmDisplay(32, weight: .semibold))
                                .foregroundStyle(Color.appInkInverse)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)

                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.bmUI(16))
                                    .foregroundStyle(Color.appAccentSoft)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.bmUI(14, weight: .medium))
                                .foregroundStyle(Color.appInkInverse.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }

                // Rating + city row
                HStack(spacing: Space.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAccentSoft)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(13, weight: .semibold))
                            .foregroundStyle(Color.appInkInverse)
                        Text("·")
                            .foregroundStyle(Color.appInkInverse.opacity(0.5))
                        Text("\(braider.reviewCount) review\(braider.reviewCount == 1 ? "" : "s")")
                            .font(.bmUI(13))
                            .foregroundStyle(Color.appInkInverse.opacity(0.85))
                    }

                    Text("·")
                        .foregroundStyle(Color.appInkInverse.opacity(0.5))

                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.bmUI(10))
                        Text(braider.city)
                            .font(.bmUI(13))
                    }
                    .foregroundStyle(Color.appInkInverse.opacity(0.85))
                    .lineLimit(1)

                    Spacer(minLength: 0)
                }

                // From price + scroll hint
                HStack(spacing: Space.sm) {
                    Text("FROM")
                        .font(.bmUI(9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color.appInkInverse.opacity(0.55))
                    Text("£\(braider.priceFrom)")
                        .font(.bmDisplay(20, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        Image(systemName: "chevron.up")
                            .font(.bmUI(10, weight: .bold))
                        Text("Swipe for portfolio")
                            .font(.bmUI(11, weight: .semibold))
                    }
                    .foregroundStyle(Color.appInkInverse.opacity(0.75))
                }
            }
            .frame(width: width - Space.lg * 2, alignment: .leading)
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 140)
        }
        .frame(width: width, height: height)
    }

    // ----- PHOTO PAGE -----

    private func photoPage(item: PortfolioItem, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {

            RemoteImage(url: item.imageUrl)
                .frame(width: width, height: height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0.0),
                    .init(color: .clear, location: 0.30),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.55), location: 0.85),
                    .init(color: .black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: width, height: height)

            // Bottom info
            VStack(alignment: .leading, spacing: Space.sm) {

                // Tag chip
                if !item.tag.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "tag.fill")
                            .font(.bmUI(9, weight: .bold))
                        Text(item.tag.uppercased())
                            .font(.bmUI(10, weight: .semibold))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }

                // Caption
                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(.bmDisplay(22, weight: .semibold))
                        .foregroundStyle(Color.appInkInverse)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Likes + counter
                HStack(spacing: Space.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAccentSoft)
                        Text("\(item.likes)")
                            .font(.bmMono(12, weight: .medium))
                            .foregroundStyle(Color.appInkInverse)
                    }

                    Spacer(minLength: 0)

                    Text("\(pageIndex + 1) / \(pages.count)")
                        .font(.bmMono(11, weight: .medium))
                        .foregroundStyle(Color.appInkInverse.opacity(0.7))
                }
            }
            .frame(width: width - Space.lg * 2, alignment: .leading)
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 140)
        }
        .frame(width: width, height: height)
    }

    // =====================================================================
    // MARK: - Top chrome
    // =====================================================================

    private func topChrome(width: CGFloat) -> some View {
        HStack(spacing: Space.sm) {

            // Back
            chromeCircleButton(icon: "chevron.left") {
                dismiss()
            }

            // Name (only on pages after the intro)
            if pageIndex > 0 {
                Text(braider.name)
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 2)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Save
            chromeCircleButton(
                icon: isSaved ? "heart.fill" : "heart",
                tint: isSaved ? Color.appAlert : Color.appInkInverse
            ) {
                Task {
                    let uid = session.uid
                    guard !uid.isEmpty else { return }
                    await fb.toggleSave(braiderId: braider.id, uid: uid)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, 56)
        .frame(width: width, alignment: .top)
    }

    private func chromeCircleButton(
        icon: String,
        tint: Color = Color.appInkInverse,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptic.press()
            action()
        } label: {
            Image(systemName: icon)
                .font(.bmUI(15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
        }
        .buttonStyle(BMIconPressStyle())
    }

    // =====================================================================
    // MARK: - Page dots
    // =====================================================================

    private var pageDots: some View {
        VStack(spacing: 4) {
            Spacer()
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == pageIndex ? Color.appInkInverse : Color.appInkInverse.opacity(0.35))
                    .frame(
                        width: i == pageIndex ? 4 : 3,
                        height: i == pageIndex ? 20 : 10
                    )
                    .animation(Motion.press, value: pageIndex)
            }
            Spacer().frame(height: 160)
        }
        .padding(.trailing, Space.md)
        .allowsHitTesting(false)
    }

    // =====================================================================
    // MARK: - Handle bar
    // =====================================================================

    private func handleBar(width: CGFloat) -> some View {
        Button {
            Haptic.press()
            showSheet = true
        } label: {
            VStack(spacing: Space.sm) {
                Capsule()
                    .fill(Color.appInkInverse.opacity(0.5))
                    .frame(width: 40, height: 4)

                HStack(spacing: Space.md) {
                    // Rating pill
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAccent)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(13, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                        Text("(\(braider.reviewCount))")
                            .font(.bmUI(11))
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 6)
                    .background(Color.appSurface, in: Capsule())

                    Text("Reviews & services")
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(Color.appInk)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.up")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .frame(width: 28, height: 28)
                        .background(Color.appAccentTint, in: Circle())
                }
            }
            .frame(width: width - Space.lg * 2)
            .padding(Space.md)
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: -4)
        }
        .buttonStyle(BMPressStyle(scale: 0.98))
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }
}

// =============================================================================
// MARK: - PROFILE SHEET (services + reviews)
// =============================================================================

struct ProfileSheet: View {
    let braider: Braider
    let reviews: [Review]
    let reviewsLoading: Bool
    let onWriteReview: () -> Void
    let onSeeAllReviews: () -> Void
    let onBook: () -> Void
    let onBookService: (BraidService) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    aboutSection
                    servicesSection
                    reviewsSection
                    Color.clear.frame(height: Space.xxl)
                }
                .padding(.top, Space.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bookingBar
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionLabel(text: "About")
                .padding(.horizontal, Space.lg)

            if !braider.bio.isEmpty {
                Text(braider.bio)
                    .font(.bmUI(15))
                    .foregroundStyle(Color.appInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.lg)
            }

            // Specialties
            if !braider.specialties.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
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
                    HStack {
                        BMSectionLabel(text: "Services")
                        Spacer()
                        Text("\(braider.services.count)")
                            .font(.bmMono(12, weight: .semibold))
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.horizontal, Space.lg)

                    VStack(spacing: Space.sm) {
                        ForEach(braider.services) { service in
                            ServiceCard(service: service) {
                                Haptic.select()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    onBookService(service)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                BMSectionLabel(text: "Reviews")
                Spacer()
                Button {
                    Haptic.press()
                    onWriteReview()
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
            .padding(.horizontal, Space.lg)

            if reviewsLoading {
                BMLoadingView(message: "Loading reviews")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.lg)
            } else if reviews.isEmpty {
                emptyReviews
            } else {
                // Aggregate
                let breakdown = RatingBreakdown.from(reviews)
                aggregateCard(breakdown: breakdown)

                // Recent reviews
                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(2).enumerated()), id: \.element.id) { index, review in
                        SheetReviewRow(review: review)
                        if index < min(reviews.count, 2) - 1 {
                            BMDivider(inset: Space.lg)
                        }
                    }
                }

                if reviews.count > 2 {
                    Button {
                        Haptic.press()
                        onSeeAllReviews()
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
                        .frame(height: 48)
                    }
                }
            }
        }
    }

    private func aggregateCard(breakdown: RatingBreakdown) -> some View {
        HStack(alignment: .center, spacing: Space.lg) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.bmDisplay(48, weight: .semibold))
                    .foregroundStyle(Color.appInk)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.lg)
    }

    // MARK: - Booking bar

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
                }

                Spacer(minLength: 0)

                Button {
                    Haptic.press()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onBook()
                    }
                } label: {
                    HStack(spacing: Space.xs) {
                        Image(systemName: "calendar")
                            .font(.bmUI(14, weight: .semibold))
                        Text("Book")
                            .font(.bmUI(15, weight: .semibold))
                    }
                    .foregroundStyle(Color.appInkInverse)
                    .padding(.horizontal, Space.lg)
                    .frame(height: 52)
                    .background(Color.appInk, in: Capsule())
                }
                .buttonStyle(BMPressStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
            .background(Color.appSurface)
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
// MARK: - REVIEW ROW (sheet variant)
// =============================================================================

struct SheetReviewRow: View {
    let review: Review

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
                    }
                }
                Spacer(minLength: 0)
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
                        .lineLimit(1)
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

                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(reviews.enumerated()), id: \.element.id) { index, r in
                            SheetReviewRow(review: r)
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