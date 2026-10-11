import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider

    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false
    @State private var currentStage = 0
    @State private var likedPhotos: Set<String> = []
    @State private var reviewsAppeared = false
    @State private var showAllReviews = false
    @State private var appeared = false

    private let reviews: [Review]
    private let breakdown: RatingBreakdown

    init(braider: Braider) {
        self.braider = braider
        self.reviews = FirebaseManager.shared.reviews(for: braider)
        self.breakdown = FirebaseManager.shared.ratingBreakdown(for: braider)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                AppTheme.ink.ignoresSafeArea()

                // Vertical snap-scroll stages
                TabView(selection: $currentStage) {
                    heroStage(width: geo.size.width, height: geo.size.height * 0.78)
                        .tag(0)
                    statsStage(width: geo.size.width, height: geo.size.height * 0.78)
                        .tag(1)
                    portfolioStage(width: geo.size.width, height: geo.size.height * 0.78)
                        .tag(2)
                    reviewsStage(width: geo.size.width, height: geo.size.height * 0.78)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .rotationEffect(.degrees(-90))
                .frame(width: geo.size.width, height: geo.size.height)
                .rotationEffect(.degrees(90), anchor: .topLeading)
                .offset(y: 90)

                // Persistent chrome
                topNav
                stageDots
                bottomBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea()
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
        VStack {
            HStack {
                Button {
                    Haptics.soft()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(BouncyPress())

                Spacer()

                Button {
                    Haptics.soft()
                    toggleLike(braider.id)
                } label: {
                    Image(systemName: likedPhotos.contains(braider.id) ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(likedPhotos.contains(braider.id) ? AppTheme.rose : .white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                }
                .buttonStyle(BouncyPress())
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
        }
    }

    // MARK: - Stage dots

    private var stageDots: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == currentStage ? Color.white : Color.white.opacity(0.35))
                        .frame(
                            width: i == currentStage ? 4 : 3,
                            height: i == currentStage ? 26 : 12
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStage)
                }
            }
            .padding(.trailing, 16)
            Spacer().frame(width: 0)
        }
        .padding(.bottom, 140)
        .frame(maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.4), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)

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
                    Text("£\(braider.priceFrom)+")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(AppTheme.bronzeGradient)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 20, y: 10)
            }
            .buttonStyle(SoftPress())
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(Color.black.opacity(0.85))
        }
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }

    // MARK: - Stage 0: Hero

    private func heroStage(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RemoteImage(url: braider.coverUrl)
                .frame(width: width, height: height + 200)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.4), location: 0.0),
                    .init(color: .black.opacity(0.05), location: 0.3),
                    .init(color: .black.opacity(0.4), location: 0.7),
                    .init(color: .black.opacity(0.95), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                HStack(spacing: 14) {
                    ZStack {
                        RemoteImage(url: braider.avatarUrl)
                            .frame(width: 76, height: 76)
                            .clipShape(Circle())
                        Circle().stroke(AppTheme.snow, lineWidth: 3)
                            .frame(width: 82, height: 82)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(braider.name)
                                .font(AppTheme.serif(26))
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
                    GlassChip(icon: "star.fill", title: String(format: "%.1f", braider.rating))
                    GlassChip(icon: "mappin.and.ellipse", title: braider.city)
                    GlassChip(icon: "clock", title: braider.responseTime)
                }

                Text(braider.bio)
                    .font(AppTheme.sans(14))
                    .foregroundColor(.white.opacity(0.88))
                    .lineSpacing(4)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("Swipe up for more")
                        .font(AppTheme.sans(11, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 200)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Stage 1: Stats + Specialties

    private func statsStage(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            AppTheme.inkGradient

            VStack(alignment: .leading, spacing: 22) {
                Spacer().frame(height: 100)

                SectionLabel(text: "By the numbers")
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 14) {
                    bigStat(
                        value: String(format: "%.1f", braider.rating),
                        label: "Rating",
                        icon: "star.fill",
                        tint: AppTheme.gold
                    )
                    bigStat(
                        value: "\(braider.yearsExperience)y",
                        label: "Experience",
                        icon: "clock.fill",
                        tint: AppTheme.accentLight
                    )
                }

                HStack(spacing: 14) {
                    bigStat(
                        value: "\(braider.reviewCount)",
                        label: "Bookings",
                        icon: "calendar",
                        tint: AppTheme.sage
                    )
                    bigStat(
                        value: "£\(braider.priceFrom)+",
                        label: "From",
                        icon: "pound",
                        tint: AppTheme.rose
                    )
                }

                Spacer().frame(height: 8)

                SectionLabel(text: "Specialties")
                    .foregroundColor(.white.opacity(0.5))

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
                        .frame(height: 36)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .frame(width: width, height: height)
    }

    private func bigStat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.2)).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(value)
                .font(AppTheme.serif(34))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label.uppercased())
                .font(AppTheme.sans(10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Stage 2: Portfolio

    private func portfolioStage(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            AppTheme.inkGradient

            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 100)

                HStack {
                    SectionLabel(text: "Recent work")
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("\(braider.portfolio.count) photos")
                        .font(AppTheme.sans(12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { idx, item in
                            PortfolioStageCard(
                                item: item,
                                isLiked: likedPhotos.contains(item.id),
                                onLike: { toggleLike(item.id) }
                            )
                            .frame(width: 260, height: 380)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                            .animation(
                                .spring(response: 0.7, dampingFraction: 0.85)
                                    .delay(0.1 + Double(idx) * 0.06),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Stage 3: Reviews

    private func reviewsStage(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            AppTheme.inkGradient

            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 100)

                SectionLabel(text: "What clients say")
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 24)

                ReviewSummaryCard(breakdown: breakdown)
                    .padding(.horizontal, 24)
                    .onAppear {
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                            reviewsAppeared = true
                        }
                    }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { idx, r in
                            ReviewDarkCard(review: r)
                                .opacity(reviewsAppeared ? 1 : 0)
                                .offset(y: reviewsAppeared ? 0 : 30)
                                .animation(
                                    .spring(response: 0.7, dampingFraction: 0.85)
                                        .delay(Double(idx) * 0.08),
                                    value: reviewsAppeared
                                )
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(SoftPress())

                        Color.clear.frame(height: 160)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Like

    private func toggleLike(_ id: String) {
        Haptics.soft()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            if likedPhotos.contains(id) { likedPhotos.remove(id) }
            else { likedPhotos.insert(id) }
        }
    }
}

// MARK: - Portfolio card (dark variant)

struct PortfolioStageCard: View {
    let item: PortfolioItem
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.55), .black.opacity(0.9)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(item.tag.uppercased())
                        .font(AppTheme.sans(10, weight: .bold))
                        .tracking(1.1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))

                    Spacer()

                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isLiked ? AppTheme.rose : .white)
                            Text("\(item.likes + (isLiked ? 1 : 0))")
                                .font(AppTheme.sans(11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(BouncyPress())
                }

                Text(item.caption)
                    .font(AppTheme.serif(17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}

// MARK: - Review summary card (dark)

struct ReviewSummaryCard: View {
    let breakdown: RatingBreakdown
    @State private var animateBars = false

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(spacing: 6) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(AppTheme.serif(44))
                    .foregroundColor(.white)
                StarRow(rating: breakdown.average, size: 11)
                Text("\(breakdown.total) reviews")
                    .font(AppTheme.sans(11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(width: 100)

            VStack(spacing: 7) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    DarkRatingBar(
                        stars: stars,
                        count: count(stars),
                        total: breakdown.total,
                        animate: animateBars
                    )
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.3)) {
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

struct DarkRatingBar: View {
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
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(AppTheme.gold)
                        .frame(width: animate ? geo.size.width * ratio : 0)
                }
            }
            .frame(height: 5)

            Text("\(count)")
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 26, alignment: .trailing)
        }
    }
}

// MARK: - Review dark card

struct ReviewDarkCard: View {
    let review: Review

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(barColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    RemoteImage(url: review.userAvatar)
                        .frame(width: 34, height: 34)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.userName)
                            .font(AppTheme.sans(13, weight: .semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 5) {
                            StarRow(rating: review.rating, size: 9)
                            Text(review.date)
                                .font(AppTheme.sans(10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                }

                Text(review.text)
                    .font(AppTheme.sans(13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var barColor: Color {
        if review.rating >= 4.5 { return AppTheme.gold }
        if review.rating >= 3.5 { return AppTheme.accent }
        return AppTheme.rose
    }
}

// MARK: - All reviews sheet

struct AllReviewsSheet: View {
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.cloud.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ReviewSummaryLight(breakdown: breakdown)

                        ForEach(Array(reviews.enumerated()), id: \.element.id) { idx, r in
                            ReviewLightCard(review: r)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 30)
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
            .navigationTitle("All reviews")
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

struct ReviewSummaryLight: View {
    let breakdown: RatingBreakdown

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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

struct ReviewLightCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RemoteImage(url: review.userAvatar)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
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

// MARK: - Flow layout helper (for specialty chips)

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