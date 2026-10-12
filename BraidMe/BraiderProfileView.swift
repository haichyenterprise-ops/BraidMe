import SwiftUI

// =============================================================================
// BraiderProfileView — rebuilt from scratch
//
// Layout:
//   1. Fixed-height hero (not scroll-collapsing — that was the bug source)
//   2. Content sections below, all native ScrollView
//   3. No custom drag gesture (iOS handles swipe-back natively)
//   4. No horizontal ScrollView inside vertical ScrollView (portfolio is a grid)
//
// This eliminates: swipe conflict, scroll freeze, text overflow.
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

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                contentStack
            }
            .padding(.bottom, 120)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            bottomBar
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

    // MARK: - Hero
    //
    // Fixed height. Content laid out with absolute control so nothing overflows.

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image or fallback
            Group {
                if !braider.coverUrl.isEmpty {
                    RemoteImage(url: braider.coverUrl)
                        .frame(height: 380)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    Color.appSurfaceInverse.frame(height: 380)
                }
            }

            // Legibility gradient
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.30), location: 0.0),
                    .init(color: .clear, location: 0.40),
                    .init(color: .black.opacity(0.55), location: 0.75),
                    .init(color: .black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 380)

            // Foreground content
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(alignment: .center, spacing: Space.md) {
                    BMAvatar(
                        url: braider.avatarUrl,
                        size: 72,
                        ringed: true,
                        initials: initials
                    )
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Space.xxs) {
                            Text(braider.name)
                                .font(.bmDisplay(24, weight: .semibold))
                                .foregroundStyle(Color.appInkInverse)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.bmUI(14))
                                    .foregroundStyle(Color.appAccentSoft)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.bmUI(13, weight: .medium))
                                .foregroundStyle(Color.appInkInverse.opacity(0.85))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: Space.sm) {
                    HStack(spacing: Space.xxs) {
                        Image(systemName: "star.fill")
                            .font(.bmUI(10))
                            .foregroundStyle(Color.appAccentSoft)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(12, weight: .semibold))
                            .foregroundStyle(Color.appInkInverse)
                        Text("·")
                            .font(.bmMono(12))
                            .foregroundStyle(Color.appInkInverse.opacity(0.5))
                        Text("\(braider.reviewCount) reviews")
                            .font(.bmUI(12))
                            .foregroundStyle(Color.appInkInverse.opacity(0.85))
                    }

                    Text("·")
                        .font(.bmUI(11))
                        .foregroundStyle(Color.appInkInverse.opacity(0.5))

                    HStack(spacing: 3) {
                        Image(systemName: "mappin")
                            .font(.bmUI(10))
                        Text(braider.city)
                            .font(.bmUI(12))
                    }
                    .foregroundStyle(Color.appInkInverse.opacity(0.85))

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .frame(height: 380)
        .clipped()
    }

    // MARK: - Content

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            statsRow
            portfolioGrid
            storySection
            specialtiesSection
            servicesSection
            reviewsSection
        }
        .padding(.top, Space.xl)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: String(format: "%.1f", braider.rating), label: "Rating")
            statDivider
            statItem(value: "\(braider.yearsExperience)", label: "Years")
            statDivider
            statItem(value: "\(braider.reviewCount)", label: "Reviews")
        }
        .padding(.horizontal, Space.lg)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(width: 0.5, height: 32)
            .padding(.horizontal, Space.lg)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.bmDisplay(24, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text(label.uppercased())
                .font(.bmUI(10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color.appAsh)
        }
    }

    // MARK: - Portfolio (grid, not horizontal scroll)

    private var portfolioGrid: some View {
        Group {
            if !braider.portfolio.isEmpty {
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack {
                        BMSectionLabel(text: "Portfolio")
                        Spacer()
                        Text("\(braider.portfolio.count) photos")
                            .font(.bmMono(11, weight: .medium))
                            .foregroundStyle(Color.appAsh)
                    }
                    .padding(.horizontal, Space.lg)

                    portfolioLayout
                }
                .padding(.vertical, Space.md)
                .background(Color.appSurfaceInverse)
            }
        }
    }

    // Layout: first image full-width tall, then a 2-column grid of the rest
    private var portfolioLayout: some View {
        let items = braider.portfolio
        return VStack(spacing: Space.xs) {
            if let first = items.first {
                PortfolioImageBlock(item: first, height: 340, index: 0, appeared: appeared)
                    .padding(.horizontal, Space.lg)
            }

            let rest = Array(items.dropFirst())
            if !rest.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Space.xs),
                        GridItem(.flexible(), spacing: Space.xs)
                    ],
                    spacing: Space.xs
                ) {
                    ForEach(Array(rest.enumerated()), id: \.element.id) { index, item in
                        PortfolioImageBlock(item: item, height: 180, index: index + 1, appeared: appeared)
                    }
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    // MARK: - Story

    private var storySection: some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: Space.sm) {
                    BMSectionLabel(text: "The story")
                        .padding(.horizontal, Space.lg)

                    Text(braider.bio)
                        .font(.bmDisplay(20, weight: .regular))
                        .foregroundStyle(Color.appInk)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.lg)
                }
            }
        }
    }

    // MARK: - Specialties

    private var specialtiesSection: some View {
        Group {
            if !braider.specialties.isEmpty {
                VStack(alignment: .leading, spacing: Space.sm) {
                    BMSectionLabel(text: "Specialties")
                        .padding(.horizontal, Space.lg)

                    FlowLayout(spacing: Space.xs) {
                        ForEach(braider.specialties, id: \.self) { s in
                            Text(s)
                                .font(.bmUI(13, weight: .medium))
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, Space.sm)
                                .frame(minHeight: 32)
                                .padding(.vertical, 6)
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

                    VStack(spacing: 0) {
                        ForEach(Array(braider.services.enumerated()), id: \.element.id) { index, service in
                            ServiceRowTappable(service: service) {
                                Haptic.select()
                                showBookingForService = service
                            }
                            if index < braider.services.count - 1 {
                                BMDivider(inset: Space.lg)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                BMSectionLabel(text: "Reviews")
                Spacer()
                Button {
                    Haptic.press()
                    showWriteReview = true
                } label: {
                    HStack(spacing: Space.xxs) {
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

            if reviewsLoading {
                BMLoadingView(message: "Loading reviews")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.lg)
            } else if reviews.isEmpty {
                emptyReviews
            } else {
                let breakdown = RatingBreakdown.from(reviews)

                HStack(alignment: .center, spacing: Space.md) {
                    Text(String(format: "%.1f", breakdown.average))
                        .font(.bmDisplay(44, weight: .semibold))
                        .foregroundStyle(Color.appInk)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                                    .font(.bmUI(12))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        Text("\(reviews.count) review\(reviews.count == 1 ? "" : "s")")
                            .font(.bmUI(12))
                            .foregroundStyle(Color.appAsh)
                    }

                    Spacer()
                }
                .padding(.horizontal, Space.lg)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(2).enumerated()), id: \.element.id) { index, review in
                        ReviewRowView(review: review)
                        if index < min(reviews.count, 2) - 1 {
                            BMDivider(inset: Space.lg)
                        }
                    }
                }

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
                            Image(systemName: "chevron.right")
                                .font(.bmUI(11, weight: .semibold))
                                .foregroundStyle(Color.appAccent)
                        }
                        .padding(.horizontal, Space.lg)
                        .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private var emptyReviews: some View {
        VStack(spacing: Space.sm) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.bmUI(24, weight: .light))
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
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
                    BMPrimaryButton(
                        title: "Book \(firstName)",
                        subtitle: "from £\(braider.priceFrom)",
                        icon: "calendar"
                    ) {
                        showBooking = true
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

// MARK: - Portfolio image block

struct PortfolioImageBlock: View {
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

            if !item.caption.isEmpty {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
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
        .scaleEffect(revealed ? 1 : 0.96)
        .animate(Motion.reveal.delay(Motion.stagger(index)), value: revealed)
        .onAppear { if appeared { revealed = true } }
        .onChange(of: appeared) { _, newValue in
            if newValue { revealed = true }
        }
    }
}

// MARK: - Service row (tappable)

struct ServiceRowTappable: View {
    let service: BraidService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Space.md) {
                ZStack {
                    if service.imageUrl.isEmpty {
                        RoundedRectangle(cornerRadius: Radius.button)
                            .fill(Color.appDivider)
                            .frame(width: 60, height: 60)
                        Image(systemName: "photo")
                            .font(.bmUI(20))
                            .foregroundStyle(Color.appSmoke)
                    } else {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
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
                    HStack(spacing: Space.xs) {
                        Text("£\(service.priceFrom)")
                            .font(.bmMono(13, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                        Text("·")
                            .foregroundStyle(Color.appSmoke)
                        Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                            .font(.bmUI(12))
                            .foregroundStyle(Color.appAsh)
                    }
                    if !service.description.isEmpty {
                        Text(service.description)
                            .font(.bmUI(12))
                            .foregroundStyle(Color.appAsh)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.bmUI(12, weight: .semibold))
                    .foregroundStyle(Color.appSmoke)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}

// MARK: - Review row

struct ReviewRowView: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: review.userAvatar, size: 36, initials: userInitials)
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.bmUI(13, weight: .semibold))
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
                .foregroundStyle(Color.appInk.opacity(0.88))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                Text(review.styleDone)
                    .font(.bmUI(10, weight: .semibold))
                    .tracking(0.4)
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

// MARK: - Flow layout

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