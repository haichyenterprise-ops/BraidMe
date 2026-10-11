import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var needsOnboarding = false
    @State private var isCheckingProfile = true

    var body: some View {
        Group {
            if !session.isInitialized {
                splash
            } else if !session.isSignedIn {
                AuthView()
                    .transition(.opacity)
            } else if isCheckingProfile {
                splash
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
        .animation(.easeInOut(duration: 0.35), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: needsOnboarding)
        .animation(.easeInOut(duration: 0.35), value: isCheckingProfile)
        .task(id: session.uid) {
            await checkProfile()
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

    private func checkProfile() async {
        guard session.isSignedIn else {
            await MainActor.run {
                needsOnboarding = false
                isCheckingProfile = false
            }
            return
        }

        let uid = session.uid
        guard !uid.isEmpty else {
            await MainActor.run { isCheckingProfile = false }
            return
        }

        await MainActor.run { isCheckingProfile = true }

        do {
            let snap = try await FirebaseManager.shared.db
                .collection("users")
                .document(uid)
                .getDocument()

            let completed = (snap.data()?["profileCompleted"] as? Bool) ?? false

            await MainActor.run {
                needsOnboarding = !completed
                isCheckingProfile = false
            }
        } catch {
            print("[ContentView] profile check failed:", error)
            await MainActor.run {
                needsOnboarding = false
                isCheckingProfile = false
            }
        }
    }
}