import SwiftUI
import UIKit

// Compatibility aliases so any file still using the previous design-system names
// (for example GlobeMorphView) keeps compiling. Prefer the bm* tokens in new code.
extension Color {
    static var appBackground: Color { Color.bmBase }
    static var appSurface: Color { Color.bmSurface }
    static var appSurfaceInverse: Color { Color.bmDeep }
    static var appInk: Color { Color.bmText }
    static var appInkInverse: Color { Color.bmOnGilt }
    static var appAsh: Color { Color.bmTextDim }
    static var appSmoke: Color { Color.bmTextFaint }
    static var appDivider: Color { Color.bmLine }
    static var appAccent: Color { Color.bmGilt }
    static var appAccentDeep: Color { Color.bmGiltLo }
    static var appAccentSoft: Color { Color.bmGiltHi }
    static var appAccentTint: Color { Color.bmGilt.opacity(0.14) }
    static var appSignal: Color { Color.bmGood }
    static var appAlert: Color { Color.bmBad }
}

extension Font {
    static func bmMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        bmNum(size, weight: weight)
    }
}

// Names used by GlobeMorphView
extension Color {
    static var goldLight: Color { Color.bmGiltHi }
    static var gold: Color { Color.bmGilt }
    static var goldDeep: Color { Color.bmGiltLo }
}

extension Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}

// More names used by GlobeMorphView
extension Color {
    static var glassTintStrong: Color { Color.white.opacity(0.14) }
    static var glassTint: Color { Color.white.opacity(0.06) }
}

extension Braider {
    var ratingText: String { String(format: "%.1f", rating) }
}