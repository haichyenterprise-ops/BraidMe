import SwiftUI
import AuthenticationServices

// =============================================================================
// AuthView — Landing page, rebuilt
// Ambient gold orbs, staggered hero reveal, feature cards, three auth paths.
// =============================================================================

struct AuthView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var mode: AuthMode = .landing
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var appeared = false

    // Ambient background motion
    @State private var orbAOffset: CGSize = .zero
    @State private var orbBOffset: CGSize = .zero
    @State private var orbAAngle: Double = 0
    @State private var orbBAngle: Double = 0

    enum AuthMode: Equatable {
        case landing
        case emailSignup
        case emailLogin
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base
                Color.appBackground.ignoresSafeArea()

                // Ambient gold orbs — breathing
                ambientOrbs(in: geo.size)

                // Content
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
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        mode = .landing
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }

                        Spacer().frame(height: Space.xxl)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            startAmbientMotion()
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

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Ambient orbs

    private func ambientOrbs(in size: CGSize) -> some View {
        ZStack {
            // Top-right gold
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.16),
                            Color.gold.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 320
                    )
                )
                .frame(width: 640, height: 640)
                .offset(x: orbAOffset.width + size.width * 0.28,
                        y: orbAOffset.height - size.height * 0.32)
                .blur(radius: 40)

            // Bottom-left warm
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#A88461").opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .offset(x: orbBOffset.width - size.width * 0.42,
                        y: orbBOffset.height + size.height * 0.40)
                .blur(radius: 60)
        }
        .allowsHitTesting(false)
    }

    private func startAmbientMotion() {
        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
            orbAOffset = CGSize(width: 40, height: 30)
        }
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
            orbBOffset = CGSize(width: -30, height: -40)
        }
    }

    // ═══════════════════════════════════════════════════════════════
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
                    .fill(Color.gold)
                    .frame(width: 24, height: 2)
                Text("BRAIDME")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Color.gold)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)

            // Headline
            Text("Where craft\nmeets care.")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .lineSpacing(-6)
                .foregroundStyle(Color.appInk)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

            // Subtitle
            Text("Discover braiders near you — booked, verified, and rated by real clients.")
                .font(.system(size: 15))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureStack: some View {
        VStack(spacing: Space.sm) {
            featureRow(
                icon: "magnifyingglass",
                title: "Search by city",
                subtitle: "Find braiders near you",
                delay: 0.15
            )
            featureRow(
                icon: "star.fill",
                title: "Real reviews",
                subtitle: "From verified customers",
                delay: 0.20
            )
            featureRow(
                icon: "calendar",
                title: "Book in seconds",
                subtitle: "Pick a time, confirm, done",
                delay: 0.25
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    private func featureRow(icon: String, title: String, subtitle: String, delay: Double) -> some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appAsh)
            }
            Spacer()
        }
        .padding(Space.sm)
        .background(Color.appSurface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(Color.appDivider.opacity(0.5), lineWidth: 0.5)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .animation(.spring(response: 0.65, dampingFraction: 0.85).delay(delay), value: appeared)
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
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
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
                        .font(.system(size: 18))
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
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
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
            }
            .buttonStyle(BMPressStyle())
            .disabled(session.isBusy)

            // Email signup
            Button {
                Haptic.press()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    mode = .emailSignup
                }
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Sign up with Email")
                        .font(.system(size: 16, weight: .semibold))
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
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    mode = .emailLogin
                }
            } label: {
                HStack(spacing: Space.xxs) {
                    Text("Already have an account?")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appAsh)
                    Text("Log in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.gold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
        .animation(.spring(response: 0.75, dampingFraction: 0.85).delay(0.30), value: appeared)
    }

    private var legal: some View {
        Text("By continuing you agree to our ")
            .font(.system(size: 12))
            .foregroundStyle(Color.appSmoke)
        + Text("Terms").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appAsh)
        + Text(" and ").font(.system(size: 12)).foregroundStyle(Color.appSmoke)
        + Text("Privacy Policy.").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appAsh)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Apple / Google handlers

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