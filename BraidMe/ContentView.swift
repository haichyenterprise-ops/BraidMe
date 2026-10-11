import SwiftUI

enum AppState: Equatable {
    case auth
    case ageVerification
    case mainApp
}

struct ContentView: View {
    @State private var appState: AppState = .auth

    var body: some View {
        ZStack {
            switch appState {
            case .auth:
                AuthView {
                    withAnimation(.easeInOut(duration: 0.55)) { appState = .ageVerification }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .scale(scale: 0.98))
                ))

            case .ageVerification:
                AgeVerificationView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appState = .mainApp }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

            case .mainApp:
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
}