import SwiftUI
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct AuthView: View {
    var onAuthenticated: (ContentView.PendingUser) -> Void

    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var currentNonce: String?
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppTheme.cloud.ignoresSafeArea()
                ambient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // TOP SPACER — shrinks on small devices
                        Spacer()
                            .frame(height: 40)

                        // BRAND
                        brandBlock
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer()
                            .frame(height: 28)

                        // HERO
                        hero
                            .frame(maxWidth: .infinity, alignment: .center)

                        Spacer()
                            .frame(height: 32)

                        // AUTH BUTTONS
                        authStack
                            .padding(.horizontal, 28)

                        Spacer()
                            .frame(height: 24)

                        // LEGAL
                        legal
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Spacer()
                            .frame(height: 40)
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
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.accent.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 460, height: 460)
                .blur(radius: 50)
                .offset(x: -140, y: -240)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.plum.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 60)
                .offset(x: 160, y: 300)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2).delay(0.1), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Brand block

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
                .fixedSize(horizontal: false, vertical: false)

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

    // MARK: - Hero

    private var hero: some View {
        ZStack {
            Circle()
                .fill(AppTheme.bronzeSoft)
                .frame(width: 150, height: 150)

            RemoteImage(
                url: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&q=85"
            )
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

    // MARK: - Auth stack

    private var authStack: some View {
        VStack(spacing: 12) {
            appleSignIn
            googleSignIn
            guestButton
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
    }

    private var appleSignIn: some View {
        ZStack {
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                },
                onCompletion: handleAppleResult
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.25), radius: 16, y: 8)
            .opacity(isProcessing ? 0.6 : 1)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView().tint(.white)
            }
        }
    }

    private var googleSignIn: some View {
        Button {
            handleGoogleSignIn()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20))
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
        .disabled(isProcessing)
    }

    private var guestButton: some View {
        Button {
            Haptics.soft()
            let uid = "guest_\(UUID().uuidString.prefix(10))"
            UserDefaults.standard.set(uid, forKey: "currentUid")
            onAuthenticated(
                .init(
                    uid: uid,
                    displayName: "",
                    email: nil,
                    provider: "guest",
                    needsName: true
                )
            )
        } label: {
            Text("Continue as Guest")
                .font(AppTheme.sans(15, weight: .medium))
                .foregroundColor(AppTheme.slate)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(SoftPress())
        .disabled(isProcessing)
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

    // MARK: - Apple Sign In

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type."
                return
            }

            isProcessing = true
            Haptics.success()

            let given = credential.fullName?.givenName ?? ""
            let family = credential.fullName?.familyName ?? ""
            let assembled = [given, family]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let email = credential.email

            var uid = credential.user
            if uid.isEmpty {
                uid = UserDefaults.standard.string(forKey: "currentUid")
                    ?? "apple_\(UUID().uuidString.prefix(12))"
            }

            UserDefaults.standard.set(uid, forKey: "currentUid")
            UserDefaults.standard.set(uid, forKey: "appleUserId")

            let needsName = assembled.isEmpty

            Task {
                do {
                    try await FirebaseManager.shared.upsertUser(
                        uid: uid,
                        displayName: assembled.isEmpty ? "BraidMe User" : assembled,
                        email: email,
                        provider: "apple"
                    )
                } catch {
                    print("[Auth] apple upsert failed:", error)
                }

                await MainActor.run {
                    isProcessing = false
                    onAuthenticated(
                        .init(
                            uid: uid,
                            displayName: assembled,
                            email: email,
                            provider: "apple",
                            needsName: needsName
                        )
                    )
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Google Sign In

    private func handleGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        else {
            performFallbackGoogle()
            return
        }

        isProcessing = true

        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            if let error {
                self.isProcessing = false
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    return
                }
                print("[Auth] Google SDK error:", error.localizedDescription)
                self.performFallbackGoogle()
                return
            }

            guard let user = result?.user else {
                self.performFallbackGoogle()
                return
            }

            var uid = user.userID ?? ""
            if uid.isEmpty {
                uid = "google_\(UUID().uuidString.prefix(10))"
            }
            let name = user.profile?.name ?? ""
            let email = user.profile?.email

            UserDefaults.standard.set(uid, forKey: "currentUid")
            Haptics.success()

            Task {
                do {
                    try await FirebaseManager.shared.upsertUser(
                        uid: uid,
                        displayName: name.isEmpty ? "Google User" : name,
                        email: email,
                        provider: "google"
                    )
                } catch {
                    print("[Auth] google upsert failed:", error)
                }

                await MainActor.run {
                    self.isProcessing = false
                    self.onAuthenticated(
                        .init(
                            uid: uid,
                            displayName: name,
                            email: email,
                            provider: "google",
                            needsName: name.isEmpty
                        )
                    )
                }
            }
        }
    }

    private func performFallbackGoogle() {
        isProcessing = true
        Haptics.soft()

        let uid = "google_\(UUID().uuidString.prefix(10))"
        UserDefaults.standard.set(uid, forKey: "currentUid")

        Task {
            try? await FirebaseManager.shared.upsertUser(
                uid: uid,
                displayName: "Google User",
                email: nil,
                provider: "google"
            )
            await MainActor.run {
                isProcessing = false
                onAuthenticated(
                    .init(
                        uid: uid,
                        displayName: "",
                        email: nil,
                        provider: "google",
                        needsName: true
                    )
                )
            }
        }
    }
}

// MARK: - Nonce helpers

private func randomNonceString(length: Int = 32) -> String {
    let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length

    while remaining > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        guard status == errSecSuccess else {
            fatalError("Nonce generation failed.")
        }
        randoms.forEach { byte in
            if remaining == 0 { return }
            if byte < chars.count {
                result.append(chars[Int(byte)])
                remaining -= 1
            }
        }
    }

    return result
}

private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    return SHA256.hash(data: data)
        .compactMap { String(format: "%02x", $0) }
        .joined()
}