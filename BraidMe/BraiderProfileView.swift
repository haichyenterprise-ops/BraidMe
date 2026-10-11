import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false
    @State private var scrollOffset: CGFloat = 0
    @State private var heroScale: CGFloat = 1
    @State private var appeared = false
    @State private var reviewsAppeared = false
    @State private var currentReview: Review?
    @State private var showAllReviews = false

    private let reviews: [Review]
    private let breakdown: RatingBreakdown

    init(braider: Braider) {
        self.braider = braider
        self.reviews = FirebaseManager.shared.reviews(for: braider)
        self.breakdown = FirebaseManager.shared.ratingBreakdown(for: braider)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.cloud.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroHeader
                        .padding(.bottom, 0)

                    VStack(spacing: 28) {
                        statsStrip
                            .padding(.top, 20)

                        specialtiesRow

                        portfolioSection

                        aboutSection

                        reviewsSection

                        Color.clear.frame(height: 140)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }

            stickyBookBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            topNav
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsSheet(braider: braider, reviews: reviews, breakdown: breakdown)
        }
        .fullScreenCover(isPresented: $showBooking) {
            BookingSelectionView(braider: braider)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Top nav

    private var topNav: some View {
        HStack {
            IconButton(icon: "chevron.left", size: 40, iconSize: 16) {
                dismiss()
            }
            Spacer()
            IconButton(icon: "square.and.arrow.up", size: 40, iconSize: 15) {
                // share
            }
            IconButton(icon: "heart", size: 40, iconSize: 15) {
                Haptics.soft()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Hero

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                let minY = geo.frame(in: .named("scroll")).minY
                let scale = max(1, 1 + (minY / 400))
                RemoteImage(url: braider.coverUrl)
                    .frame(width: geo.size.width, height: 400 + (minY > 0 ? minY : 0))
                    .scaleEffect(scale)
                    .clipped()
                    .offset(y: minY > 0 ? -minY : 0)
            }
            .frame(height: 400)

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.5), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 400)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                        Circle()
                            .stroke(AppTheme.snow, lineWidth: 4)
                            .frame(width: 92, height: 92)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 6)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text(braider.name)
                        .font(AppTheme.serif(32))
                        .foregroundColor(.white)
                    if braider.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accentLight)
                    }
                }

                Text(braider.tagline)
                    .font(AppTheme.sans(15, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))

                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.gold)
                        Text(String(format: "%.1f", braider.rating))
                            .font(AppTheme.sans(13, weight: .bold))
                            .foregroundColor(.white)
                        Text("(\(braider.reviewCount))")
                            .font(AppTheme.sans(12))
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Circle().fill(Color.white.opacity(0.4)).frame(width: 3, height: 3)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .semibold))
                        Text(braider.city)
                            .font(AppTheme.sans(12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .frame(height: 400)
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Stat strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statItem(value: String(format: "%.1f", braider.rating), label: "Rating", icon: "star.fill")
            Divider().frame(height: 34).background(AppTheme.hairline)
            statItem(value: "\(braider.yearsExperience)y", label: "Experience", icon: "clock.fill")
            Divider().frame(height: 34).background(AppTheme.hairline)
            statItem(value: "\(braider.reviewCount)", label: "Bookings", icon: "calendar")
        }
        .padding(.vertical, 16)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.045), radius: 14, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(value)
                    .font(AppTheme.serif(20))
                    .foregroundColor(AppTheme.ink)
            }
            Text(label.uppercased())
                .font(AppTheme.sans(9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(AppTheme.stone)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Specialties

    private var specialtiesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Specialties")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(braider.specialties, id: \.self) { s in
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                            Text(s)
                                .font(AppTheme.sans(13, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(AppTheme.accentSoft)
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "Portfolio")
                Spacer()
                Text("\(braider.portfolio.count) photos")
                    .font(AppTheme.sans(12, weight: .medium))
                    .foregroundColor(AppTheme.stone)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { idx, item in
                        PortfolioCard(item: item)
                            .frame(width: 240, height: 300)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.7, dampingFraction: 0.85)
                                    .delay(0.1 + Double(idx) * 0.06),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "About")
            Text(braider.bio)
                .font(AppTheme.sans(15))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                infoPill(icon: "clock", label: "Responds \(braider.responseTime)")
                infoPill(icon: "pound", label: "From £\(braider.priceFrom)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func infoPill(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.accent)
            Text(label)
                .font(AppTheme.sans(12, weight: .medium))
                .foregroundColor(AppTheme.ink)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(AppTheme.mist)
        .clipShape(Capsule())
    }

    // MARK: - Reviews (animated)

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionLabel(text: "Reviews")
                Spacer()
                Button {
                    Haptics.soft()
                    showAllReviews = true
                } label: {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(AppTheme.sans(13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.accentDeep)
                }
            }

            ReviewsHero(breakdown: breakdown)
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                        reviewsAppeared = true
                    }
                }

            VStack(spacing: 12) {
                ForEach(Array(reviews.prefix(2).enumerated()), id: \.element.id) { idx, review in
                    ReviewRowCompact(review: review)
                        .opacity(reviewsAppeared ? 1 : 0)
                        .offset(y: reviewsAppeared ? 0 : 30)
                        .animation(
                            .spring(response: 0.7, dampingFraction: 0.85)
                                .delay(Double(idx) * 0.08),
                            value: reviewsAppeared
                        )
                }
            }

            Button {
                Haptics.soft()
                showAllReviews = true
            } label: {
                HStack {
                    Text("Read all \(breakdown.total) reviews")
                        .font(AppTheme.sans(14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.ink)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(AppTheme.snow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(SoftPress())
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Sticky book bar

    private var stickyBookBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.cloud.opacity(0), AppTheme.cloud.opacity(0.9), AppTheme.cloud],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 30)

            Button {
                Haptics.medium()
                showBooking = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Book with \(firstName)")
                        .font(AppTheme.sans(17, weight: .semibold))
                    Spacer()
                    Text("from £\(braider.priceFrom)")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
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
                .shadow(color: AppTheme.ink.opacity(0.32), radius: 20, y: 10)
            }
            .buttonStyle(SoftPress())
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .background(AppTheme.cloud)
        }
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }
}

