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
        self.user = Auth.auth().currentUser

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isInitialized = true
            }
        }
    }

    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Computed

    var isSignedIn: Bool { user != nil }
    var uid: String { user?.uid ?? "" }
    var email: String? { user?.email }
    var displayName: String? { user?.displayName }

    /// Provider string used across the app
    var providerString: String {
        guard let user else { return "guest" }
        let ids = user.providerData.compactMap { $0.providerID }
        if ids.contains("apple.com") { return "apple" }
        if ids.contains("google.com") { return "google" }
        if ids.contains("password") { return "email" }
        return "guest"
    }

    // MARK: - Sign Out

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
            Haptic.warning()
        } catch {
            print("[SessionManager] signOut failed:", error)
        }
    }

    func hardSignOut() {
        signOut()
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
                          userInfo: [NSLocalizedDescriptionKey: "Apple didn't return an identity token."])
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        let result = try await Auth.auth().signIn(with: firebaseCredential)
        self.user = result.user

        // Persist Apple's full name (only provided on first sign-in)
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
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't find the app window."])
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Firebase client ID is missing."])
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)

        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Google didn't return an ID token."])
        }

        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

        let authResult = try await Auth.auth().signIn(with: credential)
        self.user = authResult.user
    }

    // MARK: - Email

    func signUpWithEmail(email: String, password: String, name: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "That email doesn't look quite right."])
        }
        guard password.count >= 6 else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Password needs at least 6 characters."])
        }
        guard !trimmedName.isEmpty else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "We need your name to set up your account."])
        }

        let result = try await Auth.auth().createUser(withEmail: clean, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = trimmedName
        try await change.commitChanges()
        self.user = result.user
    }

    func signInWithEmail(email: String, password: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()

        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "That email doesn't look quite right."])
        }
        guard !password.isEmpty else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter your password to continue."])
        }

        let result = try await Auth.auth().signIn(withEmail: clean, password: password)
        self.user = result.user
    }

    func sendPasswordReset(email: String) async throws {
        let clean = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty, clean.contains("@") else {
            throw NSError(domain: "BraidMe", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Enter a valid email first."])
        }
        try await Auth.auth().sendPasswordReset(withEmail: clean)
    }

    // MARK: - Friendly Errors

    /// Maps Firebase Auth errors into warm, human copy that matches the new tone.
    static func friendlyError(_ error: Error) -> String {
        let ns = error as NSError

        // Handle our own custom errors first
        if ns.domain == "BraidMe" {
            return ns.localizedDescription
        }

        // Map Firebase Auth errors
        if let code = AuthErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .emailAlreadyInUse:
                return "That email's already registered. Try logging in instead."
            case .invalidEmail:
                return "That email doesn't look quite right."
            case .weakPassword:
                return "Password needs at least 6 characters."
            case .wrongPassword:
                return "That password doesn't match. Try again."
            case .userNotFound:
                return "We couldn't find an account for that email."
            case .invalidCredential:
                return "Wrong email or password. Give it another go."
            case .networkError:
                return "Connection hiccup. Check your internet and try again."
            case .tooManyRequests:
                return "Too many tries. Take a breather, then try again."
            case .operationNotAllowed:
                return "Email sign-in isn't enabled yet. Try Google or Apple."
            case .userDisabled:
                return "This account has been disabled. Contact support."
            case .requiresRecentLogin:
                return "For security, please sign in again."
            case .missingEmail:
                return "We need an email to continue."
            case .credentialAlreadyInUse:
                return "That credential is linked to another account."
            default:
                return ns.localizedDescription
            }
        }

        return ns.localizedDescription
    }
}

// MARK: - Apple Nonce

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