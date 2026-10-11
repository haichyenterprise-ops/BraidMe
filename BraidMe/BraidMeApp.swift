import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct BraidMeApp: App {

    @StateObject private var session = SessionManager.shared

    init() {
        FirebaseApp.configure()
        print("[BraidMe] Firebase configured: \(FirebaseApp.app() != nil)")
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
}