import SwiftUI

// =============================================================================
// GlobeMorphView — Simple elegant transition
//
// No stars, no vortex, no confetti. Just:
//   0.00  Avatar appears at small scale at center
//   0.30  Avatar expands with spring
//   0.60  Gold ring orbits around once
//   1.10  Text reveals
//   1.60  Fade to profile
// =============================================================================

struct GlobeMorphView: View {
    let braider: Braider
    let onFinish: () -> Void

    // Ring
    @State private var ringRotation: Double = 0
    @State private var ringOpacity: Double = 0

    // Avatar
    @State private var avatarScale: CGFloat = 0.5
    @State private var avatarOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    // Text
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var starOpacity: Double = 0

    // Exit
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0

    @State private var sequenceID = UUID()

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            ZStack {
                // Gold halo glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.goldLight.opacity(0.45),
                                Color.gold.opacity(0.18),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .blur(radius: 24)
                    .opacity(glowOpacity)

                // Orbiting ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.goldLight.opacity(0),
                                Color.goldLight.opacity(0.85),
                                Color.gold.opacity(0.4),
                                Color.goldLight.opacity(0)
                            ],
                            center: .center,
                            angle: .degrees(ringRotation)
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 240, height: 240)
                    .opacity(ringOpacity)

                // Avatar medallion
                avatarMedallion

                // Text
                VStack(spacing: 10) {
                    Text("ENTERING")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(Color.gold)
                        .opacity(textOpacity)

                    Text(braider.name)
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(-1)
                        .foregroundStyle(.white)
                        .opacity(textOpacity)
                        .offset(y: textOffset)

                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: Double(i) < braider.rating.rounded() ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gold)
                        }
                        Text(braider.ratingText)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.leading, 2)
                    }
                    .opacity(starOpacity)
                    .offset(y: textOffset)
                }
                .offset(y: 200)
            }
            .scaleEffect(exitScale)
            .opacity(exitOpacity)
        }
        .onAppear { play() }
    }

    private var avatarMedallion: some View {
        ZStack {
            // Outer gold border
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.goldLight, Color.gold, Color.goldDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 190, height: 190)

            // Frosted glass container
            Circle()
                .fill(Color.glassTintStrong)
                .frame(width: 178, height: 178)
                .shadow(color: Color.gold.opacity(0.55), radius: 32, y: 8)

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

            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 1)
                .frame(width: 160, height: 160)
        }
        .frame(width: 190, height: 190)
        .scaleEffect(avatarScale)
        .opacity(avatarOpacity)
    }

    private func play() {
        let token = UUID()
        sequenceID = token

        // Avatar appears + scales up
        withAnimation(.easeOut(duration: 0.20)) {
            avatarOpacity = 1
        }
        withAnimation(.spring(response: 0.70, dampingFraction: 0.72)) {
            avatarScale = 1.0
        }

        // Glow fades in
        withAnimation(.easeOut(duration: 0.60).delay(0.15)) {
            glowOpacity = 1.0
        }

        // Ring fades in + rotates once
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard sequenceID == token else { return }
            Haptic.light()
            withAnimation(.easeIn(duration: 0.30)) {
                ringOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.0)) {
                ringRotation = 360
            }
        }

        // Text reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) {
            guard sequenceID == token else { return }
            Haptic.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.15)) {
                starOpacity = 1
            }
        }

        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            guard sequenceID == token else { return }
            Haptic.medium()
            withAnimation(.easeIn(duration: 0.35)) {
                exitScale = 1.15
                exitOpacity = 0
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            guard sequenceID == token else { return }
            onFinish()
        }
    }
}