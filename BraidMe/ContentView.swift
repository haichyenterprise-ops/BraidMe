import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var needsOnboarding = false
    @State private var isCheckingProfile = true
    @State private var showSignOutIsolation = false

    var body: some View {
        Group {
            if !session.isInitialized || isCheckingProfile {
                splash
            } else if showSignOutIsolation {
                SignOutIsolationView(appName: "BraidMe") {
                    showSignOutIsolation = false
                    session.signOut()
                }
                .transition(.opacity)
            } else if !session.isSignedIn {
                AuthView()
                    .transition(.opacity)
            } else if needsOnboarding {
                ProfileSetupView(
                    uid: session.uid,
                    displayName: session.displayName ?? "",
                    provider: providerString,
                    needsName: (session.displayName ?? "").isEmpty
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        needsOnboarding = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.5), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.5), value: needsOnboarding)
        .animation(.easeInOut(duration: 0.35), value: showSignOutIsolation)
        .task(id: session.uid) {
            await checkOnboarding()
        }
    }

    private var splash: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 88, height: 88)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 20, y: 10)
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(.white)
                }
                Text("BraidMe")
                    .font(AppTheme.serif(32))
                    .foregroundColor(AppTheme.ink)
                ProgressView()
                    .tint(AppTheme.accent)
                    .padding(.top, 8)
            }
        }
    }

    private var providerString: String {
        guard let user = session.user else { return "guest" }
        let ids = user.providerData.compactMap { $0.providerID }
        if ids.contains("apple.com") { return "apple" }
        if ids.contains("google.com") { return "google" }
        if ids.contains("password") { return "email" }
        return "guest"
    }

    private func checkOnboarding() async {
        guard session.isSignedIn else {
            await MainActor.run {
                needsOnboarding = false
                isCheckingProfile = true
                showSignOutIsolation = false
            }
            return
        }

        let uid = session.uid
        guard !uid.isEmpty else { return }

        do {
            let snap = try await FirebaseManager.shared.db
                .collection("users")
                .document(uid)
                .getDocument()

            let completed = (snap.data()?["profileCompleted"] as? Bool) ?? false

            await MainActor.run {
                needsOnboarding = !completed
                isCheckingProfile = false
                showSignOutIsolation = false
            }
        } catch {
            await MainActor.run {
                needsOnboarding = false
                isCheckingProfile = false
            }
        }
    }
}

// MARK: - Sign-out isolation screen (used by both apps)

struct SignOutIsolationView: View {
    let appName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeSoft)
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(spacing: 10) {
                    Text("Session closed")
                        .font(AppTheme.serif(26))
                        .foregroundColor(AppTheme.ink)
                    Text("Your \(appName) session has been signed out on this device. Tap continue to sign in again.")
                        .font(AppTheme.sans(14))
                        .foregroundColor(AppTheme.slate)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 40)
                }

                Spacer()

                PrimaryButton(title: "Continue", icon: "arrow.right") {
                    onContinue()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}