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
                AuroraBackground()

                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        if mode == .landing {
                            landingView(minHeight: geo.size.height)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        } else {
                            EmailAuthView(
                                mode: mode == .emailSignup ? .signup : .login,
                                onBack: {
                                    withAnimation(Motion.navigation) { mode = .landing }
                                }
                            )
                            .frame(minHeight: geo.size.height, alignment: .top)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear { appeared = true }
        .alert("Sign-in failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Landing

    private func landingView(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xxl)

            Spacer(minLength: Space.xl)

            featureRow
                .padding(.bottom, Space.lg)

            authPanel
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.sm)

            legal
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.lg)
        }
        .frame(minHeight: minHeight, alignment: .top)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .center, spacing: Space.sm) {
                BraidMark(length: 46, thickness: 28, strand: 6, horizontal: true, cycles: 1.4)
                Text("BraidMe")
                    .font(.bmDisplay(22, weight: .semibold))
                    .foregroundStyle(Color.bmText)
            }
            .reveal(appeared, delay: 0.0)

            Text("Braids, booked\nbeautifully.")
                .font(.bmDisplay(46, weight: .semibold))
                .foregroundStyle(Color.bmText)
                .lineSpacing(-6)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .reveal(appeared, delay: 0.08, offset: 26, blur: 10)

            Text("Verified braiders near you, real reviews from real clients, and an appointment in a few taps.")
                .font(.bmUI(16))
                .foregroundStyle(Color.bmTextDim)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .reveal(appeared, delay: 0.16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.sm) {
                featurePill(icon: "mappin.and.ellipse", title: "Search your city", tint: Color.bmGilt)
                featurePill(icon: "star.bubble.fill", title: "Real reviews", tint: Color.bmOrchid)
                featurePill(icon: "calendar.badge.checkmark", title: "Book in seconds", tint: Color.bmEmber)
            }
            .padding(.horizontal, Space.lg)
        }
        .reveal(appeared, delay: 0.24)
    }

    private func featurePill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: icon)
                .font(.bmUI(13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: Circle())
            Text(title)
                .font(.bmUI(13, weight: .semibold))
                .foregroundStyle(Color.bmText)
        }
        .padding(.leading, 8)
        .padding(.trailing, Space.md)
        .padding(.vertical, 8)
        .bmGlass(radius: 40)
    }

    // MARK: - Auth stack

    private var authPanel: some View {
        VStack(spacing: Space.sm) {
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
                .signInWithAppleButtonStyle(.white)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .opacity(session.isBusy ? 0.6 : 1)
                .disabled(session.isBusy)

                if session.isBusy, currentNonce != nil {
                    BMSpinner(color: Color.black)
                }
            }

            Button {
                Task { await handleGoogle() }
            } label: {
                HStack(spacing: Space.xs) {
                    Text("G")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "#4285F4"))
                        .frame(width: 24, height: 24)
                        .background(Color.white, in: Circle())
                    Text("Continue with Google")
                        .font(.bmUI(16, weight: .semibold))
                }
                .foregroundStyle(Color.bmText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .bmGlass(radius: Radius.button)
            }
            .buttonStyle(BMPressStyle())
            .disabled(session.isBusy)

            BMPrimaryButton(title: "Sign up with email", icon: "envelope.fill") {
                withAnimation(Motion.navigation) { mode = .emailSignup }
            }
            .disabled(session.isBusy)

            Button {
                Haptic.select()
                withAnimation(Motion.navigation) { mode = .emailLogin }
            } label: {
                HStack(spacing: Space.xxs) {
                    Text("Already have an account?")
                        .font(.bmUI(14))
                        .foregroundStyle(Color.bmTextDim)
                    Text("Log in")
                        .font(.bmUI(14, weight: .bold))
                        .foregroundStyle(Color.bmGilt)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
            }
            .buttonStyle(BMPressStyle(scale: 0.98, dim: 0))
        }
        .padding(Space.md)
        .bmGlass(radius: Radius.modal, tint: Color.black.opacity(0.18))
        .reveal(appeared, delay: 0.32, offset: 40, blur: 0)
    }

    private var legal: some View {
        (Text("By continuing you agree to our ")
            .font(.bmUI(12))
            .foregroundStyle(Color.bmTextFaint)
        + Text("Terms")
            .font(.bmUI(12, weight: .semibold))
            .foregroundStyle(Color.bmTextDim)
        + Text(" and ")
            .font(.bmUI(12))
            .foregroundStyle(Color.bmTextFaint)
        + Text("Privacy Policy.")
            .font(.bmUI(12, weight: .semibold))
            .foregroundStyle(Color.bmTextDim))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .reveal(appeared, delay: 0.4, offset: 8, blur: 0)
    }

    // MARK: - Handlers

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
