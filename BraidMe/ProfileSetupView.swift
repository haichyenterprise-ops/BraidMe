import SwiftUI

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
            AuroraBackground(intensity: 0.7)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.xxl)

                    if needsName {
                        nameField
                            .padding(.horizontal, Space.lg)
                            .padding(.top, Space.xl)
                    }

                    agePicker
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.xl)

                    footer
                        .padding(.horizontal, Space.lg)
                        .padding(.top, Space.xl)
                        .padding(.bottom, Space.xl)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if !needsName && name.isEmpty { name = displayName }
            appeared = true
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(spacing: Space.sm) {
                BraidMark(length: 46, thickness: 28, strand: 6, horizontal: true, cycles: 1.4)
                Text("One last step")
                    .font(.bmUI(14, weight: .semibold))
                    .foregroundStyle(Color.bmTextDim)
            }

            Text(needsName ? "A little\nabout you." : "How old\nare you?")
                .font(.bmDisplay(44, weight: .semibold))
                .foregroundStyle(Color.bmText)
                .lineSpacing(-6)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(needsName
                 ? "We'll use this to match you with the right braiders."
                 : "This helps us keep BraidMe safe and show age-appropriate styles.")
                .font(.bmUI(15))
                .foregroundStyle(Color.bmTextDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reveal(appeared, offset: 26, blur: 8)
    }

    // MARK: - Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            BMSectionLabel(text: "Your name")
            BMFieldRow(
                icon: "person",
                placeholder: "First and last name",
                text: $name,
                contentType: .name,
                submitLabel: .done
            )
            .focused($nameFocused)
            .onSubmit { nameFocused = false }
        }
        .reveal(appeared, delay: 0.08)
    }

    // MARK: - Age

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            BMSectionLabel(text: "Your age")

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                    Text("\(age)")
                        .font(.bmDisplay(84, weight: .semibold))
                        .foregroundStyle(LinearGradient.bmGiltGradient)
                        .contentTransition(.numericText())
                        .animation(Motion.press, value: age)
                    Text("years")
                        .font(.bmUI(18, weight: .medium))
                        .foregroundStyle(Color.bmTextDim)
                }
                .padding(.top, Space.md)

                ZStack {
                    RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 44)
                        .padding(.horizontal, Space.lg)

                    Picker("Age", selection: $age) {
                        ForEach(range, id: \.self) { n in
                            Text("\(n)")
                                .font(.bmNum(22, weight: .semibold))
                                .foregroundStyle(Color.bmText)
                                .tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                    .clipped()
                    .onChange(of: age) { _, _ in Haptic.select() }
                }
            }
            .frame(maxWidth: .infinity)
            .bmCard(radius: Radius.card)
        }
        .reveal(appeared, delay: 0.14)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Space.sm) {
            if !isValid && !name.isEmpty {
                Text("You must be at least 13 to continue.")
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.bmBad)
            }

            BMPrimaryButton(
                title: saving ? "Saving…" : "Continue",
                icon: saving ? nil : "arrow.right",
                loading: saving
            ) {
                save()
            }
            .disabled(!isValid || saving)
            .opacity(isValid ? 1 : 0.4)
            .animation(Motion.subtle, value: isValid)
        }
        .reveal(appeared, delay: 0.2)
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }
        saving = true
        nameFocused = false
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
