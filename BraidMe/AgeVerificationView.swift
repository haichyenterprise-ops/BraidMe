import SwiftUI

struct AgeVerificationView: View {
    @State private var age: String = ""
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Text("How old are you?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.top, 100)
            
            TextField("Enter age", text: $age)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .medium))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .shadow(color: Color.black.opacity(0.05), radius: 10)
                .padding(.horizontal, 40)
            
            Spacer()
            
            PremiumButton(title: "Confirm", action: {
                // You can validate age here
                onConfirm()
            })
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}