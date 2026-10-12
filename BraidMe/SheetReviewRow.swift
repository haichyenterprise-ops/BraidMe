import SwiftUI

struct SheetReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                BMAvatar(url: review.userAvatar, size: 42, initials: userInitials, ringed: false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(review.userName)
                        .font(.bmUI(14, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)

                    HStack(spacing: Space.xs) {
                        HStack(spacing: 2) {
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
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            if !review.styleDone.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "scissors")
                        .font(.bmUI(9, weight: .semibold))
                    Text(review.styleDone)
                        .font(.bmUI(10, weight: .semibold))
                        .tracking(0.4)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.appAccent)
                .padding(.horizontal, Space.xs)
                .padding(.vertical, 5)
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

// MARK: - Profile Sheet (compatibility wrapper)

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
                let breakdown = RatingBreakdown.from(reviews)
                aggregateCard(breakdown: breakdown)

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

// MARK: - Service Card

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