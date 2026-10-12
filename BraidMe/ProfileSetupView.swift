import SwiftUI

// =============================================================================
// ProfileSetupView — Onboarding step 2, rebuilt
// Massive age numeral with numeric transitions, ambient gradient, staggered reveal.
// =============================================================================

struct ProfileSetupView: View {
    let uid: String
    let displayName: String
    let provider: String
    let needsName: Bool
    var onComplete: () -> Void

    @State private var name: String = ""
    @State private var age: Int = 22
    @State private var appeared = false
    @State private var saving = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private let range = Array(13...90)

    private var isNameValid: Bool {
        !needsName || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isValid: Bool { isNameValid && age >= 13 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient gradient
            RadialGradient(
                colors: [Color.gold.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Space.xxl)

                    header.padding(.horizontal, Space.lg)
                    Spacer().frame(height: Space.xl)

                    if needsName {
                        nameField.padding(.horizontal, Space.lg)
                        Spacer().frame(height: Space.lg)
                    }

                    agePicker.padding(.horizontal, Space.lg)
                    Spacer().frame(height: Space.lg)

                    footer.padding(.horizontal, Space.lg)
                    Spacer().frame(height: Space.xxl)
                }
            }
        }
        .onAppear {
            if !needsName && name.isEmpty { name = displayName }
            withAnimation(.spring(response: 0.85, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if needsName { nameFocused = true }
            }
        }
        .alert("Couldn't save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 24, height: 2)
                Text("SETUP · STEP 2 OF 2")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(Color.gold)
            }

            Text(needsName ? "A little\nabout you." : "How old\nare you?")
                .font(.system(size: 42, weight: .bold, design: .serif))
                .lineSpacing(-6)
                .foregroundStyle(Color.appInk)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(needsName
                 ? "We'll use this to personalise your feed and match you with the right braiders."
                 : "This helps us keep BraidMe safe and shows age-appropriate styles.")
                .font(.system(size: 15))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("YOUR NAME")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAsh)
            }
            BMFieldRow(
                icon: "person",
                placeholder: "First and last name",
                text: $name,
                contentType: .name,
                submitLabel: .done
            )
            .focused($nameFocused)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 20, height: 1.5)
                Text("YOUR AGE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color.appAsh)
            }

            VStack(spacing: Space.md) {
                // Giant numeral
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text("\(age)")
                        .font(.system(size: 88, weight: .bold, design: .serif))
                        .foregroundStyle(Color.appInk)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: age)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("years")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                        .padding(.bottom, 16)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .fill(Color.gold.opacity(0.10))
                        .frame(height: 44)
                        .padding(.horizontal, Space.xl)

                    Picker("Age", selection: $age) {
                        ForEach(range, id: \.self) { n in
                            Text("\(n)").tag(n)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)
                    .clipped()
                    .onChange(of: age) { _, _ in Haptic.select() }
                }
                .frame(height: 180)
            }
            .padding(.vertical, Space.sm)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.20), value: appeared)
    }

    private var footer: some View {
        VStack(spacing: Space.sm) {
            if !isValid && !name.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("You must be at least 13 to continue.")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.appAlert)
                .padding(.horizontal, Space.md)
                .padding(.vertical, 8)
                .background(Color.appAlert.opacity(0.1), in: Capsule())
                .transition(.scale.combined(with: .opacity))
            }

            BMPrimaryButton(
                title: saving ? "Saving…" : "Continue",
                icon: "arrow.right",
                loading: saving
            ) {
                save()
            }
            .disabled(!isValid || saving)
            .opacity(isValid ? 1 : 0.4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.25), value: appeared)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isValid)
    }

    private func save() {
        guard isValid else { return }
        saving = true
        Haptic.press()

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName: String = {
            if !trimmed.isEmpty { return trimmed }
            if !displayName.isEmpty { return displayName }
            return "BraidMe User"
        }()

        UserDefaults.standard.set(age, forKey: "userAge")
        UserDefaults.standard.set(finalName, forKey: "userName")
        UserDefaults.standard.set(uid, forKey: "currentUid")

        Task {
            do {
                try await FirebaseManager.shared.updateUser(uid: uid, data: [
                    "displayName": finalName,
                    "age": age,
                    "provider": provider,
                    "profileCompleted": true,
                    "profileCompletedAt": Date()
                ])
                await FirebaseManager.shared.loadUser(uid: uid)

                await MainActor.run {
                    saving = false
                    Haptic.success()
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    saving = false
                    errorMessage = error.localizedDescription
                    Haptic.error()
                }
            }
        }
    }
}