import SwiftUI

struct ProfileSetupView: View {
    let user: ContentView.PendingUser
    var onComplete: () -> Void

    @State private var name: String = ""
    @State private var age: Int = 22
    @State private var appeared = false
    @State private var saving = false
    @State private var errorMessage: String?

    private let range = Array(13...90)

    private var isNameValid: Bool {
        // If the provider supplied a name, name is optional
        !user.needsName || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isValid: Bool {
        isNameValid && age >= 13
    }

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambient

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    header
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 32)

                    if user.needsName {
                        nameField
                            .padding(.horizontal, 26)
                        Spacer().frame(height: 24)
                    }

                    agePicker
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 24)

                    footer
                        .padding(.horizontal, 26)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear(perform: startEntrance)
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Ambient

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 460, height: 460)
                .blur(radius: 50)
                .offset(x: -140, y: -200)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text("SETUP · STEP 2 OF 3")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text(user.needsName ? "A little\nabout you." : "How old\nare you?")
                .font(AppTheme.serif(40))
                .lineSpacing(-3)
                .foregroundColor(AppTheme.ink)

            Text(user.needsName
                 ? "We'll use this to personalise your feed and match you with the right braiders."
                 : "This helps us keep BraidMe safe and shows age-appropriate styles.")
                .font(AppTheme.sans(15))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Your name")

            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.slate)

                TextField("First and last name", text: $name)
                    .font(AppTheme.sans(16, weight: .medium))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundColor(AppTheme.ink)

                if !name.isEmpty {
                    Button {
                        Haptics.soft()
                        name = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
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
                    .stroke(
                        name.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppTheme.hairline
                            : AppTheme.accent.opacity(0.7),
                        lineWidth: name.isEmpty ? 1 : 1.2
                    )
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Age

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Your age")

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(age)")
                        .font(.system(size: 72, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.ink)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: age)

                    Text("years")
                        .font(AppTheme.sans(18, weight: .medium))
                        .foregroundColor(AppTheme.slate)
                        .padding(.bottom, 12)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .frame(height: 44)
                        .padding(.horizontal, 20)

                    Picker("Age", selection: $age) {
                        ForEach(range, id: \.self) { n in
                            Text("\(n)").tag(n)
                                .font(AppTheme.sans(22, weight: .semibold))
                                .foregroundColor(AppTheme.ink)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 170)
                    .clipped()
                    .onChange(of: age) { _, _ in Haptics.select() }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 4)
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if !isValid && !name.isEmpty {
                Text("You must be at least 13 to continue.")
                    .font(AppTheme.sans(13, weight: .medium))
                    .foregroundColor(AppTheme.danger)
            }

            PrimaryButton(title: saving ? "Saving…" : "Continue", loading: saving) {
                save()
            }
            .disabled(!isValid || saving)
            .opacity(isValid ? 1 : 0.4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func startEntrance() {
        withAnimation(.spring(response: 0.95, dampingFraction: 0.85).delay(0.1)) {
            appeared = true
        }
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }
        saving = true
        Haptics.medium()

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty
            ? (user.displayName.isEmpty ? "Guest" : user.displayName)
            : trimmed

        UserDefaults.standard.set(age, forKey: "userAge")
        UserDefaults.standard.set(finalName, forKey: "userName")

        Task {
            do {
                try await FirebaseManager.shared.updateUser(uid: user.uid, data: [
                    "displayName": finalName,
                    "age": age,
                    "provider": user.provider,
                    "profileCompleted": true,
                    "profileCompletedAt": Date()
                ])
                // Refresh local cache so MainTabView has the user
                await FirebaseManager.shared.loadUser(uid: user.uid)
            } catch {
                print("[ProfileSetup] save failed:", error)
                await MainActor.run {
                    saving = false
                    errorMessage = error.localizedDescription
                }
                return
            }

            await MainActor.run {
                saving = false
                Haptics.success()
                onComplete()
            }
        }
    }
}