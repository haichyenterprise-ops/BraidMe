import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider
    @State private var isReviewsExpanded = false
    @State private var showBooking = false
    @Environment(\.dismiss) var dismiss
    
    private var posts: [String] { [braider.imageUrl] + braider.posts }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: Reels-style vertical pager
            GeometryReader { geo in
                TabView {
                    ForEach(Array(posts.enumerated()), id: \.offset) { idx, url in
                        ReelPage(url: url, index: idx, total: posts.count, braider: braider)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .rotationEffect(.degrees(-90))
                    }
                }
                .frame(width: geo.size.height, height: geo.size.width)
                .rotationEffect(.degrees(90), anchor: .topLeading)
                .offset(x: geo.size.width)
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .ignoresSafeArea()
            
            // MARK: Overlay chrome
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(braider.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
            
            // MARK: Bottom reviews pull-up + book now
            VStack(spacing: 12) {
                if !isReviewsExpanded {
                    Button {
                        showBooking = true
                    } label: {
                        Text("Book Now")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 15, y: 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isReviewsExpanded)
            
            // MARK: Reviews drawer
            ReviewsDrawer(
                isExpanded: $isReviewsExpanded,
                reviews: FirebaseManager.shared.reviews(for: braider)
            )
        }
        .statusBarHidden(false)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showBooking) {
            BookingSelectionView(braider: braider)
        }
    }
}

// MARK: - Reel Page
struct ReelPage: View {
    let url: String
    let index: Int
    let total: Int
    let braider: Braider
    
    var body: some View {
        ZStack {
            RemoteImage(url: url)
                .ignoresSafeArea()
            
            // Gradient overlay for legibility
            LinearGradient(
                colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Top content (info post)
            if index == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer()
                    Text(braider.name)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", braider.rating))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("•")
                            .foregroundColor(.white.opacity(0.6))
                        Text("Birmingham")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Text(braider.bio)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(4)
                        .padding(.top, 4)
                    Spacer().frame(height: 180)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Photo posts
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(braider.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Recent work")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 160)
                }
            }
        }
    }
}

// MARK: - Reviews Drawer
struct ReviewsDrawer: View {
    @Binding var isExpanded: Bool
    let reviews: [Review]
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(AppTheme.hairline)
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                
                HStack {
                    Text("Reviews")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Spacer()
                    Text("\(reviews.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.mist)
                        .clipShape(Capsule())
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.slate)
                        .padding(.leading, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(reviews) { review in
                            ReviewCard(review: review)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollDisabled(!isExpanded)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isExpanded ? geo.size.height : 220)
            .background(
                AppTheme.snow
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: -8)
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: isExpanded ? 0 : geo.size.height - 220)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isExpanded)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        withAnimation {
                            if value.translation.height < -40 { isExpanded = true }
                            else if value.translation.height > 40 { isExpanded = false }
                        }
                    }
            )
            .onTapGesture {
                withAnimation { isExpanded.toggle() }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct ReviewCard: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RemoteImage(url: review.userAvatar)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text(review.date)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.slate)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: Double(i) < review.rating ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            Text(review.text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.ink.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cloud)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}