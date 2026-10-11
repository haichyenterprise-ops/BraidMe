import SwiftUI

enum AppState: Equatable {
    case auth
    case profileSetup
    case mainApp
}

struct ContentView: View {
    @State private var state: AppState = .auth
    @State private var pendingUser: PendingUser?

    struct PendingUser: Equatable {
        let uid: String
        let displayName: String
        let email: String?
        let provider: String
        let needsName: Bool
    }

    var body: some View {
        ZStack {
            switch state {
            case .auth:
                AuthView { user in
                    pendingUser = user
                    withAnimation(.easeInOut(duration: 0.5)) {
                        state = .profileSetup
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    )
                )

            case .profileSetup:
                if let user = pendingUser {
                    ProfileSetupView(user: user) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                            state = .mainApp
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                } else {
                    Color.clear.onAppear { state = .auth }
                }

            case .mainApp:
                MainTabView()
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .preferredColorScheme(.light)
        
    }
    .onReceive(NotificationCenter.default.publisher(for: .braidMeSignOut)) { _ in
    withAnimation(.easeInOut(duration: 0.5)) {
        state = .auth
    }
    pendingUser = nil
}
}
