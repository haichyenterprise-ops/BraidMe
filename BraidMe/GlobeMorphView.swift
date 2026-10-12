import SwiftUI
import UIKit

// =============================================================================
// GlobeMorphView — Star Vortex Transition (Final Form)
//
// The full sequence:
//   0.00  Map dims, avatar extracts from pin position
//   1.00  Avatar settles at center with gold halo
//   1.30  Stars emerge one by one (N = rating rounded)
//   2.05  Stars orbit + accelerate, chromatic aura, comet trails
//   4.05  Magnetic collapse — stars converge to avatar
//   4.40  Stars swoosh right, avatar follows, screen shifts
//   5.00  Profile handoff
//
// Enhanced: chromatic aura (3 offset rings), 40 dust motes per star,
// magnetic collapse, sound-wave ring, comet trails 2× longer,
// star pulse per rotation, confetti burst at peak.
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let isFastMode: Bool
    let onFinish: () -> Void

    // Star count from rating — rounds to nearest.
    private var starCount: Int {
        let rounded = Int(braider.rating.rounded())
        return max(1, min(5, rounded))
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Animation state

    // Curtain
    @State private var dimOpacity: Double = 0

    // Avatar
    @State private var avatarScale: CGFloat = 0.05
    @State private var avatarOffset: CGSize = CGSize(width: 0, height: -260)
    @State private var avatarOpacity: Double = 0
    @State private var avatarGlowOpacity: Double = 0
    @State private var avatarPulse: CGFloat = 1.0

    // Sound-wave ring
    @State private var waveRingScale: CGFloat = 0.5
    @State private var waveRingOpacity: Double = 0

    // Stars
    @State private var starsEmerged: [Bool] = [false, false, false, false, false]
    @State private var orbitAngle: Double = 0
    @State private var orbitRadius: CGFloat = 140
    @State private var starTrailOpacity: Double = 0
    @State private var starPulse: CGFloat = 1.0

    // Magnetic collapse (pull stars inward briefly)
    @State private var magnetPull: CGFloat = 0

    // Chromatic aura
    @State private var auraPhase: Double = 0

    // Confetti
    @State private var confettiProgress: CGFloat = 0
    @State private var confettiOpacity: Double = 0

    // Swoosh exit
    @State private var swooshOffset: CGFloat = 0
    @State private var swooshScale: CGFloat = 1.0
    @State private var swooshOpacity: Double = 1.0
    @State private var screenShift: CGFloat = 0

    // Sequence token — guards against stale async callbacks
    @State private var sequenceID = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ─── Dim layer over map ───
                Color.black
                    .ignoresSafeArea()
                    .opacity(dimOpacity * 0.7)

                // ─── Everything that swooshes right on exit ───
                ZStack {
                    // ─── Chromatic aura (3 offset rings) ───
                    chromaticAura

                    // ─── Avatar gold halo (breathing) ───
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
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 20)
                        .opacity(avatarGlowOpacity)
                        .scaleEffect(avatarPulse)

                    // ─── Sound-wave ring ───
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.goldLight.opacity(0.9),
                                    Color.gold.opacity(0.3),
                                    .clear
                                ],
                                startPoint: .center,
                                endPoint: .topTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 240, height: 240)
                        .scaleEffect(waveRingScale)
                        .opacity(waveRingOpacity)

                    // ─── Orbiting stars ───
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
                                    magnetPull: magnetPull,
                                    pulse: starPulse
                                )
                            }
                        }
                    }
                    .opacity(avatarGlowOpacity)

                    // ─── Avatar medallion ───
                    avatarMedallion
                        .scaleEffect(avatarPulse)

                    // ─── Confetti burst at peak ───
                    ConfettiBurst(progress: confettiProgress)
                        .opacity(confettiOpacity)
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
    // MARK: - Chromatic aura

    private var chromaticAura: some View {
        ZStack {
            // Outer gold ring — pulsing
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.goldLight.opacity(0.55),
                            Color.gold.opacity(0.1),
                            Color.gold.opacity(0.55),
                            Color.goldDeep.opacity(0.1),
                            Color.goldLight.opacity(0.55)
                        ],
                        center: .center,
                        angle: .degrees(auraPhase)
                    ),
                    lineWidth: 1.4
                )
                .frame(width: 220, height: 220)
                .blur(radius: 1.5)
                .opacity(avatarGlowOpacity * 0.7)

            // Middle ring — offset
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.gold.opacity(0.4),
                            .clear,
                            Color.goldLight.opacity(0.5),
                            .clear,
                            Color.gold.opacity(0.4)
                        ],
                        center: .center,
                        angle: .degrees(auraPhase * -1.3 + 90)
                    ),
                    lineWidth: 0.8
                )
                .frame(width: 240, height: 240)
                .blur(radius: 3)
                .opacity(avatarGlowOpacity * 0.5)

            // Inner ring — opposite direction
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            .clear,
                            Color.goldLight.opacity(0.4),
                            .clear,
                            Color.white.opacity(0.35)
                        ],
                        center: .center,
                        angle: .degrees(auraPhase * 1.8)
                    ),
                    lineWidth: 1
                )
                .frame(width: 200, height: 200)
                .blur(radius: 2)
                .opacity(avatarGlowOpacity * 0.45)
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

            // Frosted glass container (blur-free)
            Circle()
                .fill(Color.glassTintStrong)
                .frame(width: 178, height: 178)
                .shadow(color: Color.gold.opacity(0.55), radius: 40, y: 8)

            // Avatar
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

        let tDim: TimeInterval        = 0.00 * m
        let tExtract: TimeInterval    = 0.00 * m
        let tSettle: TimeInterval     = 1.00 * m
        let tStarsStart: TimeInterval = 1.30 * m
        let tOrbitFor: TimeInterval   = 4.05 * m
        let tCollapse: TimeInterval   = tOrbitFor - 0.20 * m
        let tSwoosh: TimeInterval     = 4.40 * m
        let tComplete: TimeInterval   = 5.00 * m

        // ─── Dim map ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tDim) {
            guard sequenceID == token else { return }
            withAnimation(.easeIn(duration: 0.50)) {
                dimOpacity = 1.0
            }
        }

        // ─── Avatar extracts ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tExtract) {
            guard sequenceID == token else { return }
            Haptic.medium()

            withAnimation(.spring(response: 0.85, dampingFraction: 0.58)) {
                avatarScale = 1.0
                avatarOffset = .zero
                avatarOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.90).delay(0.20)) {
                avatarGlowOpacity = 1.0
            }

            // Chromatic aura rotation — continuous
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                auraPhase = 360
            }

            // Sound-wave ring burst at 0.4s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                guard sequenceID == token else { return }
                withAnimation(.easeOut(duration: 1.0)) {
                    waveRingScale = 2.6
                    waveRingOpacity = 0.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                waveRingOpacity = 1.0
            }
        }

        // ─── Subtle pulse once settled ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSettle) {
            guard sequenceID == token else { return }
            withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true)) {
                avatarPulse = 1.03
            }
        }

        // ─── Stars emerge ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tStarsStart) {
            guard sequenceID == token else { return }

            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                orbitAngle = 360
            }
            withAnimation(.easeIn(duration: 0.4)) {
                starTrailOpacity = 1.0
            }

            // Per-rotation pulse (5 pulses in a rotation)
            withAnimation(
                .easeInOut(duration: 0.32)
                .repeatForever(autoreverses: true)
            ) {
                starPulse = 1.12
            }

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

        // ─── Magnetic collapse (stars pull inward briefly) ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tCollapse) {
            guard sequenceID == token else { return }
            Haptic.medium()

            withAnimation(.easeIn(duration: 0.20)) {
                magnetPull = 0.75
            }
            // Spring back to expanded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                guard sequenceID == token else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    magnetPull = 0
                    orbitRadius = 260
                }
            }
        }

        // ─── Confetti burst at peak collapse ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tOrbitFor) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            // Radial expansion of stars
            withAnimation(.easeInOut(duration: 0.35)) {
                orbitRadius = 320
            }

            // Confetti fires
            withAnimation(.easeOut(duration: 0.02)) {
                confettiOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.70)) {
                confettiProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard sequenceID == token else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    confettiOpacity = 0
                }
            }
        }

        // ─── Swoosh right ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSwoosh) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            withAnimation(.easeIn(duration: 0.45)) {
                swooshOffset = size.width * 1.4
                swooshScale = 1.15
                swooshOpacity = 0.0
            }
            withAnimation(.easeInOut(duration: 0.55)) {
                screenShift = size.width * 0.35
            }
        }

        // ─── Complete ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tComplete) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Orbiting Star Node
