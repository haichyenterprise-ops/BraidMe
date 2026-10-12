import SwiftUI
import UIKit

// =============================================================================
// GlobeMorphView — Full-screen globe transition overlay.
//
// Rendered inside a ZStack — NOT a modal. Fades in over the map. Plays a
// 3D globe spin + morph to avatar sequence. Fires onFinish when done.
//
// Cinematic: 2.9s. Fast: 1.4s.
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let isFastMode: Bool
    let onFinish: () -> Void

    // SceneKit driven
    @State private var rotation: Float = 0
    @State private var ringRotation: Float = 0
    @State private var cameraDistance: Float = 4.2
    @State private var globeOpacity: Float = 0
    @State private var atmosphereOpacity: Float = 0
    @State private var ringOpacity: Float = 0

    // Overlays
    @State private var backdropOpacity: Double = 0
    @State private var goldGlowOpacity: Double = 0
    @State private var avatarScale: CGFloat = 0.4
    @State private var avatarOpacity: Double = 0
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
                .opacity(backdropOpacity * 0.85)

            // ─── SceneKit globe ───
            GlobeSceneView(
                rotation: $rotation,
                cameraDistance: $cameraDistance,
                globeOpacity: $globeOpacity,
                atmosphereOpacity: $atmosphereOpacity,
                ringOpacity: $ringOpacity,
                ringRotation: $ringRotation
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ─── Gold glow burst (during morph) ───
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.goldLight.opacity(0.5),
                            Color.gold.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(goldGlowOpacity)
                .allowsHitTesting(false)

            // ─── Avatar medallion ───
            avatarMedallion

            // ─── Text block ───
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
            .offset(y: 250)
        }
        .ignoresSafeArea()
        .opacity(exitOpacity)
        .scaleEffect(exitScale)
        .allowsHitTesting(true)
        .onAppear { play() }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Star field

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
    // MARK: - Avatar medallion

    private var avatarMedallion: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.55),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 14)
                .opacity(avatarOpacity)

            Circle()
                .fill(.regularMaterial)
                .frame(width: 148, height: 148)
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
                        lineWidth: 4
                    )
                )
                .shadow(color: Color.gold.opacity(0.7), radius: 30, y: 6)

            if braider.avatarUrl.isEmpty {
                Circle()
                    .fill(Color.gold.opacity(0.20))
                    .frame(width: 130, height: 130)
                    .overlay(
                        Text(braider.initials)
                            .font(.system(size: 48, weight: .bold, design: .serif))
                            .foregroundStyle(Color.gold)
                    )
            } else {
                RemoteImage(url: braider.avatarUrl)
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
            }
        }
        .scaleEffect(avatarScale)
        .opacity(avatarOpacity)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Sequence

    private func play() {
        let token = UUID()
        sequenceID = token

        if reduceMotion {
            backdropOpacity = 1
            globeOpacity = 1
            atmosphereOpacity = 1
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

        let tFadeIn: TimeInterval = isFastMode ? 0.20 : 0.40
        let tSpinUp: TimeInterval = isFastMode ? 0.25 : 0.55
        let tMorph: TimeInterval = isFastMode ? 0.55 : 1.30
        let tAvatar: TimeInterval = isFastMode ? 0.75 : 1.70
        let tText: TimeInterval = isFastMode ? 0.90 : 1.95
        let tExit: TimeInterval = isFastMode ? 1.10 : 2.35
        let tComplete: TimeInterval = isFastMode ? 1.45 : 2.90

        // ─── Phase A: fade in backdrop + globe + atmosphere ───
        withAnimation(.easeIn(duration: tFadeIn)) {
            backdropOpacity = 1
            globeOpacity = 1
            atmosphereOpacity = 1
        }

        // ─── Phase B: spin ───
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            rotation = 360 * 6
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            ringRotation = 360 * 4
        }

        // ─── Phase C: rings appear + camera pushes in ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tSpinUp) {
            guard sequenceID == token else { return }
            Haptic.light()

            withAnimation(.easeInOut(duration: 0.9)) {
                ringOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2)) {
                cameraDistance = 3.2
            }
        }

        // ─── Phase D: globe fades, gold glow bursts ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tMorph) {
            guard sequenceID == token else { return }
            Haptic.medium()

            withAnimation(.easeInOut(duration: 0.55)) {
                globeOpacity = 0.35
                atmosphereOpacity = 0.4
                ringOpacity = 0.3
                goldGlowOpacity = 1.0
            }
        }

        // ─── Phase E: avatar materializes ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tAvatar) {
            guard sequenceID == token else { return }
            Haptic.success()

            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                avatarScale = 1.0
                avatarOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4)) {
                globeOpacity = 0.15
                atmosphereOpacity = 0.2
                ringOpacity = 0.15
                goldGlowOpacity = 0.55
            }
        }

        // ─── Phase F: text reveal ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tText) {
            guard sequenceID == token else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.15)) {
                starOpacity = 1
            }
        }

        // ─── Phase G: exit ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tExit) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            withAnimation(.easeIn(duration: 0.4)) {
                exitScale = 1.2
                exitOpacity = 0
                goldGlowOpacity = 0
            }
        }

        // ─── Phase H: complete ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tComplete) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}