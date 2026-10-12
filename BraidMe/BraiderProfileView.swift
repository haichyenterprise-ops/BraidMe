import SwiftUI



// =============================================================================
// BraiderProfileView — editorial, premium braider profile
//
// Full-width photographic hero, restrained editorial typography, artist metrics,
// horizontal portfolio, service cards, real review data, and a persistent booking
// dock. Existing booking, save, review, and Firebase flows are retained.
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
        .task { await loadReviews() }
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
                            .init(color: .black.opacity(0.48), location: 0),
                            .init(color: .clear, location: 0.32),
                            .init(color: .black.opacity(0.16), location: 0.56),
                            .init(color: .black.opacity(0.88), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }

            VStack {
                HStack {
                    heroIcon("chevron.left", label: "Go back") { dismiss() }
                    Spacer()
                    Button {
                        Haptic.press()
                        Task {
                            guard !session.uid.isEmpty else { return }
                            await fb.toggleSave(braiderId: braider.id, uid: session.uid)
                        }
                    } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSaved ? Color.appAlert : .white)
                            .frame(width: 46, height: 46)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.7))
                    }
                    .accessibilityLabel(isSaved ? "Remove from saved braiders" : "Save braider")
                }
                .padding(.horizontal, 22)
                .padding(.top, 58)

                Spacer()

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(spacing: 7) {
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.appAccentSoft)
                                Text("VERIFIED ARTIST")
                                    .tracking(2)
                            } else {
                                Text("INDEPENDENT BRAIDER")
                                    .tracking(2)
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.86))

                        HStack(alignment: .center, spacing: 8) {
                            Text(braider.name)
                                .font(.system(size: 35, weight: .regular, design: .serif))
                                .tracking(-1.1)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.appAccentSoft)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            Label(braider.city, systemImage: "mappin")
                            Circle().fill(.white.opacity(0.55)).frame(width: 3, height: 3)
                            Label(ratingText, systemImage: "star.fill")
                            Text("(\(ratingCount))")
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    if !braider.avatarUrl.isEmpty {
                        BMAvatar(url: braider.avatarUrl, size: 58, initials: initials)
                            .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .frame(height: 535)
        .accessibilityElement(children: .contain)
    }

    private func heroIcon(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.press()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.7))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Overview

    private var profileOverview: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 0) {
                metric(value: ratingText, label: "RATING", icon: "star.fill")
                metricDivider
                metric(value: "\(ratingCount)", label: "REVIEWS")
                metricDivider
                metric(value: "\(braider.services.count)", label: "SERVICES")
                metricDivider
                metric(value: "£\(braider.priceFrom)", label: "FROM")
            }

            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    eyebrow("THE ARTIST")
                    Text(braider.bio)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.appInk.opacity(0.82))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !braider.specialties.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(braider.specialties, id: \.self) { specialty in
                            Text(specialty.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(Color.appInk)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 27)
        .padding(.bottom, 34)
    }

    private func metric(value: String, label: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                Text(value)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(Color.appInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.appAsh)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.appDivider)
            .frame(width: 1, height: 35)
            .padding(.horizontal, 9)
    }

    // MARK: - Portfolio

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { index, item in
                            Button {
                                Haptic.select()
                                selectedPortfolioItem = item
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ZStack(alignment: .bottomLeading) {
                                        RemoteImage(url: item.imageUrl)
                                            .frame(width: 230, height: 285)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        LinearGradient(
                                            colors: [.clear, .black.opacity(0.56)],
                                            startPoint: .center,
                                            endPoint: .bottom
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(14)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !item.tag.isEmpty {
                                            Text(item.tag.uppercased())
                                                .font(.system(size: 9, weight: .bold))
                                                .tracking(1.3)
                                                .foregroundStyle(Color.appAccent)
                                        }
                                        if !item.caption.isEmpty {
                                            Text(item.caption)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(Color.appInk)
                                                .lineLimit(2)
                                        }
                                    }
                                    .frame(width: 230, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 38)
        .fullScreenCover(item: $selectedPortfolioItem) { item in
            PortfolioDetailView(item: item, name: braider.name)
        }
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 17) {
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
                VStack(spacing: 10) {
                    ForEach(braider.services) { service in
                        Button {
                            Haptic.select()
                            showBookingForService = service
                        } label: {
                            HStack(spacing: 14) {
                                if !service.imageUrl.isEmpty {
                                    RemoteImage(url: service.imageUrl)
                                        .frame(width: 82, height: 92)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    ZStack {
                                        Color.appSurface
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 20, weight: .light))
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    .frame(width: 82, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                VStack(alignment: .leading, spacing: 7) {
                                    if service.popular {
                                        Text("SIGNATURE STYLE")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(1.2)
                                            .foregroundStyle(Color.appAccent)
                                    }
                                    Text(service.name)
                                        .font(.system(size: 16, weight: .medium, design: .serif))
                                        .foregroundStyle(Color.appInk)
                                        .multilineTextAlignment(.leading)
                                    Text("\(service.durationMinutes / 60)h \(service.durationMinutes % 60)m")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.appAsh)
                                    Text("From £\(service.priceFrom)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.appInk)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.appInk)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
                            }
                            .padding(12)
                            .background(Color.appSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appDivider.opacity(0.75), lineWidth: 0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if reviews.isEmpty {
                emptySection(
                    icon: "quote.opening",
                    title: "The first word is yours",
                    message: "There are no reviews yet. Book an appointment and share your experience."
                )
                .padding(.horizontal, 24)
            } else {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(ratingText)
                            .font(.system(size: 46, weight: .regular, design: .serif))
                            .tracking(-1.5)
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
                    .frame(width: 120, alignment: .leading)

                    Rectangle()
                        .fill(Color.appDivider)
                        .frame(width: 1, height: 72)

                    VStack(alignment: .leading, spacing: 8) {
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
                                    .frame(width: 20, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.appDivider, lineWidth: 0.7))
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    ForEach(Array(reviews.prefix(3).enumerated()), id: \.element.id) { index, review in
                        SheetReviewRow(review: review)
                            .padding(.horizontal, 8)
                        if index < min(reviews.count, 3) - 1 {
                            Rectangle()
                                .fill(Color.appDivider)
                                .frame(height: 0.7)
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 15)
                    }
                }
            }

            Button {
                Haptic.press()
                showWriteReview = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                    Text("Share your experience")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.appDivider, lineWidth: 1))
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 38)
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

    // MARK: - Shared pieces

    private func sectionHeading(kicker: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            eyebrow(kicker)
            Text(title)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .tracking(-0.7)
                .foregroundStyle(Color.appInk)
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(Color.appAsh)
    }

    private func emptySection(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.appAccent)
            Text(title)
                .font(.system(size: 19, weight: .regular, design: .serif))
                .foregroundStyle(Color.appInk)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.appSurface)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.appAccent.opacity(0.7)).frame(width: 2)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("BRAIDME")
                .font(.system(size: 10, weight: .bold))
                .tracking(3.5)
                .foregroundStyle(Color.appAsh)
            Text("Good hair. Great feeling.")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color.appAsh)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var bookingDock: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STARTING FROM")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(Color.appAsh)
                Text("£\(braider.priceFrom)")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(Color.appInk)
            }
            Spacer()
            Button {
                Haptic.press()
                showBooking = true
            } label: {
                HStack(spacing: 10) {
                    Text("Book an appointment")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appInkInverse)
                .padding(.horizontal, 21)
                .frame(height: 52)
                .background(Color.appInk, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(BMPressStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 13)
        .padding(.bottom, 10)
        .background {
            Color.appBackground
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.appDivider).frame(height: 0.7)
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

// MARK: - Portfolio lightbox

private struct PortfolioDetailView: View {
    let item: PortfolioItem
    let name: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    Spacer()
                    Text(name.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer(minLength: 20)
                RemoteImage(url: item.imageUrl)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 590)
                    .clipped()
                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    if !item.tag.isEmpty {
                        Text(item.tag.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.appAccentSoft)
                    }
                    if !item.caption.isEmpty {
                        Text(item.caption)
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    if item.likes > 0 {
                        Label("\(item.likes)", systemImage: "heart.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.top, 3)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 34)
            }
        }
        .statusBarHidden()
    }
}

// MARK: - PROFILE SHEET (services + reviews)

// =============================================================================



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



    // MARK: - About



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



            // Specialties

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



    // MARK: - Reviews



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

                // Aggregate

                let breakdown = RatingBreakdown.from(reviews)

                aggregateCard(breakdown: breakdown)



                // Recent reviews

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



    // MARK: - Booking bar



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



// =============================================================================

// MARK: - SERVICE CARD

// =============================================================================



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



// =============================================================================

// MARK: - REVIEW ROW (sheet variant)

// =============================================================================



struct SheetReviewRow: View {

    let review: Review



    var body: some View {

        VStack(alignment: .leading, spacing: Space.sm) {

            HStack(spacing: Space.sm) {

                BMAvatar(url: review.userAvatar, size: 38, initials: userInitials)

                VStack(alignment: .leading, spacing: 3) {

                    Text(review.userName)

                        .font(.bmUI(14, weight: .semibold))

                        .foregroundStyle(Color.appInk)

                        .lineLimit(1)

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

                Spacer(minLength: 0)

            }



            Text(review.text)

                .font(.bmUI(14))

                .foregroundStyle(Color.appInk.opacity(0.9))

                .lineSpacing(4)

                .fixedSize(horizontal: false, vertical: true)



            if !review.styleDone.isEmpty {

                HStack(spacing: 4) {

                    Image(systemName: "scissors")

                        .font(.bmUI(9, weight: .semibold))

                    Text(review.styleDone)

                        .font(.bmUI(10, weight: .semibold))

                        .tracking(0.3)

                        .lineLimit(1)

                }

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



// =============================================================================

// MARK: - ALL REVIEWS SHEET

// =============================================================================



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

                            SheetReviewRow(review: r)

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