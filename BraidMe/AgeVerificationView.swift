import SwiftUI

struct AgeVerificationView: View {
    let user: ContentView.PendingUser
    var onConfirm: () -> Void

    @State private var age: Int = 22
    @State private var appeared = false
    @State private var saving = false
    @State private var errorMessage: String?

    private let range = Array(13...90)
    private var isValid: Bool { age >= 13 }

    var body: some View {
        ZStack {
            AppTheme.cloud.ignoresSafeArea()
            ambient

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                header
                Spacer().frame(height: 44)
                bigNumber
                Spacer().frame(height: 8)
                wheelPicker
                Spacer()

                footer
            }
            .padding(.horizontal, 26)
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

    // MARK: - Ambient background

    private var ambient: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.accent.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 260
                ))
                .frame(width: 520, height: 520)
                .blur(radius: 50)
                .offset(x: -140, y: -220)
                .opacity(appeared ? 1 : 0)

            Circle()
                .fill(RadialGradient(
                    colors: [AppTheme.plum.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 220
                ))
                .frame(width: 460, height: 460)
                .blur(radius: 60)
                .offset(x: 160, y: 260)
                .opacity(appeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 1.2), value: appeared)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                Text("STEP 2 OF 3")
                    .font(AppTheme.sans(11, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(AppTheme.accentDeep)
            }

            Text("How old\nare you?")
                .font(AppTheme.serif(42))
                .lineSpacing(-4)
                .foregroundColor(AppTheme.ink)

            Text("This helps us personalise your feed and keep everyone safe.")
                .font(AppTheme.sans(15))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(4)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .animation(.spring(response: 0.85, dampingFraction: 0.85), value: appeared)
    }

    // MARK: - Big number

    private var bigNumber: some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text("\(age)")
                .font(.system(size: 96, weight: .bold, design: .serif))
                .foregroundColor(AppTheme.ink)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: age)

            Text("years")
                .font(AppTheme.sans(20, weight: .medium))
                .foregroundColor(AppTheme.slate)
                .padding(.bottom, 20)
        }
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.05), value: appeared)
    }

    // MARK: - Picker

    private var wheelPicker: some View {
        ZStack {
            // Selection indicator
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accentSoft)
                .frame(height: 46)
                .padding(.horizontal, 40)

            Picker("Age", selection: $age) {
                ForEach(range, id: \.self) { n in
                    Text("\(n)").tag(n)
                        .font(AppTheme.sans(22, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 180)
            .clipped()
            .onChange(of: age) { _, _ in Haptics.select() }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1), value: appeared)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if !isValid {
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
        .padding(.bottom, 30)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15), value: appeared)
    }

    // MARK: - Save

    private func save() {
        guard isValid else { return }
        saving = true
        Haptics.medium()

        Task {
            // Always store locally first
            UserDefaults.standard.set(age, forKey: "userAge")
            UserDefaults.standard.set(user.uid, forKey: "currentUid")

            // Try Firestore — but don't block the user if it fails
            if user.provider != "guest" {
                do {
                    try await FirebaseManager.shared.db
                        .collection("users")
                        .document(user.uid)
                        .setData([
                            "age": age,
                            "ageConfirmedAt": Date(),
                            "displayName": user.displayName,
                            "email": user.email as Any,
                            "provider": user.provider
                        ], merge: true)
                } catch {
                    print("[Age] Firestore write failed:", error)
                }
            }

            await MainActor.run {
                saving = false
                Haptics.success()
                onConfirm()
            }
        }
    }

    private func startEntrance() {
        withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.1)) {
            appeared = true
        }
    }
}