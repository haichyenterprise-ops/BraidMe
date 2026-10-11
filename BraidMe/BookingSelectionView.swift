import SwiftUI

struct BookingSelectionView: View {
    let braider: Braider
    @State private var selectedIndex: Int? = nil
    @State private var showPayment = false
    @Environment(\.dismiss) var dismiss
    
    let braidTypes = ["Knotless", "Box Braids", "Cornrows"]
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Select Your Style")
                    .font(.largeTitle.bold())
                    .padding(.top, 50)
                
                Spacer()
                
                HStack(spacing: 20) {
                    ForEach(0..<braidTypes.count, id: \.self) { index in
                        VStack {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: selectedIndex == index ? 150 : 80, height: selectedIndex == index ? 200 : 120)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: selectedIndex == index ? AppTheme.primary.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        selectedIndex = index
                                    }
                                }
                            
                            if selectedIndex == index {
                                Text(braidTypes[index])
                                    .font(.headline)
                                    .transition(.opacity)
                                Text("Description of \(braidTypes[index])...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .frame(height: 300)
                
                Spacer()
                
                if selectedIndex != nil {
                    PremiumButton(title: "Continue", action: {
                        showPayment = true
                    })
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showPayment) {
                PaymentView(braider: braider, selectedStyle: braidTypes[selectedIndex ?? 0])
            }
        }
    }
}