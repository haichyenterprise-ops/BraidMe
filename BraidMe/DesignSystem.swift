import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — "Night Salon"
//
// Aubergine-night surfaces, gilt / orchid / ember accents, New York serif
// display type, SF Rounded numerals. The signature element is the living
// three-strand braid (BraidMark) that appears on splash, loaders and progress.
// =============================================================================

// MARK: - Color

extension Color {
    static let bmDeep      = Color(hex: "#0B0712")
    static let bmBase      = Color(hex: "#130D1D")
    static let bmSurface   = Color(hex: "#1C1428")
    static let bmRaised    = Color(hex: "#271D37")
    static let bmLine      = Color.white.opacity(0.09)

    static let bmText      = Color(hex: "#F7F1FB")
    static let bmTextDim   = Color(hex: "#B5A9C6")
    static let bmTextFaint = Color(hex: "#7E7192")

    static let bmGiltHi    = Color(hex: "#FFE2AE")
    static let bmGilt      = Color(hex: "#F1BF79")
    static let bmGiltLo    = Color(hex: "#D38E45")
    static let bmOrchid    = Color(hex: "#B38DFF")
    static let bmEmber     = Color(hex: "#FF7D6C")
    static let bmGood      = Color(hex: "#5BD9A3")
    static let bmBad       = Color(hex: "#FF6B7B")
    static let bmOnGilt    = Color(hex: "#23132D")

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

extension LinearGradient {
    static var bmGiltGradient: LinearGradient {
        LinearGradient(
            colors: [Color.bmGiltHi, Color.bmGilt, Color.bmGiltLo],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static var bmBraidGradient: LinearGradient {
        LinearGradient(
            colors: [Color.bmGilt, Color.bmEmber, Color.bmOrchid],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    static var bmNightGradient: LinearGradient {
        LinearGradient(
            colors: [Color.bmBase, Color.bmDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Type

extension Font {
    static func bmDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func bmUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func bmNum(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - Spacing / radius

enum Space {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

enum Radius {
    static let chip:   CGFloat = 10
    static let button: CGFloat = 18
    static let card:   CGFloat = 24
    static let modal:  CGFloat = 36
    static let pill:   CGFloat = 999
}

// MARK: - Motion

enum Motion {
    static let navigation = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let press      = Animation.spring(response: 0.30, dampingFraction: 0.72)
    static let reveal     = Animation.spring(response: 0.75, dampingFraction: 0.82)
    static let sheet      = Animation.spring(response: 0.50, dampingFraction: 0.84)
    static let pop        = Animation.spring(response: 0.38, dampingFraction: 0.50)
    static let subtle     = Animation.easeOut(duration: 0.20)

    static let staggerStep: Double = 0.055
    static func stagger(_ index: Int) -> Double { Double(min(index, 10)) * staggerStep }
}

struct AdaptiveAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.subtle : animation, value: value)
    }
}

struct RevealModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let appeared: Bool
    let delay: Double
    let offset: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: (appeared || reduceMotion) ? 0 : offset)
            .blur(radius: (appeared || reduceMotion) ? 0 : blur)
            .animation(
                reduceMotion ? Motion.subtle : Motion.reveal.delay(delay),
                value: appeared
            )
    }
}

extension View {
    func animate<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AdaptiveAnimation(animation: animation, value: value))
    }

    /// Staggered entrance: rises, de-blurs and fades in.
    func reveal(_ appeared: Bool, delay: Double = 0, offset: CGFloat = 22, blur: CGFloat = 5) -> some View {
        modifier(RevealModifier(appeared: appeared, delay: delay, offset: offset, blur: blur))
    }
}

// MARK: - Surfaces

extension View {
    /// Solid raised surface with a light-catching hairline.
    func bmCard(radius: CGFloat = Radius.card, fill: Color = Color.bmSurface) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }

    /// Frosted glass surface.
    func bmGlass(radius: CGFloat = Radius.card, tint: Color = Color.white.opacity(0.04)) -> some View {
        self
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }

    func bmGlassCircle() -> some View {
        self
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            )
    }
}

// MARK: - Press styles

struct BMPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.05
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
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Haptics

enum Haptic {
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func press()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func thud()    { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.10), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: phase * geo.size.width)
                }
                .allowsHitTesting(false)
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Scroll offset

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Aurora backdrop

/// Slow-drifting colour fields behind hero screens.
struct AuroraBackground: View {
    var intensity: Double = 1.0
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.bmBase

