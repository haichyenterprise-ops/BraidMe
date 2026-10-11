import SwiftUI

enum AppState: Equatable {
    case auth
    case ageVerification
    case mainApp
}

struct ContentView: View {
    @State private var state: AppState = .auth
    @State private var pendingUser: PendingUser?

    // Carries sign-in data across screens
    struct PendingUser {
        let uid: String
        let displayName: String
        let email: String?
        let provider: String
    }

    var body: some View {
        ZStack {
            switch state {
            case .auth:
                AuthView { user in
                    pendingUser = user
                    withAnimation(.easeInOut(duration: 0.55)) {
                        state = .ageVerification
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    )
                )

            case .ageVerification:
                AgeVerificationView(
                    user: pendingUser ?? PendingUser(
                        uid: "guest",
                        displayName: "Guest",
                        email: nil,
                        provider: "guest"
                    ),
                    onConfirm: {
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.85)) {
                            state = .mainApp
                        }
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    )
                )

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
}