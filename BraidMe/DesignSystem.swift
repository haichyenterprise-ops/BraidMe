import SwiftUI
import UIKit

struct AppTheme {

    // MARK: Core palette — warm editorial neutrals
    static let ink        = Color(hex: "#0A0D12")
    static let graphite   = Color(hex: "#161A21")
    static let slate      = Color(hex: "#59616E")
    static let stone      = Color(hex: "#8A929E")
    static let ash        = Color(hex: "#C4CAD2")
    static let hairline   = Color(hex: "#E5E8ED")
    static let mist       = Color(hex: "#F1F3F6")
    static let cloud      = Color(hex: "#F8F9FB")
    static let snow       = Color.white

    // Signature accents
    static let accent       = Color(hex: "#A96B3A")
    static let accentDeep   = Color(hex: "#7A4A22")
    static let accentLight  = Color(hex: "#D9A576")
    static let accentSoft   = Color(hex: "#F7EFE5")

    static let rose  = Color(hex: "#B86868")
    static let sage  = Color(hex: "#6F8069")
    static let gold  = Color(hex: "#C6A251")
    static let plum  = Color(hex: "#6B4E71")

    static let success = Color(hex: "#2F7A57")
    static let danger  = Color(hex: "#B63B3F")

    // Gradients
    static let inkGradient = LinearGradient(
        colors: [Color(hex: "#0A0D12"), Color(hex: "#1C222C")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let bronzeGradient = LinearGradient(
        colors: [Color(hex: "#B87A44"), Color(hex: "#7A4A22")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let bronzeSoft = LinearGradient(
        colors: [Color(hex: "#F7EFE5"), Color(hex: "#FBF6F0")],
        startPoint: .top, endPoint: .bottom
    )
    static let veil = LinearGradient(
        colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let fadeBottom = LinearGradient(
        stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black.opacity(0.15), location: 0.5),
            .init(color: .black.opacity(0.7), location: 0.9),
            .init(color: .black.opacity(0.9), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )
    static let fadeTop = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.55), location: 0.0),
            .init(color: .black.opacity(0.1), location: 0.6),
            .init(color: .clear, location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    // Type helpers
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // Spacing
    static let gut: CGFloat = 20
    static let radius: CGFloat = 22
    static let pill: CGFloat = 14
}

// MARK: - Hex

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
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft()    { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func rigid()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func heavy()   { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Button styles

struct SoftPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct BouncyPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct CardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var loading: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                    Text(title).font(AppTheme.sans(17, weight: .semibold))
                }
                .opacity(loading ? 0 : 1)
                if loading { ProgressView().tint(.white) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.inkGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: AppTheme.ink.opacity(0.28), radius: 18, y: 10)
        }
        .buttonStyle(SoftPress())
        .disabled(loading)
    }
}

struct BronzeButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(AppTheme.sans(17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.bronzeGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: AppTheme.accent.opacity(0.4), radius: 20, y: 10)
        }
        .buttonStyle(SoftPress())
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(AppTheme.sans(17, weight: .semibold))
            }
            .foregroundColor(AppTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.snow)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SoftPress())
    }
}

// MARK: - Card chrome

struct CardChrome: ViewModifier {
    var radius: CGFloat = AppTheme.radius
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(elevated ? 0.055 : 0.02),
                radius: elevated ? 20 : 6,
                x: 0,
                y: elevated ? 8 : 2
            )
    }
}

extension View {
    func cardChrome(radius: CGFloat = AppTheme.radius, elevated: Bool = true) -> some View {
        modifier(CardChrome(radius: radius, elevated: elevated))
    }
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundCorners(radius: radius, corners: corners))
    }
}

struct RoundCorners: Shape {
    var radius: CGFloat = 16
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let p = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(p.cgPath)
    }
}

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.2
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 500)
                .blendMode(.overlay)
                .allowsHitTesting(false)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Reusable atoms

struct GlassChip: View {
    var icon: String? = nil
    var title: String
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            Text(title).font(AppTheme.sans(12, weight: .semibold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}

struct StarRow: View {
    let rating: Double
    var size: CGFloat = 11
    var color: Color = AppTheme.gold

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: Double(i) < rating.rounded() ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(color)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.sans(11, weight: .bold))
            .tracking(1.4)
            .foregroundColor(AppTheme.stone)
            .padding(.horizontal, 4)
    }
}

struct Pill: View {
    let icon: String?
    let text: String
    var fg: Color = AppTheme.ink
    var bg: Color = AppTheme.mist

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(AppTheme.sans(12, weight: .medium))
        }
        .foregroundColor(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(bg, in: Capsule())
    }
}

struct IconButton: View {
    let icon: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 16
    var fg: Color = .white
    var bg: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.soft()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(fg)
                .frame(width: size, height: size)
                .background(
                    Group {
                        if let bg { bg }
                        else { Color.clear.background(.ultraThinMaterial) }
                    }
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(BouncyPress())
    }
}