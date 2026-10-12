import SwiftUI

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
    @State private var dragOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var headerCompact = false

    @State private var reviews: [Review] = []
    @State private var reviewsLoading = true

    private var isSaved: Bool { fb.savedBraiderIds.contains(braider.id) }
    private let heroRestHeight: CGFloat = 420
    private let heroMinHeight: CGFloat = 120

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    content
                    Color.clear.frame(height: Space.xxxl)
                }
                .background(alignment: .top) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ProfileScrollKey.self,
                            value: -proxy.frame(in: .named("profileScroll")).minY
                        )
                    }
                }
            }
            .coordinateSpace(name: "profileScroll")
            .onPreferenceChange(ProfileScrollKey.self) { value in
                scrollOffset = value
                let compact = value > 180
                if compact != headerCompact {
                    withAnimation(Motion.navigation) { headerCompact = compact }
                }
            }
            .ignoresSafeArea(edges: .top)

            compactHeader

            Color.clear
                .frame(width: 20)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                dragOffset = min(value.translation.width, 200)
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 100 {
                                Haptic.select()
                                dismiss()
                            } else {
                                withAnimation(Motion.press) { dragOffset = 0 }
                            }
                        }
                )
        }
        .offset(x: dragOffset)
        .toolbar(.hidden, for: .navigationBar)
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
            withAnimation(Motion.navigation) {
                showBooking = false
                showBookingForService = nil
            }
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

    private var hero: some View {
        let collapse = min(max(scrollOffset / 300, 0), 1)
        let currentHeight = heroRestHeight - (heroRestHeight - heroMinHeight) * collapse
        let contentOpacity = 1 - collapse * 1.2

        return ZStack(alignment: .bottomLeading) {
            if !braider.coverUrl.isEmpty {
                RemoteImage(url: braider.coverUrl)
                    .frame(height: currentHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .scaleEffect(1 + collapse * 0.06)
            } else {
                Color.appSurfaceInverse.frame(height: currentHeight)
            }

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.35), location: 0.0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.55), location: 0.75),
                    .init(color: .black.opacity(0.92), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: currentHeight)

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    BMAvatar(
                        url: braider.avatarUrl,
                        size: 68,
                        ringed: true,
                        initials: initials
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: Space.xxs) {
                            Text(braider.name)
                                .font(.bmDisplay(26, weight: .semibold))
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
                    Spacer()
                }

                HStack(spacing: Space.sm) {
                    HStack(spacing: Space.xxs) {
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < braider.rating.rounded() ? "star.fill" : "star")
                                    .font(.bmUI(10, weight: .medium))
                                    .foregroundStyle(Color.appAccentSoft)
                            }
                        }
                        Text(String(format: "%.1f", braider.rating))
                            .font(.bmMono(12, weight: .semibold))
                            .foregroundStyle(Color.appInkInverse)
                        Text("·")
                            .font(.bmMono(12))
                            .foregroundStyle(Color.appInkInverse.opacity(0.5))
                        Text("\(braider.reviewCount)")
                            .font(.bmMono(12, weight: .medium))
                            .foregroundStyle(Color.appInkInverse.opacity(0.75))
                    }
                    Text("·")
                        .font(.bmUI(11))
                        .foregroundStyle(Color.appInkInverse.opacity(0.5))
                    Text(braider.city)
                        .font(.bmUI(12, weight: .medium))
                        .foregroundStyle(Color.appInkInverse.opacity(0.8))
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
            .opacity(contentOpacity)
        }
        .frame(height: currentHeight)
        .clipped()
        .animate(Motion.subtle, value: collapse)
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }

    // MARK: - Compact header

    private var compactHeader: some View {
        HStack(spacing: Space.sm) {
            BMIconButton(icon: "chevron.left") { dismiss() }

            if headerCompact {
                HStack(spacing: Space.xs) {
                    BMAvatar(url: braider.avatarUrl, size: 28, initials: initials)
                    Text(braider.name)
                        .font(.bmUI(15, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            BMIconButton(
                icon: isSaved ? "heart.fill" : "heart",
                fg: isSaved ? Color.appAlert : Color.appInk
            ) {
                Task {
                    let uid = session.uid
                    guard !uid.isEmpty else { return }
                    await fb.toggleSave(braiderId: braider.id, uid: uid)
                }
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xxl)
        .padding(.bottom, Space.xs)
        .background(
            LinearGradient(
                colors: headerCompact
                    ? [Color.appBackground, Color.appBackground]
                    : [Color.appBackground.opacity(0), Color.appBackground.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
        .animate(Motion.navigation, value: headerCompact)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.xxl) {
            statsRow
            portfolioStrip
            storySection
            specialtiesSection
            servicesSection
            reviewsSection
            bookButton
        }
        .padding(.top, Space.lg)
    }

    private var statsRow: some View {
        HStack(spacing: Space.lg) {
            statItem(value: String(format: "%.1f", braider.rating), label: "Rating")
            Divider().frame(height: 32).overlay(Color.appDivider)
            statItem(value: "\(braider.yearsExperience)", label: "Years")
            Divider().frame(height: 32).overlay(Color.appDivider)
            statItem(value: "\(braider.reviewCount)", label: "Reviews")
        }
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

    private var portfolioStrip: some View {
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.sm) {
                            ForEach(Array(braider.portfolio.enumerated()), id: \.element.id) { index, item in
                                PortfolioImageCard(item: item, index: index, appeared: appeared)
                            }
                        }
                        .padding(.horizontal, Space.lg)
                    }
                }
                .padding(.vertical, Space.md)
                .background(Color.appSurfaceInverse)
            }
        }
    }

    private var storySection: some View {
        Group {
            if !braider.bio.isEmpty {
                VStack(alignment: .leading, spacing: Space.sm) {
                    BMSectionLabel(text: "The story")
                        .padding(.horizontal, Space.lg)
                    Text(braider.bio)
                        .font(.bmDisplay(20, weight: .regular))
                        .foregroundStyle(Color.appInk)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.lg)
                }
            }
        }
    }

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
                                .padding(.vertical, 4)
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
                    .padding(.vertical, 2)
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.lg)
            } else {
                let breakdown = RatingBreakdown.from(reviews)
                HStack(spacing: Space.sm) {
                    Text(String(format: "%.1f", breakdown.average))
                        .font(.bmDisplay(38, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 1) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: Double(i) < breakdown.average.rounded() ? "star.fill" : "star")
                                    .font(.bmUI(11))
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
                        Text("See all \(reviews.count) reviews")
                            .font(.bmUI(13, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private var bookButton: some View {
        VStack(spacing: Space.xs) {
            if braider.services.isEmpty {
                Text("Not taking bookings yet")
                    .font(.bmUI(13))
                    .foregroundStyle(Color.appAsh)
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
    }

    private var firstName: String {
        braider.name.split(separator: " ").first.map(String.init) ?? braider.name
    }
}

// MARK: - Scroll preference

private struct ProfileScrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Portfolio card

struct PortfolioImageCard: View {
    let item: PortfolioItem
    let index: Int
    let appeared: Bool

    @State private var revealed = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.imageUrl)
                .frame(width: 220, height: 300)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

            if !item.caption.isEmpty {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                Text(item.caption)
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.appInkInverse)
                    .lineLimit(2)
                    .padding(Space.sm)
            }
        }
        .frame(width: 220, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .mask(
            Rectangle().offset(y: revealed ? 0 : 300)
        )
        .opacity(revealed ? 1 : 0.001)
        .animate(Motion.reveal.delay(Motion.stagger(index)), value: revealed)
        .onAppear { if appeared { revealed = true } }
        .onChange(of: appeared) { _, newValue in if newValue { revealed = true } }
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
                            .frame(width: 56, height: 56)
                        Image(systemName: "photo")
                            .font(.bmUI(18))
                            .foregroundStyle(Color.appSmoke)
                    } else {
                        RemoteImage(url: service.imageUrl)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
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
                }

                Spacer()

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
                BMAvatar(url: review.userAvatar, size: 34, initials: userInitials)
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