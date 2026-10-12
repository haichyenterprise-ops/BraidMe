import SwiftUI

// MARK: - Braider Profile (Editorial Redesign)

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var showBooking = false
    @State private var showAllReviews = false
    @State private var showWriteReview = false
    @State private var appeared = false
    @State private var scrollOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    @State private var reviews: [Review] = []
    @State private var breakdown: RatingBreakdown = .empty
    @State private var reviewsLoading = true

    // MARK: - Derived

    private var isSaved: Bool {
        fb.savedBraiderIds.contains(braider.id)
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    private var displayRating: String {
        guard breakdown.total > 0 else { return "New" }
        return String(format: "%.1f", breakdown.average)
    }

    private var hasAvailability: Bool {
        braider.services.contains { $0.hasAvailability }
    }

    private var sortedPortfolio: [PortfolioItem] {
        braider.portfolio
    }

    private var sortedServices: [BraidService] {
        braider.services.sorted { lhs, rhs in
            if lhs.popular != rhs.popular { return lhs.popular }
            return lhs.priceFrom < rhs.priceFrom
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                AppTheme.ink.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(width: geo.size.width, height: geo.size.height)
                        statsBar
                        portfolioSection
                        aboutSection
                        servicesSection
                        reviewsSection
                        bottomSpacer
                    }
                }
                .coordinateSpace(name: "profileScroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .ignoresSafeArea()

                floatingHeader
                floatingActionBar
            }
            .offset(x: dragOffset)
            .gesture(swipeBackGesture)
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .sheet(isPresented: $showAllReviews) {
            ReviewsListView(
                braider: braider,
                reviews: reviews,
                breakdown: breakdown,
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
        .task {
            await loadReviews()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                appeared = true
            }
        }
    }

    // MARK: - Swipe Back

    private var swipeBackGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.startLocation.x < 40 && value.translation.width > 0 {
                    dragOffset = min(value.translation.width, 220)
                }
            }
            .onEnded { value in
                if value.translation.width > 100 {
                    Haptics.soft()
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
    }

    // MARK: - Load

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            self.reviews = fetched
            self.breakdown = RatingBreakdown.from(fetched)
            self.reviewsLoading = false
        }
    }

    // MARK: - HERO

    private func heroSection(width: CGFloat, height: CGFloat) -> some View {
        let heroHeight = height * 0.72
        let progress = min(max(scrollOffset / heroHeight, 0), 1)

        return ZStack(alignment: .bottomLeading) {

            // Background image with parallax
            Group {
                if braider.coverUrl.isEmpty {
                    AppTheme.inkGradient
                } else {
                    RemoteImage(url: braider.coverUrl)
                }
            }
            .frame(width: width, height: heroHeight + 120)
            .clipped()
            .scaleEffect(1 + progress * 0.08)
            .offset(y: scrollOffset > 0 ? scrollOffset * 0.35 : 0)

            // Gradient overlay
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0.0),
                    .init(color: .black.opacity(0.05), location: 0.28),
                    .init(color: .black.opacity(0.15), location: 0.55),
                    .init(color: .black.opacity(0.75), location: 0.88),
                    .init(color: AppTheme.ink, location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Hero content
            VStack(alignment: .leading, spacing: 22) {

                // Availability pill
                HStack {
                    Spacer()
                    availabilityPill
                }
                .padding(.top, 100)

                Spacer()

                // Rating row (gold + number)
                HStack(spacing: 10) {
                    if breakdown.total > 0 {
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.gold)
                            }
                        }
                        Text(String(format: "%.1f", breakdown.average))
                            .font(AppTheme.sans(13, weight: .bold))
                            .foregroundColor(.white)
                        Text("·")
                            .foregroundColor(.white.opacity(0.4))
                        Text("\(breakdown.total) review\(breakdown.total == 1 ? "" : "s")")
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("New to BraidMe")
                                .font(AppTheme.sans(12, weight: .bold))
                                .tracking(0.6)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.9), in: Capsule())
                    }
                }

                // Name
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(braider.name)
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)

                    if braider.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppTheme.accentLight)
                            .shadow(color: .black.opacity(0.3), radius: 6)
                    }
                }

                // Tagline
                if !braider.tagline.isEmpty {
                    Text(braider.tagline)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }

                // Location + response time chips
                HStack(spacing: 8) {
                    heroChip(icon: "mappin.and.ellipse", text: braider.city)
                    if !braider.responseTime.isEmpty {
                        heroChip(icon: "clock.fill", text: braider.responseTime)
                    }
                }

                // Bio
                if !braider.bio.isEmpty {
                    Text(braider.bio)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.82))
                        .lineSpacing(5)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }

                // Scroll hint
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("SCROLL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.8)
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
                .opacity(scrollOffset < 30 ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: scrollOffset)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .frame(width: width, height: heroHeight)
        .clipped()
    }

    private var availabilityPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(hasAvailability ? AppTheme.success : AppTheme.stone)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(hasAvailability ? AppTheme.success : AppTheme.stone)
                    .frame(width: 8, height: 8)
                    .opacity(hasAvailability ? 0.6 : 0)
                    .scaleEffect(hasAvailability ? 2 : 1)
                    .animation(
                        hasAvailability
                            ? .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                            : .default,
                        value: hasAvailability
                    )
            }
            Text(hasAvailability ? "AVAILABLE" : "BOOKED OUT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
    }

    private func heroChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    }

    // MARK: - STATS BAR

    private var statsBar: some View {
        HStack(spacing: 0) {
            statCell(value: displayRating,
                     label: "Rating",
                     icon: "star.fill")

            divider

            statCell(value: "\(braider.yearsExperience)",
                     label: "Years",
                     icon: "clock.fill")

            divider

            statCell(value: "\(braider.reviewCount)",
                     label: "Bookings",
                     icon: "checkmark.seal.fill")

            divider

            statCell(value: "£\(braider.priceFrom)",
                     label: "From",
                     icon: "pound")
        }
        .padding(.vertical, 22)
        .background(AppTheme.snow)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(AppTheme.hairline),
            alignment: .bottom
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(width: 0.5, height: 34)
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accent)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundColor(AppTheme.stone)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - PORTFOLIO

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionHeader(
                eyebrow: "PORTFOLIO",
                title: "Recent work",
                count: sortedPortfolio.count
            )
            .padding(.horizontal, 24)

            if sortedPortfolio.isEmpty {
                emptyPortfolio
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(sortedPortfolio.enumerated()), id: \.element.id) { idx, item in
                            PortfolioEditorialCard(item: item, index: idx, appeared: appeared)
                                .frame(width: 280, height: 380)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 50)
        .background(AppTheme.ink)
    }

    private var emptyPortfolio: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            Text("Portfolio coming soon")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // MARK: - ABOUT

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionHeader(
                eyebrow: "ABOUT",
                title: "Meet \(firstName)",
                count: nil
            )
            .padding(.horizontal, 24)

            // Story
            if !braider.story.isEmpty || !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Her story")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(.white.opacity(0.5))

                    Text(braider.story.isEmpty ? braider.bio : braider.story)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, 24)
            }

            // Specialties
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specialties")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(.white.opacity(0.5))

                    FlowLayout(spacing: 8) {
                        ForEach(braider.specialties, id: \.self) { s in
                            HStack(spacing: 6) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.accentLight)
                                Text(s)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 50)
        .background(AppTheme.ink)
    }

    // MARK: - SERVICES

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            sectionHeader(
                eyebrow: "SERVICES",
                title: "What she offers",
                count: sortedServices.count
            )
            .padding(.horizontal, 24)

            if sortedServices.isEmpty {
                emptyServices
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(sortedServices.enumerated()), id: \.element.id) { idx, service in
                        ServiceEditorialRow(
                            service: service,
                            index: idx,
                            appeared: appeared,
                            onBook: {
                                Haptics.medium()
                                showBooking = true
                            }
                        )
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 50)
        .background(AppTheme.ink)
    }

    private var emptyServices: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            Text("Services coming soon")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - REVIEWS

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack(alignment: .top) {
                sectionHeader(
                    eyebrow: "REVIEWS",
                    title: "What clients say",
                    count: breakdown.total
                )
                Spacer()
                Button {
                    Haptics.medium()
                    showWriteReview = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("Write")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(AppTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentLight, in: Capsule())
                }
                .buttonStyle(SoftPress())
                .padding(.trailing, 24)
            }
            .padding(.leading, 24)

            if reviewsLoading {
                loadingReviews
            } else if breakdown.total == 0 {
                emptyReviews
                    .padding(.horizontal, 24)
            } else {
                // Rating summary + bars
                EditorialRatingBreakdown(breakdown: breakdown)
                    .padding(.horizontal, 24)

                // Preview of top 3 reviews
                VStack(spacing: 12) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { idx, review in
                        ReviewEditorialCard(
                            review: review,
                            index: idx,
                            appeared: appeared
                        )
                    }
                }
                .padding(.horizontal, 24)

                if reviews.count > 3 {
                    Button {
                        Haptics.soft()
                        showAllReviews = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Read all \(reviews.count) reviews")
                                .font(.system(size: 15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(SoftPress())
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 60)
        .background(AppTheme.ink)
    }

    private var loadingReviews: some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white)
            Text("Loading reviews…")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyReviews: some View {
        Button {
            Haptics.medium()
            showWriteReview = true
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 90, height: 90)
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                }

                VStack(spacing: 8) {
                    Text("No reviews yet")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    Text("Be the first to share your experience with \(firstName).")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 30)
                }

                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .bold))
                    Text("Write the first review")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(AppTheme.ink)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(AppTheme.accentLight, in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }

    // MARK: - Shared Section Header

    private func sectionHeader(eyebrow: String, title: String, count: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(AppTheme.accentLight)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Floating header

    private var floatingHeader: some View {
        let opacity: Double = {
            let progress = min(max((scrollOffset - 100) / 120, 0), 1)
            return progress
        }()

        return VStack {
            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.snow, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }
                .buttonStyle(BouncyPress())

                Spacer()

                Text(braider.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                    .opacity(opacity)

                Spacer()

                Button {
                    Haptics.soft()
                    Task {
                        guard let uid = session.uid.isEmpty ? nil : session.uid else { return }
                        await fb.toggleSave(braiderId: braider.id, uid: uid)
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSaved ? AppTheme.rose : AppTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.snow, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }
                .buttonStyle(BouncyPress())
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                Group {
                    if opacity > 0.1 {
                        LinearGradient(
                            colors: [
                                AppTheme.cloud.opacity(0.98 * opacity),
                                AppTheme.cloud.opacity(0.9 * opacity),
                                AppTheme.cloud.opacity(0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .top)
                    } else {
                        Color.clear
                    }
                }
            )
            Spacer()
        }
    }

    // MARK: - Floating action bar

    private var floatingActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Button {
                    Haptics.soft()
                    Task {
                        guard let uid = session.uid.isEmpty ? nil : session.uid else { return }
                        await fb.toggleSave(braiderId: braider.id, uid: uid)
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSaved ? AppTheme.rose : AppTheme.ink)
                        .frame(width: 58, height: 58)
                        .background(AppTheme.snow, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
                }
                .buttonStyle(BouncyPress())

                Button {
                    Haptics.medium()
                    showBooking = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Book \(firstName)")
                                .font(.system(size: 15, weight: .bold))
                            Text("from £\(braider.priceFrom)")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(AppTheme.inkGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: AppTheme.ink.opacity(0.35), radius: 20, y: 10)
                }
                .buttonStyle(SoftPress())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.ink.opacity(0),
                        AppTheme.ink.opacity(0.85),
                        AppTheme.ink
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var bottomSpacer: some View {
        Color.clear.frame(height: 120)
    }
}

// MARK: - Preference key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Portfolio card (editorial)

struct PortfolioEditorialCard: View {
    let item: PortfolioItem
    let index: Int
    let appeared: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if item.imageUrl.isEmpty {
                    Rectangle().fill(AppTheme.graphite)
                } else {
                    RemoteImage(url: item.imageUrl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.35), location: 0.7),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                if !item.tag.isEmpty {
                    Text(item.tag.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }

                if !item.caption.isEmpty {
                    Text(item.caption)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.9)
                .delay(Double(index) * 0.06 + 0.1),
            value: appeared
        )
    }
}

// MARK: - Service row (editorial)

struct ServiceEditorialRow: View {
    let service: BraidService
    let index: Int
    let appeared: Bool
    let onBook: () -> Void

    var body: some View {
        Button(action: onBook) {
            HStack(spacing: 16) {

                ZStack(alignment: .topTrailing) {
                    Group {
                        if service.imageUrl.isEmpty {
                            RoundedRectangle(cornerRadius: 14).fill(AppTheme.mist)
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.ash)
                                )
                        } else {
                            RemoteImage(url: service.imageUrl)
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if service.popular {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(AppTheme.gold, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(service.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("£\(service.priceFrom)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.accentDeep)
                        Text("·")
                            .foregroundColor(AppTheme.stone)
                        Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.slate)
                    }

                    if !service.description.isEmpty {
                        Text(service.description)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.stone)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.ash)
            }
            .padding(14)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        }
        .buttonStyle(CardPress())
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.9)
                .delay(Double(index) * 0.06 + 0.2),
            value: appeared
        )
    }
}

// MARK: - Rating breakdown

struct EditorialRatingBreakdown: View {
    let breakdown: RatingBreakdown
    @State private var animate = false

    private var bars: [(Int, Int)] {
        [(5, breakdown.five),
         (4, breakdown.four),
         (3, breakdown.three),
         (2, breakdown.two),
         (1, breakdown.one)]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 22) {

            VStack(spacing: 4) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.system(size: 52, weight: .bold, design: .serif))
                    .foregroundColor(.white)

                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.gold)
                    }
                }

                Text("\(breakdown.total) total")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 2)
            }
            .frame(width: 110)

            VStack(spacing: 8) {
                ForEach(bars, id: \.0) { stars, count in
                    HStack(spacing: 10) {
                        Text("\(stars)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 10)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.gold, AppTheme.accent],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: animate ? geo.size.width * ratio(count) : 0)
                                    .animation(
                                        .spring(response: 1.0, dampingFraction: 0.85)
                                            .delay(Double(5 - stars) * 0.05),
                                        value: animate
                                    )
                            }
                        }
                        .frame(height: 6)

                        Text("\(count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation { animate = true }
        }
    }

    private func ratio(_ count: Int) -> CGFloat {
        guard breakdown.total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(breakdown.total)
    }
}

