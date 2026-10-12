import SwiftUI

struct BookingConfirmationView: View {
    let braider: Braider
    let service: BraidService
    let date: Date
    let time: String
    let total: Int

    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var glow = false
    @State private var contentShown = false
    @State private var confetti = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            AuroraBackground(intensity: 0.9)

            if confetti && !reduceMotion {
                ConfettiBurst()
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.xl) {
                    checkmark
                        .padding(.top, Space.xxl)

                    header
                        .reveal(contentShown, delay: 0.0, offset: 18)

                    ticket
                        .reveal(contentShown, delay: 0.12, offset: 28, blur: 0)

                    nextSteps
                        .reveal(contentShown, delay: 0.22, offset: 20, blur: 0)

                    BMPrimaryButton(title: "Back to map", icon: "map.fill") {
                        finish()
                    }
                    .padding(.horizontal, Space.lg)
                    .reveal(contentShown, delay: 0.3, offset: 20, blur: 0)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await playAnimation() }
    }

    // MARK: - Check

    private var checkmark: some View {
        ZStack {
            Circle()
                .fill(Color.bmGilt.opacity(0.35))
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .scaleEffect(glow ? 1.25 : 0.8)
                .opacity(glow ? 1 : 0)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 5)
                .frame(width: 112, height: 112)
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    AngularGradient(
                        colors: [Color.bmGilt, Color.bmEmber, Color.bmOrchid, Color.bmGilt],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 112, height: 112)
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    LinearGradient.bmGiltGradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 46, height: 46)
        }
    }

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text("You're booked")
                .font(.bmDisplay(38, weight: .semibold))
                .foregroundStyle(Color.bmText)
            Text("\(braider.name) will see your appointment right away.")
                .font(.bmUI(15))
                .foregroundStyle(Color.bmTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)
        }
    }

    // MARK: - Ticket

    private var ticket: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    BMAvatar(url: braider.avatarUrl, size: 44, initials: bmInitials(braider.name))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.name)
                            .font(.bmDisplay(20, weight: .semibold))
                            .foregroundStyle(Color.bmText)
                            .lineLimit(2)
                        Text("with \(braider.name)")
                            .font(.bmUI(13))
                            .foregroundStyle(Color.bmTextDim)
                    }
                    Spacer()
                }

                HStack(alignment: .top) {
                    ticketField(label: "Date", value: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    Spacer()
                    ticketField(label: "Time", value: time)
                    Spacer()
                    ticketField(label: "Total", value: "£\(total)", highlight: true)
                }
            }
            .padding(Space.md)

            perforation

            HStack(spacing: Space.sm) {
                BraidMark(length: 70, thickness: 26, strand: 6, horizontal: true, cycles: 1.6, edge: Color.bmSurface)
                Spacer()
                Text("BraidMe")
                    .font(.bmDisplay(16, weight: .semibold))
                    .foregroundStyle(Color.bmTextDim)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
        }
        .bmCard(radius: Radius.card)
        .padding(.horizontal, Space.lg)
    }

    private func ticketField(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.bmUI(12, weight: .medium))
                .foregroundStyle(Color.bmTextDim)
            Text(value)
                .font(.bmNum(16, weight: .bold))
                .foregroundStyle(highlight ? Color.bmGilt : Color.bmText)
        }
    }

    private var perforation: some View {
        ZStack {
            Line()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                .frame(height: 1)
                .padding(.horizontal, Space.lg)
            HStack {
                Circle().fill(Color.bmBase).frame(width: 22, height: 22).offset(x: -11)
                Spacer()
                Circle().fill(Color.bmBase).frame(width: 22, height: 22).offset(x: 11)
            }
        }
        .frame(height: 22)
    }

    private var nextSteps: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "bell.badge.fill")
                .font(.bmUI(14, weight: .semibold))
                .foregroundStyle(Color.bmOrchid)
            Text("Message \(braider.name) from My Bookings to confirm any final details.")
                .font(.bmUI(13))
                .foregroundStyle(Color.bmTextDim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bmOrchid.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(Color.bmOrchid.opacity(0.28), lineWidth: 0.8)
        )
        .padding(.horizontal, Space.lg)
    }

    // MARK: - Animation

    private func playAnimation() async {
        if reduceMotion {
            circleProgress = 1
            checkProgress = 1
            contentShown = true
            Haptic.success()
            return
        }

        withAnimation(.easeOut(duration: 0.7)) { circleProgress = 1 }
        withAnimation(.easeOut(duration: 1.2)) { glow = true }
        try? await Task.sleep(nanoseconds: 550_000_000)
        withAnimation(.easeOut(duration: 0.4)) { checkProgress = 1 }
        try? await Task.sleep(nanoseconds: 250_000_000)
        Haptic.success()
        confetti = true
        withAnimation(Motion.reveal) { contentShown = true }
    }

    private func finish() {
        NotificationCenter.default.post(name: .bookingFlowFinished, object: nil)
    }
}

// MARK: - Shapes

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.80))
        path.addLine(to: CGPoint(x: rect.width * 0.88, y: rect.height * 0.20))
        return path
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Confetti

private struct ConfettiParticle {
    let angle: Double
    let speed: Double
    let spin: Double
    let colorIndex: Int
    let size: CGFloat
}

private struct ConfettiBurst: View {
    @State private var start = Date()
    private let particles: [ConfettiParticle] = ConfettiBurst.makeParticles()
    private let palette: [Color] = [Color.bmGilt, Color.bmGiltHi, Color.bmOrchid, Color.bmEmber, Color.white]

    private static func makeParticles() -> [ConfettiParticle] {
        var list: [ConfettiParticle] = []
        for _ in 0..<64 {
            list.append(
                ConfettiParticle(
                    angle: Double.random(in: (-Double.pi * 0.95)...(-Double.pi * 0.05)),
                    speed: Double.random(in: 220...520),
                    spin: Double.random(in: -8...8),
                    colorIndex: Int.random(in: 0..<5),
                    size: CGFloat.random(in: 6...11)
                )
            )
        }
        return list
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < 3.2 else { return }
                let fade = max(0.0, 1.0 - t / 3.2)
                for p in particles {
                    let x = Double(size.width) / 2 + cos(p.angle) * p.speed * t
                    let y = Double(size.height) * 0.22 + sin(p.angle) * p.speed * t + 520 * t * t
                    var c = context
                    c.opacity = fade
                    c.translateBy(x: CGFloat(x), y: CGFloat(y))
                    c.rotate(by: .radians(p.spin * t))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 3, width: p.size, height: p.size * 0.66)
                    c.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(palette[p.colorIndex]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension Notification.Name {
    static let bookingFlowFinished = Notification.Name("bookingFlowFinished")
}
