import SwiftUI
import FirebaseCore
import GoogleSignIn

// =============================================================================
// BraidMeApp — Entry point
// =============================================================================

@main
struct BraidMeApp: App {

    @StateObject private var session = SessionManager.shared

    init() {
        FirebaseApp.configure()

        #if DEBUG
        print("[BraidMe] Firebase configured: \(FirebaseApp.app() != nil)")
        if let app = FirebaseApp.app() {
            print("[BraidMe] Project: \(app.options.projectID ?? "unknown")")
            print("[BraidMe] Bundle: \(app.options.bundleID ?? "unknown")")
        }
        #endif

        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Global appearance

    private func configureGlobalAppearance() {
        // Navigation bar — transparent, let views control chrome
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Text field tint
        UITextField.appearance().tintColor = UIColor(Color.gold)
        UITextView.appearance().tintColor = UIColor(Color.gold)
    }
}