import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct BraidMeApp: App {

    init() {
        FirebaseApp.configure()
        print("[BraidMe] Firebase configured: \(FirebaseApp.app() != nil)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}