// ═══════════════════════════════════════════════════════════════════

private struct StarNode: View {
    let index: Int
    let totalStars: Int
    let orbitRadius: CGFloat
    let orbitAngle: Double
    let emerged: Bool
    let trailOpacity: Double
    let magnetPull: CGFloat
    let pulse: CGFloat

    /// Star sits at its own angle slice.
    private var baseAngle: Double {
        (Double(index) / Double(totalStars)) * 360
    }

    private var currentAngle: Double {
        baseAngle + orbitAngle
    }

    /// Effective radius = orbit radius minus magnetic pull.
    private var effectiveRadius: CGFloat {
        orbitRadius * (1 - magnetPull)
    }

    var body: some View {
        let radians = currentAngle * .pi / 180
        let x = cos(radians) * Double(effectiveRadius)
        let y = sin(radians) * Double(effectiveRadius)

        ZStack {
            // ─── Comet trail (2× longer, brighter) ───
            if emerged && trailOpacity > 0 {
                TrailArc(
                    radius: effectiveRadius,
                    angle: currentAngle,
                    trailLength: 72
                )
                .opacity(trailOpacity * 0.75)
                .offset(
                    x: cos((currentAngle - 36) * .pi / 180) * Double(effectiveRadius),
                    y: sin((currentAngle - 36) * .pi / 180) * Double(effectiveRadius)
                )

                // Second trail — softer halo
                TrailArc(
                    radius: effectiveRadius,
                    angle: currentAngle,
                    trailLength: 40
                )
                .opacity(trailOpacity * 0.35)
                .blur(radius: 2)
                .offset(
                    x: cos((currentAngle - 20) * .pi / 180) * Double(effectiveRadius),
                    y: sin((currentAngle - 20) * .pi / 180) * Double(effectiveRadius)
                )
            }

            // ─── Star body ───
            ZStack {
                // Dust motes (small ring around each star)
                if emerged {
                    ForEach(0..<8, id: \.self) { mote in
                        Circle()
                            .fill(Color.goldLight.opacity(0.6))
                            .frame(width: 1.8, height: 1.8)
                            .offset(
                                x: cos(Double(mote) * .pi / 4 + orbitAngle * 0.02) * 16,
                                y: sin(Double(mote) * .pi / 4 + orbitAngle * 0.02) * 16
                            )
                            .blur(radius: 0.3)
                    }
                }

                // Radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goldLight.opacity(0.95),
                                Color.gold.opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)

                // Star icon
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.goldLight, Color.gold, Color.goldDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.gold.opacity(0.9), radius: 14)
                    .shadow(color: Color.white.opacity(0.4), radius: 4)
            }
            .scaleEffect((emerged ? 1.0 : 0.0) * pulse)
            .opacity(emerged ? 1.0 : 0.0)
        }
        .offset(x: x, y: y)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Trail Arc
