import SwiftUI
import AuthenticationServices
import CryptoKit

struct AuthView: View {
    var onAuthenticated: (ContentView.PendingUser) -> Void

    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var phase: CGFloat = 0
    @State private var appeared = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambientBackdrop

            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                brandBlock
                Spacer()
                heroIllustration
                Spacer()
                authStack
                legalText
            }
            .padding(.horizontal, 26)
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

    // MARK: - Ambient background

    private var ambientBackdrop: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: 260
                ))
                .frame(width: 620, height: 620)
                .blur(radius: 40)
                .offset(x: -180, y: -260)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.16), .clear],
                    center: .center, startRadius: 0, endRadius: 240
                ))
                .frame(width: 540, height: 540)
                .blur(radius: 50)
                .offset(x: 200, y: 340)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.rose.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 420, height: 420)
                .blur(radius: 60)
                .offset(x: 100, y: -80)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.4).delay(0.15), value: appeared)
    }

    // MARK: - Brand

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 46, height: 46)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 16, y: 8)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }

                Text("BRAIDME")
                    .font(AppTheme.sans(13, weight: .bold))
                    .tracking(3.2)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("Where craft\nmeets care.")
                .font(AppTheme.serif(44))
                .lineSpacing(-4)
                .foregroundColor(AppTheme.ink)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)

            Text("Discover braiders near you — booked, verified, and rated by real clients.")
                .font(AppTheme.sans(16))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(4)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1), value: appeared)
    }

    // MARK: - Illustration

    private var heroIllustration: some View {
        ZStack {
            Circle()
                .fill(AppTheme.bronzeSoft)
                .frame(width: 220, height: 220)
                .overlay(Circle().stroke(AppTheme.accentSoft, lineWidth: 1))

            RemoteImage(
                url: "https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=800&q=85"
            )
            .frame(width: 200, height: 200)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.snow, lineWidth: 4))
            .shadow(color: .black.opacity(0.15), radius: 24, y: 12)

            badge(icon: "checkmark.seal.fill", tint: AppTheme.success)
                .offset(x: 80, y: -70)

            badge(icon: "star.fill", tint: AppTheme.gold)
                .offset(x: -80, y: 70)
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25), value: appeared)
    }

    private func badge(icon: String, tint: Color) -> some View {
        ZStack {
            Circle().fill(AppTheme.snow).frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    // MARK: - Auth

    private var authStack: some View {
        VStack(spacing: 12) {
            appleSignInButton
            googleButton
            guestButton
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
        .animation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.35), value: appeared)
    }

    private var appleSignInButton: some View {
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.25), radius: 18, y: 8)
            .opacity(isProcessing ? 0.6 : 1)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView().tint(.white)
            }
        }
    }

    private var googleButton: some View {
        Button {
            handleGoogleSignIn()
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
        .disabled(isProcessing)
    }

    private var guestButton: some View {
        Button {
            Haptics.soft()
            onAuthenticated(
                .init(uid: "guest_\(UUID().uuidString.prefix(8))",
                      displayName: "Guest",
                      email: nil,
                      provider: "guest")
            )
        } label: {
            Text("Continue as Guest")
                .font(AppTheme.sans(15, weight: .medium))
                .foregroundColor(AppTheme.slate)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(SoftPress())
    }

    private var legalText: some View {
        Text("By continuing you agree to our ")
            .font(AppTheme.sans(12))
            .foregroundColor(AppTheme.stone)
        + Text("Terms").font(AppTheme.sans(12, weight: .semibold)).foregroundColor(AppTheme.slate)
        + Text(" and ").font(AppTheme.sans(12)).foregroundColor(AppTheme.stone)
        + Text("Privacy Policy.").font(AppTheme.sans(12, weight: .semibold)).foregroundColor(AppTheme.slate)
    }

    // MARK: - Entrance animation

    private func startEntrance() {
        withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.1)) {
            appeared = true
        }
    }

    // MARK: - Apple handling

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type."
                return
            }
            isProcessing = true
            Haptics.success()

            let uid = credential.user
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let displayName = name.isEmpty ? "BraidMe User" : name
            let email = credential.email

            UserDefaults.standard.set(uid, forKey: "appleUserId")
            UserDefaults.standard.set(displayName, forKey: "appleUserName")

            Task {
                do {
                    _ = try await FirebaseManager.shared.signInAndUpsertUser(
                        uid: uid,
                        displayName: displayName,
                        email: email,
                        provider: "apple",
                        age: UserDefaults.standard.integer(forKey: "userAge")
                    )
                } catch {
                    print("[Auth] Firestore write failed:", error)
                }

                await MainActor.run {
                    isProcessing = false
                    onAuthenticated(
                        .init(uid: uid,
                              displayName: displayName,
                              email: email,
                              provider: "apple")
                    )
                }
            }

        case .failure(let error):
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // user cancelled — ignore silently
                return
            }
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    // MARK: - Google handling (stub — swap for real SDK later)

    private func handleGoogleSignIn() {
        Haptics.soft()
        isProcessing = true
        let uid = "google_\(UUID().uuidString.prefix(10))"
        let displayName = "Google User"
        UserDefaults.standard.set(uid, forKey: "appleUserId")

        Task {
            do {
                _ = try await FirebaseManager.shared.signInAndUpsertUser(
                    uid: uid,
                    displayName: displayName,
                    email: nil,
                    provider: "google",
                    age: UserDefaults.standard.integer(forKey: "userAge")
                )
            } catch {
                print("[Auth] Google Firestore write failed:", error)
            }
            await MainActor.run {
                isProcessing = false
                onAuthenticated(
                    .init(uid: uid,
                          displayName: displayName,
                          email: nil,
                          provider: "google")
                )
            }
        }
    }
}

// MARK: - Nonce helpers for Apple Sign In

private func randomNonceString(length: Int = 32) -> String {
    let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        guard status == errSecSuccess else { fatalError("Unable to generate nonce.") }
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
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
}