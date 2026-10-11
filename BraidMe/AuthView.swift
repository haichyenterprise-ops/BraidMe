import SwiftUI

struct AuthView: View {
    var onLoginSuccess: () -> Void
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                Text("Braid Me")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 10, x: 0, y: 5)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: onLoginSuccess) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(15)
                    }
                    
                    Button(action: onLoginSuccess) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Sign in with Google")
                        }
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.1), radius: 5)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
}