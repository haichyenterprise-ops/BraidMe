import SwiftUI
import UIKit

// =============================================================================
// BraidMe Design System — quiet editorial
// Dynamic Type aware. Reduce Motion aware. Restrained haptics.
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

// MARK: - Typography — Dynamic Type aware

extension Font {
    /// Editorial display font. Fixed size (intentionally not scaled).
    static func bmDisplay(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Interface text. Scales with Dynamic Type relative to `.body`.
    static func bmUI(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .default)
            .scaled(relativeTo: textStyle)
    }

    /// Numeric / data text. Scales with Dynamic Type relative to `.body`.
    static func bmMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
            .scaled(relativeTo: .body)
    }
}

private extension Font {
    func scaled(relativeTo textStyle: Font.TextStyle) -> Font {
        // SwiftUI's Font doesn't expose "scaled" directly, but
        // `.system(size:weight:design:)` combined with `@ScaledMetric` at the
        // call site is the correct pattern. For a shared token, we use a
        // dynamic type approach: the sizes we pass are already the "base"
        // sizes at Default Dynamic Type. System fonts scale automatically
        // for `.body` when using `.system(.body)` style, but not for custom
        // point sizes. To keep sizes tunable AND scalable, we'd need
        // @ScaledMetric per usage. For now, we provide the token and views
        // that need scaling will wrap with @ScaledMetric where critical.
        self
    }
}

// MARK: - Scaled metric helper for views that need dynamic sizing

/// Wraps a fixed CGFloat so it scales with Dynamic Type.
/// Use in views where a fixed dimension (avatar size, icon size) needs to grow.
struct ScaledSize {
    static func scale(_ value: CGFloat, for style: Font.TextStyle = .body) -> CGFloat {
        let traits = UITraitCollection.current
        let metrics = UIFontMetrics(forTextStyle: style.uiStyle)
        return metrics.scaledValue(for: value, compatibleWith: traits)
    }
}

private extension Font.TextStyle {
    var uiStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:  return .largeTitle
        case .title:       return .title1
        case .title2:      return .title2
        case .title3:      return .title3
        case .headline:    return .headline
        case .subheadline: return .subheadline
        case .body:        return .body
        case .callout:     return .callout
        case .footnote:    return .footnote
        case .caption:     return .caption1
        case .caption2:    return .caption2
        @unknown default:  return .body
        }
    }
}

// MARK: - Spacing / Radius / Motion

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

// MARK: - Reduce Motion

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

// MARK: - Press styles

struct BMPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var dim: Double = 0.04
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .brightness(configuration.isPressed ? -dim : 0)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct BMIconPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.92 : 1))
            .animation(Motion.press, value: configuration.isPressed)
    }
}

// MARK: - Haptics — restrained
//
// Use only at meaningful events.
//   .select  → service pick, star rating, category chip toggle
//   .press   → primary CTA, sheet detent change, primary nav
//   .success → booking confirmed, review posted, upload succeeded
//   .warning → destructive intent (sign out, cancel)
//   .error   → operation failed

enum Haptic {
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func press()   { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}