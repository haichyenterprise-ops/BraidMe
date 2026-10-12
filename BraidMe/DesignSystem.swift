import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — "Obsidian Couture"
// =============================================================================

// MARK: - Color Palette

extension Color {
    fileprivate enum Palette {
        static let cream        = Color(hex: "#FAF8F5")
        static let pearl        = Color(hex: "#F2EEE8")
        static let linen        = Color(hex: "#E8E2D9")
        static let sand         = Color(hex: "#D4CCC0")

        static let onyx         = Color(hex: "#121218")
        static let graphite     = Color(hex: "#1A1A22")
        static let slate        = Color(hex: "#252530")
        static let steel        = Color(hex: "#3A3A48")
        static let void         = Color(hex: "#050507")

        static let ink          = Color(hex: "#0F0F12")
        static let charcoal     = Color(hex: "#2A2A32")
        static let pewter       = Color(hex: "#6B6B78")
        static let fog          = Color(hex: "#9A9AA5")

        static let goldSoft     = Color(hex: "#F2DFA0")
        static let goldLight    = Color(hex: "#E8C84A")
        static let gold         = Color(hex: "#C9A227")
        static let goldDeep     = Color(hex: "#8B7119")
        static let goldInk      = Color(hex: "#5C4A15")

        static let emerald      = Color(hex: "#34D399")
        static let ruby         = Color(hex: "#F87171")
        static let sapphire     = Color(hex: "#60A5FA")
        static let amethyst     = Color(hex: "#A78BFA")
    }

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

    static var appAsh: Color { appInkSecondary }
    static var appSmoke: Color { appInkTertiary }
    static var appInkInverse: Color { Palette.cream }

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

    static var appSignal: Color { Palette.emerald }
    static var appAlert: Color { Palette.ruby }
    static var appInfo: Color { Palette.sapphire }
    static var appPremium: Color { Palette.amethyst }

    static var goldSoft: Color { Palette.goldSoft }
    static var goldLight: Color { Palette.goldLight }
    static var gold: Color { Palette.gold }
    static var goldDeep: Color { Palette.goldDeep }
    static var goldInk: Color { Palette.goldInk }

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight, Palette.gold, Palette.goldDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldHairline: LinearGradient {
        LinearGradient(
            colors: [Palette.gold.opacity(0), Palette.gold, Palette.gold.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var goldRim: LinearGradient {
        LinearGradient(
            colors: [Palette.goldLight.opacity(0.9), Palette.gold.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
    static func bmSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func bmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
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
    static let chip:   CGFloat = 10
    static let button: CGFloat = 16
    static let card:   CGFloat = 24
    static let modal:  CGFloat = 36
    static let pill:   CGFloat = 999
    static let hero:   CGFloat = 32
    static let squircle: CGFloat = 20
}

// MARK: - Motion

enum Motion {
    static let navigation = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let sheet      = Animation.spring(response: 0.42, dampingFraction: 0.88)

    static let press      = Animation.spring(response: 0.25, dampingFraction: 0.75)
    static let reveal     = Animation.spring(response: 0.55, dampingFraction: 0.82)
    static let subtle     = Animation.easeOut(duration: 0.22)
    static let smooth     = Animation.easeInOut(duration: 0.35)
    static let bouncy     = Animation.spring(response: 0.35, dampingFraction: 0.65)
    static let slow       = Animation.easeInOut(duration: 0.6)

    static let morph      = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let expand     = Animation.spring(response: 0.38, dampingFraction: 0.65)
    static let collapse   = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let cardDrop   = Animation.spring(response: 0.5, dampingFraction: 0.78)
    static let cardMorph  = Animation.spring(response: 0.55, dampingFraction: 0.72)

    static let heroReveal = Animation.spring(response: 0.8, dampingFraction: 0.75)
    static let cameraFly  = Animation.smooth(duration: 0.9)

    static let shimmer    = Animation.linear(duration: 2.5).repeatForever(autoreverses: false)
    static let pulse      = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let breathe    = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    static let marquee    = Animation.linear(duration: 30).repeatForever(autoreverses: false)
    static let sheenLoop  = Animation.linear(duration: 2.5).repeatForever(autoreverses: false)

    static let staggerStep: Double = 0.05
    static func stagger(_ index: Int) -> Double { Double(index) * staggerStep }
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

struct BMSquirclePressStyle: ButtonStyle {
    var scale: CGFloat = 0.965
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.expand, value: configuration.isPressed)
    }
}

// MARK: - Haptics

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

// MARK: - Dual-Layer Glass Stroke

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

// MARK: - Shimmer

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

// MARK: - Glow

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

// MARK: - Noise Texture

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

// MARK: - Pulse Ring

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

// MARK: - Check Shape

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.80))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.20))
        return path
    }
}

