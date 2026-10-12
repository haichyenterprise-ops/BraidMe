import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — "Obsidian Couture"
//
// Foundation for the entire app. Every color, font, spacing token, motion
// curve, haptic pattern, and shared modifier lives here. Waves 1–6 were
// built against this exact API surface.
// =============================================================================

// ═══════════════════════════════════════════════════════════════════
// MARK: - Color Palette
// ═══════════════════════════════════════════════════════════════════

extension Color {
    fileprivate enum Palette {
        // ─── Light neutrals ───
        static let cream        = Color(hex: "#FAF8F5")
        static let pearl        = Color(hex: "#F2EEE8")
        static let linen        = Color(hex: "#E8E2D9")
        static let sand         = Color(hex: "#D4CCC0")

        // ─── Dark neutrals ───
        static let onyx         = Color(hex: "#121218")
        static let graphite     = Color(hex: "#1A1A22")
        static let slate        = Color(hex: "#252530")
        static let steel        = Color(hex: "#3A3A48")
        static let void         = Color(hex: "#050507")

        // ─── Text hierarchy ───
        static let ink          = Color(hex: "#0F0F12")
        static let charcoal     = Color(hex: "#2A2A32")
        static let pewter       = Color(hex: "#6B6B78")
        static let fog          = Color(hex: "#9A9AA5")

        // ─── Gold scale ───
        static let goldSoft     = Color(hex: "#F2DFA0")
        static let goldLight    = Color(hex: "#E8C84A")
        static let gold         = Color(hex: "#C9A227")
        static let goldDeep     = Color(hex: "#8B7119")
        static let goldInk      = Color(hex: "#5C4A15")

        // ─── Semantic ───
        static let emerald      = Color(hex: "#34D399")
        static let ruby         = Color(hex: "#F87171")
        static let sapphire     = Color(hex: "#60A5FA")
        static let amethyst     = Color(hex: "#A78BFA")
    }

