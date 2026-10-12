import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — quiet editorial
// =============================================================================

extension Color {
    fileprivate enum Palette {
        static let ink        = Color(hex: "#0B0B0F")
        static let graphite   = Color(hex: "#17171C")
        static let charcoal   = Color(hex: "#24242A")
        static let ash        = Color(hex: "#8A8479")
        static let smoke      = Color(hex: "#B5AFA4")
        static let mist       = Color(hex: "#E8E4DD")
        static let bone       = Color(hex: "#F5F1EC")
        static let paper      = Color(hex: "#FFFFFF")
        static let bronze     = Color(hex: "#8B6B47")
        static let bronzeDeep = Color(hex: "#6B5135")
        static let bronzeWarm = Color(hex: "#A88461")
        static let signal     = Color(hex: "#2E7D5B")
        static let alert      = Color(hex: "#B3473F")
    }

    static var appBackground: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.ink) : UIColor(Palette.bone) })
    }
    static var appSurface: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.graphite) : UIColor(Palette.paper) })
    }
    static var appSurfaceInverse: Color { Palette.ink }
    static var appInk: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.bone) : UIColor(Palette.ink) })
    }
    static var appAsh: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.smoke) : UIColor(Palette.ash) })
    }
    static var appSmoke: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.ash) : UIColor(Palette.smoke) })
    }
    static var appDivider: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Palette.charcoal) : UIColor(Palette.mist) })
    }
    static var appInkInverse: Color { Palette.bone }
    static var appAccent: Color { Palette.bronze }
    static var appAccentDeep: Color { Palette.bronzeDeep }
    static var appAccentSoft: Color { Palette.bronzeWarm }
    static var appAccentTint: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(Palette.bronze).withAlphaComponent(0.20)
            : UIColor(Palette.bronze).withAlphaComponent(0.10) })
    }
    static var appSignal: Color { Palette.signal }
    static var appAlert: Color { Palette.alert }

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

extension Font {
    static func bmDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func bmUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func bmMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

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
    static let chip:   CGFloat = 6
    static let button: CGFloat = 14
    static let card:   CGFloat = 20
    static let modal:  CGFloat = 32
    static let pill:   CGFloat = 999
}

enum Motion {
    static let navigation = Animation.easeInOut(duration: 0.35)
    static let press      = Animation.spring(response: 0.28, dampingFraction: 0.82)
    static let reveal     = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let sheet      = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let subtle     = Animation.easeOut(duration: 0.20)

    static let staggerStep: Double = 0.06
    static func stagger(_ index: Int) -> Double { Double(index) * staggerStep }
}

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
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

enum Haptic {
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func press()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// =============================================================================
// FlowLayout — the ONLY definition in the project.
// Do not redefine this anywhere else. If a file needs it, it's global.
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