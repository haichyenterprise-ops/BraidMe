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
                    withAnimation(Motion.navigation) {
                        needsOnboarding = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainTabView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .animate(Motion.navigation, value: session.isSignedIn)
        .animate(Motion.navigation, value: needsOnboarding)
        .animate(Motion.navigation, value: isCheckingProfile)
        .task(id: session.uid) {
            await checkProfile()
        }
    }

    private var splash: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: Space.lg) {
                ZStack {
                    Circle()
                        .fill(Color.appAccentTint)
                        .frame(width: 88, height: 88)
                    Image(systemName: "sparkles")
                        .font(.bmUI(32, weight: .medium))
                        .foregroundStyle(Color.appAccent)
                }
                Text("BraidMe")
                    .font(.bmDisplay(30, weight: .semibold))
                    .foregroundStyle(Color.appInk)
                ProgressView()
                    .tint(Color.appAccent)
                    .padding(.top, Space.xs)
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