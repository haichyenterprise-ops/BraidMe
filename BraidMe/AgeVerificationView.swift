import SwiftUI

struct AgeVerificationView: View {
    @State private var age: String = ""
    @State private var isValid = false
    var onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How old are you?")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.ink)
                
                Text("This helps us tailor your experience.")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.slate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            
            Spacer().frame(height: 40)
            
            VStack(spacing: 8) {
                TextField("Age", text: $age)
                    .keyboardType(.numberPad)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 20)
                    .background(AppTheme.snow)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isValid ? AppTheme.accent : AppTheme.hairline, lineWidth: isValid ? 1.5 : 1)
                    )
                    .onChange(of: age) { _, newValue in
                        isValid = (Int(newValue) ?? 0) >= 13
                    }
                
                if !age.isEmpty && !isValid {
                    Text("You must be at least 13.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.danger)
                }
            }
            .padding(.horizontal, 28)
            
            Spacer()
            
            PrimaryButton(title: "Continue", action: {
                UserDefaults.standard.set(age, forKey: "userAge")
                onConfirm()
            })
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
            .opacity(isValid ? 1 : 0.4)
            .disabled(!isValid)
        }
        .background(AppTheme.cloud.ignoresSafeArea())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}