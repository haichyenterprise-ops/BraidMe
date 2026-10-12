import SwiftUI

// =============================================================================
// BookingConfirmationView — Success screen
// Animated checkmark with glow burst, celebratory gradient, staggered text reveal.
// =============================================================================

struct BookingConfirmationView: View {
    let braider: Braider
    let service: BraidService
    let date: Date
    let time: String
    let total: Int

    @Environment(\.dismiss) private var dismiss

    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    @State private var glowScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0
    @State private var ringPulse: CGFloat = 1
    @State private var ringOpacity: Double = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient celebration gradient
            RadialGradient(
                colors: [Color.gold.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.xl) {
                    Spacer().frame(height: Space.xxl)

                    checkmark.padding(.bottom, Space.lg)

                    header
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)

                    summary
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)

                    nextSteps
                        .opacity(contentOpacity)
                        .offset(y: contentOffset)

                    Spacer().frame(height: Space.xl)

                    Button {
                        Haptic.press()
                        finish()
                    } label: {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back to map")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.appInkInverse)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(Color.appInk, in: Capsule())
                        .shadow(color: Color.appInk.opacity(0.25), radius: 16, y: 8)
                    }
                    .buttonStyle(BMPressStyle())
                    .padding(.horizontal, Space.lg)
                    .opacity(contentOpacity)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await playAnimation() }
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Checkmark

    private var checkmark: some View {
        ZStack {
            // Outer gold glow burst
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.gold.opacity(0.6),
                            Color.gold.opacity(0.15),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)
                .blur(radius: 12)

            // Expanding ring pulse
            Circle()
                .stroke(Color.gold.opacity(0.5), lineWidth: 1.5)
                .frame(width: 120, height: 120)
                .scaleEffect(ringPulse)
                .opacity(ringOpacity)

            // Track circle
            Circle()
                .stroke(Color.appDivider, lineWidth: 5)
                .frame(width: 120, height: 120)

            // Progress ring
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.goldLight, Color.gold, Color.goldDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)

            // Checkmark
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    Color.gold,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 48, height: 48)
        }
    }

    private var header: some View {
        VStack(spacing: Space.sm) {
            Text("Booking confirmed")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Color.appInk)
                .multilineTextAlignment(.center)

            Text("\(braider.name) will see your appointment shortly.")
                .font(.system(size: 15))
                .foregroundStyle(Color.appAsh)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, Space.xl)
        }
    }

    private var summary: some View {
        VStack(spacing: 0) {
            row(label: "Service", value: service.name)
            BMDivider(inset: Space.md)
            row(label: "Date", value: date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            BMDivider(inset: Space.md)
            row(label: "Time", value: time)
            BMDivider(inset: Space.md)
            row(label: "Total", value: "£\(total)", emphasized: true)
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.appDivider, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
        .padding(.horizontal, Space.lg)
    }

    private func row(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.appAsh)
            Spacer()
            Text(value)
                .font(emphasized ? .system(size: 16, weight: .bold, design: .monospaced) : .system(size: 14, weight: .medium))
                .foregroundStyle(emphasized ? Color.gold : Color.appInk)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var nextSteps: some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.gold)
                    .frame(width: 36, height: 36)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appInkInverse)
            }
            Text("You'll get a message from \(braider.name) in your Bookings tab to confirm final details.")
                .font(.system(size: 13))
                .foregroundStyle(Color.appInkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Color.gold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.horizontal, Space.lg)
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Animation

    private func playAnimation() async {
        Haptic.success()

        if reduceMotion {
            circleProgress = 1
            checkProgress = 1
            glowOpacity = 1
            glowScale = 1
            contentOpacity = 1
            contentOffset = 0
            return
        }

        // Ring pulse loop
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            ringPulse = 1.8
            ringOpacity = 0
        }

        // Circle progress
        withAnimation(.easeOut(duration: 0.55)) {
            circleProgress = 1
        }

        try? await Task.sleep(nanoseconds: 400_000_000)

        // Glow burst
        Haptic.medium()
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
            glowScale = 1.0
            glowOpacity = 1.0
        }

        // Checkmark
        withAnimation(.easeOut(duration: 0.35)) {
            checkProgress = 1
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        // Content reveal
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            contentOpacity = 1
            contentOffset = 0
        }
    }

    private func finish() {
        NotificationCenter.default.post(name: .bookingFlowFinished, object: nil)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Notification Names
// ═══════════════════════════════════════════════════════════════════

extension Notification.Name {
    static let bookingFlowFinished = Notification.Name("bookingFlowFinished")
}