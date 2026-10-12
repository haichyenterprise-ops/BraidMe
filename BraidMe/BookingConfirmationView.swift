import SwiftUI

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
    @State private var confettiTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient celebration gradient
            RadialGradient(
                colors: [Color.appAccent.opacity(0.12), .clear],
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
                                .font(.bmUI(14, weight: .semibold))
                            Text("Back to map")
                                .font(.bmUI(15, weight: .semibold))
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

    private var checkmark: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.appDivider, lineWidth: 5)
                .frame(width: 120, height: 120)

            // Progress ring
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)

            // Glow
            Circle()
                .fill(Color.appAccent.opacity(0.15))
                .frame(width: 120, height: 120)
                .blur(radius: circleProgress > 0.9 ? 20 : 0)
                .opacity(circleProgress > 0.9 ? 1 : 0)

            // Checkmark
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 48, height: 48)
        }
    }

    private var header: some View {
        VStack(spacing: Space.sm) {
            Text("Booking confirmed")
                .font(.bmHero(30))
                .foregroundStyle(Color.appInk)
                .multilineTextAlignment(.center)

            Text("\(braider.name) will see your appointment shortly.")
                .font(.bmUI(15))
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
        .shadow(color: Color.appInk.opacity(0.08), radius: 20, y: 10)
        .padding(.horizontal, Space.lg)
    }

    private func row(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
            Spacer()
            Text(value)
                .font(emphasized ? .bmMono(16, weight: .bold) : .bmUI(14, weight: .medium))
                .foregroundStyle(emphasized ? Color.appAccent : Color.appInk)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var nextSteps: some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.appAccent)
                    .frame(width: 36, height: 36)
                Image(systemName: "bell.badge.fill")
                    .font(.bmUI(14))
                    .foregroundStyle(Color.appInkInverse)
            }
            Text("You'll get a message from \(braider.name) in your Bookings tab to confirm final details.")
                .font(.bmUI(13))
                .foregroundStyle(Color.appInkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Color.appAccentTint)
        .clipShape(RoundedRectangle(cornerRadius: Radius.button))
        .padding(.horizontal, Space.lg)
    }

    private func playAnimation() async {
        Haptic.success()

        if reduceMotion {
            circleProgress = 1
            checkProgress = 1
            contentOpacity = 1
            contentOffset = 0
            return
        }

        withAnimation(.easeOut(duration: 0.6)) { circleProgress = 1 }
        try? await Task.sleep(nanoseconds: 450_000_000)
        Haptic.light()
        withAnimation(.easeOut(duration: 0.4)) { checkProgress = 1 }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(Motion.heroReveal) {
            contentOpacity = 1
            contentOffset = 0
        }
    }

    private func finish() {
        NotificationCenter.default.post(name: .bookingFlowFinished, object: nil)
    }
}

extension Notification.Name {
    static let bookingFlowFinished = Notification.Name("bookingFlowFinished")
}