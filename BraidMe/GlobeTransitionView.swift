import SwiftUI
import UIKit

// =============================================================================
// GlobeTransitionView — Real spinning 3D globe transition
//
// Present as a fullScreenCover. It plays for ~2.2s then calls `onFinish`.
// The parent sets `selectedBraider` inside `onFinish` — the modal
// dismisses cleanly and the destination pushes with no black flash.
// =============================================================================

struct GlobeTransitionView: View {
    let braider: Braider
    let onFinish: () -> Void

    // ─── Animation state ───
    @State private var globeRotation: Double = 0
    @State private var globeScale: CGFloat = 0.4
    @State private var globeOpacity: Double = 0
    @State private var warpPhase: CGFloat = 0
    @State private var warpOpacity: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.3
    @State private var avatarOpacity: Double = 0
    @State private var ringPulse: CGFloat = 1
    @State private var ringOpacity: Double = 0.9
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 24
    @State private var starOpacity: Double = 0
    @State private var exitFade: Double = 1
    @State private var particleOffset: CGFloat = 0
    @State private var sequenceID = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // ─── Deep space backdrop ───
            LinearGradient(
                colors: [
                    Color(hex: "#000000"),
                    Color(hex: "#0A0A18"),
                    Color(hex: "#050510")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(exitFade)

            // ─── Star field ───
            starField
                .opacity(exitFade)

            // ─── Warp streaks ───
            warpStreaks
                .opacity(warpOpacity * exitFade)

            // ─── Globe assembly ───
            globeAssembly
                .opacity(exitFade)

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
            .offset(y: 230)
            .opacity(exitFade)

            // ─── White flash ───
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            playAnimation()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Star field
    // ═══════════════════════════════════════════════════════════════

    private var starField: some View {
        GeometryReader { geo in
            Canvas { context, size in
                var rng = SeededRNG(seed: 0xBEEF)
                for _ in 0..<180 {
                    let x = CGFloat.random(in: 0...size.width, using: &rng)
                    let y = CGFloat.random(in: 0...size.height, using: &rng)
                    let r = CGFloat.random(in: 0.4...1.4, using: &rng)
                    let opacity = Double.random(in: 0.2...0.9, using: &rng)
                    let circle = Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                    context.fill(circle, with: .color(.white.opacity(opacity)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Warp streaks
    // ═══════════════════════════════════════════════════════════════

    private var warpStreaks: some View {
        ZStack {
            ForEach(0..<48, id: \.self) { i in
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
                    .frame(width: 1.2, height: 320)
                    .offset(y: -120)
                    .rotationEffect(.degrees(Double(i) * 7.5))
                    .scaleEffect(
                        x: 1,
                        y: 0.3 + warpPhase * 1.6,
                        anchor: .bottom
                    )
                    .offset(y: 40)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Globe
    // ═══════════════════════════════════════════════════════════════

    private var globeAssembly: some View {
        ZStack {
            // ── Outer halo glow ──
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.28),
                            Color.gold.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 240
                    )
                )
                .frame(width: 480, height: 480)
                .opacity(globeOpacity * 0.85)

            // ── Expanding ring pulses ──
            Circle()
                .stroke(Color.goldLight.opacity(ringOpacity), lineWidth: 1.8)
                .frame(width: 260, height: 260)
                .scaleEffect(ringPulse)

            Circle()
                .stroke(Color.gold.opacity(ringOpacity * 0.5), lineWidth: 1)
                .frame(width: 260, height: 260)
                .scaleEffect(ringPulse * 1.35)

            // ── The globe sphere ──
            globeSphere

            // ── Avatar medallion ──
            avatarMedallion
        }
        .scaleEffect(globeScale)
        .opacity(globeOpacity)
    }

    private var globeSphere: some View {
        ZStack {
            // Base sphere — radial gradient for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#2A2416").opacity(1),
                            Color(hex: "#15110A").opacity(1),
                            Color(hex: "#050507").opacity(1)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 5,
                        endRadius: 180
                    )
                )
                .frame(width: 300, height: 300)

            // Gold graticule — rotating meridian & parallel lines
            GraticuleView()
                .frame(width: 300, height: 300)
                .rotation3DEffect(
                    .degrees(globeRotation * 0.6),
                    axis: (x: 0.12, y: 1, z: 0.05),
                    perspective: 0.35
                )

            // Rim light
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.goldLight.opacity(0.95),
                            Color.gold.opacity(0.4),
                            Color.goldDeep.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 300, height: 300)

            // Inner shadow at bottom-right for spherical depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.55)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 60,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)

            // Specular highlight top-left
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 80)
                .offset(x: -70, y: -80)
                .blur(radius: 6)
                .blendMode(.screen)
        }
        .shadow(color: Color.gold.opacity(0.35), radius: 50, y: 10)
        .shadow(color: Color.goldDeep.opacity(0.5), radius: 90)
    }

    private var avatarMedallion: some View {
        ZStack {
            // Glow halo behind avatar
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.55),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 10)

            // Avatar container
            Circle()
                .fill(.regularMaterial)
                .frame(width: 130, height: 130)
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
                .shadow(color: Color.gold.opacity(0.65), radius: 30, y: 6)

            if braider.avatarUrl.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.20))
                    .frame(width: 116, height: 116)
                    .overlay(
                        Text(braider.initials)
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 116, height: 116)
                    .clipShape(Circle())
            }
        }
        .scaleEffect(avatarScale)
        .opacity(avatarOpacity)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Animation sequence
    // ═══════════════════════════════════════════════════════════════

