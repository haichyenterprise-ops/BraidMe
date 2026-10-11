import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var onLoginSuccess: () -> Void
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Brand
                VStack(spacing: 12) {
                    Text("BraidMe")
                        .font(.system(size: 48, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.ink)
                    
                    Text("Find your perfect braider")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.slate)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    
                    // Google (still mocked — needs GoogleSignIn SDK)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onLoginSuccess()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.snow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(SoftPressStyle())
                }
                .padding(.horizontal, 28)
                
                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.slate)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .alert("Sign In Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            // Store user id — Firebase Auth would be wired here
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                UserDefaults.standard.set(credential.user, forKey: "appleUserId")
                onLoginSuccess()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}