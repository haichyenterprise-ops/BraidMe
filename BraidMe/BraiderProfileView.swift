import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider

    @State private var reviewsExpanded = false
    @State private var showBooking = false
    @State private var currentPage = 0
    @State private var likedItems: Set<String> = []
    @State private var showFullBio = false
    @Environment(\.dismiss) var dismiss

    private var reviews: [Review] { FirebaseManager.shared.reviews(for: braider) }
    private var breakdown: RatingBreakdown { FirebaseManager.shared.ratingBreakdown(for: braider) }

    var body: some View {
        GeometryReader { geo in
            let reelHeight = geo.size.height * 0.62
            let reviewsCollapsed = geo.size.height * 0.38
            let reviewsExpandedH = geo.size.height

            ZStack(alignment: .bottom) {
                AppTheme.ink.ignoresSafeArea()

                VStack(spacing: 0) {
                    reelsSection(height: reelHeight)
                    Spacer(minLength: 0)
                }

                ReviewsPanel(
                    isExpanded: $reviewsExpanded,
                    braider: braider,
                    reviews: reviews,
                    breakdown: breakdown,
                    collapsedHeight: reviewsCollapsed,
                    expandedHeight: reviewsExpandedH,
                    onBook: {
                        Haptics.medium()
                        showBooking = true
                    }
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: reviewsExpanded)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $showBooking) {
            BookingSelectionView(braider: braider)
        }
    }

    // MARK: - Reels section

    private func reelsSection(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            TabView(selection: $currentPage) {
                ForEach(Array(braider.portfolio.enumerated()), id: \.offset) { idx, item in
                    ReelSlide(
                        item: item,
                        braider: braider,
                        index: idx,
                        total: braider.portfolio.count,
                        isLiked: likedItems.contains(item.id),
                        onLike: { toggleLike(item.id) }
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)

            topOverlay
            pageIndicator
        }
        .frame(height: height)
    }

    // MARK: - Top overlay

    private var topOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                circleButton(icon: "chevron.left") {
                    Haptics.soft()
                    dismiss()
                }
                Spacer()

                HStack(spacing: 8) {
                    GlassChip(icon: "star.fill", title: String(format: "%.1f", braider.rating))
                    GlassChip(icon: "photo.stack", title: "\(braider.portfolio.count)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
        }
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(BouncyPress())
    }

    // MARK: - Page indicator (right side, TikTok-style)

    private var pageIndicator: some View {
        VStack(spacing: 4) {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    ForEach(0..<braider.portfolio.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.white : Color.white.opacity(0.35))
                            .frame(
                                width: i == currentPage ? 3 : 2,
                                height: i == currentPage ? 20 : 10
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                    }
                }
                .padding(.trailing, 12)
            }
            Spacer().frame(height: 200)
        }
    }

    private func toggleLike(_ id: String) {
        Haptics.soft()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            if likedItems.contains(id) { likedItems.remove(id) }
            else { likedItems.insert(id) }
        }
    }
}

// MARK: - Reel Slide

struct ReelSlide: View {
    let item: PortfolioItem
    let braider: Braider
    let index: Int
    let total: Int
    let isLiked: Bool
    let onLike: () -> Void

