import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var mode: AuthMode = .landing
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var appeared = false

    enum AuthMode: Equatable {
        case landing
        case emailSignup
        case emailLogin
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppTheme.cloud.ignoresSafeArea()
                ambient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 40)

                        if mode == .landing {
                            landingView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            EmailAuthView(
                                mode: mode == .emailSignup ? .signup : .login,
                                onBack: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                        mode = .landing
                                    }
                                },
                                onSuccess: {
                                    // session listener handles the rest
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        Spacer().frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { startEntrance() }
        .alert("Sign-In Failed", isPresented: bindingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var bindingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.20), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 460, height: 460)
                .blur(radius: 50)
                .offset(x: -140, y: -240)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 160, y: 300)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2).delay(0.1), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Landing

    private var landingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandBlock
                .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            hero
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer().frame(height: 32)

            authStack
                .padding(.horizontal, 28)

            Spacer().frame(height: 24)

            legal
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
                Text("BRAIDME")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("Where craft\nmeets care.")
                .font(AppTheme.serif(34))
                .lineSpacing(-2)
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text("Discover braiders near you — booked, verified, and rated by real clients.")
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(AppTheme.bronzeSoft)
                .frame(width: 150, height: 150)

            RemoteImage(url: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&q=85")
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

            floatingBadge(icon: "checkmark.seal.fill", tint: AppTheme.success)
                .offset(x: 62, y: -52)

            floatingBadge(icon: "star.fill", tint: AppTheme.gold)
                .offset(x: -62, y: 52)
        }
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
    }

    private func floatingBadge(icon: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.snow)
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    // MARK: - Auth buttons

    private var authStack: some View {
        VStack(spacing: 12) {
            appleSignIn
            googleSignIn
            emailSignupButton
            emailLoginButton
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
    }

    private var appleSignIn: some View {
        ZStack {
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = AppleNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonce.sha256(nonce)
                },
                onCompletion: handleAppleResult
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.25), radius: 16, y: 8)
            .opacity(session.isBusy ? 0.6 : 1)
            .disabled(session.isBusy)

            if session.isBusy && currentNonce != nil {
                ProgressView().tint(.white)
            }
        }
    }

    private var googleSignIn: some View {
        Button {
            Task { await handleGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill").font(.system(size: 20))
                Text("Continue with Google")
                    .font(AppTheme.sans(17, weight: .semibold))
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
        .buttonStyle(SoftPress())
        .disabled(session.isBusy)
    }

    private var emailSignupButton: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                mode = .emailSignup
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill").font(.system(size: 16))
                Text("Sign up with Email")
                    .font(AppTheme.sans(17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.inkGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: AppTheme.ink.opacity(0.28), radius: 18, y: 10)
        }
        .buttonStyle(SoftPress())
        .disabled(session.isBusy)
    }

    private var emailLoginButton: some View {
        Button {
            Haptics.soft()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                mode = .emailLogin
            }
        } label: {
            HStack(spacing: 6) {
                Text("Already have an account?")
                    .font(AppTheme.sans(14))
                    .foregroundColor(AppTheme.slate)
                Text("Log in")
                    .font(AppTheme.sans(14, weight: .semibold))
                    .foregroundColor(AppTheme.accentDeep)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(SoftPress())
        .disabled(session.isBusy)
    }

    private var legal: some View {
        Text("By continuing you agree to our ")
            .font(AppTheme.sans(12))
            .foregroundColor(AppTheme.stone)
        + Text("Terms")
            .font(AppTheme.sans(12, weight: .semibold))
            .foregroundColor(AppTheme.slate)
        + Text(" and ")
            .font(AppTheme.sans(12))
            .foregroundColor(AppTheme.stone)
        + Text("Privacy Policy.")
            .font(AppTheme.sans(12, weight: .semibold))
            .foregroundColor(AppTheme.slate)
    }

    private func startEntrance() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) {
            appeared = true
        }
    }

    // MARK: - Apple

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else {
                errorMessage = "Missing Apple credential."
                return
            }

            session.isBusy = true
            Haptics.success()

            Task {
                do {
                    try await session.signInWithApple(credential: credential, nonce: nonce)
                    await MainActor.run { session.isBusy = false }
                } catch {
                    await MainActor.run {
                        session.isBusy = false
                        errorMessage = SessionManager.friendlyError(error)
                    }
                    Haptics.error()
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Google

    private func handleGoogle() async {
        session.isBusy = true
        Haptics.soft()
        do {
            try await session.signInWithGoogle()
            await MainActor.run { session.isBusy = false }
        } catch {
            await MainActor.run {
                session.isBusy = false
                errorMessage = SessionManager.friendlyError(error)
            }
            Haptics.error()
        }
    }
}