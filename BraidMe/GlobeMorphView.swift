import SwiftUI
import UIKit

// =============================================================================
// GlobeMorphView — 11.4s cinematic globe transition.
//
//  0.00  Stars fade in (behind the black overlay MainTabView uses)
//  0.00  Globe fades in at CENTER, SMALL
//  2.20  Globe fully visible (idle spin 0.3)
//  3.50  Accelerate: 0.3 → 1.0 → 2.5 → 4.0 over 4 seconds
//  7.50  Continents dissolve, oceans glow
//  8.00  Gold flash, morph completes
//  8.30  Avatar revealed at center
// 10.80  ZOOM INTO AVATAR (0.6s) — scale 1.0 → 4.5
// 11.40  Profile handed off
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let isFastMode: Bool
    let onFinish: () -> Void

    // SceneKit bindings
    @State private var cameraDistance: Float = 7.5
    @State private var globeOpacity: Float = 0
    @State private var atmosphereOpacity: Float = 0
    @State private var ringOpacity: Float = 0
    @State private var spinSpeed: Float = 0
    @State private var globeScale: Float = 1.0
    @State private var morphProgress: Float = 0

    // Overlay state
    @State private var starOpacity: Double = 0
    @State private var backdropOpacity: Double = 0
    @State private var goldFlashOpacity: Double = 0

    @State private var avatarScale: CGFloat = 0.4
    @State private var avatarOpacity: Double = 0

    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var starRatingOpacity: Double = 0

    // Final zoom-into-avatar
    @State private var zoomOuterScale: CGFloat = 1.0
    @State private var sceneExitOpacity: Double = 1.0

    @State private var sequenceID = UUID()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // ─── Pure black backdrop ───
            Color.black
                .ignoresSafeArea()
                .opacity(backdropOpacity)

            // ─── Star field ───
            starField
                .opacity(starOpacity)

            // ─── Everything below scales together for the final zoom ───
            ZStack {
                // SceneKit globe
                GlobeSceneView(
                    cameraDistance: $cameraDistance,
                    globeOpacity: $globeOpacity,
                    atmosphereOpacity: $atmosphereOpacity,
                    ringOpacity: $ringOpacity,
                    spinSpeed: $spinSpeed,
                    scale: $globeScale,
                    morphProgress: $morphProgress
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                // Gold flash (during morph)
                Color(red: 1.0, green: 0.88, blue: 0.55)
                    .ignoresSafeArea()
                    .opacity(goldFlashOpacity)
                    .allowsHitTesting(false)
                    .blendMode(.screen)

                // Gold glow around avatar
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
                    .opacity(avatarOpacity * 0.7)
                    .allowsHitTesting(false)

                // Avatar medallion
                avatarMedallion

                // Text block
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
                    .opacity(starRatingOpacity)
                    .offset(y: textOffset)
                }
                .offset(y: 250)
            }
            .scaleEffect(zoomOuterScale)
            .opacity(sceneExitOpacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onAppear { play() }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Star field

    private var starField: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: 0xC0FFEE)

            // Far layer: dim tiny stars
            for _ in 0..<140 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.3...0.7, using: &rng)
                let alpha = Double.random(in: 0.2...0.5, using: &rng)
                let circle = Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2))
                context.fill(circle, with: .color(.white.opacity(alpha)))
            }

            // Near layer: brighter stars
            for _ in 0..<60 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.8...1.6, using: &rng)
                let alpha = Double.random(in: 0.5...0.95, using: &rng)
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
                            colors: [Color.goldLight, Color.gold, Color.goldDeep],
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
            starOpacity = 1
            globeOpacity = 1
            atmosphereOpacity = 1
            spinSpeed = 1
            avatarOpacity = 1
            avatarScale = 1
            textOpacity = 1
            starRatingOpacity = 1
            textOffset = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onFinish()
            }
            return
        }

        // ─── Timing (fast mode compresses everything by ~55%) ───
        let m: Double = isFastMode ? 0.5 : 1.0

        let tStars       = 0.0 * m
        let tGlobe       = 2.20 * m
        let tIdleSpin    = 3.00 * m
        let tAccelerate  = 3.50 * m
        let tMorphStart  = 7.50 * m
        let tFlash       = 8.00 * m
        let tAvatar      = 8.30 * m
        let tCalm        = 8.80 * m
        let tZoom        = 10.80 * m
        let tComplete    = 11.40 * m

        // ─── 0.00 — Backdrop + stars fade in ───
        withAnimation(.easeIn(duration: 0.6)) {
            backdropOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + tStars) {
            guard sequenceID == token else { return }
            withAnimation(.easeIn(duration: 0.6)) {
                starOpacity = 1
            }
        }

        // ─── 2.20 — Globe fades in, small, centered, idle spin ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tGlobe) {
            guard sequenceID == token else { return }
            Haptic.light()
            withAnimation(.easeIn(duration: 0.8)) {
                globeOpacity = 1
                atmosphereOpacity = 1
                ringOpacity = 0.85
            }
        }

        // ─── 3.00 — Idle spin ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tIdleSpin) {
            guard sequenceID == token else { return }
            spinSpeed = 0.3
        }

        // ─── 3.50 — Begin 4-second acceleration ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tAccelerate) {
            guard sequenceID == token else { return }
            Haptic.medium()

            let rampSteps = 40
            let rampDuration = (tMorphStart - tAccelerate)  // 4.0s in normal mode
            let stepInterval = rampDuration / Double(rampSteps)

            for step in 0..<rampSteps {
                let t = Double(step) / Double(rampSteps)
                // Ease-in curve: slow build, steep end
                let eased = pow(t, 1.7)
                let speed = Float(0.3 + eased * 3.7)   // 0.3 → 4.0

                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepInterval) {
                    guard sequenceID == token else { return }
                    spinSpeed = speed

                    // Subtle camera push-in as speed climbs
                    cameraDistance = Float(7.5 - eased * 1.5)   // 7.5 → 6.0

                    // Slight globe scale-up as it speeds
                    globeScale = Float(1.0 + eased * 0.1)
                }
            }
        }

        // ─── 7.50 — Peak speed, morph begins ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tMorphStart) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            // Ramp morph progress over 0.5s
            let morphDuration: TimeInterval = 0.5
            let morphSteps = 20
            let morphInterval = morphDuration / Double(morphSteps)

            for step in 0..<morphSteps {
                let t = Float(step) / Float(morphSteps)
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * morphInterval) {
                    guard sequenceID == token else { return }
                    morphProgress = t
                }
            }
        }

        // ─── 8.00 — Gold flash peak ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tFlash) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            withAnimation(.easeOut(duration: 0.15)) {
                goldFlashOpacity = 1.0
            }
        }

        // ─── 8.30 — Flash recedes, avatar revealed ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tAvatar) {
            guard sequenceID == token else { return }
            Haptic.success()

            // Globe disappears
            withAnimation(.easeOut(duration: 0.4)) {
                globeOpacity = 0
                atmosphereOpacity = 0
                ringOpacity = 0
                morphProgress = 1
            }

            // Flash recedes
            withAnimation(.easeIn(duration: 0.5)) {
                goldFlashOpacity = 0
            }

            // Avatar materializes
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
                avatarScale = 1.0
                avatarOpacity = 1.0
            }
        }

        // ─── 8.80 — Calm. Text reveal. ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tCalm) {
            guard sequenceID == token else { return }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.2)) {
                starRatingOpacity = 1
            }
        }

        // ─── 10.80 — ZOOM INTO AVATAR ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tZoom) {
            guard sequenceID == token else { return }
            Haptic.heavy()

            // Text fades out in the first 0.15s so it doesn't distract
            withAnimation(.easeOut(duration: 0.15)) {
                textOpacity = 0
                starRatingOpacity = 0
            }

            // The entire scene scales up aggressively
            withAnimation(.easeIn(duration: 0.55)) {
                zoomOuterScale = 4.5
            }

            // Scene fades slightly as it peaks, so the profile is behind
            withAnimation(.easeIn(duration: 0.55).delay(0.1)) {
                sceneExitOpacity = 0
            }
        }

        // ─── 11.40 — Complete ───
        DispatchQueue.main.asyncAfter(deadline: .now() + tComplete) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}