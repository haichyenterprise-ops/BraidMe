import SwiftUI
import UIKit

// =============================================================================
// GlobeMorphView — Star Vortex Transition
//
// Replaces the globe with a kinetic avatar extraction + orbiting stars.
//
//  0.00s  Tap → map dims to 30%, avatar extracts from pin position
//  1.00s  Avatar settles at center, gold rim glow
//  1.30s  Stars emerge from avatar, one per 0.15s (N stars for N rating)
//  2.05s  Stars orbit the avatar — fast rotation, particle trails
//  4.05s  Stars accelerate outward, pull toward right edge
//  4.40s  Everything swooshes right with parallax + motion blur
//  5.00s  Profile in place. Transition ends.
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let isFastMode: Bool
    let onFinish: () -> Void

    // Computed star count from rating (Q1 = A: round to nearest)
    private var starCount: Int {
        let rounded = Int(braider.rating.rounded())
        return max(1, min(5, rounded))
    }

    // ─── Animation state ───
    @State private var dimOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.05
    @State private var avatarOffset: CGSize = CGSize(width: 0, height: -260)
    @State private var avatarOpacity: Double = 0
    @State private var avatarGlowOpacity: Double = 0
    @State private var avatarPulse: CGFloat = 1.0

    @State private var starsEmerged: [Bool] = [false, false, false, false, false]
    @State private var orbitAngle: Double = 0
    @State private var orbitRadius: CGFloat = 140
    @State private var starTrailOpacity: Double = 0
    @State private var starParticlePhase: CGFloat = 0

    @State private var swooshOffset: CGFloat = 0
    @State private var swooshScale: CGFloat = 1.0
    @State private var swooshOpacity: Double = 1.0
    @State private var screenShift: CGFloat = 0

    @State private var sequenceID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ─── Dim layer over map (map still visible at 30%) ───
                Color.black
                    .ignoresSafeArea()
                    .opacity(dimOpacity * 0.7)

                // ─── Everything that swooshes right on exit ───
                ZStack {
                    // Avatar gold halo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.goldLight.opacity(0.55),
                                    Color.gold.opacity(0.25),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 190
                            )
                        )
                        .frame(width: 380, height: 380)
                        .blur(radius: 20)
                        .opacity(avatarGlowOpacity)

                    // Orbiting stars
                    ZStack {
                        ForEach(0..<5, id: \.self) { index in
                            if index < starCount {
                                StarNode(
                                    index: index,
                                    totalStars: starCount,
                                    orbitRadius: orbitRadius,
                                    orbitAngle: orbitAngle,
                                    emerged: starsEmerged[index],
                                    trailOpacity: starTrailOpacity,
                                    particlePhase: starParticlePhase
                                )
                            }
                        }
                    }
                    .opacity(avatarGlowOpacity)

                    // Avatar medallion
                    avatarMedallion
                        .scaleEffect(avatarPulse)

                    // Big stars pulsing behind avatar (radiance)
                    ForEach(0..<5, id: \.self) { index in
                        if index < starCount {
                            PulsingStar(
                                angle: Double(index) / Double(starCount) * 360 + orbitAngle * 0.2,
                                radius: orbitRadius * 1.15,
                                delay: Double(index) * 0.15,
                                active: starsEmerged[index]
                            )
                        }
                    }
                }
                .scaleEffect(swooshScale)
                .offset(x: swooshOffset)
                .opacity(swooshOpacity)
            }
            .offset(x: screenShift)
            .onAppear { play(in: geo.size) }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Avatar medallion

    private var avatarMedallion: some View {
        ZStack {
            // Outer gold ring with rotation gradient
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.goldLight,
                            Color.gold,
                            Color.goldDeep,
                            Color.gold,
                            Color.goldLight
                        ],
                        center: .center,
                        angle: .degrees(orbitAngle)
                    ),
                    lineWidth: 4
                )
                .frame(width: 190, height: 190)

            // Frosted glass container
            Circle()
                .fill(.regularMaterial)
                .frame(width: 178, height: 178)
                .shadow(color: Color.gold.opacity(0.55), radius: 40, y: 8)

            // Avatar image or initials
            if braider.avatarUrl.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.20))
                    .frame(width: 160, height: 160)
                    .overlay(
                        Text(braider.initials)
                            .font(.system(size: 58, weight: .bold, design: .serif))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            }

            // Inner rim highlight
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 1)
                .frame(width: 160, height: 160)
        }
        .frame(width: 190, height: 190)
        .scaleEffect(avatarScale)
        .offset(avatarOffset)
        .opacity(avatarOpacity)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Sequence

    private func play(in size: CGSize) {
        let token = UUID()
        sequenceID = token

        if reduceMotion {
            dimOpacity = 1
            avatarScale = 1
            avatarOffset = .zero
            avatarOpacity = 1
            avatarGlowOpacity = 1
            starsEmerged = [true, true, true, true, true]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onFinish()
            }
            return
        }

        let m: Double = isFastMode ? 0.55 : 1.0

        let tDim: TimeInterval       = 0.00 * m
        let tExtract: TimeInterval   = 0.00 * m
        let tSettle: TimeInterval    = 1.00 * m
        let tStarsStart: TimeInterval = 1.30 * m
        let tStarsAllIn: TimeInterval = 2.05 * m
        let tOrbitFor: TimeInterval  = 4.05 * m
        let tSwoosh: TimeInterval    = 4.40 * m
        let tComplete: TimeInterval  = 5.00 * m

        // ─── 0.00 — Dim map ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tDim) {
            guard sequenceID == token else { return }
            withAnimation(.easeIn(duration: 0.50)) {
                dimOpacity = 1.0
            }
        }

        // ─── 0.00 — Avatar extracts from pin ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tExtract) {
            guard sequenceID == token else { return }
            Haptic.medium()

            // Big overshoot — comes from "the pin"
            withAnimation(.spring(response: 0.85, dampingFraction: 0.58)) {
                avatarScale = 1.0
                avatarOffset = .zero
                avatarOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.90).delay(0.20)) {
                avatarGlowOpacity = 1.0
            }
        }

        // ─── 1.00 — Subtle pulse once settled ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSettle) {
            guard sequenceID == token else { return }
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true)) {
                avatarPulse = 1.03
            }
        }

        // ─── 1.30 — Stars emerge one by one ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tStarsStart) {
            guard sequenceID == token else { return }

            // Start orbital rotation — slow at first, accelerates
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                orbitAngle = 360
            }

            // Particle trail fades in
            withAnimation(.easeIn(duration: 0.4)) {
                starTrailOpacity = 1.0
            }

            // Emerge each star
            for i in 0..<starCount {
                let delay = Double(i) * 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard sequenceID == token else { return }
                    Haptic.light()
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                        starsEmerged[i] = true
                    }
                }
            }
        }

        // ─── 2.05 — All stars are orbiting. Let them orbit. ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tStarsAllIn) {
            guard sequenceID == token else { return }
            // No animation — just a marker
        }

        // ─── 4.05 — Orbit radius expands, stars pull right ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tOrbitFor) {
            guard sequenceID == token else { return }
            Haptic.medium()

            // Orbit radius expands
            withAnimation(.easeInOut(duration: 0.35)) {
                orbitRadius = 260
            }
        }

        // ─── 4.40 — Swoosh off to the right ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSwoosh) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            // The whole assembly (avatar + stars + halo) swooshes right
            withAnimation(.easeIn(duration: 0.45)) {
                swooshOffset = size.width * 1.4
                swooshScale = 1.15
                swooshOpacity = 0.0
            }

            // The whole screen shifts right too — parallax
            withAnimation(.easeInOut(duration: 0.55)) {
                screenShift = size.width * 0.35
            }
        }

        // ─── 5.00 — Complete ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tComplete) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Orbiting Star Node

