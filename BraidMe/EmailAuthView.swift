import SwiftUI

struct EmailAuthView: View {

    enum Mode: Equatable { case signup, login }

    let mode: Mode
    var onBack: () -> Void
    var onSuccess: () -> Void

    @EnvironmentObject private var session: SessionManager

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appeared = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
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
        } else {
            return email.contains("@") && !password.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Back button + header
            header
                .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            // Form
            formBlock
                .padding(.horizontal, 28)

            Spacer().frame(height: 24)

            // Submit
            submitBlock
                .padding(.horizontal, 28)

            Spacer().frame(height: 16)

            // Secondary actions
            secondaryActions
                .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.05)) {
                appeared = true
            }
            // Focus first field after appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focused = isSignup ? .name : .email
            }
        }
        .alert("Error", isPresented: bindingError) {
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

    private var bindingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                Haptics.soft()
                onBack()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(AppTheme.sans(14, weight: .medium))
                }
                .foregroundColor(AppTheme.slate)
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.bronzeGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, y: 6)
                    Image(systemName: isSignup ? "envelope.badge.fill" : "lock.open.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                }
                Text(isSignup ? "CREATE ACCOUNT" : "WELCOME BACK")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text(isSignup ? "Sign up\nwith email." : "Log in\nto BraidMe.")
                .font(AppTheme.serif(34))
                .lineSpacing(-2)
                .foregroundColor(AppTheme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(isSignup
                 ? "Create an account so you can book, save, and review braiders."
                 : "Enter your email and password to continue.")
                .font(AppTheme.sans(14))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Form

    private var formBlock: some View {
        VStack(spacing: 14) {
            if isSignup {
                FieldRow(
                    icon: "person.fill",
                    placeholder: "Full name",
                    text: $name,
                    contentType: .name,
                    submitLabel: .next
                )
                .focused($focused, equals: .name)
                .onSubmit { focused = .email }
            }

            FieldRow(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                submitLabel: .next
            )
            .focused($focused, equals: .email)
            .onSubmit { focused = .password }

            PasswordRow(
                placeholder: "Password",
                text: $password,
                isNew: isSignup
            )
            .focused($focused, equals: .password)
            .onSubmit {
                if isSignup { focused = .confirm } else { submit() }
            }

            if isSignup {
                PasswordRow(
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    isNew: true
                )
                .focused($focused, equals: .confirm)
                .onSubmit { submit() }
            }

            // Live validation hints for signup
            if isSignup {
                VStack(alignment: .leading, spacing: 6) {
                    validationRow(
                        ok: password.count >= 6,
                        label: "At least 6 characters"
                    )
                    validationRow(
                        ok: !confirmPassword.isEmpty && confirmPassword == password,
                        label: "Passwords match"
                    )
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSignup)
    }

    private func validationRow(ok: Bool, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ok ? AppTheme.success : AppTheme.ash)
            Text(label)
                .font(AppTheme.sans(12))
                .foregroundColor(ok ? AppTheme.success : AppTheme.stone)
        }
    }

    // MARK: - Submit

    private var submitBlock: some View {
        VStack(spacing: 10) {
            if let infoMessage {
                Text(infoMessage)
                    .font(AppTheme.sans(12, weight: .medium))
                    .foregroundColor(AppTheme.sage)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                title: isSignup ? "Create account" : "Log in",
                icon: isSignup ? "checkmark" : "arrow.right",
                loading: session.isBusy
            ) {
                submit()
            }
            .disabled(!canSubmit || session.isBusy)
            .opacity(canSubmit ? 1 : 0.45)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Secondary

    private var secondaryActions: some View {
        HStack(spacing: 4) {
            Spacer()

            if !isSignup {
                Button {
                    Haptics.soft()
                    Task { await resetPassword() }
                } label: {
                    Text("Forgot password?")
                        .font(AppTheme.sans(13, weight: .medium))
                        .foregroundColor(AppTheme.accentDeep)
                }
            }

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit, !session.isBusy else { return }
        focused = nil
        Haptics.medium()
        session.isBusy = true
        infoMessage = nil

        Task {
            do {
                if isSignup {
                    try await session.signUpWithEmail(
                        email: email,
                        password: password,
                        name: name
                    )
                } else {
                    try await session.signInWithEmail(
                        email: email,
                        password: password
                    )
                }
                await MainActor.run {
                    session.isBusy = false
                    Haptics.success()
                    onSuccess()
                }
            } catch {
                await MainActor.run {
                    session.isBusy = false
                    errorMessage = SessionManager.friendlyError(error)
                    Haptics.error()
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

// MARK: - Field row

struct FieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.slate)
                .frame(width: 18)

            TextField(placeholder, text: $text)
                .font(AppTheme.sans(16, weight: .medium))
                .foregroundColor(AppTheme.ink)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .submitLabel(submitLabel)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(true)

            if !text.isEmpty {
                Button {
                    Haptics.soft()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.ash)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(text.isEmpty ? AppTheme.hairline : AppTheme.accent.opacity(0.5), lineWidth: 1)
        )
    }
}

struct PasswordRow: View {
    let placeholder: String
    @Binding var text: String
    var isNew: Bool = false

    @State private var show = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.slate)
                .frame(width: 18)

            Group {
                if show {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(AppTheme.sans(16, weight: .medium))
            .foregroundColor(AppTheme.ink)
            .textContentType(isNew ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                Haptics.soft()
                show.toggle()
            } label: {
                Image(systemName: show ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.slate)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(AppTheme.snow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(text.isEmpty ? AppTheme.hairline : AppTheme.accent.opacity(0.5), lineWidth: 1)
        )
    }
}