// MARK: - Review card (editorial)

struct ReviewEditorialCard: View {
    let review: Review
    let index: Int
    let appeared: Bool

    private var accentColor: Color {
        if review.rating >= 4.5 { return AppTheme.gold }
        if review.rating >= 3.5 { return AppTheme.accentLight }
        return AppTheme.rose
    }

    private var initials: String {
        let parts = review.userName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "?" : r.uppercased()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 12) {

                // Header
                HStack(spacing: 10) {
                    if review.userAvatar.isEmpty {
                        ZStack {
                            Circle().fill(AppTheme.inkGradient).frame(width: 38, height: 38)
                            Text(initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        RemoteImage(url: review.userAvatar)
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(accentColor.opacity(0.4), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 5) {
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundColor(accentColor)
                                }
                            }
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                            Text(review.dateString)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()
                }

                // Text
                Text(review.text)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                // Style done chip
                if !review.styleDone.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "scissors")
                            .font(.system(size: 9, weight: .bold))
                        Text(review.styleDone)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.4)
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.9)
                .delay(Double(index) * 0.08 + 0.3),
            value: appeared
        )
    }
}

// MARK: - All reviews list

struct ReviewsListView: View {
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    let onWriteReview: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if breakdown.total > 0 {
                            LightRatingBreakdown(breakdown: breakdown)
                                .padding(.top, 10)
                        }

