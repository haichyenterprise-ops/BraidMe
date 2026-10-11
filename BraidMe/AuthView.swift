import SwiftUI
import AuthenticationServices

struct AuthView: View {
    var onLoginSuccess: () -> Void
    @State private var errorMessage: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()

            // Ambient decorative shapes
            ambientBackground

            VStack(spacing: 0) {
                Spacer()

                brand

                Spacer().frame(height: 60)

                authStack

                legal
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) {
                appeared = true
            }
        }
        .alert("Sign In Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Ambient background

    private var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(AppTheme.bronzeSoftGradient)
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -150, y: -220)
                .opacity(appeared ? 0.9 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.15), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .offset(x: 150, y: 300)
                .opacity(appeared ? 0.9 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
    }

    // MARK: - Brand

    private var brand: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.bronzeGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 24, y: 12)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.white)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("BraidMe")
                    .font(.system(size: 46, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.ink)
                Text("Find your perfect braider.")
                    .font(AppTheme.body(16))
                    .foregroundColor(AppTheme.slate)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
        }
    }

    // MARK: - Auth stack

    private var authStack: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: handleAppleSignIn
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.18), radius: 14, y: 6)

            Button(action: {
                Haptics.soft()
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
                .frame(height: 56)
                .background(AppTheme.snow)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.horizontal, 28)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    // MARK: - Legal

    private var legal: some View {
        Text("By continuing you agree to our **Terms** and **Privacy Policy**.")
            .font(.system(size: 12))
            .foregroundColor(AppTheme.stone)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.top, 24)
            .padding(.bottom, 40)
    }

    // MARK: - Apple Sign In

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                UserDefaults.standard.set(credential.user, forKey: "appleUserId")
                Haptics.success()
                onLoginSuccess()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}