// MARK: - Glass Background

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

// MARK: - Squircle Convenience

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

// =============================================================================
// MARK: - GLOBE TRANSITION (NEW)
// =============================================================================

/// Full-screen overlay that plays a spinning globe + warp + flash animation
/// when transitioning from the map to a braider profile.
struct GlobeTransitionOverlay: View {
    let isActive: Bool
    let targetName: String
    let targetInitials: String
    let targetRating: String
    let targetAvatarUrl: String
    let onComplete: () -> Void

    @State private var phase: Int = 0
    @State private var globeRotation: Double = 0
    @State private var globeScale: CGFloat = 0.3
    @State private var globeOpacity: Double = 0
    @State private var warpOpacity: Double = 0
    @State private var warpScale: CGFloat = 0.5
    @State private var flashOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.2
    @State private var avatarOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.4
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var starOpacity: Double = 0
    @State private var exitOpacity: Double = 1

    var body: some View {
        ZStack {
            // Deep space backdrop
            LinearGradient(
                colors: [
                    Color(hex: "#050507"),
                    Color(hex: "#0A0A15"),
                    Color(hex: "#050507")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(exitOpacity)

            // Warp lines radiating from center
            ForEach(0..<36, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gold.opacity(0),
                                Color.goldLight.opacity(0.9),
                                Color.gold.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.5, height: 260)
                    .offset(y: -180)
                    .rotationEffect(.degrees(Double(i) * 10))
                    .scaleEffect(warpScale, anchor: .bottom)
                    .opacity(warpOpacity)
                    .offset(y: -40)
            }

            // Orbital rings
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.goldLight.opacity(0.7),
                                Color.gold.opacity(0.2),
                                Color.goldDeep.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
                    .frame(
                        width: 240 + CGFloat(i) * 80,
                        height: 90 + CGFloat(i) * 30
                    )
                    .rotationEffect(.degrees(globeRotation * (i % 2 == 0 ? 1 : -1.3)))
                    .opacity(globeOpacity * 0.85)
                    .scaleEffect(globeScale)
            }

            // The globe — main element
            ZStack {
                // Globe base
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goldLight.opacity(0.35),
                                Color.gold.opacity(0.15),
                                Color(hex: "#0A0A15").opacity(0.9)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 260, height: 260)
                    .overlay(
                        // Latitude/longitude lines
                        ZStack {
                            ForEach(0..<7, id: \.self) { i in
                                Ellipse()
                                    .stroke(Color.gold.opacity(0.35), lineWidth: 0.8)
                                    .frame(width: 260, height: 40 + CGFloat(i) * 32)
                            }
                            ForEach(0..<4, id: \.self) { i in
                                Ellipse()
                                    .stroke(Color.gold.opacity(0.25), lineWidth: 0.6)
                                    .frame(width: 60 + CGFloat(i) * 60, height: 260)
                            }
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.goldLight.opacity(0.9),
                                        Color.gold.opacity(0.3),
                                        Color.goldDeep.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        // Specular highlight
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        .clear
                                    ],
                                    center: .init(x: 0.3, y: 0.25),
                                    startRadius: 0,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 260, height: 260)
                    )
                    .shadow(color: Color.gold.opacity(0.5), radius: 40)
                    .shadow(color: Color.goldLight.opacity(0.3), radius: 80)

                // Avatar medallion at center
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle().stroke(
                                LinearGradient(
                                    colors: [Color.goldLight, Color.gold, Color.goldDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                        )
                        .shadow(color: Color.gold.opacity(0.6), radius: 30)

                    if targetAvatarUrl.isEmpty {
                        Circle()
                            .fill(Color.gold.opacity(0.18))
                            .frame(width: 108, height: 108)
                            .overlay(
                                Text(targetInitials)
                                    .font(.system(size: 40, weight: .bold, design: .serif))
                                    .foregroundStyle(Color.gold)
                            )
                    } else {
                        RemoteImage(url: targetAvatarUrl)
                            .frame(width: 108, height: 108)
                            .clipShape(Circle())
                    }
                }
                .scaleEffect(avatarScale)
                .opacity(avatarOpacity)
            }
            .rotation3DEffect(
                .degrees(globeRotation * 0.4),
                axis: (x: 0.3, y: 1, z: 0.1),
                perspective: 0.6
            )
            .scaleEffect(globeScale)
            .opacity(globeOpacity)

            // Pulsing ring around the avatar
            Circle()
                .stroke(Color.goldLight.opacity(0.8), lineWidth: 2)
                .frame(width: 140, height: 140)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .stroke(Color.gold.opacity(0.5), lineWidth: 1.5)
                .frame(width: 140, height: 140)
                .scaleEffect(ringScale * 1.3)
                .opacity(ringOpacity * 0.6)

            // Text
            VStack(spacing: 8) {
                Text("ENTERING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(Color.gold)
                    .opacity(textOpacity)

                Text(targetName)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                    .offset(y: textOffset)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gold)
                    Text(targetRating)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .opacity(starOpacity)
                .offset(y: textOffset)
            }
            .offset(y: 200)

            // Flash
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(isActive)
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { _, active in
            if active { playSequence() }
            else { reset() }
        }
    }

