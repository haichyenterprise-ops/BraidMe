import SwiftUI

// MARK: - Palette

struct AppTheme {
    // Core neutrals — warm, editorial, expensive-feeling
    static let ink       = Color(hex: "#0B0F14")   // deepest text
    static let graphite  = Color(hex: "#1C2128")
    static let slate     = Color(hex: "#5A6470")
    static let stone     = Color(hex: "#8892A0")
    static let hairline  = Color(hex: "#E3E6EB")
    static let mist      = Color(hex: "#F3F5F7")
    static let cloud     = Color(hex: "#FAFBFC")
    static let snow      = Color.white

    // Signature accent — warm bronze / burnished amber
    static let accent       = Color(hex: "#B8763E")
    static let accentDeep   = Color(hex: "#8C5628")
    static let accentSoft   = Color(hex: "#F6EEE5")

    // Secondary accents
    static let rose      = Color(hex: "#C97C7C")
    static let sage      = Color(hex: "#7A8B7A")
    static let gold      = Color(hex: "#C9A961")

    // System
    static let success = Color(hex: "#2F7A57")
    static let danger  = Color(hex: "#B8383D")

    // Gradients
    static let inkGradient = LinearGradient(
        colors: [Color(hex: "#0B0F14"), Color(hex: "#1C2128")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let bronzeGradient = LinearGradient(
        colors: [Color(hex: "#B8763E"), Color(hex: "#8C5628")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let bronzeSoftGradient = LinearGradient(
        colors: [Color(hex: "#F6EEE5"), Color(hex: "#FDFAF6")],
        startPoint: .top, endPoint: .bottom
    )
    static let glassOverlay = LinearGradient(
        colors: [Color.white.opacity(0.15), Color.white.opacity(0.02)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // Type scale — serif headline for editorial feel
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static func title(_ size: CGFloat) -> Font   { .system(size: size, weight: .bold, design: .default) }
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .default) }
    static func body(_ size: CGFloat) -> Font    { .system(size: size, weight: .regular, design: .default) }
    static func mono(_ size: CGFloat) -> Font    { .system(size: size, weight: .medium, design: .monospaced) }

    // Spacing
    static let gut: CGFloat = 20   // page gutter
    static let cardRadius: CGFloat = 22
    static let pillRadius: CGFloat = 14
}

// MARK: - Color hex

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

// MARK: - Haptics

enum Haptics {
    static func tap()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func rigid()  { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success(){ UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning(){ UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Button styles

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            ZStack {
                HStack(spacing: 8) {
                    if let icon = systemImage {
                        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                    }
                    Text(title).font(.system(size: 17, weight: .semibold))
                }
                .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.inkGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.ink.opacity(0.25), radius: 16, y: 8)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = systemImage {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(.system(size: 17, weight: .semibold))
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
        .buttonStyle(SoftPressStyle())
    }
}

struct BronzeButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon = systemImage {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppTheme.bronzeGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 18, y: 8)
        }
        .buttonStyle(SoftPressStyle())
    }
}

// MARK: - Card modifier

struct CardBackground: ViewModifier {
    var radius: CGFloat = AppTheme.cardRadius
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .background(AppTheme.snow)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppTheme.hairline.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(
                color: Color.black.opacity(elevated ? 0.05 : 0.02),
                radius: elevated ? 16 : 6,
                x: 0,
                y: elevated ? 6 : 2
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = AppTheme.cardRadius, elevated: Bool = true) -> some View {
        modifier(CardBackground(radius: radius, elevated: elevated))
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Shimmer

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .rotationEffect(.degrees(10))
                .offset(x: phase * 400)
                .blendMode(.overlay)
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Glass chip

struct GlassChip: View {
    let icon: String?
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            }
            Text(title).font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}