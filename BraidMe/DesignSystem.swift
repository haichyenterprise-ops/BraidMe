import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — "Obsidian" Premium Edition
// A luxurious, high-tech visual language inspired by high-end fashion & tech
// =============================================================================

// MARK: - Color Palette

extension Color {
    fileprivate enum Palette {
        // Core neutrals — deep, rich, sophisticated
        static let void         = Color(hex: "#050507")      // Deepest black
        static let obsidian     = Color(hex: "#0A0A0D")      // Primary dark
        static let onyx         = Color(hex: "#121218")      // Elevated surface
        static let graphite     = Color(hex: "#1A1A22")      // Card surface
        static let slate        = Color(hex: "#252530")      // Borders/dividers
        static let steel        = Color(hex: "#3A3A48")      // Muted elements
        
        // Light neutrals — warm, editorial
        static let cream        = Color(hex: "#FAF8F5")      // Primary light bg
        static let pearl        = Color(hex: "#F2EEE8")      // Secondary light
        static let linen        = Color(hex: "#E8E2D9")      // Tertiary light
        static let sand         = Color(hex: "#D4CCC0")      // Muted light
        
        // Text hierarchy
        static let ink          = Color(hex: "#0F0F12")      // Primary text (light mode)
        static let charcoal     = Color(hex: "#2A2A32")      // Secondary text
        static let pewter       = Color(hex: "#6B6B78")      // Tertiary text
        static let fog          = Color(hex: "#9A9AA5")      // Quaternary text
        
        // Accent — molten gold with depth
        static let gold         = Color(hex: "#C9A227")      // Primary accent
        static let goldLight    = Color(hex: "#E8C84A")      // Light accent
        static let goldDeep     = Color(hex: "#8B7119")      // Deep accent
        static let amber        = Color(hex: "#D4A84B")      // Warm accent
        
        // Semantic
        static let emerald      = Color(hex: "#34D399")      // Success
        static let ruby         = Color(hex: "#F87171")      // Error
        static let sapphire     = Color(hex: "#60A5FA")      // Info
        static let amethyst     = Color(hex: "#A78BFA")      // Premium
    }
    
    // Adaptive colors
    static var appBackground: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.void) : UIColor(Palette.cream) })
    }
    static var appSurface: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.onyx) : UIColor.white })
    }
    static var appSurfaceElevated: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.graphite) : UIColor(Palette.pearl) })
    }
    static var appInk: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.cream) : UIColor(Palette.ink) })
    }
    static var appInkSecondary: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.sand) : UIColor(Palette.charcoal) })
    }
    static var appInkTertiary: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.pewter) : UIColor(Palette.pewter) })
    }
    static var appDivider: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.slate) : UIColor(Palette.linen) })
    }
    
    // Legacy aliases for compatibility
    static var appAsh: Color { appInkSecondary }
    static var appSmoke: Color { appInkTertiary }
    static var appInkInverse: Color { Palette.cream }
    static var appSurfaceInverse: Color { Palette.obsidian }
    
    // Accent system
    static var appAccent: Color { Palette.gold }
    static var appAccentSoft: Color { Palette.goldLight }
    static var appAccentDeep: Color { Palette.goldDeep }
    static var appAccentTint: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.gold).withAlphaComponent(0.15)
            : UIColor(Palette.gold).withAlphaComponent(0.10) })
    }
    static var appAccentGlow: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.gold).withAlphaComponent(0.35)
            : UIColor(Palette.gold).withAlphaComponent(0.25) })
    }
    
    // Semantic
    static var appSignal: Color { Palette.emerald }
    static var appAlert: Color { Palette.ruby }
    static var appInfo: Color { Palette.sapphire }
    static var appPremium: Color { Palette.amethyst }
    
    // Gradients
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var darkGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.obsidian, Palette.void],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.graphite) : UIColor.white }),
                Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.onyx) : UIColor(Palette.pearl) })
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Typography

extension Font {
    static func bmDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func bmUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func bmMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func bmHero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

// MARK: - Spacing

enum Space {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let huge: CGFloat = 96
}

// MARK: - Radius

enum Radius {
    static let chip:   CGFloat = 8
    static let button: CGFloat = 16
    static let card:   CGFloat = 24
    static let modal:  CGFloat = 36
    static let pill:   CGFloat = 999
    static let hero:   CGFloat = 32
}

// MARK: - Motion

enum Motion {
    static let navigation = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let press      = Animation.spring(response: 0.25, dampingFraction: 0.75)
    static let reveal     = Animation.spring(response: 0.55, dampingFraction: 0.82)
    static let sheet      = Animation.spring(response: 0.42, dampingFraction: 0.88)
    static let subtle     = Animation.easeOut(duration: 0.22)
    static let smooth     = Animation.easeInOut(duration: 0.35)
    static let bouncy     = Animation.spring(response: 0.35, dampingFraction: 0.65)
    static let slow       = Animation.easeInOut(duration: 0.6)
    
    // Stagger timing
    static let staggerStep: Double = 0.05
    static func stagger(_ index: Int) -> Double { Double(index) * staggerStep }
    
    // Hero animations
    static let heroReveal = Animation.spring(response: 0.8, dampingFraction: 0.75)
    static let shimmer    = Animation.linear(duration: 1.8).repeatForever(autoreverses: false)
    static let pulse      = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let breathe    = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)
}

// MARK: - Adaptive Animation

struct AdaptiveAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.subtle : animation, value: value)
    }
}

extension View {
    func animate<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AdaptiveAnimation(animation: animation, value: value))
    }
}

// MARK: - Button Styles

struct BMPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.04
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -dim : 0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct BMIconPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct BMGlowPressStyle: ButtonStyle {
    var glowColor: Color = .appAccent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .shadow(
                color: glowColor.opacity(configuration.isPressed ? 0.5 : 0.3),
                radius: configuration.isPressed ? 8 : 16,
                y: configuration.isPressed ? 2 : 6
            )
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Haptics

enum Haptic {
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func press()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()   { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: reduceMotion ? 0 : phase * geo.size.width * 1.6)
                    .blendMode(.overlay)
                }
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.shimmer) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Glow Effect

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat
    var intensity: Double
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius * 0.5, y: radius * 0.25)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius, y: radius * 0.5)
    }
}

extension View {
    func glow(color: Color = .appAccent, radius: CGFloat = 20, intensity: Double = 0.4) -> some View {
        modifier(GlowModifier(color: color, radius: radius, intensity: intensity))
    }
}

// MARK: - Glass Effect

struct GlassBackground: View {
    var cornerRadius: CGFloat = Radius.card
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Noise Texture

struct NoiseTexture: View {
    var opacity: Double = 0.03
    
    var body: some View {
        Canvas { context, size in
            for _ in 0..<Int(size.width * size.height / 100) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Gradient Border

struct AnimatedGradientBorder: View {
    var cornerRadius: CGFloat = Radius.card
    var lineWidth: CGFloat = 1.5
    @State private var rotation: Double = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        Color.appAccent.opacity(0.1),
                        Color.appAccent.opacity(0.8),
                        Color.appAccentSoft.opacity(0.3),
                        Color.appAccent.opacity(0.8),
                        Color.appAccent.opacity(0.1)
                    ],
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Pulse Ring

struct PulseRing: View {
    var color: Color = .appAccent
    var size: CGFloat = 60
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    scale = 1.8
                    opacity = 0
                }
            }
    }
}