    private func playSequence() {
        // Reset
        globeRotation = 0
        globeScale = 0.3
        globeOpacity = 0
        warpOpacity = 0
        warpScale = 0.5
        flashOpacity = 0
        avatarScale = 0.2
        avatarOpacity = 0
        ringScale = 0.4
        ringOpacity = 0
        textOpacity = 0
        textOffset = 20
        starOpacity = 0
        exitOpacity = 1

        // Phase 1: Warp burst (0.0 - 0.25s)
        withAnimation(.easeOut(duration: 0.35)) {
            warpOpacity = 1
            warpScale = 1.8
            globeOpacity = 0.3
        }

        // Phase 2: Globe appears + spins fast (0.15 - 0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                globeScale = 1
                globeOpacity = 1
                warpOpacity = 0.4
            }
            withAnimation(.linear(duration: 1.4)) {
                globeRotation = 720
            }
        }

        // Phase 3: Avatar medallion appears (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Haptic.medium()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                avatarScale = 1
                avatarOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) {
                ringScale = 1.9
                ringOpacity = 0
            }
        }

        // Phase 4: Text reveal (0.75s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            Haptic.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                starOpacity = 1
            }
        }

        // Phase 5: Flash (1.25s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            Haptic.heavy()
            withAnimation(.easeOut(duration: 0.15)) {
                flashOpacity = 0.85
            }
        }

        // Phase 6: Fade out (1.4s) + complete callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.35)) {
                flashOpacity = 0
                exitOpacity = 0
            }
        }

        // Complete — navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            onComplete()
        }
    }

    private func reset() {
        globeRotation = 0
        globeScale = 0.3
        globeOpacity = 0
        warpOpacity = 0
        warpScale = 0.5
        flashOpacity = 0
        avatarScale = 0.2
        avatarOpacity = 0
        ringScale = 0.4
        ringOpacity = 0
        textOpacity = 0
        textOffset = 20
        starOpacity = 0
        exitOpacity = 1
    }
}