    private func playAnimation() {
        let token = UUID()
        sequenceID = token

        if reduceMotion {
            // Skip to end immediately
            globeScale = 1
            globeOpacity = 1
            avatarScale = 1
            avatarOpacity = 1
            textOpacity = 1
            starOpacity = 1
            textOffset = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onFinish()
            }
            return
        }

        // Phase 1 (0.00s → 0.35s) — Warp burst
        withAnimation(.easeOut(duration: 0.35)) {
            warpPhase = 1
            warpOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard sequenceID == token else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                warpOpacity = 0
            }
        }

        // Phase 2 (0.10s) — Globe scales in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            guard sequenceID == token else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
                globeScale = 1
                globeOpacity = 1
            }
            // Continuous spin
            withAnimation(.linear(duration: 3.2)) {
                globeRotation = 1080
            }
        }

        // Phase 3 (0.35s) — Ring pulse loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard sequenceID == token else { return }
            withAnimation(
                .easeOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                ringPulse = 1.8
                ringOpacity = 0
            }
        }

        // Phase 4 (0.55s) — Avatar medallion pops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard sequenceID == token else { return }
            Haptic.medium()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                avatarScale = 1
                avatarOpacity = 1
            }
        }

        // Phase 5 (0.95s) — Text reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard sequenceID == token else { return }
            Haptic.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.15)) {
                starOpacity = 1
            }
        }

        // Phase 6 (1.55s) — Flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            guard sequenceID == token else { return }
            Haptic.heavy()
            withAnimation(.easeOut(duration: 0.18)) {
                flashOpacity = 0.9
            }
        }

        // Phase 7 (1.75s) — Fade overlay out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.75) {
            guard sequenceID == token else { return }
            withAnimation(.easeIn(duration: 0.30)) {
                flashOpacity = 0
                exitFade = 0
            }
        }

        // Phase 8 (2.05s) — Fire completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Graticule (latitude + longitude lines on the globe)
// ═══════════════════════════════════════════════════════════════════

private struct GraticuleView: View {
    var body: some View {
        ZStack {
            // Longitude lines (ellipses that get thinner toward poles)
            ForEach(0..<6, id: \.self) { i in
                Ellipse()
                    .stroke(Color.gold.opacity(0.55), lineWidth: 0.9)
                    .frame(
                        width: 40 + CGFloat(i) * 45,
                        height: 300
                    )
            }

            // Latitude lines (horizontal ellipses squashed vertically)
            ForEach(1..<7, id: \.self) { i in
                let y = -150 + CGFloat(i) * 50
                let visibleHeight = sqrt(max(0, 150 * 150 - y * y)) * 2
                Ellipse()
                    .stroke(Color.gold.opacity(0.45), lineWidth: 0.8)
                    .frame(
                        width: visibleHeight,
                        height: 12
                    )
                    .offset(y: y)
            }
        }
    }
}