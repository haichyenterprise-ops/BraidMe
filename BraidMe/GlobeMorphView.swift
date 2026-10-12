import SwiftUI
import UIKit

// =============================================================================
// GlobeMorphView — The full-screen globe that appears AFTER the map has
// pulled back to space. Morphs from a gold-on-obsidian Earth into the
// braider's avatar medallion, then hands off to the profile.
//
// Total runtime: 2.5s (or 0.6s in fast mode)
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let isFastMode: Bool
    let onFinish: () -> Void

    // ─── Animation state ───
    @State private var backdropOpacity: Double = 0
    @State private var sphereOpacity: Double = 0
    @State private var sphereScale: CGFloat = 1.0
    @State private var sphereRotation: Double = 0
    @State private var continentMorph: CGFloat = 0       // 0 = full continents, 1 = blurred into glow
    @State private var graticuleOpacity: Double = 1.0
    @State private var graticuleConverge: CGFloat = 1.0  // 1.0 = normal, 0.2 = pulled to center
    @State private var ringAngle: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.4
    @State private var avatarOpacity: Double = 0
    @State private var goldGlowOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var starOpacity: Double = 0
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0
    @State private var sequenceID = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // ─── Deep space backdrop ───
            LinearGradient(
                colors: [
                    Color(hex: "#000000"),
                    Color(hex: "#08080F"),
                    Color(hex: "#050510")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(backdropOpacity)

            // ─── Star field ───
            starField
                .opacity(backdropOpacity * 0.9)

            // ─── Globe assembly ───
            globeLayer
                .opacity(exitOpacity)
                .scaleEffect(exitScale)

            // ─── Text block below globe ───
            VStack(spacing: 10) {
                Text("ENTERING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(5)
                    .foregroundStyle(Color.gold)
                    .opacity(textOpacity)

                Text(braider.name)
                    .font(.system(size: 38, weight: .regular, design: .serif))
                    .tracking(-1.2)
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                    .offset(y: textOffset)

                HStack(spacing: 7) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.gold)
                    Text(braider.ratingText)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.95))
                }
                .opacity(starOpacity)
                .offset(y: textOffset)
            }
            .offset(y: 240)
            .opacity(exitOpacity)
            .scaleEffect(exitScale)
        }
        .ignoresSafeArea()
        .onAppear {
            play()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Star field
    // ═══════════════════════════════════════════════════════════════

    private var starField: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: 0xFACE)
            for _ in 0..<160 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.4...1.3, using: &rng)
                let alpha = Double.random(in: 0.15...0.85, using: &rng)
                let circle = Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                context.fill(circle, with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Globe layer
    // ═══════════════════════════════════════════════════════════════

    private var globeLayer: some View {
        ZStack {
            // ── Outer halo ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.30),
                            Color.gold.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 120,
                        endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .opacity(sphereOpacity * (1 - continentMorph) + goldGlowOpacity)

            // ── Orbiting satellite ring ──
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goldLight.opacity(0.0),
                            Color.goldLight.opacity(0.85),
                            Color.gold.opacity(0.5),
                            Color.goldLight.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.6
                )
                .frame(width: 420, height: 90)
                .rotationEffect(.degrees(ringAngle))
                .rotation3DEffect(
                    .degrees(72),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.4
                )
                .opacity(ringOpacity)

            // ── The sphere ──
            sphereBody

            // ── Gold glow burst (during morph) ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.goldLight.opacity(0.55),
                            Color.gold.opacity(0.25),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .opacity(goldGlowOpacity)

            // ── Avatar medallion ──
            avatarMedallion
        }
        .scaleEffect(sphereScale)
    }

    // ─── Sphere body ───

    private var sphereBody: some View {
        ZStack {
            // Base obsidian sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#2B2416"),
                            Color(hex: "#13100A"),
                            Color(hex: "#050507")
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 5,
                        endRadius: 200
                    )
                )
                .frame(width: 320, height: 320)

            // ── Continents (abstract gold landmasses) ──
            ContinentsView()
                .frame(width: 320, height: 320)
                .blur(radius: continentMorph * 12)
                .opacity(sphereOpacity * (1 - continentMorph * 0.7))

            // ── Graticule (grid lines) ──
            GraticuleView()
                .frame(width: 320, height: 320)
                .scaleEffect(graticuleConverge)
                .opacity(graticuleOpacity * (1 - continentMorph))

            // Rim light
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goldLight.opacity(0.95),
                            Color.gold.opacity(0.35),
                            Color.goldDeep.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 320, height: 320)
                .opacity(sphereOpacity)

            // Inner shadow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.55)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 60,
                        endRadius: 165
                    )
                )
                .frame(width: 320, height: 320)
                .opacity(sphereOpacity)

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.38),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 85)
                .offset(x: -75, y: -85)
                .blur(radius: 6)
                .blendMode(.screen)
                .opacity(sphereOpacity)
        }
        .rotation3DEffect(
            .degrees(sphereRotation * 0.15),
            axis: (x: 0.12, y: 1, z: 0.05),
            perspective: 0.35
        )
        .opacity(sphereOpacity)
        .shadow(color: Color.gold.opacity(0.35), radius: 50, y: 12)
        .shadow(color: Color.goldDeep.opacity(0.55), radius: 100)
    }

    // ─── Avatar medallion ───

    private var avatarMedallion: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.5),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 12)
                .opacity(avatarOpacity)

            // Container
            Circle()
                .fill(.regularMaterial)
                .frame(width: 140, height: 140)
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [
                                Color.goldLight,
                                Color.gold,
                                Color.goldDeep
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3.5
                    )
                )
                .shadow(color: Color.gold.opacity(0.6), radius: 30, y: 6)

            if braider.avatarUrl.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.20))
                    .frame(width: 124, height: 124)
                    .overlay(
                        Text(braider.initials)
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 124, height: 124)
                    .clipShape(Circle())
            }
        }
        .scaleEffect(avatarScale)
        .opacity(avatarOpacity)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Animation sequence
    // ═══════════════════════════════════════════════════════════════

    private func play() {
        let token = UUID()
        sequenceID = token

        if reduceMotion {
            // Skip to end
            backdropOpacity = 1
            sphereOpacity = 1
            avatarOpacity = 1
            avatarScale = 1
            textOpacity = 1
            starOpacity = 1
            textOffset = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onFinish()
            }
            return
        }

        // ─── Timing constants ───
        let tCrossfade: TimeInterval = isFastMode ? 0.15 : 0.35
        let tSpinStart: TimeInterval = isFastMode ? 0.20 : 0.50
        let tMorphStart: TimeInterval = isFastMode ? 0.40 : 1.20
        let tAvatarStart: TimeInterval = isFastMode ? 0.55 : 1.80
        let tTextStart: TimeInterval = isFastMode ? 0.65 : 2.00
        let tExitStart: TimeInterval = isFastMode ? 0.75 : 2.30
        let tComplete: TimeInterval = isFastMode ? 0.90 : 2.50

        // ─── Phase A: Backdrop + sphere fade in (crossfade from map) ───
        withAnimation(.easeIn(duration: tCrossfade)) {
            backdropOpacity = 1
            sphereOpacity = 1
        }

        // Slow initial rotation
        withAnimation(.linear(duration: 20)) {
            sphereRotation = 360
        }

        // ─── Phase B: Satellite ring appears ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSpinStart) {
            guard sequenceID == token else { return }
            withAnimation(.easeIn(duration: 0.4)) {
                ringOpacity = 0.9
            }
            withAnimation(.linear(duration: 6)) {
                ringAngle = 360
            }
        }

        // ─── Phase C: Spin accelerates + continents start compressing ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tMorphStart * 0.5) {
            guard sequenceID == token else { return }
            // Speed up the spin
            withAnimation(.easeIn(duration: 0.6)) {
                sphereScale = 1.12
            }
        }

        // ─── Phase D: The Morph — continents blur, graticule converges ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tMorphStart) {
            guard sequenceID == token else { return }
            Haptic.medium()

            withAnimation(.easeInOut(duration: 0.7)) {
                continentMorph = 1.0
                graticuleConverge = 0.35
                graticuleOpacity = 0.3
                goldGlowOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                sphereOpacity = 0.5
            }
        }

        // ─── Phase E: Avatar materializes from the center ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tAvatarStart) {
            guard sequenceID == token else { return }
            Haptic.success()

            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                avatarScale = 1.0
                avatarOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5)) {
                goldGlowOpacity = 0.6
                sphereOpacity = 0.25
            }
        }

        // ─── Phase F: Text reveal ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tTextStart) {
            guard sequenceID == token else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.15)) {
                starOpacity = 1
            }
        }

        // ─── Phase G: Exit — everything scales up + fades ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tExitStart) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            withAnimation(.easeIn(duration: 0.4)) {
                exitScale = 1.25
                exitOpacity = 0
                goldGlowOpacity = 0
            }
        }

        // ─── Phase H: Hand off ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tComplete) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Continents (abstract gold landmasses)
