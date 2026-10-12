import SwiftUI

struct EmailAuthView: View {

    enum Mode: Equatable { case signup, login }

    let mode: Mode
    var onBack: () -> Void

    @EnvironmentObject private var session: SessionManager

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appeared = false
    @State private var errorMessage: String?
    @State private var showResetSheet = false

    @FocusState private var focused: Field?
    enum Field { case name, email, password, confirm }

    private var isSignup: Bool { mode == .signup }

    private var canSubmit: Bool {
        if isSignup {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
                && email.contains("@")
                && password.count >= 6
                && password == confirmPassword
        }
        return email.contains("@") && !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.xl)
            formBlock.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.lg)
            submitBlock.padding(.horizontal, Space.lg)
            Spacer().frame(height: Space.md)
            if !isSignup {
                forgotButton.padding(.horizontal, Space.lg)
            }
            Spacer(minLength: Space.xl)
        }
        .padding(.top, Space.lg)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focused = isSignup ? .name : .email
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Check your email", isPresented: $showResetSheet) {
            Button("OK") { showResetSheet = false }
        } message: {
            Text("If an account exists for \(email), we've sent a password reset link.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                BMIconButton(icon: "chevron.left", size: 44, iconSize: 15) {
                    onBack()
                }
                Spacer()
                BraidMark(length: 46, thickness: 28, strand: 6, horizontal: true, cycles: 1.4)
            }

            VStack(alignment: .leading, spacing: Space.sm) {
                Text(isSignup ? "Create your\naccount." : "Welcome\nback.")
                    .font(.bmDisplay(42, weight: .semibold))
                    .foregroundStyle(Color.bmText)
                    .lineSpacing(-5)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text(isSignup
                     ? "Book, save and review braiders in one place."
                     : "Log in to see your bookings and saved braiders.")
                    .font(.bmUI(15))
                    .foregroundStyle(Color.bmTextDim)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reveal(appeared)
    }

    private var formBlock: some View {
        VStack(spacing: Space.sm) {
            if isSignup {
                BMFieldRow(
                    icon: "person",
                    placeholder: "Full name",
                    text: $name,
                    contentType: .name,
                    submitLabel: .next
                )
                .focused($focused, equals: .name)
                .onSubmit { focused = .email }
            }

            BMFieldRow(
                icon: "envelope",
                placeholder: "Email",
                text: $email,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                submitLabel: .next
            )
            .focused($focused, equals: .email)
            .onSubmit { focused = .password }

            BMPasswordRow(
                placeholder: "Password",
                text: $password,
                isNew: isSignup
            )
            .focused($focused, equals: .password)
            .onSubmit {
                if isSignup { focused = .confirm } else { submit() }
            }

            if isSignup {
                BMPasswordRow(
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    isNew: true
                )
                .focused($focused, equals: .confirm)
                .onSubmit { submit() }

                HStack(spacing: Space.md) {
                    validationRow(ok: password.count >= 6, label: "6+ characters")
                    validationRow(
                        ok: !confirmPassword.isEmpty && confirmPassword == password,
                        label: "Passwords match"
                    )
                    Spacer()
                }
                .padding(.top, Space.xxs)
                .padding(.horizontal, Space.xxs)
            }
        }
        .reveal(appeared, delay: 0.08)
    }

    private func validationRow(ok: Bool, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .font(.bmUI(13, weight: .semibold))
                .foregroundStyle(ok ? Color.bmGood : Color.bmTextFaint)
                .scaleEffect(ok ? 1 : 0.9)
                .animation(Motion.pop, value: ok)
            Text(label)
                .font(.bmUI(12, weight: .medium))
                .foregroundStyle(ok ? Color.bmGood : Color.bmTextDim)
        }
    }

    private var submitBlock: some View {
        BMPrimaryButton(
            title: isSignup ? "Create account" : "Log in",
            icon: isSignup ? "checkmark" : "arrow.right",
            loading: session.isBusy
        ) {
            submit()
        }
        .disabled(!canSubmit || session.isBusy)
        .opacity(canSubmit ? 1 : 0.4)
        .animation(Motion.subtle, value: canSubmit)
        .reveal(appeared, delay: 0.16)
    }

    private var forgotButton: some View {
        HStack {
            Spacer()
            Button {
                Haptic.select()
                Task { await resetPassword() }
            } label: {
                Text("Forgot password?")
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(Color.bmGilt)
                    .padding(.vertical, Space.xs)
            }
            Spacer()
        }
        .reveal(appeared, delay: 0.22)
    }

    private func submit() {
        guard canSubmit, !session.isBusy else { return }
        focused = nil
        Haptic.press()
        session.isBusy = true

        Task {
            do {
                if isSignup {
                    try await session.signUpWithEmail(email: email, password: password, name: name)
                } else {
                    try await session.signInWithEmail(email: email, password: password)
                }
                await MainActor.run {
                    session.isBusy = false
                    Haptic.success()
                }
            } catch {
                await MainActor.run {
                    session.isBusy = false
                    errorMessage = SessionManager.friendlyError(error)
                    Haptic.error()
                }
            }
        }
    }

    private func resetPassword() async {
        do {
            try await session.sendPasswordReset(email: email)
            await MainActor.run { showResetSheet = true }
        } catch {
            await MainActor.run {
                errorMessage = SessionManager.friendlyError(error)
            }
        }
    }
}
