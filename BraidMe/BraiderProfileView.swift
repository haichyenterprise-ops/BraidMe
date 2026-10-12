import SwiftUI

// =============================================================================
// BraiderProfileView — Editorial premium braider profile
// Full-bleed photographic hero, cinematic typography, artist metrics,
// horizontal portfolio, service cards, reviews, and persistent booking dock.
// =============================================================================

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
    @State private var heroAppeared = false
    @State private var contentAppeared = false
    @State private var savedPulse = false

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }

    private var initials: String {
        braider.name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var ratingText: String {
        reviews.isEmpty ? String(format: "%.1f", braider.rating) :
            String(format: "%.1f", RatingBreakdown.from(reviews).average)
    }

    private var ratingCount: Int {
        reviews.isEmpty ? braider.reviewCount : reviews.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                hero
                profileOverview
                portfolioSection
                servicesSection
                reviewsSection
                footer
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
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
            withAnimation(Motion.heroReveal.delay(0.1)) { heroAppeared = true }
            withAnimation(Motion.heroReveal.delay(0.3)) { contentAppeared = true }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                Group {
                    if !braider.coverUrl.isEmpty {
                        RemoteImage(url: braider.coverUrl)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else if let first = braider.portfolio.first {
                        RemoteImage(url: first.imageUrl)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color.appSurfaceInverse, Color.appInk],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.55), location: 0),
                            .init(color: .clear, location: 0.35),
                            .init(color: .black.opacity(0.15), location: 0.55),
                            .init(color: .black.opacity(0.92), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            VStack {
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
                        withAnimation(Motion.bouncy) {
                            savedPulse = true
                        }
                        Task {
                            guard !session.uid.isEmpty else { return }
                            await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                            Haptic.success()
                            withAnimation(Motion.bouncy) { savedPulse = false }
                        }
                    }
                    .scaleEffect(savedPulse ? 1.2 : 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 58)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : -20)

                Spacer()

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Verified badge
                        HStack(spacing: 7) {
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.appAccentSoft)
                                Text("VERIFIED ARTIST")
                                    .tracking(2.5)
                            } else {
                                Text("INDEPENDENT BRAIDER")
                                    .tracking(2.5)
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                        // Name
                        HStack(alignment: .center, spacing: 8) {
                            Text(braider.name)
                                .font(.system(size: 38, weight: .regular, design: .serif))
                                .tracking(-1.2)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.appAccentSoft)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(2)
                        }

                        // Meta row
                        HStack(spacing: 10) {
                            Label(braider.city, systemImage: "mappin")
                            Circle().fill(.white.opacity(0.5)).frame(width: 3, height: 3)
                            Label(ratingText, systemImage: "star.fill")
                            Text("(\(ratingCount))")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    if !braider.avatarUrl.isEmpty {
                        BMAvatar(url: braider.avatarUrl, size: 64, initials: initials, glow: true)
                            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 2.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
                .opacity(heroAppeared ? 1 : 0)
                .offset(y: heroAppeared ? 0 : 30)
            }
        }
        .frame(height: 560)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Overview

    private var profileOverview: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Metrics
            HStack(alignment: .top, spacing: 0) {
                metric(value: ratingText, label: "RATING", icon: "star.fill")
                metricDivider
                metric(value: "\(ratingCount)", label: "REVIEWS")
                metricDivider
                metric(value: "\(braider.services.count)", label: "SERVICES")
                metricDivider
                metric(value: "£\(braider.priceFrom)", label: "FROM")
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 20)

            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    eyebrow("THE ARTIST")
                    Text(braider.bio)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.appInk.opacity(0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }

            if !braider.specialties.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(braider.specialties, id: \.self) { specialty in
                            Text(specialty.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                        }
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 36)
        .animate(Motion.reveal, value: contentAppeared)
    }

    private func metric(value: String, label: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Text(value)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.appAsh)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(width: 1, height: 38)
            .padding(.horizontal, 10)
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading(kicker: "SELECTED WORK", title: "The portfolio")
                .padding(.horizontal, 24)

            if braider.portfolio.isEmpty {
                emptySection(
                    icon: "camera",
                    title: "Portfolio coming soon",
                    message: "New styles from \(firstName) will appear here."
                )
                .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { index, item in
                            Button {
                                Haptic.select()
                                selectedPortfolioItem = item
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    ZStack(alignment: .bottomLeading) {
                                        RemoteImage(url: item.imageUrl)
                                            .frame(width: 240, height: 300)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.6)],
                                            startPoint: .center,
                                            endPoint: .bottom
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(16)
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
                                        }
                                    }
                                    .frame(width: 240, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 40)
        .fullScreenCover(item: $selectedPortfolioItem) { item in
            PortfolioDetailView(item: item, name: braider.name)
        }
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading(kicker: "MAKE IT YOURS", title: "Services")
                .padding(.horizontal, 24)

            if braider.services.isEmpty {
                emptySection(
                    icon: "calendar",
                    title: "Services coming soon",
                    message: "Check back soon for available styles and appointments."
                )
                .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(braider.services) { service in
                        Button {
                            Haptic.select()
                            showBookingForService = service
                        } label: {
                            HStack(spacing: 16) {
                                if !service.imageUrl.isEmpty {
                                    RemoteImage(url: service.imageUrl)
                                        .frame(width: 88, height: 100)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                } else {
                                    ZStack {
                                        Color.appSurfaceElevated
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 22, weight: .light))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    .frame(width: 88, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    if service.popular {
                                        Text("SIGNATURE STYLE")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(1.3)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    Text(service.name)
                                        .font(.system(size: 17, weight: .medium, design: .serif))
                                        .foregroundStyle(Color.appInk)
                                        .multilineTextAlignment(.leading)
                                    Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.appAsh)
                                    Text("From £\(service.priceFrom)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.appInk)
                                }
                                Spacer(minLength: 0)
                                
                                ZStack {
                                    Circle()
                                        .fill(Color.appInk)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.appInkInverse)
                                }
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appDivider.opacity(0.8), lineWidth: 0.8)
                            )
                            .shadow(color: Color.appInk.opacity(0.04), radius: 12, y: 4)
                        }
                        .buttonStyle(BMPressStyle(scale: 0.99))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 42)
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                sectionHeading(kicker: "CLIENT EXPERIENCES", title: "Kind words")
                Spacer()
                if !reviews.isEmpty {
                    Button {
                        showAllReviews = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("All reviews")
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
                    .padding(.vertical, 32)
            } else if reviews.isEmpty {
                emptySection(
                    icon: "quote.opening",
                    title: "The first word is yours",
                    message: "There are no reviews yet. Book an appointment and share your experience."
                )
                .padding(.horizontal, 24)
            } else {
                // Aggregate card
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ratingText)
                            .font(.system(size: 52, weight: .regular, design: .serif))
                            .tracking(-2)
                            .foregroundStyle(Color.appInk)
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < RatingBreakdown.from(reviews).average.rounded() ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                        Text("\(reviews.count) verified review\(reviews.count == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appAsh)
                    }
                    .frame(width: 130, alignment: .leading)

                    Rectangle()
                        .fill(Color.appDivider)
                        .frame(width: 1, height: 78)

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                            let breakdown = RatingBreakdown.from(reviews)
                            let count = breakdownCount(star, breakdown)
                            HStack(spacing: 8) {
                                Text("\(star)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color.appAsh)
                                    .frame(width: 8)
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.appDivider)
                                        Capsule()
                                            .fill(Color.appAccent)
                                            .frame(width: proxy.size.width * (reviews.isEmpty ? 0 : CGFloat(count) / CGFloat(reviews.count)))
                                    }
                                }
                                .frame(height: 4)
                                Text("\(count)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color.appAsh)
                                    .frame(width: 22, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider, lineWidth: 0.8))
                .shadow(color: Color.appInk.opacity(0.04), radius: 12, y: 4)
                .padding(.horizontal, 24)

                // Recent reviews
                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                        SheetReviewRow(review: review)
                            .padding(.horizontal, 8)
                        if index < min(reviews.count, 3) - 1 {
                            Rectangle()
                                .fill(Color.appDivider)
                                .frame(height: 0.8)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .padding(.horizontal, 16)

                if reviews.count > 3 {
                    Button {
                        showAllReviews = true
                    } label: {
                        HStack {
                            Text("Read all \(reviews.count) reviews")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    }
                }
            }

            Button {
                Haptic.press()
                showWriteReview = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                    Text("Share your experience")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.appSurface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appDivider, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(BMPressStyle(scale: 0.99))
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 42)
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

    // MARK: - Shared Pieces

    private func sectionHeading(kicker: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow(kicker)
            Text(title)
                .font(.system(size: 32, weight: .regular, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(Color.appInk)
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color.appAsh)
    }

    private func emptySection(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccentTint)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.appAccent)
            }
            Text(title)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.appAccent.opacity(0.8)).frame(width: 3)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("BRAIDME")
                .font(.system(size: 10, weight: .bold))
                .tracking(4)
                .foregroundStyle(Color.appAsh)
            Text("Good hair. Great feeling.")
                .font(.system(size: 13, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var bookingDock: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("STARTING FROM")
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
                HStack(spacing: 12) {
                    Text("Book now")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appInkInverse)
                .padding(.horizontal, 24)
                .frame(height: 56)
                .background(Color.appInk, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: Color.appInk.opacity(0.25), radius: 16, y: 8)
            }
            .buttonStyle(BMPressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            Color.appBackground
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appDivider.opacity(0), Color.appDivider, Color.appDivider.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 0.8)
                }
        }
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    private func loadReviews() async {
        await MainActor.run { reviewsLoading = true }
        let fetched = await FirebaseManager.shared.fetchReviews(braiderId: braider.id)
        await MainActor.run {
            reviews = fetched
            reviewsLoading = false
        }
    }
}

// MARK: - Portfolio Lightbox

private struct PortfolioDetailView: View {
    let item: PortfolioItem
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var imageScale: CGFloat = 1.1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    BMGlassIconButton(icon: "xmark", size: 44, iconSize: 14, tint: .white) {
                        dismiss()
                    }
                    Spacer()
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 20)

                RemoteImage(url: item.imageUrl)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 600)
                    .clipped()
                    .scaleEffect(imageScale)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 20)

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
            withAnimation(Motion.heroReveal) {
                appeared = true
                imageScale = 1
            }
        }
    }
}

// MARK: - All Reviews Sheet

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
                            SheetReviewRow(review: r)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
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
            .onAppear {
                withAnimation(Motion.reveal.delay(0.1)) { appeared = true }
            }
        }
    }
}