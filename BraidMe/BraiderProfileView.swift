import SwiftUI

struct BraiderProfileView: View {
    let braider: Braider
    @State private var isReviewsExpanded = false
    @State private var showBookingFlow = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 70% Posts Section
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Post 1: Info
                    VStack(alignment: .leading, spacing: 15) {
                        Text("About \(braider.name)")
                            .font(.title2.bold())
                        Text(braider.bio)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface)
                    
                    // Post 2: Image
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(height: UIScreen.main.bounds.height * 0.6)
                        .clipped()
                        .overlay(
                            LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        )
                    
                    // Post 3: Another Image
                    Image(systemName: "photo.on.rectangle")
                        .resizable()
                        .scaledToFill()
                        .frame(height: UIScreen.main.bounds.height * 0.6)
                        .clipped()
                }
                .padding(.bottom, UIScreen.main.bounds.height * 0.3) // Space for reviews
            }
            .frame(height: UIScreen.main.bounds.height * 0.7)
            
            // 30% Reviews Section (Expands)
            VStack {
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 10)
                
                Text("Reviews")
                    .font(.headline)
                    .padding(.top, 5)
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(0..<5) { _ in
                            ReviewRow()
                        }
                    }
                    .padding()
                }
            }
            .frame(height: isReviewsExpanded ? UIScreen.main.bounds.height : UIScreen.main.bounds.height * 0.3)
            .background(AppTheme.surface)
            .cornerRadius(25, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
            .offset(y: isReviewsExpanded ? 0 : UIScreen.main.bounds.height * 0.7)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isReviewsExpanded)
            .onTapGesture {
                isReviewsExpanded.toggle()
            }
            
            // Book Now Button
            if !isReviewsExpanded {
                Button(action: {
                    showBookingFlow = true
                }) {
                    Text("Book Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.primaryGradient)
                        .cornerRadius(15)
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(braider.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showBookingFlow) {
            BookingSelectionView(braider: braider)
        }
    }
}

struct ReviewRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(AppTheme.primary.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Amazing work!")
                    .font(.subheadline.bold())
                Text("She did my knotless braids perfectly. Highly recommend.")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }
}