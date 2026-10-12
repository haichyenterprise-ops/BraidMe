import SwiftUI

// =============================================================================
// BraiderProfileView — stretchy parallax hero, fading glass nav, scroll-reactive
// portfolio, animated review bars and a floating booking dock.
// Booking, save, review and Firebase flows are unchanged.
// =============================================================================

private struct CountUpText: View {
    let target: Int
    var prefix: String = ""
    @State private var shown = 0

    var body: some View {
        Text("\(prefix)\(shown)")
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.35)) { shown = target }
            }
            .onChange(of: target) { _, new in
                withAnimation(.easeOut(duration: 0.6)) { shown = new }
            }
    }
}

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true
    @State private var showWriteReview = false
    @State private var showAllReviews = false
    @State private var showBooking = false
    @State private var showBookingForService: BraidService?
    @State private var selectedPortfolioItem: PortfolioItem?
    @State private var scrollY: CGFloat = 0
    @State private var appeared = false
    @State private var barsIn = false
    @State private var bioExpanded = false

    private let heroHeight: CGFloat = 560
    private let scrollSpace = "profileScroll"

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    private var ratingValue: Double {
        reviews.isEmpty ? braider.rating : RatingBreakdown.from(reviews).average
    }

    private var ratingText: String { String(format: "%.1f", ratingValue) }

    private var ratingCount: Int {
        reviews.isEmpty ? braider.reviewCount : reviews.count
    }

    private var navOpacity: Double {
        let v = (-Double(scrollY) - 250.0) / 90.0
        return min(max(v, 0), 1)
    }

    private var heroImageUrl: String {
        if !braider.coverUrl.isEmpty { return braider.coverUrl }
        return braider.portfolio.first?.imageUrl ?? ""
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.bmBase.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    VStack(spacing: Space.xl) {
                        statsCard
                        aboutSection
                        portfolioSection
                        servicesSection
                        reviewsSection
                        footer
                    }
                    .padding(.top, Space.lg)
                    .padding(.bottom, 120)
                }
            }
            .coordinateSpace(name: scrollSpace)
            .onPreferenceChange(ScrollOffsetKey.self) { scrollY = $0 }
            .ignoresSafeArea(edges: .top)

            navBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bookingDock
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(braider: braider) {
                Task { await loadReviews() }
            }
            .presentationBackground(Color.bmBase)
            .presentationCornerRadius(Radius.modal)
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsSheet(
                braider: braider,
                reviews: reviews,
                breakdown: RatingBreakdown.from(reviews),
                onWriteReview: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showWriteReview = true
                    }
                }
            )
            .presentationBackground(Color.bmBase)
            .presentationCornerRadius(Radius.modal)
        }
        .fullScreenCover(isPresented: $showBooking) {
            BookingSelectionView(braider: braider)
        }
        .fullScreenCover(item: $showBookingForService) { service in
            BookingSelectionView(braider: braider, preselectServiceId: service.id)
        }
        .fullScreenCover(item: $selectedPortfolioItem) { item in
            PortfolioGallery(items: braider.portfolio, startItem: item, name: braider.name)
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookingFlowFinished)) { _ in
            showBooking = false
            showBookingForService = nil
        }
        .task { await loadReviews() }
        .onAppear { appeared = true }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: Space.sm) {
            BMIconButton(icon: "chevron.left", size: 44, iconSize: 15) { dismiss() }
                .accessibilityLabel("Go back")

            Text(braider.name)
                .font(.bmDisplay(19, weight: .semibold))
                .foregroundStyle(Color.bmText)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .opacity(navOpacity)
                .offset(y: (1 - navOpacity) * 6)

            ShareLink(item: "Book \(braider.name) on BraidMe") {
                Image(systemName: "square.and.arrow.up")
                    .font(.bmUI(15, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .frame(width: 44, height: 44)
                    .bmGlassCircle()
            }
            .buttonStyle(BMIconPressStyle())

            Button {
                Haptic.press()
                Task {
                    guard !session.uid.isEmpty else { return }
                    await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                }
            } label: {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.bmUI(16, weight: .semibold))
                    .foregroundStyle(isSaved ? Color.bmBad : Color.bmText)
                    .symbolEffect(.bounce, value: isSaved)
                    .frame(width: 44, height: 44)
                    .bmGlassCircle()
            }
            .buttonStyle(BMIconPressStyle())
            .accessibilityLabel(isSaved ? "Remove from saved braiders" : "Save braider")
        }
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.bmLine).frame(height: 0.6)
                }
                .opacity(navOpacity)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                let minY = geo.frame(in: .named(scrollSpace)).minY
                let stretch = max(minY, 0)
                let parallax = minY < 0 ? -minY * 0.35 : 0

                heroMedia
                    .frame(width: geo.size.width, height: heroHeight + stretch)
                    .clipped()
                    .scaleEffect(1 + stretch / 900, anchor: .bottom)
                    .offset(y: -stretch + parallax)
                    .preference(key: ScrollOffsetKey.self, value: minY)
            }

            heroText
        }
        .frame(height: heroHeight)
    }

    private var heroMedia: some View {
        ZStack {
            if heroImageUrl.isEmpty {
                LinearGradient(
                    colors: [Color.bmRaised, Color.bmDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                BraidMark(length: 260, thickness: 90, strand: 20, animated: true, speed: 0.5, edge: Color.bmRaised)
                    .opacity(0.35)
            } else {
                RemoteImage(url: heroImageUrl)
            }

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.5), location: 0),
                    .init(color: Color.clear, location: 0.3),
                    .init(color: Color.bmBase.opacity(0.35), location: 0.62),
                    .init(color: Color.bmBase, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: 6) {
                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(LinearGradient.bmGiltGradient)
                    Text("Verified braider")
                } else {
                    Image(systemName: "scissors")
                        .foregroundStyle(Color.bmGilt)
                    Text("Independent braider")
                }
            }
            .font(.bmUI(12, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, Space.sm)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7))
            .reveal(appeared, delay: 0.05, offset: 12, blur: 0)

            HStack(alignment: .bottom, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(braider.name)
                        .font(.bmDisplay(42, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineSpacing(-4)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    if !braider.tagline.isEmpty {
                        Text(braider.tagline)
                            .font(.bmUI(15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(2)
                    }

                    HStack(spacing: Space.sm) {
                        Label(braider.city, systemImage: "mappin.and.ellipse")
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color.bmGilt)
                            Text(ratingText).fontWeight(.bold)
                            Text("(\(ratingCount))")
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.white)
                    .padding(.top, 2)
                }
                .reveal(appeared, delay: 0.12, offset: 20, blur: 8)

                Spacer(minLength: 0)

                if !braider.avatarUrl.isEmpty {
                    BMAvatar(url: braider.avatarUrl, size: 64, ringed: true, initials: bmInitials(braider.name))
                        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 8)
                        .reveal(appeared, delay: 0.2, offset: 10, blur: 0)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.lg)
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            metric(label: "Rating") {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.bmUI(13, weight: .bold))
                        .foregroundStyle(Color.bmGilt)
                    Text(ratingText)
                }
            }
            metricDivider
            metric(label: "Reviews") { CountUpText(target: ratingCount) }
            metricDivider
            metric(label: "Services") { CountUpText(target: braider.services.count) }
            metricDivider
            metric(label: "From") { CountUpText(target: braider.priceFrom, prefix: "£") }
        }
        .padding(.vertical, Space.md)
        .bmCard(radius: Radius.card)
        .padding(.horizontal, Space.lg)
        .reveal(appeared, delay: 0.1, offset: 24, blur: 0)
    }

    private func metric<V: View>(label: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 4) {
            value()
                .font(.bmNum(21, weight: .bold))
                .foregroundStyle(Color.bmText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.bmUI(12, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.bmLine)
            .frame(width: 0.6, height: 34)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if !braider.bio.isEmpty {
                BMSectionHeading(title: "About \(firstName)")

                Text(braider.bio)
                    .font(.bmUI(16))
                    .foregroundStyle(Color.bmText.opacity(0.85))
                    .lineSpacing(6)
                    .lineLimit(bioExpanded ? nil : 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(Motion.sheet, value: bioExpanded)

                if braider.bio.count > 220 {
                    Button {
                        Haptic.select()
                        bioExpanded.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(bioExpanded ? "Show less" : "Read more")
                            Image(systemName: bioExpanded ? "chevron.up" : "chevron.down")
                                .font(.bmUI(10, weight: .bold))
                        }
                        .font(.bmUI(14, weight: .bold))
                        .foregroundStyle(Color.bmGilt)
                    }
                }
            }

            quickFacts

            if !braider.specialties.isEmpty {
                FlowLayout(spacing: Space.xs) {
                    ForEach(braider.specialties, id: \.self) { specialty in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient.bmBraidGradient)
                                .frame(width: 6, height: 6)
                            Text(specialty)
                                .font(.bmUI(13, weight: .semibold))
                                .foregroundStyle(Color.bmText)
                        }
                        .padding(.horizontal, Space.sm)
                        .frame(height: 36)
                        .bmGlass(radius: 18)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !braider.story.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Image(systemName: "quote.opening")
                        .font(.bmUI(18, weight: .bold))
                        .foregroundStyle(LinearGradient.bmGiltGradient)
                    Text(braider.story)
                        .font(.bmDisplay(18, weight: .regular))
                        .foregroundStyle(Color.bmText.opacity(0.9))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bmCard(radius: Radius.card)
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var quickFacts: some View {
        HStack(spacing: Space.sm) {
            if braider.yearsExperience > 0 {
                fact(icon: "scissors", text: "\(braider.yearsExperience) yr\(braider.yearsExperience == 1 ? "" : "s") experience", tint: Color.bmGilt)
            }
            if !braider.responseTime.isEmpty {
                fact(icon: "bolt.fill", text: "Replies \(braider.responseTime)", tint: Color.bmOrchid)
            }
            Spacer(minLength: 0)
        }
    }

    private func fact(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.bmUI(11, weight: .bold))
            Text(text)
                .font(.bmUI(12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Space.sm)
        .frame(height: 32)
        .background(tint.opacity(0.13), in: Capsule())
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionHeading(
                title: "Portfolio",
                subtitle: braider.portfolio.isEmpty ? nil : "\(braider.portfolio.count) recent styles"
            )
            .padding(.horizontal, Space.lg)

            if braider.portfolio.isEmpty {
                emptyBlock(
                    icon: "camera",
                    title: "Portfolio coming soon",
                    message: "New styles from \(firstName) will appear here."
                )
                .padding(.horizontal, Space.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.sm) {
                        ForEach(braider.portfolio) { item in
                            portfolioCard(item)
                                .scrollTransition(axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                        .opacity(phase.isIdentity ? 1 : 0.55)
                                        .blur(radius: phase.isIdentity ? 0 : 2)
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, Space.lg)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func portfolioCard(_ item: PortfolioItem) -> some View {
        Button {
            Haptic.select()
            selectedPortfolioItem = item
        } label: {
            ZStack(alignment: .bottomLeading) {
                RemoteImage(url: item.imageUrl)
                    .frame(width: 236, height: 320)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.45),
                        .init(color: Color.black.opacity(0.8), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    if !item.tag.isEmpty {
                        Text(item.tag)
                            .font(.bmUI(11, weight: .bold))
                            .foregroundStyle(Color.bmOnGilt)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(LinearGradient.bmGiltGradient, in: Capsule())
                    }
                    if !item.caption.isEmpty {
                        Text(item.caption)
                            .font(.bmDisplay(17, weight: .medium))
                            .foregroundStyle(Color.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(Space.md)
            }
            .frame(width: 236, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            )
            .overlay(alignment: .topTrailing) {
                if item.likes > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.bmUI(10, weight: .bold))
                            .foregroundStyle(Color.bmBad)
                        Text("\(item.likes)")
                            .font(.bmNum(11, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(Space.sm)
                }
            }
        }
        .buttonStyle(BMPressStyle(scale: 0.97, dim: 0.02))
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionHeading(
                title: "Services",
                subtitle: braider.services.isEmpty ? nil : "Tap a style to book it"
            )
            .padding(.horizontal, Space.lg)

            if braider.services.isEmpty {
                emptyBlock(
                    icon: "calendar",
                    title: "Services coming soon",
                    message: "Check back soon for available styles and appointments."
                )
                .padding(.horizontal, Space.lg)
            } else {
                VStack(spacing: Space.sm) {
                    ForEach(braider.services) { service in
                        serviceRow(service)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    private func serviceRow(_ service: BraidService) -> some View {
        Button {
            Haptic.select()
            showBookingForService = service
        } label: {
            HStack(spacing: Space.md) {
                ZStack {
                    if service.imageUrl.isEmpty {
                        LinearGradient(
                            colors: [Color.bmRaised, Color.bmSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "sparkles")
                            .font(.bmUI(22, weight: .light))
                            .foregroundStyle(LinearGradient.bmGiltGradient)
                    } else {
                        RemoteImage(url: service.imageUrl)
                    }
                }
                .frame(width: 84, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    if service.popular {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                            Text("Signature style")
                        }
                        .font(.bmUI(11, weight: .bold))
                        .foregroundStyle(Color.bmEmber)
                    }
                    Text(service.name)
                        .font(.bmDisplay(19, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: Space.sm) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.bmUI(11, weight: .semibold))
                            Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                .font(.bmUI(12, weight: .medium))
                        }
                        .foregroundStyle(Color.bmTextDim)
                        Text("from £\(service.priceFrom)")
                            .font(.bmNum(14, weight: .bold))
                            .foregroundStyle(Color.bmGilt)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.bmUI(13, weight: .bold))
                    .foregroundStyle(Color.bmGilt)
                    .frame(width: 38, height: 38)
                    .background(Color.bmGilt.opacity(0.14), in: Circle())
            }
            .padding(Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bmCard(radius: Radius.card)
        }
        .buttonStyle(BMPressStyle(scale: 0.98, dim: 0.02))
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            BMSectionHeading(
                title: "Reviews",
                subtitle: reviews.isEmpty ? nil : "From verified clients"
            ) {
                if !reviews.isEmpty {
                    Button {
                        Haptic.select()
                        showAllReviews = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                            Image(systemName: "arrow.up.right")
                                .font(.bmUI(10, weight: .bold))
                        }
                        .font(.bmUI(13, weight: .bold))
                        .foregroundStyle(Color.bmGilt)
                    }
                }
            }
            .padding(.horizontal, Space.lg)

            if reviewsLoading {
                VStack(spacing: Space.sm) {
                    BMSkeleton(height: 120, cornerRadius: Radius.card)
                    BMSkeleton(height: 90, cornerRadius: Radius.card)
                }
                .padding(.horizontal, Space.lg)
            } else if reviews.isEmpty {
                emptyBlock(
                    icon: "quote.opening",
                    title: "The first word is yours",
                    message: "No reviews yet. Book an appointment and share your experience."
                )
                .padding(.horizontal, Space.lg)
            } else {
                ratingSummary
                    .padding(.horizontal, Space.lg)

                VStack(spacing: Space.sm) {
                    ForEach(Array(reviews.prefix(3))) { review in
                        SheetReviewRow(review: review)
                            .bmCard(radius: Radius.card)
                    }
                }
                .padding(.horizontal, Space.lg)

                if reviews.count > 3 {
                    BMSecondaryButton(title: "Read all \(reviews.count) reviews", icon: "text.bubble") {
                        showAllReviews = true
                    }
                    .padding(.horizontal, Space.lg)
                }
            }

            Button {
                Haptic.press()
                showWriteReview = true
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "square.and.pencil")
                    Text("Share your experience")
                }
                .font(.bmUI(15, weight: .bold))
                .foregroundStyle(Color.bmGilt)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.bmGilt.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .strokeBorder(Color.bmGilt.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(BMPressStyle())
            .padding(.horizontal, Space.lg)
        }
    }

    private var ratingSummary: some View {
        let breakdown = RatingBreakdown.from(reviews)
        return HStack(alignment: .center, spacing: Space.lg) {
            VStack(spacing: 6) {
                Text(ratingText)
                    .font(.bmDisplay(54, weight: .semibold))
                    .foregroundStyle(LinearGradient.bmGiltGradient)
                BMStars(rating: ratingValue, size: 12)
                Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
            }
            .frame(width: 112)

            VStack(spacing: 8) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                    ratingBar(star: star, count: breakdownCount(star, breakdown), total: breakdown.total)
                }
            }
        }
        .padding(Space.md)
        .bmCard(radius: Radius.card)
    }

    private func ratingBar(star: Int, count: Int, total: Int) -> some View {
        let ratio: CGFloat = total > 0 ? CGFloat(count) / CGFloat(total) : 0
        return HStack(spacing: Space.xs) {
            Text("\(star)")
                .font(.bmNum(11, weight: .semibold))
                .foregroundStyle(Color.bmTextDim)
                .frame(width: 10)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient.bmBraidGradient)
                        .frame(width: geo.size.width * (barsIn ? ratio : 0))
                        .animation(
                            Motion.reveal.delay(Double(5 - star) * 0.07),
                            value: barsIn
                        )
                }
            }
            .frame(height: 6)
            Text("\(count)")
                .font(.bmNum(11, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
                .frame(width: 22, alignment: .trailing)
        }
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

    // MARK: - Shared

    private func emptyBlock(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            Image(systemName: icon)
                .font(.bmUI(18, weight: .medium))
                .foregroundStyle(LinearGradient.bmGiltGradient)
                .frame(width: 42, height: 42)
                .background(Color.bmGilt.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bmDisplay(18, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                Text(message)
                    .font(.bmUI(13))
                    .foregroundStyle(Color.bmTextDim)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bmCard(radius: Radius.card)
    }

    private var footer: some View {
        VStack(spacing: Space.xs) {
            BraidMark(length: 60, thickness: 26, strand: 6, horizontal: true, cycles: 1.4)
            Text("Good hair. Great feeling.")
                .font(.bmDisplay(14, weight: .regular))
                .italic()
                .foregroundStyle(Color.bmTextFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.md)
    }

    // MARK: - Booking dock

    private var bookingDock: some View {
        HStack(spacing: Space.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Starting from")
                    .font(.bmUI(12, weight: .medium))
                    .foregroundStyle(Color.bmTextDim)
                Text("£\(braider.priceFrom)")
                    .font(.bmNum(28, weight: .bold))
                    .foregroundStyle(Color.bmText)
            }
            Spacer(minLength: 0)
            Button {
                Haptic.press()
                showBooking = true
            } label: {
                HStack(spacing: Space.xs) {
                    Text("Book appointment")
                        .font(.bmUI(15, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.bmUI(13, weight: .bold))
                }
                .foregroundStyle(Color.bmOnGilt)
                .padding(.horizontal, Space.lg)
                .frame(height: 54)
                .background(LinearGradient.bmGiltGradient, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.8))
                .shadow(color: Color.bmGilt.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(BMPressStyle())
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.sm)
        .padding(.vertical, Space.sm)
        .bmGlass(radius: 40, tint: Color.black.opacity(0.28))
        .shadow(color: Color.black.opacity(0.4), radius: 24, y: 10)
        .padding(.horizontal, Space.md)
        .padding(.bottom, Space.xs)
    }

    // MARK: - Data

    private func loadReviews() async {
        await MainActor.run {
            reviewsLoading = true
            barsIn = false
        }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            reviews = fetched
            reviewsLoading = false
        }
        try? await Task.sleep(nanoseconds: 250_000_000)
        await MainActor.run { barsIn = true }
    }
}

// =============================================================================
// MARK: - All reviews sheet
// =============================================================================

struct AllReviewsSheet: View {
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    let onWriteReview: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.4)

            VStack(spacing: 0) {
                BMSheetBar(
                    title: "Reviews",
                    subtitle: "\(String(format: "%.1f", breakdown.average)) average from \(reviews.count) client\(reviews.count == 1 ? "" : "s")"
                ) {
                    dismiss()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.sm) {
                        BMPrimaryButton(title: "Write a review", icon: "square.and.pencil", shine: false) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onWriteReview()
                            }
                        }
                        .padding(.bottom, Space.xs)

                        ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                            SheetReviewRow(review: review)
                                .bmCard(radius: Radius.card)
                                .reveal(appeared, delay: Motion.stagger(index), offset: 22, blur: 0)
                        }
                    }
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.xl)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

// =============================================================================
// MARK: - Portfolio gallery
// =============================================================================

struct PortfolioGallery: View {
    let items: [PortfolioItem]
    let startItem: PortfolioItem
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var dragY: CGFloat = 0
    @State private var appeared = false

    init(items: [PortfolioItem], startItem: PortfolioItem, name: String) {
        self.items = items
        self.startItem = startItem
        self.name = name
        _index = State(initialValue: items.firstIndex(where: { $0.id == startItem.id }) ?? 0)
    }

    private var current: PortfolioItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    private var dismissProgress: CGFloat { min(max(dragY / 320, 0), 1) }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - Double(dismissProgress) * 0.7)
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    RemoteImage(url: item.imageUrl, contentMode: .fit, backdrop: Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .scaleEffect(1 - dismissProgress * 0.12)
            .offset(y: dragY)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let vertical = abs(value.translation.height) > abs(value.translation.width)
                        if vertical && value.translation.height > 0 {
                            dragY = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if dragY > 140 || value.predictedEndTranslation.height > 420 {
                            Haptic.select()
                            dismiss()
                        } else {
                            withAnimation(Motion.sheet) { dragY = 0 }
                        }
                    }
            )

            VStack {
                topBar
                Spacer()
                bottomInfo
            }
            .opacity(1 - Double(dismissProgress) * 1.5)
            .opacity(appeared ? 1 : 0)
            .animation(Motion.subtle, value: appeared)
        }
        .statusBarHidden()
        .onAppear { appeared = true }
    }

    private var topBar: some View {
        HStack {
            BMIconButton(icon: "xmark", size: 44, iconSize: 14) { dismiss() }
            Spacer()
            VStack(spacing: 2) {
                Text(name)
                    .font(.bmDisplay(16, weight: .semibold))
                    .foregroundStyle(Color.white)
                Text("\(index + 1) of \(items.count)")
                    .font(.bmNum(12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .contentTransition(.numericText())
                    .animation(Motion.press, value: index)
            }
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xs)
    }

    private var bottomInfo: some View {
        VStack(spacing: Space.sm) {
            if let item = current {
                if !item.tag.isEmpty {
                    Text(item.tag)
                        .font(.bmUI(12, weight: .bold))
                        .foregroundStyle(Color.bmOnGilt)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(LinearGradient.bmGiltGradient, in: Capsule())
                }
                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(.bmDisplay(24, weight: .regular))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if item.likes > 0 {
                    Label("\(item.likes)", systemImage: "heart.fill")
                        .font(.bmUI(12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<items.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Color.bmGilt : Color.white.opacity(0.3))
                        .frame(width: i == index ? 22 : 6, height: 6)
                        .animation(Motion.press, value: index)
                }
            }
            .padding(.top, Space.xs)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
