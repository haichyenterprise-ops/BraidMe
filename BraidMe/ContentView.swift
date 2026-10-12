import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var session: SessionManager

    @State private var needsOnboarding = false
    @State private var isCheckingProfile = true

    var body: some View {
        ZStack {
            Color.bmBase.ignoresSafeArea()

            Group {
                if !session.isInitialized {
                    SplashView()
                        .transition(.opacity)
                } else if !session.isSignedIn {
                    AuthView()
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else if isCheckingProfile {
                    SplashView()
                        .transition(.opacity)
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.96))
                    ))
                } else {
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.06)),
                            removal: .opacity
                        ))
                }
            }
        }
        .animate(Motion.navigation, value: session.isSignedIn)
        .animate(Motion.navigation, value: session.isInitialized)
        .animate(Motion.navigation, value: needsOnboarding)
        .animate(Motion.navigation, value: isCheckingProfile)
        .task(id: session.uid) {
            await checkProfile()
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

// MARK: - Splash

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.85)

            VStack(spacing: Space.lg) {
                BraidMark(length: 176, thickness: 60, strand: 13, cycles: 2.2)
                    .reveal(appeared, delay: 0.0, offset: 10, blur: 10)

                VStack(spacing: Space.xs) {
                    Text("BraidMe")
                        .font(.bmDisplay(40, weight: .semibold))
                        .foregroundStyle(Color.bmText)
                    Text("Your braider, booked.")
                        .font(.bmUI(14, weight: .medium))
                        .foregroundStyle(Color.bmTextDim)
                }
                .reveal(appeared, delay: 0.18, offset: 14, blur: 8)
            }
        }
        .onAppear { appeared = true }
    }
}