private struct StarNode: View {
    let index: Int
    let totalStars: Int
    let orbitRadius: CGFloat
    let orbitAngle: Double
    let emerged: Bool
    let trailOpacity: Double
    let particlePhase: CGFloat

    /// Each star sits at its own angle slice
    private var baseAngle: Double {
        (Double(index) / Double(totalStars)) * 360
    }

    private var currentAngle: Double {
        baseAngle + orbitAngle
    }

    var body: some View {
        let radians = currentAngle * .pi / 180
        let x = cos(radians) * Double(orbitRadius)
        let y = sin(radians) * Double(orbitRadius)

        ZStack {
            // ── Trail ──
            if emerged && trailOpacity > 0 {
                TrailArc(
                    radius: orbitRadius,
                    angle: currentAngle,
                    trailLength: 40
                )
                .opacity(trailOpacity * 0.55)
                .offset(
                    x: cos((currentAngle - 20) * .pi / 180) * Double(orbitRadius),
                    y: sin((currentAngle - 20) * .pi / 180) * Double(orbitRadius)
                )
            }

            // ── Star body ──
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goldLight.opacity(0.9),
                                Color.gold.opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 26
                        )
                    )
                    .frame(width: 52, height: 52)

                // Star icon
                Image(systemName: "star.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.goldLight, Color.gold, Color.goldDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.gold.opacity(0.8), radius: 12)
            }
            .scaleEffect(emerged ? 1.0 : 0.0)
            .opacity(emerged ? 1.0 : 0.0)
        }
        .offset(x: x, y: y)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Trail arc (drawn behind each star)

private struct TrailArc: View {
    let radius: CGFloat
    let angle: Double
    let trailLength: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let steps = 12
            let start = angle - trailLength
            let end = angle

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let a = (start + (end - start) * t) * .pi / 180
                let x = cos(a) * Double(radius)
                let y = sin(a) * Double(radius)
                if i == 0 {
                    path.move(to: CGPoint(x: size.width / 2 + x, y: size.height / 2 + y))
                } else {
                    path.addLine(to: CGPoint(x: size.width / 2 + x, y: size.height / 2 + y))
                }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.gold.opacity(0),
                        Color.goldLight.opacity(0.6),
                        Color.gold.opacity(0.9)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
        .frame(width: radius * 2 + 60, height: radius * 2 + 60)
        .allowsHitTesting(false)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Pulsing star behind avatar

private struct PulsingStar: View {
    let angle: Double
    let radius: CGFloat
    let delay: Double
    let active: Bool

    @State private var pulse: CGFloat = 0.7

    var body: some View {
        let rad = angle * .pi / 180
        let x = cos(rad) * Double(radius)
        let y = sin(rad) * Double(radius)

        Circle()
            .fill(Color.goldLight.opacity(0.25))
            .frame(width: 40, height: 40)
            .scaleEffect(pulse)
            .opacity(active ? 0.6 : 0)
            .offset(x: x, y: y)
            .onAppear {
                guard active else { return }
                withAnimation(
                    .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    pulse = 1.4
                }
            }
    }
}