// ═══════════════════════════════════════════════════════════════════

private struct TrailArc: View {
    let radius: CGFloat
    let angle: Double
    let trailLength: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let steps = 16
            let start = angle - trailLength
            let end = angle

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let a = (start + (end - start) * t) * .pi / 180
                let x = cos(a) * Double(radius)
                let y = sin(a) * Double(radius)
                let pt = CGPoint(x: size.width / 2 + x, y: size.height / 2 + y)
                if i == 0 {
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.gold.opacity(0),
                        Color.goldLight.opacity(0.55),
                        Color.gold.opacity(0.95),
                        Color.white.opacity(0.4)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )
        }
        .frame(width: radius * 2 + 120, height: radius * 2 + 120)
        .allowsHitTesting(false)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Confetti Burst
// ═══════════════════════════════════════════════════════════════════

private struct ConfettiBurst: View {
    let progress: CGFloat

    private let count = 24

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                ConfettiParticle(index: i, total: count, progress: progress)
            }
        }
    }
}

private struct ConfettiParticle: View {
    let index: Int
    let total: Int
    let progress: CGFloat

    private var angle: Double {
        Double(index) / Double(total) * 360
    }

    private var distance: CGFloat {
        progress * (110 + CGFloat(index % 4) * 25)
    }

    private var size: CGFloat {
        let base: CGFloat = 3
        return base + CGFloat(index % 3)
    }

    private var rotation: Double {
        Double(index) * 45 + Double(progress) * 360
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.goldLight, Color.gold, Color.goldDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .offset(
                x: cos(angle * .pi / 180) * Double(distance),
                y: sin(angle * .pi / 180) * Double(distance)
            )
            .opacity(1.0 - Double(progress))
            .rotationEffect(.degrees(rotation))
            .shadow(color: Color.gold.opacity(0.6), radius: 4)
    }
}