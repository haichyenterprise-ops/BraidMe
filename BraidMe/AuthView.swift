import SwiftUI
import AuthenticationServices

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
                // Background
                Color.appBackground.ignoresSafeArea()
                
                // Ambient gradient orbs
                ambientBackground
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: geo.safeAreaInsets.top + Space.xl)

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
                                    withAnimation(Motion.press) { mode = .landing }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        Spacer().frame(height: Space.xl)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { 
            withAnimation(Motion.heroReveal.delay(0.1)) { 
                appeared = true 
            } 
        }
        .alert("Sign-In Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Ambient Background
    
    private var ambientBackground: some View {
        ZStack {
            // Top right orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -200)
                .blur(radius: 40)
            
            // Bottom left orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.appAccent.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -200, y: 400)
                .blur(radius: 60)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Landing

    private var landingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandBlock.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.xxl)
            featureStack.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.xxl)
            authStack.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.lg)
            legal.padding(.horizontal, Space.lg)
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // Eyebrow
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.appAccent)
                    .frame(width: 24, height: 2)
                Text("BRAIDME")
                    .font(.bmUI(11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.appAccent)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            Text("Where craft\nmeets care.")
                .font(.bmHero(42))
                .lineSpacing(-6)
                .foregroundStyle(Color.appInk)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            Text("Discover braiders near you — booked, verified, and rated by real clients.")
                .font(.bmUI(15))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animate(Motion.heroReveal, value: appeared)
    }

    private var featureStack: some View {
        VStack(spacing: Space.sm) {
            featureRow(icon: "magnifyingglass", title: "Search by city", subtitle: "Find braiders near you")
            featureRow(icon: "star.fill", title: "Real reviews", subtitle: "From verified customers")
            featureRow(icon: "calendar", title: "Book in seconds", subtitle: "Pick a time, confirm, done")
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animate(Motion.heroReveal.delay(0.15), value: appeared)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appAccentTint)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.bmUI(16, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text(subtitle)
                    .font(.bmUI(12))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(Space.sm)
        .background(Color.appSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var authStack: some View {
        VStack(spacing: Space.sm) {
            // Apple Sign In
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
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .shadow(color: Color.appInk.opacity(0.15), radius: 12, y: 6)
                .opacity(session.isBusy ? 0.6 : 1)
                .disabled(session.isBusy)

                if session.isBusy, currentNonce != nil {
                    ProgressView().tint(.white).scaleEffect(1.1)
                }
            }

            // Google
            Button {
                Task { await handleGoogle() }
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "g.circle.fill")
                        .font(.bmUI(18))
                    Text("Continue with Google")
                        .font(.bmUI(16, weight: .semibold))
                }
                .foregroundStyle(Color.appInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .stroke(Color.appDivider, lineWidth: 1)
                )
                .shadow(color: Color.appInk.opacity(0.06), radius: 8, y: 4)
            }
            .buttonStyle(BMPressStyle())
            .disabled(session.isBusy)

            // Email signup
            Button {
                Haptic.press()
                withAnimation(Motion.press) { mode = .emailSignup }
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "envelope.fill")
                        .font(.bmUI(15, weight: .semibold))
                    Text("Sign up with Email")
                        .font(.bmUI(16, weight: .semibold))
                }
                .foregroundStyle(Color.appInkInverse)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.appInk)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .shadow(color: Color.appInk.opacity(0.2), radius: 12, y: 6)
            }
            .buttonStyle(BMPressStyle())
            .disabled(session.isBusy)

            // Login link
            Button {
                Haptic.select()
                withAnimation(Motion.press) { mode = .emailLogin }
            } label: {
                HStack(spacing: Space.xxs) {
                    Text("Already have an account?")
                        .font(.bmUI(13))
                        .foregroundStyle(Color.appAsh)
                    Text("Log in")
                        .font(.bmUI(13, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
        .animate(Motion.heroReveal.delay(0.25), value: appeared)
    }

    private var legal: some View {
        Text("By continuing you agree to our ")
            .font(.bmUI(12))
            .foregroundStyle(Color.appSmoke)
        + Text("Terms").font(.bmUI(12, weight: .semibold)).foregroundStyle(Color.appAsh)
        + Text(" and ").font(.bmUI(12)).foregroundStyle(Color.appSmoke)
        + Text("Privacy Policy.").font(.bmUI(12, weight: .semibold)).foregroundStyle(Color.appAsh)
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else {
                errorMessage = "Missing Apple credential."
                return
            }
            session.isBusy = true
            Haptic.success()
            Task {
                do {
                    try await session.signInWithApple(credential: credential, nonce: nonce)
                    await MainActor.run { session.isBusy = false }
                } catch {
                    await MainActor.run {
                        session.isBusy = false
                        errorMessage = SessionManager.friendlyError(error)
                    }
                    Haptic.error()
                }
            }
        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription
            Haptic.error()
        }
    }

    private func handleGoogle() async {
        session.isBusy = true
        Haptic.press()
        do {
            try await session.signInWithGoogle()
            await MainActor.run { session.isBusy = false }
        } catch {
            await MainActor.run {
                session.isBusy = false
                errorMessage = SessionManager.friendlyError(error)
            }
            Haptic.error()
        }
    }
}