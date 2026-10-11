import SwiftUI

struct AgeVerificationView: View {
    @State private var age: Int = 22
    @State private var appeared = false
    var onConfirm: () -> Void

    private let ageRange = Array(13...80)
    private var isValid: Bool { age >= 13 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            header
            Spacer().frame(height: 40)
            picker
            Spacer()

            cta
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How old are you?")
                .font(AppTheme.display(34))
                .foregroundColor(AppTheme.ink)
            Text("We use this to personalise your experience and keep BraidMe safe.")
                .font(AppTheme.body(15))
                .foregroundColor(AppTheme.slate)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private var picker: some View {
        VStack(spacing: 20) {
            HStack(spacing: 6) {
                Text("\(age)")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.ink)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: age)
                Text("years")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppTheme.slate)
                    .padding(.top, 30)
            }

            Picker("Age", selection: $age) {
                ForEach(ageRange, id: \.self) { n in
                    Text("\(n)").tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)
            .clipped()
            .onChange(of: age) { _, _ in Haptics.select() }

            if !isValid {
                Text("You must be at least 13 to continue.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.danger)
            }
        }
        .padding(.horizontal, 28)
        .opacity(appeared ? 1 : 0)
    }

    private var cta: some View {
        PrimaryButton(title: "Continue") {
            UserDefaults.standard.set(age, forKey: "userAge")
            onConfirm()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .opacity(isValid ? 1 : 0.4)
        .disabled(!isValid)
    }
}