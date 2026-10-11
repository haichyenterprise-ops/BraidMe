import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @StateObject private var fb = FirebaseManager.shared

    @State private var showBooking = false
    @State private var showAllReviews = false
    @State private var showWriteReview = false
    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var heroScale: CGFloat = 1
    @State private var headerOpacity: Double = 0
    @State private var activeSection: Section = .hero

    @State private var reviews: [Review] = []
    @State private var breakdown: RatingBreakdown = .empty
    @State private var reviewsLoading = true

    enum Section: Int, CaseIterable {
        case hero, work, about, reviews
    }

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                AppTheme.ink.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection(width: geo.size.width, height: geo.size.height)
                        workSection(width: geo.size.width)
                        aboutSection(width: geo.size.width)
                        reviewsSection(width: geo.size.width)
                        Color.clear.frame(height: 160)
                    }
                    .background(alignment: .top) {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetKey.self,
                                    value: -proxy.frame(in: .named("braiderProfileScroll")).minY
                                )
                        }
                    }
                }
                .coordinateSpace(name: "braiderProfileScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    handleScroll(value, screenHeight: geo.size.height)
                }
                .ignoresSafeArea()

                topChrome.opacity(headerOpacity)

                stageRail
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.trailing, 12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    actionBar
                }
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow rightward swipe that starts near the left edge
                        if value.startLocation.x < 40 && value.translation.width > 0 {
                            dragOffset = min(value.translation.width, 240)
                        }
                    }
                    .onEnded { value in
                        if value.translation.width > 100 {
                            Haptics.soft()
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
        .sheet(isPresented: $showAllReviews) {
            AllReviewsSheet(
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
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            Task { await loadReviews() }
        }
    }

    // MARK: - Load reviews

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            self.reviews = fetched
            self.breakdown = RatingBreakdown.from(fetched)
            self.reviewsLoading = false
        }
    }

    // MARK: - Scroll

    private func handleScroll(_ offset: CGFloat, screenHeight: CGFloat) {
        scrollOffset = offset
        let progress = min(max(offset / screenHeight, 0), 1)
        heroScale = 1 + progress * 0.15
        headerOpacity = min(max((offset - 60) / 200, 0), 1)

        let normalized = offset / screenHeight
        let newSection: Section
        if normalized < 0.8 { newSection = .hero }
        else if normalized < 1.6 { newSection = .work }
        else if normalized < 2.4 { newSection = .about }
        else { newSection = .reviews }

        if newSection != activeSection {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                activeSection = newSection
            }
            Haptics.select()
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                        Text("Map")
                            .font(AppTheme.sans(13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(AppTheme.snow, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                }
                .buttonStyle(BouncyPress())

                Spacer()

                Button {
                    Haptics.soft()
                    Task {
                        if let uid = session.uid.isEmpty ? nil : session.uid {
                            await fb.toggleSave(braiderId: braider.id, uid: uid)
                        }
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSaved ? AppTheme.rose : AppTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.snow, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                }
                .buttonStyle(BouncyPress())
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [
                        AppTheme.cloud.opacity(0.98),
                        AppTheme.cloud.opacity(0.9),
                        AppTheme.cloud.opacity(0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
            Spacer()
        }
    }

    private var stageRail: some View {
        VStack(spacing: 10) {
            ForEach(Section.allCases, id: \.rawValue) { section in
                Circle()
                    .fill(section == activeSection ? AppTheme.accent : Color.white.opacity(0.5))
                    .frame(
                        width: section == activeSection ? 8 : 6,
                        height: section == activeSection ? 8 : 6
                    )
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeSection)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        .opacity(headerOpacity)
    }

    private var actionBar: some View {
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
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            }
            .buttonStyle(BouncyPress())

            Button {
                Haptics.medium()
                showBooking = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Book with \(firstName)")
                            .font(AppTheme.sans(15, weight: .semibold))
                        Text("from £\(braider.priceFrom)")
                            .font(AppTheme.sans(11, weight: .medium))
                            .opacity(0.75)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AppTheme.inkGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: AppTheme.ink.opacity(0.3), radius: 18, y: 8)
            }
            .buttonStyle(SoftPress())
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud.opacity(0.95), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    // MARK: - Hero

    private func heroSection(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if !braider.coverUrl.isEmpty {
                RemoteImage(url: braider.coverUrl)
                    .frame(width: width, height: height)
                    .clipped()
                    .scaleEffect(heroScale)
                    .offset(y: scrollOffset > 0 ? scrollOffset * 0.4 : 0)
            } else {
                AppTheme.inkGradient
                    .frame(width: width, height: height)
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0.0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.35), location: 0.65),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    availabilityBadge
                }
                .padding(.top, 90)

                Spacer()

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.accentLight, lineWidth: 2.5)
                            .frame(width: 92, height: 92)
                        if braider.avatarUrl.isEmpty {
                            ZStack {
                                Circle().fill(AppTheme.inkGradient)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .frame(width: 82, height: 82)
                        } else {
                            RemoteImage(url: braider.avatarUrl)
                                .frame(width: 82, height: 82)
                                .clipShape(Circle())
                        }
                    }
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(braider.name)
                                .font(AppTheme.serif(28))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.accentLight)
                            }
                        }
                        Text(braider.tagline)
                            .font(AppTheme.sans(13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    if breakdown.total > 0 {
                        GlassChip(icon: "star.fill",
                                  title: String(format: "%.1f", breakdown.average))
                    } else {
                        GlassChip(icon: "star", title: "New")
                    }
                    GlassChip(icon: "mappin.and.ellipse", title: braider.city)
                    GlassChip(icon: "clock", title: braider.responseTime)
                }

                Text(braider.bio)
                    .font(AppTheme.sans(14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("Scroll to explore")
                        .font(AppTheme.sans(11, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 4)
                .opacity(scrollOffset < 40 ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: scrollOffset)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var availabilityBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppTheme.success)
                .frame(width: 6, height: 6)
                .shadow(color: AppTheme.success, radius: 4)
            Text(hasAvailability ? "Available" : "No availability")
                .font(AppTheme.sans(11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
    }

    private var hasAvailability: Bool {
        braider.services.contains { $0.hasAvailability }
    }

    // MARK: - Work

    private func workSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(eyebrow: "PORTFOLIO",
                          title: "Recent work",
                          subtitle: "\(braider.portfolio.count) photos")
                .padding(.horizontal, 24)

            if braider.portfolio.isEmpty {
                emptyPortfolio
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { idx, item in
                            WorkCard(item: item, index: idx)
                                .frame(width: 260, height: 400)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private var emptyPortfolio: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.white.opacity(0.35))
            Text("No portfolio yet")
                .font(AppTheme.sans(14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - About

    private func aboutSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(eyebrow: "ABOUT",
                          title: "Meet \(firstName)",
                          subtitle: braider.city)
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                statBlock(value: breakdown.total > 0 ? String(format: "%.1f", breakdown.average) : "—",
                          label: "Rating",
                          icon: "star.fill",
                          tint: AppTheme.gold)
                statBlock(value: "\(braider.yearsExperience)",
                          label: "Years exp.",
                          icon: "clock.fill",
                          tint: AppTheme.accentLight)
                statBlock(value: "\(breakdown.total)",
                          label: "Reviews",
                          icon: "bubble.left.fill",
                          tint: AppTheme.sage)
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("The story")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.45))

                Text(braider.bio.isEmpty ? "—" : braider.bio)
                    .font(AppTheme.sans(15))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Specialties")
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.45))

                    FlowLayout(spacing: 8) {
                        ForEach(braider.specialties, id: \.self) { s in
                            HStack(spacing: 6) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppTheme.accentLight)
                                Text(s)
                                    .font(AppTheme.sans(13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private func statBlock(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)
            }
            Text(value)
                .font(AppTheme.serif(30))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label.uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(1.1)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Reviews

    private func reviewsSection(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                sectionHeader(eyebrow: "REVIEWS",
                              title: "What clients say",
                              subtitle: breakdown.total == 0 ? "Be the first" : "\(breakdown.total) total")
                Spacer()
                Button {
                    Haptics.medium()
                    showWriteReview = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Write")
                            .font(AppTheme.sans(12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(AppTheme.accent, in: Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(SoftPress())
            }
            .padding(.horizontal, 24)

            if reviewsLoading {
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Loading reviews…")
                        .font(AppTheme.sans(12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if reviews.isEmpty {
                emptyReviews
                    .padding(.horizontal, 24)
            } else {
                RatingBloom(breakdown: breakdown)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { idx, r in
                        ReviewCinemaCard(review: r, index: idx)
                            .padding(.horizontal, 24)
                    }
                }

                if reviews.count > 3 {
                    Button {
                        Haptics.soft()
                        showAllReviews = true
                    } label: {
                        HStack {
                            Text("Read all \(reviews.count) reviews")
                                .font(AppTheme.sans(15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(SoftPress())
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 40)
        .frame(width: width, alignment: .leading)
        .background(AppTheme.ink)
    }

    private var emptyReviews: some View {
        Button {
            Haptics.medium()
            showWriteReview = true
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.5))
                }

                VStack(spacing: 6) {
                    Text("No reviews yet")
                        .font(AppTheme.serif(20))
                        .foregroundColor(.white)
                    Text("Be the first to review \(firstName). Your feedback helps others decide.")
                        .font(AppTheme.sans(13))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                }

                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Write the first review")
                        .font(AppTheme.sans(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .background(AppTheme.bronzeGradient, in: Capsule())
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPress())
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(2.0)
                .foregroundColor(AppTheme.accentLight)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(AppTheme.serif(26))
                    .foregroundColor(.white)

                Text("·")
                    .font(AppTheme.sans(20))
                    .foregroundColor(.white.opacity(0.3))

                Text(subtitle)
                    .font(AppTheme.sans(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Scroll offset key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Work card

struct WorkCard: View {
    let item: PortfolioItem
    let index: Int

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(appeared ? 1 : 1.05)
                .animation(
                    .spring(response: 0.9, dampingFraction: 0.85).delay(Double(index) * 0.08),
                    value: appeared
                )

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.6), .black.opacity(0.95)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Text(item.tag.uppercased())
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))

                    Spacer()
                }

                Text(item.caption)
                    .font(AppTheme.serif(17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.85).delay(Double(index) * 0.08 + 0.15),
                value: appeared
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .onAppear {
            withAnimation { appeared = true }
        }
    }
}

// MARK: - Rating Bloom

struct RatingBloom: View {
    let breakdown: RatingBreakdown
    @State private var animate = false

    private var barData: [(stars: Int, count: Int)] {
        [
            (5, breakdown.five),
            (4, breakdown.four),
            (3, breakdown.three),
            (2, breakdown.two),
            (1, breakdown.one)
        ]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: animate ? CGFloat(breakdown.average / 5.0) : 0)
                    .stroke(AppTheme.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(
                        .spring(response: 1.2, dampingFraction: 0.85).delay(0.2),
                        value: animate
                    )
                    .shadow(color: AppTheme.gold.opacity(0.5), radius: 8)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", breakdown.average))
                        .font(AppTheme.serif(38))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    StarRow(rating: breakdown.average, size: 9, color: AppTheme.gold)
                    Text("\(breakdown.total)")
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 2)
                }
            }

            VStack(spacing: 8) {
                ForEach(barData, id: \.stars) { data in
                    HStack(spacing: 10) {
                        Text("\(data.stars)")
                            .font(AppTheme.sans(11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 10)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [AppTheme.gold, AppTheme.accent],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: animate ? geo.size.width * ratio(data.count) : 0)
                                    .animation(
                                        .spring(response: 1.0, dampingFraction: 0.85)
                                            .delay(0.3 + Double(5 - data.stars) * 0.06),
                                        value: animate
                                    )
                            }
                        }
                        .frame(height: 6)

                        Text("\(data.count)")
                            .font(AppTheme.sans(11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear { withAnimation { animate = true } }
    }

    private func ratio(_ count: Int) -> CGFloat {
        guard breakdown.total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(breakdown.total)
    }
}

// MARK: - Cinema review card

struct ReviewCinemaCard: View {
    let review: Review
    let index: Int

    @State private var appeared = false

    private var accentColor: Color {
        if review.rating >= 4.5 { return AppTheme.gold }
        if review.rating >= 3.5 { return AppTheme.accent }
        return AppTheme.rose
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if review.userAvatar.isEmpty {
                        ZStack {
                            Circle().fill(AppTheme.inkGradient).frame(width: 36, height: 36)
                            Text(String(review.userName.prefix(1)).uppercased())
                                .font(AppTheme.sans(14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        RemoteImage(url: review.userAvatar)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(accentColor.opacity(0.4), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName)
                            .font(AppTheme.sans(13, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 5) {
                            StarRow(rating: review.rating, size: 9, color: accentColor)
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                            Text(review.dateString)
                                .font(AppTheme.sans(10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()
                }

                Text(review.text)
                    .font(AppTheme.sans(13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)

                if !review.styleDone.isEmpty {
                    Text(review.styleDone)
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(0.4)
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(
            .spring(response: 0.7, dampingFraction: 0.85).delay(Double(index) * 0.1),
            value: appeared
        )
        .onAppear { withAnimation { appeared = true } }
    }
}

// MARK: - All reviews sheet

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
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if breakdown.total > 0 {
                            ReviewSummaryLight(breakdown: breakdown)
                        }

                        ForEach(Array(reviews.enumerated()), id: \.element.id) { idx, r in
                            LightReviewCard(review: r)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 24)
                                .animation(
                                    .spring(response: 0.7, dampingFraction: 0.85)
                                        .delay(Double(idx) * 0.06),
                                    value: appeared
                                )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
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
                                .font(.system(size: 12, weight: .semibold))
                            Text("Write")
                                .font(AppTheme.sans(14, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.accentDeep)
                    }
                }
            }
            .onAppear { withAnimation { appeared = true } }
        }
    }
}

struct ReviewSummaryLight: View {
    let breakdown: RatingBreakdown

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 6) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(AppTheme.serif(44))
                    .foregroundColor(AppTheme.ink)
                StarRow(rating: breakdown.average, size: 11)
                Text("\(breakdown.total) reviews")
                    .font(AppTheme.sans(11, weight: .medium))
                    .foregroundColor(AppTheme.stone)
            }
            .frame(width: 110)

            VStack(spacing: 7) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    HStack(spacing: 8) {
                        Text("\(stars)")
                            .font(AppTheme.sans(11, weight: .bold))
                            .foregroundColor(AppTheme.slate)
                            .frame(width: 10)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.hairline)
                                Capsule()
                                    .fill(AppTheme.gold)
                                    .frame(width: geo.size.width * ratio(stars))
                            }
                        }
                        .frame(height: 6)

                        Text("\(count(stars))")
                            .font(AppTheme.sans(11, weight: .medium))
                            .foregroundColor(AppTheme.stone)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
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

struct LightReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if review.userAvatar.isEmpty {
                    ZStack {
                        Circle().fill(AppTheme.inkGradient).frame(width: 42, height: 42)
                        Text(String(review.userName.prefix(1)).uppercased())
                            .font(AppTheme.sans(15, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    RemoteImage(url: review.userAvatar)
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(review.dateString)
                        .font(AppTheme.sans(11))
                        .foregroundColor(AppTheme.stone)
                }
                Spacer()
                StarRow(rating: review.rating, size: 11)
            }

            Text(review.text)
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.ink.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                HStack(spacing: 10) {
                    Pill(icon: "scissors", text: review.styleDone,
                         fg: AppTheme.accentDeep, bg: AppTheme.accentSoft)
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
    }
}

// MARK: - Flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

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
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

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