                        ForEach(Array(reviews.enumerated()), id: \.element.id) { idx, review in
                            LightReviewCard(review: review)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                                .animation(
                                    .spring(response: 0.7, dampingFraction: 0.9)
                                        .delay(Double(idx) * 0.05),
                                    value: appeared
                                )
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("All Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.medium()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onWriteReview()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11, weight: .bold))
                            Text("Write")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(AppTheme.accentDeep)
                    }
                }
            }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }
}

// MARK: - Light rating breakdown

struct LightRatingBreakdown: View {
    let breakdown: RatingBreakdown
    @State private var animate = false

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 5) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.ink)
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.gold)
                    }
                }
                Text("\(breakdown.total) reviews")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.stone)
            }
            .frame(width: 120)

            VStack(spacing: 8) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    HStack(spacing: 8) {
                        Text("\(stars)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.slate)
                            .frame(width: 10)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.hairline)
                                Capsule()
                                    .fill(AppTheme.gold)
                                    .frame(width: animate ? geo.size.width * ratio(stars) : 0)
                                    .animation(
                                        .spring(response: 0.9, dampingFraction: 0.85)
                                            .delay(Double(5 - stars) * 0.05),
                                        value: animate
                                    )
                            }
                        }
                        .frame(height: 7)

                        Text("\(count(stars))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.stone)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation { animate = true }
        }
    }

    private func ratio(_ stars: Int) -> CGFloat {
        guard breakdown.total > 0 else { return 0 }
        return CGFloat(count(stars)) / CGFloat(breakdown.total)
    }

    private func count(_ stars: Int) -> Int {
        switch stars {
        case 5: return breakdown.five
        case 4: return breakdown.four
        case 3: return breakdown.three
        case 2: return breakdown.two
        default: return breakdown.one
        }
    }
}

// MARK: - Light review card

struct LightReviewCard: View {
    let review: Review

    private var initials: String {
        let parts = review.userName.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "?" : r.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if review.userAvatar.isEmpty {
                    ZStack {
                        Circle().fill(AppTheme.inkGradient).frame(width: 44, height: 44)
                        Text(initials)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    RemoteImage(url: review.userAvatar)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(review.userName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(review.dateString)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.stone)
                }
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < review.rating.rounded() ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }

            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.ink.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "scissors")
                        .font(.system(size: 9, weight: .bold))
                    Text(review.styleDone)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.3)
                }
                .foregroundColor(AppTheme.accentDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accentSoft, in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.hairline.opacity(0.5), lineWidth: 0.5)
        )
    }
}