import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var needsProfileSetup = false
    @State private var hasCheckedProfile = false

    var body: some View {
        Group {
            if !session.isInitialized {
                // Splash — session loading
                splash
            } else if !session.isSignedIn {
                // Auth landing
                AuthView()
                    .transition(.opacity)
            } else if needsProfileSetup {
                // First-time profile setup
                ProfileSetupView(
                    uid: session.uid,
                    displayName: session.displayName ?? "",
                    provider: providerString,
                    needsName: (session.displayName ?? "").isEmpty
                ) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        needsProfileSetup = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Main app
                MainTabView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.5), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.5), value: needsProfileSetup)
        .task(id: session.uid) {
            await checkProfileCompletion()
        }
    }

    // MARK: - Splash

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

    // MARK: - Provider

    private var providerString: String {
        guard let user = session.user else { return "guest" }
        let providerIds = user.providerData.compactMap { $0.providerID }
        if providerIds.contains("apple.com")  { return "apple" }
        if providerIds.contains("google.com") { return "google" }
        if providerIds.contains("password")   { return "email" }
        return "guest"
    }

    // MARK: - Profile setup check

    private func checkProfileCompletion() async {
        guard session.isSignedIn else {
            await MainActor.run {
                needsProfileSetup = false
                hasCheckedProfile = true
            }
            return
        }

        // Wait until session has been initialized
        if !session.isInitialized {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let uid = session.uid
        guard !uid.isEmpty else { return }

        do {
            // Read user doc directly — if missing profileCompleted, show setup
            let fb = FirebaseManager.shared
            let snap = try await fb.db.collection("users").document(uid).getDocument()
            let completed = (snap.data()?["profileCompleted"] as? Bool) ?? false

            await MainActor.run {
                needsProfileSetup = !completed
                hasCheckedProfile = true
            }
        } catch {
            print("[ContentView] profile check failed:", error)
            await MainActor.run {
                // On error, be lenient — go straight to main so app isn't stuck
                needsProfileSetup = false
                hasCheckedProfile = true
            }
        }
    }
}