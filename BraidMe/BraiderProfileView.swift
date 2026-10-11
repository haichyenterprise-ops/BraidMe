import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider

    @State private var reviewsExpanded = false
    @State private var showBooking = false
    @State private var currentPage = 0
    @Environment(\.dismiss) var dismiss

    private var reviews: [Review] { FirebaseManager.shared.reviews(for: braider) }
    private var breakdown: RatingBreakdown { FirebaseManager.shared.ratingBreakdown(for: braider) }

    var body: some View {
        GeometryReader { geo in
            let reelHeight = geo.size.height * 0.62
            let reviewsHeight = geo.size.height * 0.38

            ZStack(alignment: .bottom) {
                AppTheme.ink.ignoresSafeArea()

                // MARK: Reels section (top 62%)
                VStack(spacing: 0) {
                    reelsSection(height: reelHeight)
                    Spacer(minLength: 0)
                }

                // MARK: Reviews panel (bottom 38%, expands upward on tap)
                ReviewsPanel(
                    isExpanded: $reviewsExpanded,
                    braider: braider,
                    reviews: reviews,
                    breakdown: breakdown,
                    collapsedHeight: reviewsHeight,
                    expandedHeight: geo.size.height,
                    onBook: { showBooking = true }
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

    // MARK: Reels

    private func reelsSection(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            // Vertical TabView pager
            TabView(selection: $currentPage) {
                ForEach(Array(braider.portfolio.enumerated()), id: \.offset) { idx, item in
                    ReelSlide(
                        item: item,
                        braider: braider,
                        index: idx,
                        total: braider.portfolio.count
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)

            // Top overlay controls
            topOverlay
        }
        .frame(height: height)
    }

    // MARK: Top overlay

    private var topOverlay: some View {
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
                }
                Spacer()
                HeartButton()
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Reel Slide

struct ReelSlide: View {
    let item: PortfolioItem
    let braider: Braider
    let index: Int
    let total: Int

    var body: some View {
        ZStack {
            RemoteImage(url: item.imageUrl)
                .ignoresSafeArea(edges: .top)

            // Multi-stop gradient for legibility
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0.0),
                    .init(color: .black.opacity(0.05), location: 0.28),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.35), location: 0.82),
                    .init(color: .black.opacity(0.75), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            // Bottom content
            VStack {
                Spacer()
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if index == 0 {
                brandHeader
            } else {
                smallHeader
            }

            HStack(spacing: 8) {
                GlassChip(icon: "tag.fill", title: item.tag)
                GlassChip(icon: "photo.stack", title: "\(index + 1) / \(total)")
            }

            Text(item.caption)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(braider.name)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(.white)
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.gold)
                    Text(String(format: "%.1f", braider.rating))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text("·")
                    .foregroundColor(.white.opacity(0.5))
                Text("\(braider.reviewCount) reviews")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                Text("·")
                    .foregroundColor(.white.opacity(0.5))
                Text("from £\(braider.priceFrom)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            Text(braider.bio)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(3)
                .lineSpacing(3)
                .padding(.top, 4)
        }
    }

    private var smallHeader: some View {
        Text(braider.name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
    }
}

// MARK: - Heart Button

struct HeartButton: View {
    @State private var isLiked = false
    @State private var scale: CGFloat = 1

    var body: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isLiked.toggle()
                scale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { scale = 1 }
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(isLiked ? AppTheme.rose : .white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .scaleEffect(scale)
        }
    }
}

// MARK: - Reviews Panel

struct ReviewsPanel: View {
    @Binding var isExpanded: Bool
    let braider: Braider
    let reviews: [Review]
    let breakdown: RatingBreakdown
    let collapsedHeight: CGFloat
    let expandedHeight: CGFloat
    let onBook: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            handle
            header
            Divider().background(AppTheme.hairline)

            ScrollView {
                VStack(spacing: 14) {
                    summaryCard
                    ForEach(reviews) { review in
                        ReviewCard(review: review)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .scrollDisabled(!isExpanded)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .background(AppTheme.snow)
        .cornerRadius(28, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.15), radius: 24, y: -8)
        .gesture(
            DragGesture()
                .onEnded { value in
                    Haptics.soft()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        if value.translation.height < -50 { isExpanded = true }
                        else if value.translation.height > 50 { isExpanded = false }
                    }
                }
        )
        .overlay(alignment: .bottom) {
            if !isExpanded {
                stickyBookButton
                    .transition(.opacity)
            }
        }
    }

    private var handle: some View {
        Capsule()
            .fill(AppTheme.hairline)
            .frame(width: 42, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 12)
    }

    private var header: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reviews")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text("\(reviews.count) verified bookings")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.slate)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.slate)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .buttonStyle(SoftPressStyle())
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text(String(format: "%.1f", breakdown.average))
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.ink)
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.gold)
                    }
                }
                Text("\(breakdown.total) reviews")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.slate)
            }
            .frame(width: 100)

            VStack(spacing: 5) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { stars in
                    RatingBar(stars: stars, count: count(stars), total: breakdown.total)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        BronzeButton(title: "Book Now", systemImage: "sparkles") {
            onBook()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Rating Bar

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
                .font(.system(size: 11, weight: .medium))
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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.stone)
                .frame(width: 26, alignment: .trailing)
        }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RemoteImage(url: review.userAvatar)
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(review.date)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.stone)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < review.rating ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.gold)
                    }
                }
            }

            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.ink.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text(review.styleDone)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.accentDeep)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.accentSoft)
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}