    // ─── Adaptive surfaces ───
    static var appBackground: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.onyx) : UIColor(Palette.cream) })
    }
    static var appSurface: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.graphite) : UIColor.white })
    }
    static var appSurfaceElevated: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.slate) : UIColor(Palette.pearl) })
    }
    static var appSurfaceInverse: Color { Palette.onyx }

    // ─── Adaptive text ───
    static var appInk: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.cream) : UIColor(Palette.ink) })
    }
    static var appInkSecondary: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.sand) : UIColor(Palette.charcoal) })
    }
    static var appInkTertiary: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.fog) : UIColor(Palette.pewter) })
    }
    static var appDivider: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.slate) : UIColor(Palette.linen) })
    }

    // ─── Legacy aliases ───
    static var appAsh: Color { appInkSecondary }
    static var appSmoke: Color { appInkTertiary }
    static var appInkInverse: Color { Palette.cream }

    // ─── Gold accent system ───
    static var appAccent: Color { Palette.gold }
    static var appAccentSoft: Color { Palette.goldLight }
    static var appAccentDeep: Color { Palette.goldDeep }
    static var appAccentTint: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.gold).withAlphaComponent(0.16)
            : UIColor(Palette.gold).withAlphaComponent(0.10) })
    }
    static var appAccentGlow: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.goldLight).withAlphaComponent(0.35)
            : UIColor(Palette.gold).withAlphaComponent(0.25) })
    }

    // ─── Semantic shortcuts ───
    static var appSignal: Color { Palette.emerald }
    static var appAlert: Color { Palette.ruby }
    static var appInfo: Color { Palette.sapphire }
    static var appPremium: Color { Palette.amethyst }

    // ─── Direct gold accessors ───
    static var goldSoft: Color { Palette.goldSoft }
    static var goldLight: Color { Palette.goldLight }
    static var gold: Color { Palette.gold }
    static var goldDeep: Color { Palette.goldDeep }
    static var goldInk: Color { Palette.goldInk }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Blur-free glass tints (performance)
    // ═══════════════════════════════════════════════════════════════

    /// Cheap alternative to `.ultraThinMaterial` — same visual, no GPU blur cost.
    static var glassTint: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.graphite).withAlphaComponent(0.72)
            : UIColor.white.withAlphaComponent(0.82) })
    }
    /// Cheap alternative to `.regularMaterial`.
    static var glassTintStrong: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.slate).withAlphaComponent(0.88)
            : UIColor.white.withAlphaComponent(0.94) })
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Gradients
    // ═══════════════════════════════════════════════════════════════

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gold hairline for section dividers — bright in center, transparent at edges.
    static var goldHairline: LinearGradient {
        LinearGradient(
            colors: [Palette.gold.opacity(0), Palette.gold, Palette.gold.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Gold rim for outlined cards.
    static var goldRim: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight.opacity(0.9), Palette.gold.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Moving gold sheen — used on shimmer overlays.
    static var goldSweep: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Palette.gold.opacity(0), location: 0.0),
                .init(color: Palette.goldLight.opacity(0.6), location: 0.5),
                .init(color: Palette.gold.opacity(0), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var darkGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.onyx, Palette.void],
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

    /// 5-stop cinematic veil used on hero images.
    static var heroVeil: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.55), location: 0.00),
                .init(color: .clear,                location: 0.30),
                .init(color: .black.opacity(0.10), location: 0.55),
                .init(color: .black.opacity(0.78), location: 0.85),
                .init(color: .black.opacity(0.98), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Hex init
    // ═══════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Typography
// ═══════════════════════════════════════════════════════════════════

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
    static func bmSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func bmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Spacing
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Radius
// ═══════════════════════════════════════════════════════════════════

enum Radius {
    static let chip:     CGFloat = 10
    static let button:   CGFloat = 16
    static let card:     CGFloat = 24
    static let modal:    CGFloat = 36
    static let pill:     CGFloat = 999
    static let hero:     CGFloat = 32
    static let squircle: CGFloat = 20
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Motion
// ═══════════════════════════════════════════════════════════════════

enum Motion {
    // Navigation & sheets
    static let navigation = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let sheet      = Animation.spring(response: 0.42, dampingFraction: 0.88)

    // Interactions
    static let press      = Animation.spring(response: 0.25, dampingFraction: 0.75)
    static let reveal     = Animation.spring(response: 0.55, dampingFraction: 0.82)
    static let subtle     = Animation.easeOut(duration: 0.22)
    static let smooth     = Animation.easeInOut(duration: 0.35)
    static let bouncy     = Animation.spring(response: 0.35, dampingFraction: 0.65)
    static let slow       = Animation.easeInOut(duration: 0.6)

    // Physical dynamics
    static let morph      = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let expand     = Animation.spring(response: 0.38, dampingFraction: 0.65)
    static let collapse   = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let cardDrop   = Animation.spring(response: 0.5, dampingFraction: 0.78)
    static let cardMorph  = Animation.spring(response: 0.55, dampingFraction: 0.72)

    // Hero
    static let heroReveal = Animation.spring(response: 0.8, dampingFraction: 0.75)
    static let cameraFly  = Animation.smooth(duration: 0.9)

    // Loops
    static let shimmer    = Animation.linear(duration: 2.5).repeatForever(autoreverses: false)
    static let pulse      = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let breathe    = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    static let marquee    = Animation.linear(duration: 30).repeatForever(autoreverses: false)
    static let sheenLoop  = Animation.linear(duration: 2.5).repeatForever(autoreverses: false)

    // Stagger
    static let staggerStep: Double = 0.05
    static func stagger(_ index: Int) -> Double { Double(index) * staggerStep }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Adaptive Animation Modifier
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Haptics
// ═══════════════════════════════════════════════════════════════════

enum Haptic {
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func press()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()   { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func rigid()   { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Dual-Layer Glass Stroke
// ═══════════════════════════════════════════════════════════════════

struct DualLayerGlassStroke: ViewModifier {
    var cornerRadius: CGFloat = Radius.card
    var lineWidth: CGFloat = 0.8
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goldLight.opacity(colorScheme == .dark ? 0.55 : 0.75),
                            Color.gold.opacity(colorScheme == .dark ? 0.35 : 0.45),
                            Color.goldDeep.opacity(colorScheme == .dark ? 0.20 : 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
        )
    }
}

extension View {
    func dualLayerGlassStroke(cornerRadius: CGFloat = Radius.card, lineWidth: CGFloat = 0.8) -> some View {
        modifier(DualLayerGlassStroke(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Shimmer Modifier
// ═══════════════════════════════════════════════════════════════════

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.4), .clear],
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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Glow Modifier
// ═══════════════════════════════════════════════════════════════════

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - Noise Texture
// ═══════════════════════════════════════════════════════════════════

struct NoiseTexture: View {
    var opacity: Double = 0.03
    var seed: UInt64 = 42

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            let count = Int(size.width * size.height / 180)
            for _ in 0..<count {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Seeded RNG
// ═══════════════════════════════════════════════════════════════════

/// Deterministic RNG so noise and star fields are stable across re-renders.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Animated Gradient Border
// ═══════════════════════════════════════════════════════════════════

struct AnimatedGradientBorder: View {
    var cornerRadius: CGFloat = Radius.card
    var lineWidth: CGFloat = 1.5
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: [
                        Color.gold.opacity(0.08),
                        Color.goldLight.opacity(0.85),
                        Color.gold.opacity(0.25),
                        Color.goldDeep.opacity(0.6),
                        Color.gold.opacity(0.08)
                    ],
                    center: .center,
                    angle: .degrees(rotation)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pulse Ring
// ═══════════════════════════════════════════════════════════════════

struct PulseRing: View {
    var color: Color = .gold
    var size: CGFloat = 60
    var duration: Double = 1.8
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.7

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) {
                    scale = 2.0
                    opacity = 0
                }
            }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Glass Background
// ═══════════════════════════════════════════════════════════════════

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
                                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.65),
                                Color.white.opacity(colorScheme == .dark ? 0.06 : 0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Squircle Convenience
// ═══════════════════════════════════════════════════════════════════

extension View {
    func bmSquircle(_ radius: CGFloat = Radius.card) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func bmCouturePanel(_ radius: CGFloat = Radius.card) -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .dualLayerGlassStroke(cornerRadius: radius)
    }
}