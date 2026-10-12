import SwiftUI
import FirebaseCore
import GoogleSignIn

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
                .onAppear {
                    UIApplication.shared.applicationSupportsShakeToEdit = true
                }
        }
    }
    
    // MARK: - Global Appearance
    
    private func configureGlobalAppearance() {
        // Navigation bar — remove default chrome, let views control their own
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // Tab bar (if ever used)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        // Text fields — no default styling
        UITextField.appearance().tintColor = UIColor(Color.appAccent)
        UITextView.appearance().tintColor = UIColor(Color.appAccent)
        
        // Sheet presentation — support our custom corner radius
        if #available(iOS 17.0, *) {
            // Nothing to configure here — SwiftUI handles it via .presentationCornerRadius
        }
    }
}