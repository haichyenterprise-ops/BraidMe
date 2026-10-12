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
    @State private var contentOffset: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

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
                        HStack(spacing: Space.xxs) {
                            Image(systemName: "map")
                                .font(.bmUI(14, weight: .semibold))
                            Text("Back to map")
                                .font(.bmUI(15, weight: .semibold))
                        }
                        .foregroundStyle(Color.appInkInverse)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .padding(.vertical, Space.xs)
                        .background(Color.appInk, in: Capsule())
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
            Circle()
                .stroke(Color.appDivider, lineWidth: 4)
                .frame(width: 100, height: 100)
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 100)
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 40, height: 40)
        }
    }

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text("Booking confirmed")
                .font(.bmDisplay(28, weight: .semibold))
                .foregroundStyle(Color.appInk)
            Text("\(braider.name) will see your appointment shortly.")
                .font(.bmUI(14))
                .foregroundStyle(Color.appAsh)
                .multilineTextAlignment(.center)
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
        .padding(.horizontal, Space.lg)
    }

    private func row(label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.bmUI(13))
                .foregroundStyle(Color.appAsh)
            Spacer()
            Text(value)
                .font(emphasized ? .bmMono(15, weight: .semibold) : .bmUI(14, weight: .medium))
                .foregroundStyle(emphasized ? Color.appAccent : Color.appInk)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var nextSteps: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "bell.badge")
                .font(.bmUI(13))
                .foregroundStyle(Color.appAccent)
            Text("You'll get a message from \(braider.name) in your Bookings tab to confirm final details.")
                .font(.bmUI(12))
                .foregroundStyle(Color.appAsh)
                .lineSpacing(3)
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

        withAnimation(.easeOut(duration: 0.55)) { circleProgress = 1 }
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.easeOut(duration: 0.35)) { checkProgress = 1 }
        try? await Task.sleep(nanoseconds: 250_000_000)
        withAnimation(Motion.reveal) {
            contentOpacity = 1
            contentOffset = 0
        }
    }

    private func finish() {
        NotificationCenter.default.post(name: .bookingFlowFinished, object: nil)
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.80))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.20))
        return path
    }
}

extension Notification.Name {
    static let bookingFlowFinished = Notification.Name("bookingFlowFinished")
}