    var body: some View {
        ZStack {
            RemoteImage(url: item.imageUrl)
                .ignoresSafeArea(edges: .top)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0.0),
                    .init(color: .black.opacity(0.1), location: 0.25),
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.35), location: 0.82),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            VStack {
                Spacer()
                bottomContent
            }
        }
    }

    private var bottomContent: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                if index == 0 {
                    brandHeader
                } else {
                    smallHeader
                }

                HStack(spacing: 8) {
                    GlassChip(icon: "tag.fill", title: item.tag)
                    GlassChip(icon: "heart.fill", title: "\(item.likes)")
                }

                Text(item.caption)
                    .font(AppTheme.serif(22, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }

            Spacer(minLength: 0)

            sideActions
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(braider.name)
                    .font(AppTheme.serif(30))
                    .foregroundColor(.white)
                if braider.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.accentLight)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.gold)
                    Text(String(format: "%.1f", braider.rating))
                        .font(AppTheme.sans(13, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("·").foregroundColor(.white.opacity(0.5))
                Text("\(braider.reviewCount) reviews")
                    .font(AppTheme.sans(13))
                    .foregroundColor(.white.opacity(0.85))
                Text("·").foregroundColor(.white.opacity(0.5))
                Text("from £\(braider.priceFrom)")
                    .font(AppTheme.sans(13, weight: .medium))
                    .foregroundColor(.white)
            }

            Text(braider.bio)
                .font(AppTheme.sans(14))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
                .lineSpacing(3)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        }
    }

    private var smallHeader: some View {
        HStack(spacing: 8) {
            Text(braider.name)
                .font(AppTheme.sans(17, weight: .semibold))
                .foregroundColor(.white)
            if braider.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accentLight)
            }
        }
    }

    private var sideActions: some View {
        VStack(spacing: 18) {
            sideButton(
                icon: isLiked ? "heart.fill" : "heart",
                tint: isLiked ? AppTheme.rose : .white,
                label: "\(item.likes + (isLiked ? 1 : 0))",
                action: onLike
            )

            sideButton(
                icon: "bookmark",
                tint: .white,
                label: "Save",
                action: { Haptics.soft() }
            )

            sideButton(
                icon: "square.and.arrow.up",
                tint: .white,
                label: "Share",
                action: { Haptics.soft() }
            )
        }
    }

    private func sideButton(icon: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(tint)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                Text(label)
                    .font(AppTheme.sans(11, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(BouncyPress())
    }
}

// MARK: - Reviews panel

struct ReviewsPanel: View {
    @Binding var isExpanded: Bool
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    let collapsedHeight: CGFloat
    let expandedHeight: CGFloat
    let onBook: () -> Void

    @GestureState private var drag: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            handleArea
            header

            Divider().background(AppTheme.hairline.opacity(0.4))

            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                    }
                    Color.clear.frame(height: 130)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .scrollDisabled(!isExpanded)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .background(AppTheme.snow)
        .cornerRadius(28, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.18), radius: 26, y: -10)
        .gesture(
            DragGesture()
                .onEnded { value in
                    Haptics.soft()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        if value.translation.height < -40 { isExpanded = true }
                        else if value.translation.height > 40 { isExpanded = false }
                    }
                }
        )
        .overlay(alignment: .bottom) {
            if !isExpanded {
                stickyBookButton
            }
        }
    }

    private var handleArea: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(spacing: 10) {
                Capsule()
                    .fill(AppTheme.hairline)
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Reviews")
                    .font(AppTheme.serif(22))
                    .foregroundColor(AppTheme.ink)

                HStack(spacing: 6) {
                    StarRow(rating: breakdown.average, size: 10)
                    Text(String(format: "%.1f", breakdown.average))
                        .font(AppTheme.sans(12, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text("· \(breakdown.total) verified")
                        .font(AppTheme.sans(12))
                        .foregroundColor(AppTheme.stone)
                }
            }

            Spacer()

            Button {
                Haptics.soft()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.mist, in: Circle())
            }
            .buttonStyle(SoftPress())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(AppTheme.serif(44))
                    .foregroundColor(AppTheme.ink)
                StarRow(rating: breakdown.average, size: 11)
                Text("\(breakdown.total) reviews")
                    .font(AppTheme.sans(11))
                    .foregroundColor(AppTheme.stone)
            }
            .frame(width: 100)

            VStack(spacing: 6) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    RatingBar(
                        stars: stars,
                        count: count(stars),
                        total: breakdown.total
                    )
                }
            }
        }
        .padding(18)
        .background(AppTheme.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var stickyBookButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.snow.opacity(0), AppTheme.snow],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 30)

            BronzeButton(title: "Book with \(braider.name.split(separator: " ").first.map(String.init) ?? "her")", icon: "sparkles") {
                onBook()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .background(AppTheme.snow)
        }
    }
}

// MARK: - Rating bar

struct RatingBar: View {
    let stars: Int
    let count: Int
    let total: Int

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(stars)")
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundColor(AppTheme.slate)
                .frame(width: 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.hairline)
                    Capsule()
                        .fill(AppTheme.gold)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 5)

            Text("\(count)")
                .font(AppTheme.sans(11, weight: .medium))
                .foregroundColor(AppTheme.stone)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// MARK: - Review card

struct ReviewCard: View {
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

                StarRow(rating: review.rating, size: 10)
            }

            Text(review.text)
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.ink.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "scissors")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                    Text(review.styleDone)
                        .font(AppTheme.sans(11, weight: .medium))
                        .foregroundColor(AppTheme.accentDeep)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accentSoft)
                .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 10))
                    Text("\(review.helpful)")
                        .font(AppTheme.sans(11, weight: .medium))
                }
                .foregroundColor(AppTheme.stone)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}