            Circle()
                .fill(Color.bmOrchid.opacity(0.42 * intensity))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: drift ? -110 : 80, y: drift ? -260 : -170)

            Circle()
                .fill(Color.bmGilt.opacity(0.26 * intensity))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: drift ? 120 : -60, y: drift ? 80 : 190)

            Circle()
                .fill(Color.bmEmber.opacity(0.20 * intensity))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: drift ? -40 : 110, y: drift ? 330 : 260)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

// MARK: - Braid mark (signature element)

private struct BraidSegment {
    let z: Double
    let strand: Int
    let alpha: Double
    let a: CGPoint
    let b: CGPoint
}

/// Three interwoven strands, drawn live. Used as the app's mark, loader and progress motif.
struct BraidMark: View {
    var length: CGFloat = 150
    var thickness: CGFloat = 44
    var strand: CGFloat = 10
    var horizontal: Bool = false
    var animated: Bool = true
    var speed: Double = 1.0
    var cycles: Double = 2.4
    var edge: Color = Color.bmBase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: [Color] { [Color.bmGilt, Color.bmOrchid, Color.bmEmber] }

    var body: some View {
        let live = animated && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 45.0, paused: !live)) { timeline in
            Canvas { context, size in
                let t: Double = live ? timeline.date.timeIntervalSinceReferenceDate * speed : 0.7
                let segments = buildSegments(size: size, t: t)
                for seg in segments {
                    var path = Path()
                    path.move(to: seg.a)
                    path.addLine(to: seg.b)
                    let width = strand * CGFloat(0.86 + 0.14 * seg.z)
                    context.stroke(
                        path,
                        with: .color(edge.opacity(seg.alpha)),
                        style: StrokeStyle(lineWidth: width + 4, lineCap: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(palette[seg.strand].opacity(seg.alpha)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round)
                    )
                }
            }
        }
        .frame(
            width: horizontal ? length : thickness,
            height: horizontal ? thickness : length
        )
        .accessibilityHidden(true)
    }

    private func buildSegments(size: CGSize, t: Double) -> [BraidSegment] {
        let along: Double = horizontal ? Double(size.width) : Double(size.height)
        let across: Double = horizontal ? Double(size.height) : Double(size.width)
        let amp: Double = (across - Double(strand)) / 2
        let center: Double = across / 2
        let steps = 64
        var out: [BraidSegment] = []
        out.reserveCapacity(steps * 3)

        for s in 0..<3 {
            let phase = Double(s) * 2.0 * Double.pi / 3.0
            for i in 0..<steps {
                let u0 = Double(i) / Double(steps)
                let u1 = Double(i + 1) / Double(steps)
                let a0 = u0 * cycles * 2.0 * Double.pi - t * 2.2 + phase
                let a1 = u1 * cycles * 2.0 * Double.pi - t * 2.2 + phase
                let p0 = braidPoint(u: u0, angle: a0, along: along, center: center, amp: amp)
                let p1 = braidPoint(u: u1, angle: a1, along: along, center: center, amp: amp)
                let mid = (u0 + u1) / 2
                let taper = min(1.0, min(mid * 7.0, (1.0 - mid) * 7.0))
                out.append(
                    BraidSegment(z: cos((a0 + a1) / 2), strand: s, alpha: max(0.0, taper), a: p0, b: p1)
                )
            }
        }
        out.sort { $0.z < $1.z }
        return out
    }

    private func braidPoint(u: Double, angle: Double, along: Double, center: Double, amp: Double) -> CGPoint {
        let cross = center + amp * sin(angle)
        let main = u * along
        return horizontal
            ? CGPoint(x: main, y: cross)
            : CGPoint(x: cross, y: main)
    }
}

/// Small rotating arc for use inside buttons.
struct BMSpinner: View {
    var color: Color = Color.bmText
    var size: CGFloat = 18
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.78)
            .stroke(color, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
    }
}

// =============================================================================
// FlowLayout — the ONLY definition in the project.
// =============================================================================

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
