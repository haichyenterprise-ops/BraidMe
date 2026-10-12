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

    private let range = Array(13...90)

    private var isNameValid: Bool {
        !needsName || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isValid: Bool { isNameValid && age >= 13 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

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
                    Spacer().frame(height: Space.xl)
                }
            }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("SETUP · STEP 2 OF 2")
                .font(.bmUI(11, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(Color.appAccent)

            Text(needsName ? "A little\nabout you." : "How old\nare you?")
                .font(.bmDisplay(40, weight: .semibold))
                .lineSpacing(-4)
                .foregroundStyle(Color.appInk)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(needsName
                 ? "We'll use this to personalise your feed and match you with the right braiders."
                 : "This helps us keep BraidMe safe and shows age-appropriate styles.")
                .font(.bmUI(15))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal, value: appeared)
    }

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
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal.delay(0.05), value: appeared)
    }

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BMSectionLabel(text: "Your age")

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                    Text("\(age)")
                        .font(.bmDisplay(72, weight: .semibold))
                        .foregroundStyle(Color.appInk)
                        .contentTransition(.numericText())
                        .animation(Motion.press, value: age)

                    Text("years")
                        .font(.bmUI(18, weight: .medium))
                        .foregroundStyle(Color.appAsh)
                        .padding(.bottom, 12)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: Radius.button)
                        .fill(Color.appAccentTint)
                        .frame(height: 44)
                        .padding(.horizontal, Space.lg)

                    Picker("Age", selection: $age) {
                        ForEach(range, id: \.self) { n in
                            Text("\(n)").tag(n)
                                .font(.bmUI(22, weight: .semibold))
                                .foregroundStyle(Color.appInk)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 170)
                    .clipped()
                    .onChange(of: age) { _, _ in Haptic.select() }
                }
            }
            .padding(.vertical, Space.xxs)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal.delay(0.10), value: appeared)
    }

    private var footer: some View {
        VStack(spacing: Space.sm) {
            if !isValid && !name.isEmpty {
                Text("You must be at least 13 to continue.")
                    .font(.bmUI(13, weight: .medium))
                    .foregroundStyle(Color.appAlert)
            }

            BMPrimaryButton(
                title: saving ? "Saving…" : "Continue",
                loading: saving
            ) {
                save()
            }
            .disabled(!isValid || saving)
            .opacity(isValid ? 1 : 0.4)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animate(Motion.reveal.delay(0.15), value: appeared)
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