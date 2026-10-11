import SwiftUI

enum AppState {
    case auth
    case ageVerification
    case mainApp
}

struct ContentView: View {
    @State private var appState: AppState = .auth
    
    var body: some View {
        ZStack {
            if appState == .auth {
                AuthView(onLoginSuccess: {
                    withAnimation(.easeInOut(duration: 0.5)) { appState = .ageVerification }
                })
                .transition(.opacity)
            } else if appState == .ageVerification {
                AgeVerificationView(onConfirm: {
                    withAnimation(.spring()) { appState = .mainApp }
                })
                .transition(.move(edge: .trailing))
            } else {
                MainTabView()
                    .transition(.move(edge: .bottom))
            }
        }
    }
}