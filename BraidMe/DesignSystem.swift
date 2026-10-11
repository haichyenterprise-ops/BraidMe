import SwiftUI

struct AppTheme {
    // Neutral premium palette
    static let ink = Color(hex: "#0F1419")            // near-black text
    static let slate = Color(hex: "#536471")          // secondary text
    static let mist = Color(hex: "#EFF3F4")           // light bg
    static let cloud = Color(hex: "#F7F9F9")          // card bg
    static let snow = Color.white
    static let hairline = Color(hex: "#CFD9DE")       // borders
    
    // Single accent — warm bronze/terracotta, feels upscale
    static let accent = Color(hex: "#8B5A3C")
    static let accentSoft = Color(hex: "#F2E8E1")
    
    // Subtle success/danger
    static let success = Color(hex: "#2D6A4F")
    static let danger = Color(hex: "#B91C1C")
    
    // Typography scale
    static let titleFont = Font.system(size: 32, weight: .bold, design: .serif)
    static let headerFont = Font.system(size: 22, weight: .semibold, design: .default)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 13, weight: .medium, design: .default)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Primary Button (casual, professional)
struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        }) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppTheme.snow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
    }
}

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Card
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardModifier()) }
}