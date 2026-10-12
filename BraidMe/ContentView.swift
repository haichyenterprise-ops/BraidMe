import SwiftUI
import FirebaseAuth

// =============================================================================
// ContentView — Root router + splash
// =============================================================================

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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
            } else if isCheckingProfile {
                splash
            } else if needsOnboarding {
                ProfileSetupView(
                    uid: session.uid,
                    displayName: session.displayName ?? "",
                    provider: providerString,
                    needsName: (session.displayName ?? "").isEmpty
                ) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        needsOnboarding = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: session.isSignedIn)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: needsOnboarding)
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: isCheckingProfile)
        .task(id: session.uid) {
            await checkProfile()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Splash

    private var splash: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient gold gradient
            RadialGradient(
                colors: [Color.gold.opacity(0.10), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: Space.xl) {
                // Animated logo
                ZStack {
                    // Breathing outer glow
                    Circle()
                        .fill(Color.gold.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.2)
                        .opacity(0.6)

                    Circle()
                        .stroke(Color.gold.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.35)
                        .opacity(0.35)

                    Circle()
                        .fill(Color.gold.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.gold)
                }

                VStack(spacing: Space.xs) {
                    Text("BraidMe")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(Color.appInk)

                    Text("Where craft meets care")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                        .tracking(1)
                }

                ProgressView()
                    .tint(Color.gold)
                    .scaleEffect(1.1)
                    .padding(.top, Space.sm)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Provider

    private var providerString: String {
        guard let user = session.user else { return "guest" }
        let ids = user.providerData.compactMap { $0.providerID }
        if ids.contains("apple.com") { return "apple" }
        if ids.contains("google.com") { return "google" }
        if ids.contains("password") { return "email" }
        return "guest"
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Profile check

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