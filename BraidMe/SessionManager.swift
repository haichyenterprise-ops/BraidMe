import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
final class SessionManager: NSObject, ObservableObject {

    static let shared = SessionManager()

    @Published var user: User?
    @Published var isInitialized = false
    @Published var isBusy = false
    @Published var authError: String?

    private var authListener: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()

        // Restore previous session if the SDK has one
        self.user = Auth.auth().currentUser

        // Listen for auth changes
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isInitialized = true
            }
        }
    }

    // MARK: - Computed

    var isSignedIn: Bool { user != nil }
    var uid: String { user?.uid ?? "" }
    var email: String? { user?.email }
    var displayName: String? { user?.displayName }

    // MARK: - Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()

            UserDefaults.standard.removeObject(forKey: "currentUid")
            UserDefaults.standard.removeObject(forKey: "appleUserId")
            UserDefaults.standard.removeObject(forKey: "userAge")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.removeObject(forKey: "locationPermissionDecision")

            self.user = nil
            Haptics.warning()
        } catch {
            print("[SessionManager] signOut failed:", error)
        }
    }

    /// Strong sign-out — wipes the Keychain-backed Firebase session
    /// so the user isn't auto-logged-in on next launch or after reinstall.
    func hardSignOut() {
        signOut()

        // Wipe generic password entries (where Firebase stores its auth tokens)
        let secItemClasses: [CFString] = [kSecClassGenericPassword]
        for itemClass in secItemClasses {
            let spec: [CFString: Any] = [kSecClass: itemClass]
            SecItemDelete(spec as CFDictionary)
        }
    }

    // MARK: - Apple
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No identity token from Apple."])
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let result = try await Auth.auth().signIn(with: firebaseCredential)
        self.user = result.user

        if let name = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let display = formatter.string(from: name)
            if !display.isEmpty {
                let change = result.user.createProfileChangeRequest()
                change.displayName = display
                try? await change.commitChanges()
            }
        }
    }

    // MARK: - Google
    func signInWithGoogle() async throws {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to locate window."])
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Firebase client ID missing."])
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)

        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Google returned no ID token."])
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        let authResult = try await Auth.auth().signIn(with: credential)
        self.user = authResult.user
    }

    // MARK: - Email signup
    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters."])
        }
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter your name."])
        }

        let result = try await Auth.auth().createUser(withEmail: clean, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = trimmedName
        try await change.commitChanges()
        self.user = result.user
    }

    // MARK: - Email login
    func signInWithEmail(email: String, password: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        guard !password.isEmpty else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Please enter your password."])
        }

        let result = try await Auth.auth().signIn(withEmail: clean, password: password)
        self.user = result.user
    }

    // MARK: - Reset
    func sendPasswordReset(email: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email address."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: clean)
    }

    // MARK: - Friendly errors
    static func friendlyError(_ error: Error) -> String {
        let ns = error as NSError
        let code = AuthErrorCode.Code(rawValue: ns.code)

        if let code {
            switch code {
            case .emailAlreadyInUse: return "That email is already registered. Try logging in."
            case .invalidEmail: return "That email doesn't look right."
            case .weakPassword: return "Password must be at least 6 characters."
            case .wrongPassword: return "Incorrect password."
            case .userNotFound: return "No account found for that email."
            case .invalidCredential: return "Wrong email or password."
            case .networkError: return "Network problem. Check your connection."
            case .tooManyRequests: return "Too many attempts. Try again in a moment."
            case .operationNotAllowed: return "Email sign-in isn't enabled in Firebase Console."
            default: return ns.localizedDescription
            }
        }
        return ns.localizedDescription
    }
}

// MARK: - Nonce helpers

enum AppleNonce {
    static func random(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else { fatalError("Nonce generation failed.") }
            randoms.forEach { byte in
                if remaining == 0 { return }
                if byte < chars.count {
                    result.append(chars[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        return SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}