// ═══════════════════════════════════════════════════════════════════

private struct ContinentsView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let radius = min(w, h) / 2

            // Draw abstract continent blobs. Each is a soft-edged shape
            // filled with a gold gradient and clipped to a circle.
            let shapes: [(CGRect, CGFloat)] = [
                (CGRect(x: w * 0.12, y: h * 0.20, width: w * 0.30, height: h * 0.35), 0.9),
                (CGRect(x: w * 0.55, y: h * 0.14, width: w * 0.30, height: h * 0.22), 0.85),
                (CGRect(x: w * 0.62, y: h * 0.42, width: w * 0.28, height: h * 0.38), 0.9),
                (CGRect(x: w * 0.22, y: h * 0.60, width: w * 0.26, height: h * 0.26), 0.8),
                (CGRect(x: w * 0.05, y: h * 0.48, width: w * 0.14, height: h * 0.18), 0.7),
                (CGRect(x: w * 0.78, y: h * 0.62, width: w * 0.14, height: h * 0.14), 0.65)
            ]

            context.clip(to: Path(ellipseIn: CGRect(x: 0, y: 0, width: w, height: h)))

            for (rect, alpha) in shapes {
                // Round the rectangle into a blob
                let blobPath = blobShape(in: rect)
                let gradient = Gradient(colors: [
                    Color.goldLight.opacity(alpha),
                    Color.gold.opacity(alpha * 0.9),
                    Color.goldDeep.opacity(alpha * 0.7)
                ])
                context.fill(
                    blobPath,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )
            }
        }
    }

    private func blobShape(in rect: CGRect) -> Path {
        // Build a rounded organic blob using bezier curves
        var path = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        path.move(to: CGPoint(x: x + w * 0.15, y: y + h * 0.10))
        path.addCurve(
            to: CGPoint(x: x + w * 0.85, y: y + h * 0.15),
            control1: CGPoint(x: x + w * 0.40, y: y - h * 0.05),
            control2: CGPoint(x: x + w * 0.75, y: y + h * 0.0)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.90, y: y + h * 0.65),
            control1: CGPoint(x: x + w * 1.05, y: y + h * 0.30),
            control2: CGPoint(x: x + w * 1.02, y: y + h * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.55, y: y + h * 0.92),
            control1: CGPoint(x: x + w * 0.78, y: y + h * 0.85),
            control2: CGPoint(x: x + w * 0.68, y: y + h * 0.95)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.10, y: y + h * 0.70),
            control1: CGPoint(x: x + w * 0.30, y: y + h * 0.98),
            control2: CGPoint(x: x + w * 0.08, y: y + h * 0.88)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.15, y: y + h * 0.10),
            control1: CGPoint(x: x + w * 0.0, y: y + h * 0.40),
            control2: CGPoint(x: x + w * 0.05, y: y + h * 0.15)
        )
        path.closeSubpath()
        return path
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Graticule (latitude + longitude lines)
// ═══════════════════════════════════════════════════════════════════

private struct GraticuleView: View {
    var body: some View {
        ZStack {
            // Longitude lines
            ForEach(0..<7, id: \.self) { i in
                Ellipse()
                    .stroke(Color.gold.opacity(0.5), lineWidth: 0.85)
                    .frame(
                        width: 30 + CGFloat(i) * 45,
                        height: 320
                    )
            }

            // Latitude lines (curved with the sphere)
            ForEach(1..<8, id: \.self) { i in
                let y = -160 + CGFloat(i) * 45
                let visibleHeight = sqrt(max(0, 160 * 160 - y * y)) * 2
                Ellipse()
                    .stroke(Color.gold.opacity(0.4), lineWidth: 0.75)
                    .frame(
                        width: visibleHeight,
                        height: 11
                    )
                    .offset(y: y)
            }
        }
    }
}