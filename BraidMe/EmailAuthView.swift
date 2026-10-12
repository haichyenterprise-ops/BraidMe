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
            Spacer().frame(height: Space.sm)
            if !isSignup {
                forgotButton.padding(.horizontal, Space.lg)
            }
        }
        .onAppear {
            withAnimation(Motion.heroReveal) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focused = isSignup ? .name : .email
            }
        }
        .alert("Error", isPresented: Binding(
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
        VStack(alignment: .leading, spacing: Space.md) {
            // Back button
            Button {
                Haptic.select()
                onBack()
            } label: {
                HStack(spacing: Space.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.bmUI(13, weight: .semibold))
                    Text("Back")
                        .font(.bmUI(14, weight: .medium))
                }
                .foregroundStyle(Color.appAsh)
                .padding(.vertical, Space.xs)
            }
            .buttonStyle(BMPressStyle(scale: 0.96))

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.xs) {
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: 24, height: 2)
                    Text(isSignup ? "CREATE ACCOUNT" : "WELCOME BACK")
                        .font(.bmUI(11, weight: .bold))
                        .tracking(2.5)
                        .foregroundStyle(Color.appAccent)
                }

                Text(isSignup ? "Sign up\nwith email." : "Log in\nto BraidMe.")
                    .font(.bmHero(36))
                    .lineSpacing(-5)
                    .foregroundStyle(Color.appInk)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text(isSignup
                     ? "Create an account so you can book, save, and review braiders."
                     : "Enter your email and password to continue.")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appAsh)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.heroReveal, value: appeared)
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
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animate(Motion.heroReveal.delay(0.05), value: appeared)
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
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animate(Motion.heroReveal.delay(0.1), value: appeared)

            BMPasswordRow(
                placeholder: "Password",
                text: $password,
                isNew: isSignup
            )
            .focused($focused, equals: .password)
            .onSubmit {
                if isSignup { focused = .confirm } else { submit() }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animate(Motion.heroReveal.delay(0.15), value: appeared)

            if isSignup {
                BMPasswordRow(
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    isNew: true
                )
                .focused($focused, equals: .confirm)
                .onSubmit { submit() }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animate(Motion.heroReveal.delay(0.2), value: appeared)

                VStack(alignment: .leading, spacing: Space.xs) {
                    validationRow(ok: password.count >= 6, label: "At least 6 characters")
                    validationRow(
                        ok: !confirmPassword.isEmpty && confirmPassword == password,
                        label: "Passwords match"
                    )
                }
                .padding(.top, Space.xxs)
                .padding(.horizontal, Space.xxs)
                .opacity(appeared ? 1 : 0)
                .animate(Motion.heroReveal.delay(0.25), value: appeared)
            }
        }
    }

    private func validationRow(ok: Bool, label: String) -> some View {
        HStack(spacing: Space.xs) {
            ZStack {
                Circle()
                    .fill(ok ? Color.appSignal.opacity(0.15) : Color.appDivider)
                    .frame(width: 18, height: 18)
                Image(systemName: ok ? "checkmark" : "circle")
                    .font(.bmUI(9, weight: .bold))
                    .foregroundStyle(ok ? Color.appSignal : Color.appSmoke)
            }
            Text(label)
                .font(.bmUI(12, weight: .medium))
                .foregroundStyle(ok ? Color.appSignal : Color.appAsh)
        }
    }

    private var submitBlock: some View {
        BMPrimaryButton(
            title: isSignup ? "Create account" : "Log in",
            icon: isSignup ? "arrow.right" : "arrow.right",
            loading: session.isBusy
        ) {
            submit()
        }
        .disabled(!canSubmit || session.isBusy)
        .opacity(canSubmit ? 1 : 0.45)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.heroReveal.delay(0.3), value: appeared)
    }

    private var forgotButton: some View {
        HStack {
            Spacer()
            Button {
                Haptic.select()
                Task { await resetPassword() }
            } label: {
                Text("Forgot password?")
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            Spacer()
        }
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

// MARK: - Field Components

struct BMFieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.appAccentTint : Color.appBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(isFocused ? Color.appAccent : Color.appAsh)
            }
            .animation(Motion.subtle, value: isFocused)

            TextField(placeholder, text: $text)
                .font(.bmUI(16, weight: .medium))
                .foregroundStyle(Color.appInk)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .submitLabel(submitLabel)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                .autocorrectionDisabled(true)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    Haptic.select()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.bmUI(16))
                        .foregroundStyle(Color.appSmoke)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 60)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(
                    isFocused ? Color.appAccent.opacity(0.5) : Color.appDivider,
                    lineWidth: isFocused ? 1.5 : 0.5
                )
        )
        .shadow(color: isFocused ? Color.appAccent.opacity(0.1) : .clear, radius: 8, y: 2)
        .animation(Motion.subtle, value: isFocused)
        .animation(Motion.subtle, value: text.isEmpty)
    }
}

struct BMPasswordRow: View {
    let placeholder: String
    @Binding var text: String
    var isNew: Bool = false

    @State private var show = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isFocused ? Color.appAccentTint : Color.appBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: "lock")
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(isFocused ? Color.appAccent : Color.appAsh)
            }
            .animation(Motion.subtle, value: isFocused)

            Group {
                if show {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .font(.bmUI(16, weight: .medium))
            .foregroundStyle(Color.appInk)
            .textContentType(isNew ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .focused($isFocused)

            Button {
                Haptic.select()
                show.toggle()
            } label: {
                Image(systemName: show ? "eye.slash" : "eye")
                    .font(.bmUI(14, weight: .medium))
                    .foregroundStyle(Color.appAsh)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(height: 60)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(
                    isFocused ? Color.appAccent.opacity(0.5) : Color.appDivider,
                    lineWidth: isFocused ? 1.5 : 0.5
                )
        )
        .shadow(color: isFocused ? Color.appAccent.opacity(0.1) : .clear, radius: 8, y: 2)
        .animation(Motion.subtle, value: isFocused)
    }
}