// MARK: - Scroll offset tracking

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Portfolio card

struct PortfolioCard: View {
    let item: PortfolioItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.5), .black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(item.tag)
                        .font(AppTheme.sans(11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                        Text("\(item.likes)")
                            .font(AppTheme.sans(11, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                Text(item.caption)
                    .font(AppTheme.serif(16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

// MARK: - Reviews hero (breakdown chart with animated bars)

struct ReviewsHero: View {
    let breakdown: RatingBreakdown
    @State private var animateBars = false

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            VStack(spacing: 6) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(AppTheme.serif(46))
                    .foregroundColor(AppTheme.ink)

                StarRow(rating: breakdown.average, size: 12)

                Text("\(breakdown.total) reviews")
                    .font(AppTheme.sans(11, weight: .medium))
                    .foregroundColor(AppTheme.stone)
            }
            .frame(width: 110)

            VStack(spacing: 7) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    AnimatedRatingBar(
                        stars: stars,
                        count: count(stars),
                        total: breakdown.total,
                        animate: animateBars
                    )
                }
            }
        }
        .padding(18)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.045), radius: 14, y: 4)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.2)) {
                animateBars = true
            }
        }
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

struct AnimatedRatingBar: View {
    let stars: Int
    let count: Int
    let total: Int
    let animate: Bool

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(stars)")
                .font(AppTheme.sans(11, weight: .bold))
                .foregroundColor(AppTheme.slate)
                .frame(width: 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.hairline)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.gold, AppTheme.accent],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: animate ? geo.size.width * ratio : 0)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundColor(AppTheme.stone)
                .frame(width: 26, alignment: .trailing)
        }
    }
}

// MARK: - Compact review row

struct ReviewRowCompact: View {
    let review: Review

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(barColor)
                    .frame(width: 3, height: 42)
                    .offset(y: 4)
            }
            .frame(width: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Avatar(url: review.userAvatar, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName)
                            .font(AppTheme.sans(13, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        HStack(spacing: 5) {
                            StarRow(rating: review.rating, size: 9)
                            Text(review.date)
                                .font(AppTheme.sans(10))
                                .foregroundColor(AppTheme.stone)
                        }
                    }
                    Spacer()
                }

                Text(review.text)
                    .font(AppTheme.sans(13))
                    .foregroundColor(AppTheme.ink.opacity(0.82))
                    .lineSpacing(3)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
    }

    private var barColor: Color {
        if review.rating >= 4.5 { return AppTheme.gold }
        if review.rating >= 3.5 { return AppTheme.accent }
        return AppTheme.rose
    }
}

// MARK: - Full review card

struct ReviewCardFull: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Avatar(url: review.userAvatar, size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(AppTheme.sans(14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(review.date)
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

            HStack(spacing: 10) {
                Pill(icon: "scissors", text: review.styleDone, fg: AppTheme.accentDeep, bg: AppTheme.accentSoft)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 10))
                    Text("\(review.helpful) found helpful")
                        .font(AppTheme.sans(11, weight: .medium))
                }
                .foregroundColor(AppTheme.stone)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
        )
    }
}

// MARK: - All reviews sheet

struct AllReviewsSheet: View {
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ReviewsHero(breakdown: breakdown)

                    VStack(spacing: 12) {
                        ForEach(Array(reviews.enumerated()), id: \.element.id) { idx, r in
                            ReviewCardFull(review: r)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 30)
                                .animation(
                                    .spring(response: 0.7, dampingFraction: 0.85)
                                        .delay(Double(idx) * 0.06),
                                    value: appeared
                                )
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.cloud)
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.sans(15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }
}