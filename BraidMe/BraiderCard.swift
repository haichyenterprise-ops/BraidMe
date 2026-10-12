import SwiftUI

// =============================================================================
// BraiderCard — Cards for the map sheet, upgraded
// Parallax tilt on touch, breathing verified seal, parallax cover backgrounds.
// =============================================================================

// ═══════════════════════════════════════════════════════════════════
// MARK: - Standard Row (medium detent)
// ═══════════════════════════════════════════════════════════════════

struct BraiderCard: View {
    let braider: Braider
    var isHighlighted: Bool = false
    let onTap: () -> Void

    @State private var tilt: CGSize = .zero

    var body: some View {
        Button(action: {
            Haptic.select()
            onTap()
        }) {
            HStack(spacing: Space.sm) {
                avatarWithRing

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: Space.xxs) {
                        Text(braider.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.appInk)
                            .lineLimit(1)
                        if braider.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.gold)
                        }
                    }

                    BMRatingLine(rating: braider.rating, count: braider.reviewCount, size: 11)

                    HStack(spacing: Space.xxs) {
                        Text("from")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appSmoke)
                        Text("£\(braider.priceFrom)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.gold)
                        if !braider.city.isEmpty {
                            Text("·").foregroundStyle(Color.appSmoke)
                            Text(braider.city)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appSmoke)
                    .offset(x: tilt.width * 0.5)
            }
            .padding(.vertical, Space.sm)
            .padding(.horizontal, isHighlighted ? Space.sm : 0)
            .background(isHighlighted ? Color.gold.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button))
            .contentShape(Rectangle())
            .rotation3DEffect(
                .degrees(Double(tilt.width) * 0.4),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = min(max(value.translation.width / 12, -3), 3)
                    let dy = min(max(value.translation.height / 12, -3), 3)
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.7)) {
                        tilt = CGSize(width: dx, height: dy)
                    }
                }
                .onEnded { _ in
                    withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.65)) {
                        tilt = .zero
                    }
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isHighlighted)
    }

    private var avatarWithRing: some View {
        ZStack {
            if braider.verified {
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
                            angle: .degrees(0)
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 66, height: 66)
                    .shadow(color: Color.gold.opacity(0.35), radius: 8)
            }
            BMAvatar(url: braider.avatarUrl, size: 60, initials: initials)
        }
        .frame(width: 66, height: 66)
    }

    private var initials: String {
        let parts = braider.name.split(separator: " ")
        let r = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return r.isEmpty ? "·" : r.uppercased()
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Big Row (expanded detent)
// ═══════════════════════════════════════════════════════════════════

struct BigBraiderRow: View {
    let braider: Braider
    let onTap: () -> Void

    @State private var appeared = false
    @State private var imageParallax: CGFloat = 0

    var body: some View {
        Button(action: {
            Haptic.select()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                if !braider.coverUrl.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        GeometryReader { geo in
                            RemoteImage(url: braider.coverUrl)
                                .frame(width: geo.size.width, height: 200 + abs(imageParallax))
                                .offset(y: imageParallax)
                                .clipped()
                        }
                        .frame(height: 200)
                        .clipped()

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gold)
                            Text(String(format: "%.1f", braider.rating))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.appInk)
                        }
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 5)
                        .background(Color.appSurface.opacity(0.92), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .padding(Space.sm)
                    }
                    .clipShape(
                        .rect(
                            topLeadingRadius: Radius.card,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: Radius.card
                        )
                    )
                }

                HStack(spacing: Space.sm) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: Space.xxs) {
                            Text(braider.name)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.appInk)
                            if braider.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gold)
                            }
                        }

                        if !braider.tagline.isEmpty {
                            Text(braider.tagline)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appAsh)
                                .lineLimit(1)
                        }

                        HStack(spacing: Space.sm) {
                            BMPriceTag(price: braider.priceFrom)
                            if !braider.responseTime.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(braider.responseTime)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                }
                                .foregroundStyle(Color.appAsh)
                            }
                        }
                        .padding(.top, 2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appSmoke)
                }
                .padding(Space.md)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
        }
        .buttonStyle(BMPressStyle(scale: 0.99))
    }
}